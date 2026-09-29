module CureAPI
  # 🔴 **GAS へ実通信して、fixture と形がずれていないかを見る**（#326）。⚠⚠ **CI の既定（`rake test`）
  # からは外してある** — 通信が不安定で赤くなるので、**依存を上げた PR の中で走らせない。**
  # 手で `bundle exec rake test:integration` を叩く。
  #
  # ⚠ **見るのは列の名前と件数が 0 でないことだけ**（中身はスプレッドシートが人手で変わるので比べない）。
  # ⚠ **`Datasource` を通さず生の応答を比べる**（`series` は取り込みで列の名前を変えるので）。
  class GasSchemaTest < TestCase
    def setup
      GasStub.disable!
    end

    def test_girls_have_the_fixture_keys
      assert_keys('girls')
    end

    def test_series_have_the_fixture_keys
      assert_keys('series')
    end

    private

    def assert_keys(action)
      records = HTTP.new.get("#{config["/gas/#{action}/url"]}?action=#{action}").to_a
      fixture = JSON.parse(File.read(GasStub.path(action)))

      assert_operator(records.size, :>, 0, "#{action} が 0 件")
      assert_equal(fixture.flat_map(&:keys).to_set, records.flat_map(&:keys).to_set)
    end
  end
end
