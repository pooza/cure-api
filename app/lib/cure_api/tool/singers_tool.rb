module CureAPI
  # プリキュア歌手（「プリキュア歌手辞書」スプレッドシート）。
  #
  # ⚠ **グループは `members` に構成員を持つ**（キュア・レインボーズ = 五條真由美,
  # うちやえゆか, …）。ソロ名義は空配列。
  #
  # 利用側の例: `pooza/makoto2` のバースデーライブ（#13）は、⚠ **ゲストコーナーで
  # 出すカバーを「プリキュア歌手の持ち歌」に限る**ためにこれを引く。カラオケレーベル
  # （歌っちゃ王）やオルゴール盤が混ざるのを、名義の側で落とす。
  class SingersTool < Tool
    def exec(args = {})
      case args[1]&.underscore
      when nil
        return all
      when 'index'
        return index
      else
        return singer(args[1])
      end
    end

    def index
      return datasource.singers.map {|s| s[:name]}
    end

    def all
      return datasource.singers
    end

    def singer(name)
      s = datasource.find_singer(name)
      raise Ginseng::NotFoundError, "singer '#{name}' not found" unless s
      return s
    end

    def help
      return [
        'bin/cure.rb singers - すべてのプリキュア歌手 (JSON)',
        'bin/cure.rb singers index - すべてのプリキュア歌手の名前 (JSON)',
        'bin/cure.rb singers :name - 指定した歌手 (JSON)',
        '  ex) bin/cure.rb singers 宮本佳那子 # 姓名の間の空白は有無どちらでも引ける',
      ]
    end
  end
end
