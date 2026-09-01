source 'https://rubygems.org'
ruby '~>4.0.1'
gem 'ginseng-core', github: 'pooza/ginseng-core', require: 'ginseng', branch: 'main'
gem 'ginseng-web', github: 'pooza/ginseng-web', branch: 'main'
gem 'icalendar'
gem 'puma'

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
