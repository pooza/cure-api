# cure-api 開発ガイド

## プロジェクト概要

プリキュア淑女録スプレッドシートにアクセスするための独立 API サーバー / CLI ツール。

- **技術スタック**: Ruby / Sinatra (ginseng-web) / Puma
- **データソース**: Google Spreadsheet → GAS (Google Apps Script) → JSON API
- **リポジトリ**: `pooza/cure-api`（旧名 `mulukhiya-rubicure`、GitHub リネーム済み）
- **現バージョン**: 3.0.1

## 経緯

もともとモロヘイヤ (`pooza/mulukhiya-toot-proxy`) に統合されていたが、Bundler 二重管理・`Open3.capture3` の不安定さ・Broken pipe インシデント (2026-03-08) を経て、v3.0.0 で独立デーモンに分離（モロヘイヤ #4144）。設計経緯の詳細はモロヘイヤ側の `docs/custom-api-redesign.md` を参照。

## ブランチ戦略

| ブランチ | 目的 |
|---------|------|
| `main` | リリース済み安定版（デフォルト） |
| `develop` | 開発ブランチ |

## デプロイ環境

### 本番: キュアスタ！ (lbock.b-shock.co.jp)

| 項目 | 値 |
|------|-----|
| OS | FreeBSD 14.3-RELEASE |
| Ruby | 3.3.10 (rbenv、モロヘイヤと共有) |
| パス | `/home/pooza/repos/cure-api` |
| シンボリックリンク | `~/repos/mulukhiya-rubicure` → `cure-api` |
| ポート | 3009 |
| ドメイン | `cure-api.precure.ml` (HTTPS, Let's Encrypt) |
| SSH | `curesta_mulukhiya`（pooza ユーザー） |
| rc.d | `/usr/local/etc/rc.d/cure_api_puma` |
| monit | `/usr/local/etc/monit.d/cure-api` |
| nginx | `/etc/nginx/servers/cure-api.precure.ml.conf` |

rc.conf:
```
cure_api_enable="YES"
cure_api_path="/home/pooza/repos/cure-api"
cure_api_user="pooza"
```

### ステージング: dev22 (キュアスタ！ステージング)

| 項目 | 値 |
|------|-----|
| パス | `/home/pooza/repos/mulukhiya-rubicure`（後日リネーム予定） |
| ポート | 3009 |
| ドメイン | `cure-api.st.precure.ml` |
| SSH | `dev22_mulukhiya`（pooza ユーザー） |

### 同居サービス

同じサーバーでモロヘイヤ（ポート 3008）と Mastodon が稼働している。Ruby は rbenv で共有。

## デプロイ手順

### 本番

```bash
ssh curesta_mulukhiya
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
ssh dev22_mulukhiya
cd ~/repos/mulukhiya-rubicure
git pull origin main
bundle install
sudo service cure_api_puma restart
```

## 運用上の注意

### rc.d と起動順序

- rc.d スクリプトは `REQUIRE: LOGIN redis` で Redis 依存を宣言している
- VPS 再起動時に Redis より先に起動すると失敗する（2026-03-28 障害で発覚、修正済み）
- monit がプロセス不在を検知して自動復旧するが、rc.d の依存宣言が正しければ発生しない

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
docs/
  datasource-design.md  # rubicure gem 脱却の設計メモ・データソース仕様
```

## CI

GitHub Actions (`.github/workflows/test.yml`)。

## 既知の問題・障害履歴

- **2026-03-08**: Broken pipe インシデント（モロヘイヤ統合時代、Open3.capture3 経由）→ 独立デーモン化で解消
- **2026-03-20**: 本番初回デプロイ時に `tmp/cache/` 未存在で起動失敗 → `.gitkeep` 追加で対応済み
- **2026-03-28**: VPS カーネル更新後の再起動で起動失敗 → rc.d に `redis` 依存追加で対応済み（monit が自動復旧していた）

## 関連プロジェクト・外部ドキュメント

- **モロヘイヤ** (`pooza/mulukhiya-toot-proxy`): 元の統合先。カスタム API 機能は 5.9.0 で削除済み。分離の設計経緯は `docs/custom-api-redesign.md` にある
- **キュアスタ！**: cure-api の唯一の利用インスタンス
- **インフラノート** (`pooza/chubo2` の `docs/infra-note.md`): サーバー構成・デプロイ履歴の正本。cure-api に関連するセクション:
  - 「cure-api ステージングデプロイ (2026-03-19)」— dev22 への初回デプロイ記録・判明した問題
  - 「cure-api 本番デプロイ (2026-03-20)」— lbock への v3.0.0 デプロイ記録・nginx/monit/rc.d 設定の詳細
