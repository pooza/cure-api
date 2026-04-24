module CureAPI
  class Environment < Ginseng::Environment
    def self.name
      return File.basename(dir)
    end

    def self.dir
      return CureAPI.dir
    end

    def self.type
      env = ENV['RACK_ENV']
      return env.to_sym if env && !env.empty?
      return super
    end
  end
end
