#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.expand_path('..', __dir__), 'app/lib'))

# ⚠⚠ **黙らせるのは常駐する経路だけ。**`start` / `restart` は常駐して標準出力の
# 相手が居なくなるので `Errno::EPIPE` を避けるために落とすが、**`stop` / `status` の
# 出力は監視やスクリプトから読めないと意味が無い。**
#
# ⚠ 無条件に落としていたため、**起動失敗のエラーが 1 文字も出ずに「何も起きない」
# だけになっていた**（2026-08-13・dev25 で実際に原因の特定に時間を溶かした）。
DAEMONIZING = ['start', 'restart'].include?(ARGV.first.to_s).freeze

if DAEMONIZING
  $stdin.reopen(File::NULL, 'r') unless $stdin.tty?
  [$stdout, $stderr].each do |io|
    io.reopen(File::NULL, 'w') unless io.tty?
  end
end

require 'cure_api'
module CureAPI
  if PumaDaemon.disable?
    warn "#{PumaDaemon.name}: disabled, skipping"
    exit 0
  end
  PumaDaemon.spawn!
end
