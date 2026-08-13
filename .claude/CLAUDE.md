# cure-api 開発ガイド

## プロジェクト概要

プリキュア淑女録スプレッドシートにアクセスするための独立 API サーバー / CLI ツール。

- **技術スタック**: Ruby / Sinatra (ginseng-web) / Puma
- **データソース**: Google Spreadsheet → GAS (Google Apps Script) → JSON API
- **リポジトリ**: `pooza/cure-api`（旧名 `mulukhiya-rubicure`、GitHub リネーム済み）
- **現バージョン**: 3.1.2

## 経緯

もともとモロヘイヤ (`pooza/mulukhiya-toot-proxy`) に統合されていたが、Bundler 二重管理・`Open3.capture3` の不安定さ・Broken pipe インシデント (2026-03-08) を経て、v3.0.0 で独立デーモンに分離（モロヘイヤ #4144）。設計経緯の詳細はモロヘイヤ側の `docs/custom-api-redesign.md` を参照。

## ブランチ戦略

| ブランチ | 目的 |
|---------|------|
| `main` | リリース済み安定版（デフォルト） |
| `develop` | 開発ブランチ |

## リリース戦略

- マイルストーンは設けず、小さな修正が発生するたびにバージョンをバンプしてリリースする
- `develop` で作業 → `main` にマージ → デプロイの流れ

## デプロイ環境

⚠ **2026-07-28 にキュアスタ！が lbock（さくら VPS）から gomander（Linode）へ移行した。**
旧 lbock は 07-29 に停止済み。⚠ **ステージングも dev22 から dev25 に変わっている**（dev22 は名前解決もできない）。
⚠⚠ **着地ユーザーが `pooza` から `mastodon` に変わった**（SNS・モロヘイヤ・cure-api の 3 つが `~mastodon/repos/` に並ぶ）。
正本は `pooza/chubo2` の `docs/infra-note.md`。

### 本番: キュアスタ！ (gomander.b-shock.co.jp)

