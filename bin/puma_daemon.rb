#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.expand_path('..', __dir__), 'app/lib'))

$stdin.reopen(File::NULL, 'r') unless $stdin.tty?
[$stdout, $stderr].each do |io|
  io.reopen(File::NULL, 'w') unless io.tty?
end

require 'cure_api'
module CureAPI
  if PumaDaemon.disable?
    warn "#{PumaDaemon.name}: disabled, skipping"
    exit 0
  end
  PumaDaemon.spawn!
end
