module CureAPI
  extend Rake::DSL

  desc 'test all'
  task :test do
    TestCase.load
  end

  namespace :test do
    # 🔴 **GAS へ実通信する**（#326）。⚠ **CI の既定からは外す**（通信が不安定で赤くなる）。
    desc 'GAS の形が fixture とずれていないかを実通信で見る'
    task :integration do
      ENV['TEST'] = Package.full_name
      require File.join(TestCase.dir, 'integration/gas_schema.rb')
    end
  end
end
