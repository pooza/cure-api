module CureAPI
  extend Rake::DSL

  namespace :bundle do
    desc 'install gems'
    task :install do
      sh 'gem install bundler -v "~>4.0"'
      sh 'bundle install --jobs 4 --retry 3'
    end

    desc 'update gems'
    task :update do
      sh 'bundle update --jobs 4 --retry 3'
    end

    desc 'check gems'
    task :check do
      unless Environment.gem_fresh?
        warn 'gems is not fresh.'
        exit 1
      end
    end
  end
end
