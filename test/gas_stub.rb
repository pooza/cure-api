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