| 項目 | 値 |
|------|-----|
| OS | FreeBSD 15（ネットインストーラ導入。持ち込みイメージ由来ではない） |
| Ruby | rbenv（モロヘイヤと共有） |
| パス | `/home/mastodon/repos/cure-api` |
| ポート | 3009 |
| ドメイン | `cure-api.precure.ml` (HTTPS, Let's Encrypt) |
| SSH | `gomander.b-shock.co.jp`（mastodon ユーザー） |
| rc.d | `/usr/local/etc/rc.d/cure_api_puma` |
| monit | `/usr/local/etc/monit.d/cure-api` |

### ステージング: dev25 (キュアスタ！ステージング)

| 項目 | 値 |
|------|-----|
| パス | `/home/mastodon/repos/cure-api` |
| ポート | 3009 |
| ドメイン | `cure-api.st.precure.ml` |
| SSH | `dev25.b-shock.local`（pooza ユーザーで入り、`mastodon` へ sudo） |

### 同居サービス

同じサーバーでモロヘイヤ（ポート 3008）と Mastodon が稼働している。Ruby は rbenv で共有。

## デプロイ手順

### 本番

```bash
ssh gomander.b-shock.co.jp
cd ~/repos/cure-api
sudo service monit stop          # monit 停止（HTTP 監視による誤検知防止）
git pull origin main
bundle install
sudo service cure_api_puma restart
sudo service monit start          # monit 再開
curl -s http://localhost:3009/girls/index | head -1  # 動作確認
```

### ステージング

```bash
ssh dev25.b-shock.local
cd ~mastodon/repos/cure-api
git pull origin main
bundle install
sudo service cure_api_puma restart
```

## 運用上の注意

### rc.d と起動順序

- rc.d スクリプトは `REQUIRE: LOGIN redis` を宣言しているが、cure-api 自体は Redis を使用していない（起動順序の遅延目的で残存しているだけ）
- VPS 再起動直後はネットワークスタックが不安定な場合があり、GAS API への外向き HTTPS 接続が `Errno::EPIPE` で失敗することがある → HTTP クライアントのリトライロジック（v3.0.1、2026-03-28）で対策済み

### monit

- プロセスマッチング `"cure.api.*puma"` で監視
- サービス再起動時は必ず `service monit stop` → 作業 → `service monit start` の手順を踏む
- monit が動いたまま restart すると、stop → start の間にダウン検知→先行起動→「Already started!」エラーになる

### FreeBSD rc.d の制約

- rc.d スクリプトのファイル名にハイフン不可（`cure-api-puma` → `cure_api_puma`）

## API エンドポイント

| パス | 内容 | 形式 |
|------|------|------|
| `/` | エンドポイント一覧（HTML） | HTML |
| `/girls` | すべてのプリキュア | JSON |
| `/girls/index` | プリキュア名の一覧 | JSON |
| `/girls/:name` | 指定したプリキュア | JSON |
| `/girls/calendar` | プリキュアの誕生日カレンダー | iCalendar |
| `/series` | すべてのシリーズ | JSON |
| `/series/index` | シリーズ名の一覧 | JSON |
| `/series/:name` | 指定したシリーズ | JSON |
| `/singers` | すべてのプリキュア歌手 | JSON |
| `/singers/index` | プリキュア歌手名の一覧 | JSON |
| `/singers/:name` | 指定した歌手 | JSON |
| `/cast/calendar` | キャストの誕生日カレンダー | iCalendar |

## ディレクトリ構成

```text
app/lib/cure_api/
  controller.rb    # Sinatra コントローラ（全エンドポイント）
  puma_daemon.rb   # Ginseng::Daemon サブクラス（Puma 起動管理）
  tool.rb          # 抽象 Tool 基底クラス
  tool/            # Tool 実装 (GirlsTool, SeriesTool, CastTool 等)
  datasource.rb    # GAS API からデータ取得・キャッシュ
  girl.rb          # プリキュアデータラッパー
  calendar/        # iCalendar 生成
  config.rb        # 設定
  http.rb          # HTTParty クライアント
bin/
  cure.rb          # CLI エントリポイント
  puma_daemon.rb   # デーモンエントリポイント
config/
  application.yaml # メイン設定（GAS URL、Puma ポート等）
  sample/          # rc.d / systemd / nginx / monit サンプル
gas/
  girls/           # GAS ソース (clasp 管理)
  series/          # GAS ソース (clasp 管理)
  singers/         # GAS ソース (clasp 管理)
docs/
  datasource-design.md  # rubicure gem 脱却の設計メモ・データソース仕様
```

## CI

GitHub Actions (`.github/workflows/test.yml`)。

## 既知の問題・障害履歴

- **2026-03-08**: Broken pipe インシデント（モロヘイヤ統合時代、Open3.capture3 経由）→ 独立デーモン化で解消
- **2026-03-20**: 本番初回デプロイ時に `tmp/cache/` 未存在で起動失敗 → `.gitkeep` 追加で対応済み
- **2026-03-28**: VPS カーネル更新後の再起動で GAS API 呼び出しが `Errno::EPIPE` で失敗。当初 rc.d に Redis 依存を追加したが的外れ（cure-api は Redis 不使用）。同日再発し、HTTP クライアントにリトライロジックを追加して根本対策

## 依存ライブラリに関する注意

### rack / sinatra のアップグレード → ✅ 解禁（2026-08-13）

モロヘイヤで rack 3.2 + sinatra 4.2 の組み合わせにより**異なるアカウントの投稿として送信される**致命的な問題が発生した（2025-10-26、`pooza/mulukhiya-toot-proxy` の `docs/postmortem-2025-10-rack32.md` 参照）。この記述は長らく「モロヘイヤ側での検証を待つ」「安全な組み合わせは rack 3.1.x + sinatra 4.1.x」としていたが、**2 点とも実態と合わなくなっていた。**

- ✅ **待つ条件は満たされた。**sinatra 4.2.1 はモロヘイヤ **v5.33.0** に入っており（`e055d27f`）、**本番 4 台にデプロイ済み**（`pooza/chubo2` の作業履歴）。モロヘイヤの現在の組み合わせは **rack 3.2.6 + sinatra 4.2.1**
- ⚠ **「安全な組み合わせ」の記述はドリフトしていた。**cure-api の lockfile は**この記述より前から rack 3.2.6** になっていた（sinatra だけが 4.1.1 で止まっていた）。⚠ **守っているつもりで、実際には片方しか守れていない状態だった**

#### ⚠⚠ 本当の判定基準は「リクエスト単位の同一性を持つか」

**バージョンの組み合わせではなく、事故が宿る場所で判断する。**あの事故は「**誰のリクエストか**」がリクエストをまたいで混ざったもので、**それを持たないアプリには起こりようがない。**

| | セッション / Cookie | リクエスト単位の資格情報 | 影響 |
| --- | --- | --- | --- |
| モロヘイヤ | ⚠ **あり**（`Rack::Session::Cookie`） | ⚠ **あり**（アカウントごとのトークンで投稿） | 事故が起きた |
| **cure-api** | ✅ **無し**（grep で 0 件） | ✅ **無し**（認証を持たない公開 API・読み取り専用） | ⚠ **構造的に起こらない** |

⚠⚠ **cure-api がリクエスト単位の同一性を持たないのは、たまたまではなく方針。**⚠ **セッション・認証を必要とする機能は、そもそも実装しない**（cure-api は**認証を持たない公開 API** として運用する。この前提は `pooza/makoto2` 側の設計方針にも「cure-api に認証を足す前提の設計をしない」「非公開のものは cure-api の外に置く」として書かれている）。

✅ **したがって条件付きの保留ではなく解除でよい。rack / sinatra は通常の依存として扱う。**⚠ **この判断が効かなくなるのは「認証を持たない公開 API」という方針そのものを見直すときだけ**で、そのときは依存の話ではなく方針の話として扱う。

## セッション開始時の同期手順

会話の最初に「進捗を同期してください」等の指示があった場合、以下の手順を実行する。

### 1. プロジェクトガイドの読み込み

- `.claude/CLAUDE.md` を読む（プロジェクトのルール・構造・履歴の正本）
- `docs/datasource-design.md` — データソース仕様の詳細が必要な場合に参照

### 2. リモートとの同期・状態確認

- `git fetch origin` — **最初に必ず実行**。リモートが正本であり、ローカルの状態を信用しない
- `git log HEAD..origin/main --oneline` — リモートに未取り込みのコミットがないか確認。差分があれば pull を検討
- `git log --oneline -10` — 直近のコミット履歴
- `gh issue list --state open` — open Issue 一覧
- `gh pr list --state open` — open PR 一覧

### 3. Dependabot セキュリティアラート

- `gh api repos/pooza/cure-api/dependabot/alerts` で open アラートを確認
- 0件なら対応不要、あれば提案

### 4. 外部リポジトリの同期確認（chubo2）

- `cd ~/repos/chubo2 && git fetch origin` + `git log HEAD..origin/main --oneline` でリモートとの差分を確認
- `docs/infra-note.md` に cure-api 関連の変更があれば内容を確認

### 5. 同期結果の報告

- 現在のブランチ・状態、各確認項目の結果をまとめて報告する

## 情報の記載先ルール

- **課題・タスク** → GitHub Issue で管理（インフラ面の課題は `pooza/chubo2` の Issue として起票）
- **プロジェクト共有すべき知見** → `.claude/CLAUDE.md` や `docs/` 配下など git 管理下のファイルに記載
- **インフラ情報** → `pooza/chubo2` リポジトリの `docs/infra-note.md` に記載

## 関連プロジェクト・外部ドキュメント

- **MAKOTO** (`pooza/makoto2`): `/singers` の利用者。バースデーライブ（#13）のゲストコーナーで出すカバーを「プリキュア歌手の持ち歌」に限るために引く。⚠ **MAKOTO 側にプリキュアの情報を抱え込まない**方針なので、足りない情報は cure-api を伸ばす
- **モロヘイヤ** (`pooza/mulukhiya-toot-proxy`): 元の統合先。カスタム API 機能は 5.9.0 で削除済み。分離の設計経緯は `docs/custom-api-redesign.md` にある
- **キュアスタ！**: cure-api の唯一の利用インスタンス
- **インフラノート** (`pooza/chubo2` の `docs/infra-note.md`): サーバー構成・デプロイ履歴の正本。cure-api に関連するセクション:
  - 「cure-api ステージングデプロイ (2026-03-19)」— dev22 への初回デプロイ記録・判明した問題
  - 「cure-api 本番デプロイ (2026-03-20)」— lbock への v3.0.0 デプロイ記録・nginx/monit/rc.d 設定の詳細
