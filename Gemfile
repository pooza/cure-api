source 'https://rubygems.org'
ruby '~>4.0.1'
# ⚠⚠ 版で固定する。`branch: 'main'` だと、向こうの main にマージされた瞬間が露出になり、
# 破壊的変更が**次の `bundle update`（＝無関係な PR の中）**で出る（pooza/ginseng-style#103）。
# 🔴 版は手で上げる（`tag:` を書き換えて `bundle update ginseng-core ginseng-web`）。
#   ⚠⚠ dependabot は `versioning-strategy: lockfile-only` なので Gemfile の `tag:` を
#   書き換えられず、版上げの PR は来ない（→ .github/dependabot.yml）。
# ⚠ この固定は「いま lock にある版を書き写しただけ」で、ginseng-core の revision は動いていない。
gem 'ginseng-core', github: 'pooza/ginseng-core', require: 'ginseng', tag: 'v1.23.7'
# ⚠ v2.0.0 と、いま刺さっている revision (2f4fd0e) の**配布物は完全に同一**
#   （差分は .github/ と向こう自身の Gemfile だけ）。⚠⚠ v3.0.0 は破壊的変更なので
#   ここでは上げない（pooza/ginseng-web#127。上の rack / sinatra などの宣言がその前提）。
gem 'ginseng-web', github: 'pooza/ginseng-web', tag: 'v2.0.0'
gem 'icalendar'
gem 'puma'
# ⚠⚠ rack / rack-session / sinatra / tilt は ginseng-web が使っていないのに宣言していた
# 依存で、版を決めているのも向こうだった。3.0.0 で外れるので、自分で持つ
# （pooza/ginseng-web#133 / #359）。⚠ cure-api は sinatra を実使用している
# （app/lib/cure_api.rb の require 'sinatra/base'）のに宣言が無い状態だった。
#
# 🔴 床の由来は 2025-10 のモロヘイヤのトークン汚染事故（rack 3.2.3 + Sinatra 4.2.0 で
# 「他のユーザーのトークンで投稿が送信される」）。⚠⚠ CVE も upstream の Issue も無く
# 原因も未特定なので、advisory では版を判定できない。
# 正本: pooza/mulukhiya-toot-proxy の docs/archive/postmortem-2025-10-rack32.md
#
# ⚠ **上限（`~>`）はモロヘイヤだけが持つ。**あちらはリクエスト単位でトークンを持つので
# 事故が直撃するが、cure-api は同じ形の状態を持たない。ここは床だけにしてある
# （pooza/mulukhiya-toot-proxy#4663 の 3. と同じ切り分け）。
gem 'rack', '>= 3.2.5' # 2026-02 の同時アクセステスト (500 req × 2 並列・不整合 0) が通った版
gem 'rack-session', '>= 2.1.1' # CVE-2025-46336
# 🔴 require: 'sinatra/base' を外さない。ginseng-core の Bundler.require が
# 素の `sinatra` を読むと、クラシックモード（トップレベルの Sinatra::Delegator と
# at_exit のランナー）が入る。⚠⚠ 実測（2026-09-06）: この宣言を require 無しにすると
# bin/cure.rb などの経路で main が get / set に応答するようになる（develop では false）。
# ⚠ アプリは app/lib/cure_api.rb で sinatra/base だけを読むモジュラー構成。
gem 'sinatra', '>= 4.2.1', require: 'sinatra/base' # 🔴 4.2.0 は事故版。CVE-2024-21510 の床 4.1.0 も含む
gem 'tilt', '>= 2.1.0'

group :development do
  # ⚠⚠ タグではなく SHA で固定する（pooza/ginseng-style#75）。タグは付け替えられる。
  gem 'ginseng-style', github: 'pooza/ginseng-style',
    ref: 'ed862dcf9550d704ee670f65a30a333a694b883a', require: false # v1.1.12
  gem 'rack-test'
  gem 'ricecream'
  gem 'test-unit'
  gem 'timecop'
  gem 'webmock'
end
