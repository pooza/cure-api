require 'English'
module CureAPI
  extend Rake::DSL

  namespace :clasp do
    ['girls', 'series', 'singers'].each do |name|
      namespace name do
        gas_dir = File.join(dir, 'gas', name)

        desc "push #{name} GAS script"
        task :push do
          Dir.chdir(gas_dir) {sh 'clasp push'}
        end

        desc "deploy #{name} GAS script"
        task deploy: :push do
          output = Dir.chdir(gas_dir) {`clasp deploy 2>&1`}
          puts output
          raise 'clasp deploy failed' unless $CHILD_STATUS.success?
          if (m = output.match(/Deployed\s+(\S+)\s+@/))
            deployment_id = m[1]
            url = "https://script.google.com/macros/s/#{deployment_id}/exec"
            config_path = File.join(dir, 'config/application.yaml')
            content = File.read(config_path)
            in_section = false
            updated = content.lines.map do |line|
              in_section = true if line.match?(/^\s+#{name}:/)
              if in_section && line.match?(/^\s+\w+:/) &&
                 !line.match?(/^\s+#{name}:/) && !line.match?(/^\s+url:/)
                in_section = false
              end
              if in_section && line.match?(/^\s+url:/)
                in_section = false
                line.sub(/url:.*$/, "url: #{url}")
              else
                line
              end
            end.join
            File.write(config_path, updated)
            puts "Updated #{name} URL in application.yaml"
          end
        end
      end
    end
  end
end
