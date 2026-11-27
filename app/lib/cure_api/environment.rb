module CureAPI
  class Environment < Ginseng::Environment
    def self.name
      return File.basename(dir)
    end

    def self.dir
      return CureAPI.dir
    end
  end
end
