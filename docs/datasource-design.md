# rubicure gem脱却の設計メモ

## 経緯

rubicureライブラリはRubyの実装としての正しさを追求しているが、肝心のデータに間違いがあり方向性の違いを感じたため、自前のデータソースに切り替えることにした。

## データソース

- girlsとseriesで別々のGoogle Spreadsheetを使用
  - [girls用スプレッドシート](https://docs.google.com/spreadsheets/d/1Tba5B-l2zwLkYs-SRhI_whKHNY86CYmlIp_Xu6WPILk/edit)
  - [series用スプレッドシート](https://docs.google.com/spreadsheets/d/1BLJXOFMqayF75-sVLJY56XwnNhmyck_RGRLWKm3wXB4/edit)
- GAS (Google Apps Script) でJSON APIとして公開
- GASのコードは `gas/girls/`, `gas/series/` で管理し、claspでデプロイ
- Rakeタスクでpush/deployが可能:
  - `rake clasp:girls:push` / `rake clasp:series:push` — コードをpush
  - `rake clasp:girls:deploy` / `rake clasp:series:deploy` — push後にdeploy

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

### seriesスプレッドシート

| カラム | 内容 | 使用 |
|---|---|---|
| `series` | シリーズ名 (例: ドキドキ!プリキュア) | o |
| `nicknames` | ニックネーム (カンマ区切り) | aliasesのみ |
| `related_series` | 関連シリーズ (カンマ区切り) | aliasesのみ |
| `key` | 識別キー (例: `dokidoki`) | o |

## GAS APIエンドポイント

### girls (`gas/girls/`)

- `?action=girls` — 全プリキュアの詳細データ (JSON配列)
- パラメータなし — 名前の関連付けマップ (既存互換)

### series (`gas/series/`)

- `?action=series` — 全シリーズデータ (JSON配列、`key`と`series`のみ)
- パラメータなし — ニックネーム/関連シリーズのマッピング (既存互換)

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
