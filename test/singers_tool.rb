require 'webmock'

module CureAPI
  # ⚠⚠ **このテストは GAS へ実通信しない。**✅ #326 で全テストが遮断されるようになった
  # （`TestCase` → `test/fixtures/gas_stub.rb`）が、**歌手は fixture を持たず、ここで自前の
  # 3 件を返す**（後から登録した stub が勝つ）。
  #
  # ⚠ `require 'webmock'` だけでは HTTP アダプタは差し替わらない。**`WebMock.enable!` を
  # 呼ぶまで `stub_request` も `disable_net_connect!` も無言で素通りする。**
  class SingersToolTest < TestCase
    include WebMock::API

    URL = 'https://script.google.test/macros/s/singers/exec'.freeze

    RECORDS = [
      {'name' => '宮本 佳那子', 'members' => [], 'nicknames' => ['かなちゃん', 'かなちょ', 'ちゃん']},
      {'name' => '五條 真由美', 'members' => [], 'nicknames' => ['まいこ', 'ちゃん']},
      {'name' => 'キュア・レインボーズ',
       'members' => ['五條真由美', 'うちやえゆか', '工藤真由', '宮本佳那子']},
    ].freeze

    def setup
      WebMock.enable!
      WebMock.disable_net_connect!
      config['/gas/singers/url'] = URL
      stub_request(:get, "#{URL}?action=singers")
        .to_return(body: RECORDS.to_json, headers: {'Content-Type' => 'application/json'})
      # ⚠ Datasource はシングルトンでキャッシュを持つ。テスト間で持ち越さない。
      Datasource.instance.instance_variable_set(:@singers, nil)
      @tool = Tool.create('singers')
    end

    def teardown
      Datasource.instance.instance_variable_set(:@singers, nil)
      WebMock.reset!
      WebMock.allow_net_connect!
      WebMock.disable!
      super
    end

    def test_all
      singers = @tool.exec

      assert_equal(3, singers.size)
      assert_equal('宮本 佳那子', singers.first[:name])
      assert_equal('application/json; charset=UTF-8', @tool.type)
    end

    def test_index
      assert_equal(['宮本 佳那子', '五條 真由美', 'キュア・レインボーズ'],
        @tool.exec(['singers', 'index']))
    end

    # ⚠ グループは構成員を持つ。ソロ名義は空配列。
    def test_group_has_members
      group = @tool.exec(['singers', 'キュア・レインボーズ'])

      assert_equal(4, group[:members].size)
      assert_includes(group[:members], '宮本佳那子')
      assert_empty(@tool.exec(['singers', '五條 真由美'])[:members])
    end

    # ⚠⚠ **姓名の間の空白は有無どちらでも引ける。**スプレッドシートは「宮本 佳那子」、
    # 曲データの名義は「宮本佳那子」。⚠ ここが効かないと利用側（makoto2 のカバー選曲）が
    # **静かに 1 件も一致しない**形で壊れる。
    def test_lookup_ignores_spacing
      ['宮本 佳那子', '宮本佳那子', '宮本　佳那子'].each do |name|
        assert_equal('宮本 佳那子', @tool.exec(['singers', name])[:name], "'#{name}' で引けない")
      end
    end

    # ⚠ あだ名でも引ける（#399・名前から推せない「まいこ」が本命）。
    def test_lookup_by_nickname
      assert_equal('五條 真由美', @tool.exec(['singers', 'まいこ'])[:name])
      assert_equal('宮本 佳那子', @tool.exec(['singers', 'かなちょ'])[:name])
      assert_equal(['かなちゃん', 'かなちょ', 'ちゃん'], @tool.exec(['singers', '宮本佳那子'])[:nicknames])
    end

    # 🔴 **2 人以上に当たるあだ名では引かない**（取り違えるより無いと言う）。
    def test_ambiguous_nickname_is_not_found
      assert_raise Ginseng::NotFoundError do
        @tool.exec(['singers', 'ちゃん'])
      end
    end

    # ⚠ 古い GAS は `nicknames` を返さない。空配列にそろえる。
    def test_missing_nicknames_become_empty
      assert_empty(@tool.exec(['singers', 'キュア・レインボーズ'])[:nicknames])
    end

    def test_unknown_name_raises
      assert_raise Ginseng::NotFoundError do
        @tool.exec(['singers', '存在しない歌手'])
      end
    end

    # ⚠⚠ **GAS が未デプロイのまま叩かれたら、HTTP の失敗ではなく設定の誤りとして落とす。**
    # 「404 が返る」より「まだ用意していない」と言えたほうが原因がすぐ分かる。
    def test_unconfigured_url_is_a_config_error
      Datasource.instance.instance_variable_set(:@singers, nil)
      config['/gas/singers/url'] = 'REPLACE_ME_AFTER_CLASP_DEPLOY'

      assert_raise Ginseng::ConfigError do
        @tool.exec
      end
    end

    # ⚠ **遮断そのものを見る。**stub していないリクエストが素通りしていないこと。
    def test_net_connect_is_blocked
      Datasource.instance.instance_variable_set(:@singers, nil)
      config['/gas/singers/url'] = 'https://script.google.test/macros/s/unstubbed/exec'

      assert_raise WebMock::NetConnectNotAllowedError do
        @tool.exec
      end
    end
  end
end
