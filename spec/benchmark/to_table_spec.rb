RSpec.describe Benchmark::Sweet do
  describe ".to_table" do
    def capture_table(rows)
      output = StringIO.new
      $stdout = output
      Benchmark::Sweet.to_table(rows)
      output.string
    ensure
      $stdout = STDOUT
    end

    def table_lines(rows)
      capture_table(rows).split("\n")
    end

    it "renders a simple table" do
      rows = [
        {"name" => "fast", "value" => "100"},
        {"name" => "slow", "value" => "50"},
      ]
      lines = table_lines(rows)
      expect(lines[0]).to match(/name.*\|.*value/)
      expect(lines[1]).to match(/----.*-\|-.*-----/)
      expect(lines[2]).to match(/fast.*\|.*100/)
      expect(lines[3]).to match(/slow.*\|.*50/)
      expect(lines.length).to eq(4)
    end

    it "aligns columns correctly with varying widths" do
      rows = [
        {"method" => "x&.empty?",     "result" => "100.0 i/s"},
        {"method" => "x.try(:empty)", "result" => "50.0 i/s - 2.00x"},
      ]
      lines = table_lines(rows)
      # header, separator, and data lines should all have | at the same position
      stripped = lines.map { |l| l.gsub(/\e\[[^m]*m/, '') }
      pipe_positions = stripped.map { |l| l.index("|") }
      expect(pipe_positions.uniq.length).to eq(1)
    end

    it "handles ANSI color codes without breaking alignment" do
      rows = [
        {"method" => "fast", "metric" => "\e[32m100.0 i/s\e[0m"},
        {"method" => "slow", "metric" => "\e[31m50.0 i/s - 2.00x\e[0m"},
      ]
      lines = table_lines(rows)
      # strip ANSI codes and check that pipes align
      stripped = lines.map { |l| l.gsub(/\e\[[^m]*m/, '') }
      pipe_positions = stripped.map { |l| l.index("|") || l.index("+") }
      expect(pipe_positions.uniq.length).to eq(1)
    end

    it "handles headers wider than values" do
      rows = [
        {"wide_header_name" => "x", "another_wide_one" => "y"},
      ]
      lines = table_lines(rows)
      expect(lines[0]).to include("wide_header_name")
      expect(lines[0]).to include("another_wide_one")
    end

    it "handles values wider than headers" do
      rows = [
        {"h" => "a very long value here"},
      ]
      lines = table_lines(rows)
      stripped = lines.map { |l| l.gsub(/\e\[[^m]*m/, '') }
      # separator should be as wide as the value, not the header
      expect(stripped[1].length).to be >= "a very long value here".length
    end

    it "handles multiple columns" do
      rows = [
        {"method" => "x&.empty?", "NIL" => "44.0 i/s", "EMPTY" => "41.7 i/s", "FULL" => "41.7 i/s"},
        {"method" => "x.blank?",  "NIL" => "39.2 i/s", "EMPTY" => "40.3 i/s", "FULL" => "39.9 i/s"},
      ]
      lines = table_lines(rows)
      expect(lines[0]).to include("NIL")
      expect(lines[0]).to include("EMPTY")
      expect(lines[0]).to include("FULL")
    end

    it "returns nil for empty input" do
      expect(capture_table([])).to eq("")
    end
  end
end
