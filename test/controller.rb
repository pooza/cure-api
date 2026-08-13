require 'rack/test'
require 'webmock'

module CureAPI
  # ⚠⚠ **未知のパスに 200 を返していた回帰を止めるためのテスト。**
  #
  # `after` フィルタが `@renderer.status`（既定 200）で Sinatra の 404 を上書きしており、
  # **`/nonexistent` が「HTTP 200 ＋ `<h1>Not Found</h1>`」で返っていた**（2026-08-13）。
  # ⚠ 利用側はステータスでしか失敗を判定できないので、⚠⚠ **未実装のエンドポイントを
  # 叩いた `pooza/makoto2` が 200 を成功と受け取り、HTML を JSON として扱って
  # 黙って 0 件になった。**
  class ControllerTest < TestCase
    include Rack::Test::Methods
    include WebMock::API

    URL = 'https://script.google.test/macros/s/singers/exec'.freeze
    GIRLS_URL = 'https://script.google.test/macros/s/girls/exec'.freeze

    def app
      return Controller
    end

    def setup
      WebMock.enable!
      WebMock.disable_net_connect!
      config['/gas/singers/url'] = URL
      stub_request(:get, "#{URL}?action=singers")
        .to_return(body: [{'name' => '宮本 佳那子', 'members' => []}].to_json,
          headers: {'Content-Type' => 'application/json'})
      # ⚠ girls も遮断する。stub しないと `/girls/zzz` が通信できずに 500 になり、
      # 「ハンドラが立てた 404」を見るテストが別の理由で落ちる。
      config['/gas/girls/url'] = GIRLS_URL
      stub_request(:get, "#{GIRLS_URL}?action=girls")
        .to_return(body: [{'key' => 'cure_sword', 'cure_name' => 'キュアソード'}].to_json,
          headers: {'Content-Type' => 'application/json'})
      reset_cache
    end

    def reset_cache
      [:@singers, :@girls].each do |name|
        Datasource.instance.instance_variable_set(name, nil)
      end
    end

    def teardown
      reset_cache
      WebMock.reset!
      WebMock.allow_net_connect!
      WebMock.disable!
      super
    end

    # ⚠⚠ **ルートに当たらなければ 404。**ここが 200 に戻ると、利用側は失敗を
    # 検知できないまま壊れたデータを掴む。
    def test_unknown_path_is_not_found
      get '/nonexistent'

      assert_equal(404, last_response.status)
      assert_equal("'/nonexistent' not found", JSON.parse(last_response.body)['error'])
    end

    # ⚠ **ハンドラが自分で立てた 404 の本文を潰さない。**`not_found` で拾うと
    # 固有のメッセージが消えて、何が無いのか分からなくなる。
    def test_handler_owned_not_found_keeps_its_message
      get '/girls/zzz'

      assert_equal(404, last_response.status)
      assert_equal("girl 'zzz' not found", JSON.parse(last_response.body)['error'])
    end

    def test_singers_returns_json
      get '/singers'

      assert_equal(200, last_response.status)
      assert_equal('宮本 佳那子', JSON.parse(last_response.body).first['name'])
    end

    # ⚠ `/singers/index` は `/singers/:name` より先に定義すること（順序が逆だと
    # `index` という名前の歌手を探しに行く）。
    def test_singers_index_is_not_shadowed_by_the_name_route
      get '/singers/index'

      assert_equal(200, last_response.status)
      assert_equal(['宮本 佳那子'], JSON.parse(last_response.body))
    end

    def test_unknown_singer_is_not_found
      # ⚠ 日本語のパスは URL エンコードして渡す（rack-test は生のマルチバイトを解けない）。
      get "/singers/#{CGI.escape('存在しない歌手')}"

      assert_equal(404, last_response.status)
    end
  end
end
