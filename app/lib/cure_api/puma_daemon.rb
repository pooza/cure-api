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
    def command
      return Ginseng::CommandLine.new([
        'bundle', 'exec', 'puma',
        File.join(Environment.dir, 'config.ru'),
        '--port', config['/puma/port'].to_s,
        '--environment', Environment.type
      ])
    end

    def self.disable?
      return false
    end
  end
end
