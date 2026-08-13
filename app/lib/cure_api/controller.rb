module CureAPI
  class Controller < Sinatra::Base
    set :host_authorization, {permitted_hosts: []}

    ENDPOINTS = [
      {path: '/girls', description: 'すべてのプリキュア (JSON)'},
      {path: '/girls/index', description: 'プリキュア名の一覧 (JSON)'},
      {path: '/girls/:name', description: '指定したプリキュア (JSON)', example: '/girls/cure_black'},
      {path: '/girls/calendar', description: 'プリキュアの誕生日カレンダー (iCalendar)'},
      {path: '/series', description: 'すべてのシリーズ (JSON)'},
      {path: '/series/index', description: 'シリーズ名の一覧 (JSON)'},
      {path: '/series/:name', description: '指定したシリーズ (JSON)', example: '/series/dokidoki'},
      {path: '/singers', description: 'すべてのプリキュア歌手 (JSON)'},
      {path: '/singers/index', description: 'プリキュア歌手名の一覧 (JSON)'},
      {path: '/singers/:name', description: '指定した歌手 (JSON)', example: '/singers/宮本佳那子'},
      {path: '/cast/calendar', description: 'キャストの誕生日カレンダー (iCalendar)'},
    ].freeze

    INDEX_STYLE = <<~CSS.freeze
      body { font-family: sans-serif; max-width: 900px; margin: 2em auto; padding: 0 1em; }
      a[data-endpoint] { cursor: pointer; }
      pre#result { background: #f4f4f4; padding: 1em; border-radius: 4px;
        overflow-x: auto; white-space: pre-wrap; word-break: break-word; display: none; }
      #endpoint-label { color: #666; font-size: 0.9em; }
    CSS

    INDEX_SCRIPT = <<~JS.freeze
      document.querySelectorAll('a[data-endpoint]').forEach(a => {
        a.addEventListener('click', async (e) => {
          e.preventDefault()
          const path = a.dataset.endpoint
          const label = document.getElementById('endpoint-label')
          const result = document.getElementById('result')
          const url = new URL(path, location.origin).href
          label.innerHTML = '<a href="' + url + '" target="_blank">' + url + '</a>'
          result.style.display = 'block'
          result.textContent = 'Loading...'
          try {
            const res = await fetch(path)
            const ct = res.headers.get('content-type') || ''
            const text = await res.text()
            result.textContent = ct.includes('json')
              ? JSON.stringify(JSON.parse(text), null, 2) : text
          } catch (err) { result.textContent = 'Error: ' + err.message }
        })
      })
    JS

    before do
      @renderer = Ginseng::Web::JSONRenderer.new
    end

    # ⚠⚠ **ルートに当たらなかったときに 200 を返さない。**`@renderer.status` の既定は
    # 200 なので、素通しにすると **Sinatra の 404 を 200 で上書きしてしまう**
    # （`/nonexistent` が「HTTP 200 ＋ `<h1>Not Found</h1>`」で返っていた）。
    #
    # ⚠ **利用側はステータスでしか失敗を判定できない。**実際に `pooza/makoto2` の
    # ゲストコーナーが、未実装の `/singers` の 200 を成功と受け取り、HTML を JSON として
    # 扱って**黙って 0 件**になった（2026-08-13）。
    after do
      content_type(@renderer.type) unless @raw_response
      # ルートが無ければ Sinatra が立てた 404 をそのまま通す。
      next if response.status == 404 && @renderer.status == 200
      status @renderer.status
    end

    # ⚠ **`not_found` ではなく `Sinatra::NotFound`。**前者は 404 全般に効くので、
    # `/girls/zzz` のように**ハンドラが自分で 404 を立てた応答の本文まで潰す**
    # （固有のメッセージが消えて原因が分からなくなる）。ここで拾いたいのは
    # **ルートに 1 つも当たらなかった場合だけ。**
    error Sinatra::NotFound do
      @raw_response = true
      content_type('application/json; charset=UTF-8')
      status 404
      return {error: "'#{request.path_info}' not found"}.to_json
    end

    get '/' do
      @raw_response = true
      content_type 'text/html; charset=UTF-8'
      return index_html
    end

    get '/girls' do
      tool = Tool.create('girls')
      @renderer.message = tool.all
      return @renderer.to_s
    end

    get '/girls/index' do
      tool = Tool.create('girls')
      @renderer.message = tool.index
      return @renderer.to_s
    end

    get '/girls/calendar' do
      tool = Tool.create('girls')
      @raw_response = true
      content_type 'text/calendar; charset=UTF-8'
      return tool.ical
    end

    get '/girls/:name' do
      tool = Tool.create('girls')
      @renderer.message = tool.girl(params[:name])
      return @renderer.to_s
    rescue Ginseng::NotFoundError => e
      @renderer.status = 404
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/series' do
      tool = Tool.create('series')
      @renderer.message = tool.all
      return @renderer.to_s
    end

    get '/series/index' do
      tool = Tool.create('series')
      @renderer.message = tool.index
      return @renderer.to_s
    end

    get '/series/:name' do
      tool = Tool.create('series')
      @renderer.message = tool.series(params[:name])
      return @renderer.to_s
    rescue Ginseng::NotFoundError => e
      @renderer.status = 404
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/singers' do
      tool = Tool.create('singers')
      @renderer.message = tool.all
      return @renderer.to_s
    end

    get '/singers/index' do
      tool = Tool.create('singers')
      @renderer.message = tool.index
      return @renderer.to_s
    end

    # ⚠ `/singers/index` より後に置かない。Sinatra は先に書いたルートが勝つので、
    # 逆にすると `index` という名前の歌手を探しに行く。
    get '/singers/:name' do
      tool = Tool.create('singers')
      @renderer.message = tool.singer(params[:name])
      return @renderer.to_s
    rescue Ginseng::NotFoundError => e
      @renderer.status = 404
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/cast/calendar' do
      tool = Tool.create('cast')
      @raw_response = true
      content_type 'text/calendar; charset=UTF-8'
      return tool.ical
    end

    get '/help' do
      tool = Tool.create('help')
      @raw_response = true
      content_type 'text/plain; charset=UTF-8'
      return tool.exec
    end

    error do
      e = env['sinatra.error']
      @renderer.status = 500
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    private

    def index_html
      items = ENDPOINTS.map do |ep|
        href = ep[:example] || ep[:path]
        %(<li><a href="#" data-endpoint="#{href}">) +
          "#{ep[:path]}</a> &mdash; #{ep[:description]}</li>"
      end.join("\n      ")
      <<~HTML
        <!DOCTYPE html>
        <html lang="ja">
        <head><meta charset="UTF-8"><title>#{Package.name}</title>
        <style>#{INDEX_STYLE}</style></head>
        <body>
        <h1>#{Package.name}</h1>
        <p>#{Package.full_name}</p>
        <h2>エンドポイント一覧</h2>
        <ul>#{items}</ul>
        <h2>結果 <span id="endpoint-label"></span></h2>
        <pre id="result"></pre>
        <script>#{INDEX_SCRIPT}</script>
        </body></html>
      HTML
    end
  end
end
