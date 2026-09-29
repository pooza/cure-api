module CureAPI
  # ⚠⚠ **遮断が効いていること自体を確かめる**（#326）。`require 'webmock'` だけでは HTTP アダプタは
  # 差し替わらず、**`WebMock.enable!` を呼ぶまで `stub_request` も `disable_net_connect!` も無言で
  # 素通りする**（`pooza/makoto2` で同じ穴を踏んでいる）。
  class GasStubTest < TestCase
    def test_unstubbed_request_is_not_allowed
      assert_raise(WebMock::NetConnectNotAllowedError) do
        Net::HTTP.get(URI('https://script.google.com/macros/s/unknown/exec?action=unknown'))
      end
    end

    # 🔴 **設定と違う URL は差し替えない**（PR #369 の Codex の P2）。打ち間違えた URL は、テストでも落ちる。
    def test_only_the_configured_url_is_stubbed
      assert_raise(WebMock::NetConnectNotAllowedError) do
        Net::HTTP.get(URI('https://script.google.com/macros/s/typo/exec?action=girls'))
      end
    end

    def test_girls_come_from_the_fixture
      fixture = JSON.parse(File.read(GasStub.path('girls')))

      assert_equal(fixture.size, Datasource.instance.girls.size)
      assert_equal('キュアソード', Datasource.instance.find_girl('sword').precure_name)
    end

    def test_series_come_from_the_fixture
      fixture = JSON.parse(File.read(GasStub.path('series')))

      assert_equal(fixture.size, Datasource.instance.series.size)
    end
  end
end
