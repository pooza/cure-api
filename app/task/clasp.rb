require 'English'
module CureAPI
  extend Rake::DSL

  # clasp の呼び出し方。⚠ **グローバルに入っているとは限らない**（Debian 側には
  # 入っていなかった）。無ければ npx で落として使う。
  #
  # ⚠⚠ **バージョンを固定する。**`~/.clasprc.json` は clasp 3.x の形式
  # （`tokens.default.*`）で書かれており、**2.x はこれを読めずに
  # `Cannot read properties of undefined` で落ちる。**
  def self.clasp
    return @clasp ||= system('which clasp > /dev/null 2>&1') ? 'clasp' : 'npx -y @google/clasp@3'
  end

  # 設定済みの URL からデプロイ ID を取り出す。
  #
  # ⚠⚠ **既存のデプロイを更新するために要る。**`clasp deploy` を引数なしで叩くと
  # **新しいデプロイが作られて URL が変わる。**cure-api 自身は application.yaml を
  # 書き換えるので追随できるが、⚠ **GAS の URL を直接見ている外部の利用者は黙って
  # 壊れる**（singers には実際に、リポジトリ内から辿れない利用者が居た）。
  def self.deployment_id(name)
    url = Config.instance["/gas/#{name}/url"].to_s
    return url[%r{/macros/s/([^/]+)/exec}, 1]
  end

  namespace :clasp do
    ['girls', 'series', 'singers'].each do |name|
      namespace name do
        gas_dir = File.join(dir, 'gas', name)

        desc "push #{name} GAS script"
        task :push do
          Dir.chdir(gas_dir) {sh "#{CureAPI.clasp} push --force"}
        end

        desc "deploy #{name} GAS script"
        task deploy: :push do
          # ⚠ 既にデプロイ済みなら同じ ID を使い回して URL を変えない。
          id = CureAPI.deployment_id(name)
          command = [CureAPI.clasp, 'deploy']
          command.push('--deploymentId', id) if id
          output = Dir.chdir(gas_dir) {`#{command.join(' ')} 2>&1`}
          puts output
          raise 'clasp deploy failed' unless $CHILD_STATUS.success?
          next puts "Kept #{name} URL (deployment #{id})" if id
          unless (m = output.match(/Deployed\s+(\S+)\s+@/))
            # ⚠⚠ **黙って成功にしない。**出力書式が変わって拾えなくなると、
            # デプロイしたのに URL が古いまま「成功」して終わる。
            raise "clasp deploy: could not read the deployment id from:\n#{output}"
          end
          CureAPI.update_gas_url(name, m[1])
        end
      end
    end
  end

  # application.yaml の `/gas/{name}/url` を書き換える。
  def self.update_gas_url(name, deployment_id)
    url = "https://script.google.com/macros/s/#{deployment_id}/exec"
    config_path = File.join(dir, 'config/application.yaml')
    in_section = false
    updated = File.read(config_path).lines.map do |line|
      in_section = true if line.match?(/^\s+#{name}:/)
      if in_section && line.match?(/^\s+\w+:/) &&
          !line.match?(/^\s+#{name}:/) && !line.match?(/^\s+url:/)
        in_section = false
      end
      next line unless in_section && line.match?(/^\s+url:/)
      in_section = false
      next line.sub(/url:.*$/, "url: #{url}")
    end.join
    File.write(config_path, updated)
    puts "Updated #{name} URL in application.yaml"
  end
end
