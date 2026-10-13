require 'English'
module CureAPI
  class CureCommandTest < TestCase
    def setup
      @bin = File.join(Environment.dir, 'bin/cure.rb')
    end

    def test_girls
      output = exec_command('girls')

      assert_content_type(output, 'application/json')
      assert_json_array(output)
    end

    def test_girls_index
      output = exec_command('girls', 'index')

      assert_content_type(output, 'application/json')
      assert_json_array(output)
    end

    def test_girls_name
      output = exec_command('girls', 'black')

      assert_content_type(output, 'application/json')
      json = parse_body(output)

      assert_kind_of(Hash, json)
      assert_equal('cure_black', json['girl_name'])
    end

    def test_girls_calendar
      output = exec_command('girls', 'calendar')

      assert_content_type(output, 'text/calendar')
      assert_match(/^BEGIN:VCALENDAR\r?\n/, body(output))
    end

    def test_series
      output = exec_command('series')

      assert_content_type(output, 'application/json')
      assert_json_array(output)
    end

    def test_series_index
      output = exec_command('series', 'index')

      assert_content_type(output, 'application/json')
      assert_json_array(output)
    end

    def test_series_name
      output = exec_command('series', 'unmarked')

      assert_content_type(output, 'application/json')
      json = parse_body(output)

      assert_kind_of(Hash, json)
      assert_equal('ふたりはプリキュア', json['title'])
    end

    def test_cast_calendar
      output = exec_command('cast', 'calendar')

      assert_content_type(output, 'text/calendar')
      assert_match(/^BEGIN:VCALENDAR\r?\n/, body(output))
    end

    def test_help
      output = exec_command('help')

      assert_content_type(output, 'text/plain')
      assert_match(%r{bin/cure\.rb}, body(output))
    end

    private

    def exec_command(*args)
      # 🔴 **子プロセスにも GAS の遮断を効かせる**（#326）。⚠ **親の `WebMock` は子に届かない**ので、
      # `RUBYOPT` の `-r` で同じ差し替えを読ませる（→ `GasStub::ENV_KEY`）。
      env = {
        GasStub::ENV_KEY => '1',
        'RUBYOPT' => [ENV.fetch('RUBYOPT', nil), "-r#{TestCase.gas_stub_path}"].compact.join(' '),
      }
      output = IO.popen(env, ['ruby', @bin, *args], err: [:child, :out], &:read)

      assert_predicate($CHILD_STATUS, :success?, "bin/cure.rb #{args.join(' ')} failed: #{output}")
      return output
    end

    def body(output)
      return output.split("\n\n", 2).last
    end

    def parse_body(output)
      return JSON.parse(body(output))
    end

    def assert_content_type(output, expected)
      first_line = output.lines.first.chomp

      assert_match(/^Content-Type: #{Regexp.escape(expected)}/, first_line)
    end

    def assert_json_array(output)
      json = parse_body(output)

      assert_kind_of(Array, json)
      assert_operator(json.size, :>, 0, 'JSON array should not be empty')
    end
  end
end
