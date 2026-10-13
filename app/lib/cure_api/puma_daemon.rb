module CureAPI
  class PumaDaemon < Ginseng::Daemon
    include Package

    # ⚠⚠ **`bundle exec` を通す。**素の `puma` を叩くと、**Ruby の default gem が先に
    # activate されて lockfile と衝突する。**
    #
    # 実際に踏んだ（2026-08-13・dev25）: Ruby 4.0.6 の default gem は fileutils 1.8.0 だが、
    # `ginseng-core` が `fileutils (~> 1.7.0)` を要求するため lockfile は 1.7.3。
    # ⚠ `You have already activated fileutils 1.8.0, but your Gemfile requires 1.7.3`
    # で起動しなくなった。
    #
    # ⚠ **Ruby のバージョンを下げて回避しない。**あの箱では `.ruby-version` を手で
    # 4.0.5 に書き換えて凌いだ痕跡が残っていたが、**リポジトリに戻らないドリフトを
    # 増やすだけ**で、default gem が動くたびに再発する。
    # ⚠⚠ **待受アドレスを明示する（`--port` に任せない）。**
    #
    # puma 8 は `--port` だけ渡すと **`[::]` に bind する**（7 までは `0.0.0.0`）。
    # ⚠ FreeBSD は `net.inet6.ip6.v6only` の既定が 1 なので、⚠⚠ **IPv4 の接続を
    # 一切受けなくなる。**nginx の `proxy_pass http://localhost:3009` が IPv4 に
    # 落ちると、**アプリは生きているのに 502** になる（2026-08-13・dev25 で実際に踏んだ）。
    # `pooza/chubo2#105`（proxy_pass の localhost が ::1 に落ちる）と同じ型の罠。
    #
    # ⚠ **IPv4 と IPv6 を両方 bind する手は採れない。**Linux は `[::]` が IPv4 を
    # 兼ねるため、2 つ並べると 2 本目が `EADDRINUSE` で落ちる（実測）。
    # **逆プロキシからしか叩かれない**ので、puma 7 と同じ `0.0.0.0` に揃える。
    def command
      return Ginseng::CommandLine.new([
        'bundle', 'exec', 'puma',
        File.join(Environment.dir, 'config.ru'),
        '--bind', "tcp://0.0.0.0:#{config['/puma/port']}",
        '--environment', Environment.type
      ])
    end

    def self.disable?
      return false
    end
  end
end
