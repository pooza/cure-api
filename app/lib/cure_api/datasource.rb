module CureAPI
  class Datasource
    include Package
    include Singleton

    def girls
      @girls ||= fetch_girls.map {|record| Girl.new(record)}
    end

    def find_girl(name)
      name = name.to_s
      girls.find {|g| [name, "cure_#{name}"].include?(g.key)}
    end

    def series
      @series ||= fetch_series
    end

    def find_series(name)
      name = name.to_s
      series.find {|s| s[:key] == name}
    end

    # プリキュア歌手（「プリキュア歌手辞書」スプレッドシート）。
    #
    # ⚠ **`key` 列を持たないので、識別子は `name` そのもの。**girls / series と違って
    # ASCII のキーが無い（人名に機械的なキーを振る意味が薄く、スプレッドシートの
    # 列を増やすことになるため）。
    def singers
      @singers ||= fetch_singers
    end

    # ⚠⚠ **表記の揺れを吸収して引く。**スプレッドシートは「宮本 佳那子」のように
    # 姓名の間に空白を持つが、⚠ **iTunes 由来の曲データの名義は「宮本佳那子」**。
    # 空白の有無で引けなくなると、利用側（`pooza/makoto2` のカバー選曲）が
    # **静かに 1 件も一致しない**形で壊れる。
    def find_singer(name)
      key = self.class.normalize_name(name)
      return nil if key.empty?
      singers.find {|s| self.class.normalize_name(s[:name]) == key}
    end

    # ⚠ 全角・半角と空白を落とすだけ。**表記の同一性の判定はここが唯一の正本**に
    # なるので、利用側でそれぞれ正規化を書かせない。
    def self.normalize_name(value)
      value.to_s.unicode_normalize(:nfkc).gsub(/[[:space:]]/, '')
    end

    private

    def initialize
      @http = HTTP.new
    end

    def fetch_girls
      url = "#{config['/gas/girls/url']}?action=girls"
      @http.get(url).map {|record| record.transform_keys(&:to_sym)}
    end

    def fetch_series
      url = "#{config['/gas/series/url']}?action=series"
      @http.get(url).map do |record|
        h = record.transform_keys(&:to_sym)
        h[:title] = h.delete(:series) if h.key?(:series)
        h
      end
    end

    def fetch_singers
      url = config['/gas/singers/url'].to_s
      # ⚠⚠ **未デプロイのまま叩かれたら、HTTP の失敗ではなく設定の誤りとして落とす。**
      # 「404 が返る」より「まだ用意していない」と言えたほうが、原因がすぐ分かる。
      if url.empty? || url.include?('REPLACE_ME')
        raise Ginseng::ConfigError, '/gas/singers/url is not configured (GAS が未デプロイ)'
      end
      @http.get("#{url}?action=singers").map do |record|
        h = record.transform_keys(&:to_sym)
        h[:members] = Array(h[:members])
        h
      end
    end
  end
end
