require 'timecop'

module CureAPI
  class TestCase < Ginseng::TestCase
    include Package

    # 🔴 **GAS を叩かない**（#326 → `test/fixtures/gas_stub.rb`）。⚠ **各テストの `setup` より前**に
    # 差し込むので、**テストが自分で `stub_request` した URL はそちらが勝つ**（後から登録したほうが当たる）。
    setup :stub_gas, before: :prepend
    teardown :unstub_gas, after: :append

    def self.gas_stub_path
      return File.join(dir, 'fixtures/gas_stub.rb')
    end

    def stub_gas
      require self.class.gas_stub_path
      GasStub.enable!
      reset_datasource
    end

    def unstub_gas
      GasStub.disable!
      reset_datasource
    end

    # ⚠ `Datasource` はシングルトンでキャッシュを持つ。テスト間で持ち越さない。
    def reset_datasource
      [:@girls, :@series, :@singers].each do |name|
        Datasource.instance.instance_variable_set(name, nil)
      end
    end

    def teardown
      config.reload
      @handler&.clear
      Timecop.return
    end

    def self.load(cases = nil)
      ENV['TEST'] = Package.full_name
      names(cases).each do |name|
        raise 'disabled' if name.end_with?('_handler') && Handler.create(name).disable?
        puts "+ case: #{name}" if Environment.test?
        require File.join(dir, "#{name}.rb")
      rescue => e
        puts "- case: #{name} (#{e.message})" if Environment.test?
      end
    end

    def self.names(cases = nil)
      if cases
        names = cases.split(',')
          .map {|v| [v, "#{v}Test", v.underscore, "#{v.underscore}_test"]}.flatten
          .select {|v| File.exist?(File.join(dir, "#{v}.rb"))}.compact
      else
        names = Dir.glob(File.join(dir, '*.rb')).map {|v| File.basename(v, '.rb')}
      end
      return names.to_set
    end

    def self.dir
      return File.join(Environment.dir, 'test')
    end
  end
end
