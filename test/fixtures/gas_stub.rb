require 'bundler/setup'
require 'json'
require 'webmock'
$LOAD_PATH.unshift(File.join(File.expand_path('../..', __dir__), 'app/lib'))
require 'cure_api'

module CureAPI
  # 🔴 **GAS への実通信を遮断し、fixture を返す**（#326）。
  #
  # ⚠⚠ **GAS は同じコードで結果が割れる**（2026-08-13 に 4 回中 1 回だけ 404・2026-09-28〜29 の
  # dependabot の PR も 2 回続けて 404）。**変更が壊したのか通信が不安定だったのかを、テストの
  # 結果から区別できない**ので、既定のテストは GAS を叩かない。
  #
  # ⚠ **`TestCase` の全テストに効く**（`setup` の前に差し込む）。**個別のテストが自分で
  # `stub_request` した URL はそちらが勝つ**（後から登録したほうが当たる）。
  #
  # ⚠⚠ **`bin/cure.rb` を子プロセスで叩くテスト（`CureCommandTest`）にも効かせるため、
  # `RUBYOPT` の `-r` で単独でも読めるようにしてある**（→ `ENV_KEY`）。
  #
  # 🔴 **差し替えるのは設定にある GAS の URL だけ**（PR #369 の Codex の P2）。⚠⚠ **`action=girls` を
  # 持つ URL を全部差し替えると、設定の URL を打ち間違えてもテストが通る**（本番でだけ落ちる）。
  # ⚠ そのため子プロセスでも `cure_api` を読んで、設定から URL を引く。
  #
  # ⚠ **fixture は実データの写し**（2026-09-29 に GAS から取得）。スプレッドシートは人手で
  # 更新されるので放っておくとずれる — ⚠ **形がずれていないかは `rake test:integration` が
  # 実通信で見る**（CI の既定からは外してある）。
  module GasStub
    DIR = __dir__
    ACTIONS = ['girls', 'series'].freeze
    ENV_KEY = 'CURE_API_GAS_STUB'.freeze

    def self.enable!
      WebMock.enable!
      WebMock.disable_net_connect!
      ACTIONS.each do |action|
        WebMock::API.stub_request(:get, url(action))
          .to_return(body: File.read(path(action)), headers: {'Content-Type' => 'application/json'})
      end
    end

    def self.disable!
      WebMock.reset!
      WebMock.allow_net_connect!
      WebMock.disable!
    end

    def self.url(action)
      return "#{CureAPI::Config.instance["/gas/#{action}/url"]}?action=#{action}"
    end

    def self.path(action)
      return File.join(DIR, "#{action}.json")
    end
  end
end

CureAPI::GasStub.enable! if ENV[CureAPI::GasStub::ENV_KEY]
