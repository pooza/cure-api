# rubicure gem脱却の設計メモ

## 経緯

rubicureライブラリはRubyの実装としての正しさを追求しているが、肝心のデータに間違いがあり方向性の違いを感じたため、自前のデータソースに切り替えることにした。

## データソース

- girls / series / singers でそれぞれ別のGoogle Spreadsheetを使用
  - [girls用スプレッドシート](https://docs.google.com/spreadsheets/d/1Tba5B-l2zwLkYs-SRhI_whKHNY86CYmlIp_Xu6WPILk/edit)
  - [series用スプレッドシート](https://docs.google.com/spreadsheets/d/1BLJXOFMqayF75-sVLJY56XwnNhmyck_RGRLWKm3wXB4/edit)
  - [singers用スプレッドシート（プリキュア歌手辞書）](https://docs.google.com/spreadsheets/d/1ZAtmhHN5mTsmRUB5yekBDEHC6G5fw8vWvCp14vkSNB8/edit)
- GAS (Google Apps Script) でJSON APIとして公開
- GASのコードは `gas/girls/`, `gas/series/`, `gas/singers/` で管理し、claspでデプロイ
- Rakeタスクでpush/deployが可能:
  - `rake clasp:girls:push` / `rake clasp:series:push` / `rake clasp:singers:push` — コードをpush
  - `rake clasp:girls:deploy` / `rake clasp:series:deploy` / `rake clasp:singers:deploy` — push後にdeploy

## スプレッドシート構成

### girlsスプレッドシート

| カラム | 内容 |
|---|---|
| `key` | 識別キー (例: `cure_sword`) |
| `cure_name` | プリキュア名 (例: キュアソード) |
| `human_name` | 人間名 (例: 剣崎 真琴) |
| `cv` | 声優 |
| `nickname` | ニックネーム (カンマ区切り) |
| `nickname_unofficial` | 非公式ニックネーム (カンマ区切り) |
| `birthday` | 誕生日 (m/d形式) |
| `cv_birthday` | 声優誕生日 (m/d形式) |
| `title` | 称号 (例: 光の使者) |

#### 🔴 この表は名簿ではない。人数を数える用途に使わない

**収録の基準はおおむね「本編でメインキャラクターだった者」。**⚠⚠ **ただしその境界はどこまでも曖昧で、厳密に定義することにも意味がない**（2026-09-05・オーナー）。

| ⚠ 曖昧なところ | 例 |
|---|---|
| **劇場版のキャラクターを数えてよいか** | キュアシュプリーム / キュアエコー |
| **メインキャラクターだが、劇中の扱いはプリキュアではない者** | シャイニールミナス / ミルキィローズ |
| 🔴 **そもそも載っていないプリキュアが劇中に多数いる** | — |

🔴 **したがって「プリキュアは何人か」に、この表は答えられない。**⚠⚠ **行数を人数として出さないこと** — ⚠ **`/girls/index` の件数も同じ**（**答えのある問いではない**）。

⚠ **境界を厳密に引き直す作業もしない。**🔴 **どこに引いても恣意的**で、**引き直しても API が答えられる問いは 1 つも増えない。**

##### 🔴 曖昧なのは収録基準ではなく、作品の側

⚠⚠ **「基準を厳密にすれば数えられる」ではない。**🔴 **作品自体が有限の名簿を否定している。**

- **劇場版でキュアミューズが「女の子は誰だってプリキュアになれる」と言った**
- 🔴 **『HUGっと！プリキュア』はテーマが「なりたい自分になる」（自己実現）で、クライマックスでそれを望んだ全人類がプリキュアになった**（⚠ **オチとしては破綻しており賛否両論** — **だが「なかったこと」にはできない**）

⚠ **したがって数字を出さないのは妥協ではなく、原作に忠実な結論。**

#### 🔴 プリキュア名から本名は引けない（襲名がある）

⚠⚠ **プリキュア名は劇中で一意ではない。**🔴 **同じ名前を継ぐ設定がある** — **キュアフローラ / キュアマーメイド / キュアトゥインクルには「先代」がいる**（2026-09-05・オーナー）。

✅ **実用上は「一意である」前提で扱ってよい**（2026-09-05・オーナー）。⚠ **いまの表では `precure_name` は重複していない**（実測 **0 件**）し、🔴 **先代はメインキャラクターの基準に入らないので、当面そうなる見込みも無い。**

🔴 **ただし保証ではない、というだけ書いておく。**⚠⚠ **一意性はデータの性質ではなく、収録基準のたまたまの帰結** — ⚠ **破れたときに「なぜ壊れたか」を追えるようにしておくためのもので、いま何かを避ける話ではない。**

- 🔴 **識別子は `key`。**⚠⚠ **`key` は行を指すのであって、「その名前を持つ唯一の人」を指さない**（`cure_flora` ＝ **当代**）
- ⚠ **`find_girl` が見るのは `key` だけ**（`/girls/flora` も `cure_` を補って `key` に当てている）。**逆引きの口はもともと無い**ので、⚠⚠ **利用側が `cure_name` で引く対応表を持つなら、それは利用側の前提。**⚠ **持ってよいが、API が支えているわけではない**

⚠⚠ **上の「1 行 ＝ 1 変身形態」と対になっている** — 🔴 **1 人が複数行に現れる**（変身形態）**一方で、1 つの名前が複数人を指しうる**（襲名）。⚠ **どちらも「行 ↔ 人物 ↔ 名前」が素直に 1 対 1 だという前提を壊す。**

#### ⚠ `girls` は歴史的な名前。男性のプリキュアも入る

🔴 **名前に反して、男性のプリキュアが「例外」と呼べないほど載っている**（2026-09-05）。⚠⚠ **改名しない**（オーナー判断）— **エンドポイント名・`key`・GAS の `action` まで連動する破壊的変更**で、⚠ **利用側（モロヘイヤ / makoto2 / 増子）を全部書き換えることになる。**

⚠ **性別の列は持たない。**🔴 **持たせる予定も無い**（**この API が答えるのは「誰がいつ生まれたか」であって、区分ではない**）。

#### ⚠⚠ 1 行 ＝ 1 変身形態。人物ではない

**同じ人物が複数のプリキュアに変身し分けるケースがある。**⚠ **その場合は形態ごとに 1 行を立て、`human_name` / `cv` が複数の行に重複して現れる。**

🔴 **人物に属するデータ（`birthday` / `cv_birthday`）は「本来の姿」の行にだけ載せる。**⚠⚠ **もう一方の形態の行では空にする** — **両方に載せると 1 人が 2 回祝われる。**

⚠ **スプレッドシートに人物テーブルを分けずに済ませるための約束事**（列を増やすほうが高くつく）。**この関係は API のどこにも現れない** — ⚠⚠ **`human_name` が一致することだけが手掛かり。**

**実データ（2026-09-05 時点・3 グループ 6 行）:**

| 人物 | 🔴 本来の姿（誕生日を持つ） | もう一方の形態（空） |
|---|---|---|
| 日向 咲 | `cure_bloom`（8/7） | `cure_bright` |
| 美翔 舞 | `cure_egret`（11/20） | `cure_windy` |
| 森亜 るるか | `cure_arcana`（11/1） | `cure_arcana_shadow` |

##### ⚠ 利用側が踏むところ

- 🔴 **`birthday` が空なのは「未入力」とは限らない。**⚠⚠ **別形態の行なので、本来の姿の行が持っている** — ⚠ **`cure_bright` を見て「日向 咲の誕生日は不明」と結論しないこと**
- ⚠⚠ **同じ人物が複数行に現れるので、行を数えても人数にはならない** — 🔴 **そもそも人数を数える用途に使わない**（→ 上記「この表は名簿ではない」）
- ✅ **`/girls/calendar` はこの約束事の上で正しく動く** — **`birthday?` で絞るので、1 人が 2 回並ばない**

##### 🔴 誕生日を移したときは本番を再起動する

⚠⚠ **`Datasource` は Singleton で `@girls ||=` とメモ化しており、TTL も無効化の口も無い**（→ 下記「Ruby側の構成」）。⚠ **スプレッドシートを直しても、走っているプロセスは古い一覧を持ち続ける。**

```sh
sudo service cure_api_puma restart   # gomander
```

⚠ **2026-09-05 に実際に踏んだ** — 🔴 **`cure_arcana` を足して誕生日を `cure_arcana_shadow` から移したのに、本番だけが 100 行のまま**だった。⚠⚠ **足りないのは 1 行だけではない** — **11/1 を「キュアアルカナ・シャドウ の誕生日」として出し続けていた**（⚠ **ステージングは反映済みだった** ＝ **差はプロセスの起動時刻だけ**）。

⚠ **リロードの口は足さない**（2026-09-05 判断）。🔴 **このサービスは捨てて困る状態を持たない**（メモ化だけ）ので、**再起動が事実上いちばん軽いリロード** — ⚠⚠ **`/reload` を生やせば公開の口が 1 つ増え、TTL を入れれば「いつ反映されるか分からない窓」を代わりに抱えることになる。**

### seriesスプレッドシート

| カラム | 内容 | 使用 |
|---|---|---|
| `series` | シリーズ名 (例: ドキドキ!プリキュア) | o |
| `nicknames` | ニックネーム (カンマ区切り) | aliasesのみ |
| `related_series` | 関連シリーズ (カンマ区切り) | aliasesのみ |
| `key` | 識別キー (例: `dokidoki`) | o |

### singersスプレッドシート（プリキュア歌手辞書）

| カラム | 内容 |
|---|---|
| `name` | 歌手・グループ名 (例: 宮本 佳那子) |
| `members` | グループの構成員 (カンマ区切り。ソロ名義は空) |

⚠ **`key` 列を持たない。**識別子は `name` そのもの（人名に機械的なキーを振る意味が薄く、スプレッドシートの列を増やすことになるため）。

⚠⚠ **表記の揺れは `Datasource.normalize_name` が吸収する。**スプレッドシートは「宮本 佳那子」のように姓名の間に空白を持つが、iTunes 由来の曲データの名義は「宮本佳那子」。NFKC 正規化して空白を落として比較する。**利用側でそれぞれ正規化を書かせない。**

## GAS APIエンドポイント

### girls (`gas/girls/`)

- `?action=girls` — 全プリキュアの詳細データ (JSON配列)
- パラメータなし — 名前の関連付けマップ (既存互換)

### series (`gas/series/`)

- `?action=series` — 全シリーズデータ (JSON配列、`key`と`series`のみ)
- パラメータなし — ニックネーム/関連シリーズのマッピング (既存互換)

### singers (`gas/singers/`)

- `?action=singers`（既定） — 全歌手データ (JSON配列、`name` と `members`)
- `?action=index` — 歌手名の配列

## 新しいスプレッドシートを足すとき

⚠ **GAS プロジェクトの作成とデプロイは Google アカウントの操作なので、リポジトリ側だけでは完結しない。**

1. `gas/{name}/` に `main.gs` / `appsscript.json` / `.clasp.json` を置く
2. ⚠ **対象のスプレッドシートを開き、拡張機能 → Apps Script でコンテナバインドのプロジェクトを作る**（スタンドアロンだと `SpreadsheetApp.getActiveSpreadsheet()` が nil になる）
3. そのプロジェクトの **スクリプト ID** を `gas/{name}/.clasp.json` の `scriptId` に書く
4. `rake clasp:{name}:push` → `rake clasp:{name}:deploy`
   - ⚠ deploy タスクが `config/application.yaml` の `/gas/{name}/url` を自動で書き換える
5. `app/task/clasp.rb` の対象リストに `{name}` を足す
6. `Datasource#fetch_{name}` / `{Name}Tool` / `Controller` のルート / `config` の `tools` を足す

⚠ **デプロイのアクセス設定は `ANYONE_ANONYMOUS`**（`appsscript.json`）。cure-api は認証を持たない公開 API なので、GAS 側も匿名アクセスで揃える。

## Ruby側の構成

- `Datasource` — GAS APIからデータを取得しキャッシュするシングルトン
- `Girl` — 各プリキュアのデータラッパー。rubicureの`Girl`互換メソッドを提供
- 各Tool/Calendarクラスは `Datasource.instance` 経由でデータにアクセス

## rubicureからの主な変更点

- `Precure.all` → `Datasource.instance.girls`
- `::Rubicure::Girl.find(sym)` → `Datasource.instance.find_girl(name)`
- `::Rubicure::Series.find(sym)` → `Datasource.instance.find_series(name)`
- `transform_message` は廃止 (スプレッドシートに該当データなし)

## 設定

`config/application.yaml` にGAS URLをgirls/series別に設定:

```yaml
gas:
  girls:
    url: https://script.google.com/macros/s/DEPLOYMENT_ID/exec
  series:
    url: https://script.google.com/macros/s/DEPLOYMENT_ID/exec
```
