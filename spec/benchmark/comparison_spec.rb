require "benchmark/ips"

RSpec.describe Benchmark::Sweet::Comparison do
  def make_stats(values)
    Benchmark::IPS::Stats::SD.new(Array(values))
  end

  def make_comparison(metric, label, stats, offset, total, best, worst: nil)
    Benchmark::Sweet::Comparison.new(metric, label, stats, offset, total, best, worst: worst)
  end

  let(:fast_stats) { make_stats([100.0, 110.0, 105.0]) }
  let(:slow_stats) { make_stats([50.0, 55.0, 52.0]) }
  let(:same_stats) { make_stats([100.0, 110.0, 105.0]) }

  describe "#mode" do
    it "returns :best for the baseline entry" do
      comp = make_comparison("ips", {method: "fast"}, fast_stats, 0, 2, fast_stats)
      expect(comp.mode).to eq(:best)
    end

    it "returns :best when there is no baseline" do
      comp = make_comparison("ips", {method: "only"}, fast_stats, 0, 1, nil)
      expect(comp.mode).to eq(:best)
    end

    it "returns :slower for a significantly slower entry" do
      comp = make_comparison("ips", {method: "slow"}, slow_stats, 1, 2, fast_stats)
      expect(comp.mode).to eq(:slower).or eq(:slowerish)
    end
  end

  describe "#slowdown" do
    it "returns 1.0 for the baseline" do
      comp = make_comparison("ips", {method: "fast"}, fast_stats, 0, 2, fast_stats)
      expect(comp.slowdown).to eq(1.0)
    end

    it "returns a factor > 1 for slower entries" do
      comp = make_comparison("ips", {method: "slow"}, slow_stats, 1, 2, fast_stats)
      expect(comp.slowdown).to be > 1.0
    end
  end

  describe "#ratio" do
    # fast ~105, slow ~52, so mid between them
    let(:mid_stats) { make_stats([75.0, 77.0, 76.0]) }

    it "returns nil when no reference is set" do
      comp = make_comparison("ips", {method: "fast"}, fast_stats, 0, 2, fast_stats)
      expect(comp.ratio).to be_nil
    end

    it "returns 1.0 for the reference entry itself" do
      comp = Benchmark::Sweet::Comparison.new("ips", {method: "mid"}, mid_stats, 1, 3, fast_stats, worst: slow_stats, reference: mid_stats)
      expect(comp.ratio).to eq(1.0)
    end

    it "returns >1.0 when faster than reference" do
      comp = Benchmark::Sweet::Comparison.new("ips", {method: "fast"}, fast_stats, 0, 3, fast_stats, worst: slow_stats, reference: mid_stats)
      expect(comp.ratio).to be > 1.0
    end

    it "returns <1.0 when slower than reference" do
      comp = Benchmark::Sweet::Comparison.new("ips", {method: "slow"}, slow_stats, 2, 3, fast_stats, worst: slow_stats, reference: mid_stats)
      expect(comp.ratio).to be < 1.0
    end

    it "preserves best/worst ranking independent of reference" do
      comp = Benchmark::Sweet::Comparison.new("ips", {method: "fast"}, fast_stats, 0, 3, fast_stats, worst: slow_stats, reference: mid_stats)
      expect(comp.best?).to be true
      expect(comp.ratio).to be > 1.0
    end
  end

  describe "#units" do
    it "returns i/s for ips metric" do
      comp = make_comparison("ips", {}, fast_stats, 0, 1, fast_stats)
      expect(comp.units).to eq("i/s")
    end

    it "returns bytes for memsize metric" do
      comp = make_comparison("memsize", {}, fast_stats, 0, 1, fast_stats)
      expect(comp.units).to eq("bytes")
    end

    it "returns objs for unknown metrics" do
      comp = make_comparison("queries", {}, fast_stats, 0, 1, fast_stats)
      expect(comp.units).to eq("objs")
    end
  end

  describe "#comp_short" do
    it "returns value and units for best" do
      comp = make_comparison("ips", {method: "fast"}, fast_stats, 0, 1, fast_stats)
      expect(comp.comp_short).to match(/\d+\.\d+ i\/s/)
    end

    it "includes slowdown for slower entries" do
      comp = make_comparison("ips", {method: "slow"}, slow_stats, 1, 2, fast_stats)
      expect(comp.comp_short).to match(/\d+\.\d+ i\/s.*\dx/)
    end

    it "accepts a custom value string" do
      comp = make_comparison("ips", {method: "slow"}, slow_stats, 1, 2, fast_stats)
      result = comp.comp_short("custom")
      expect(result).to include("custom")
    end
  end

  describe "#color" do
    it "returns 32 (green) for best" do
      comp = make_comparison("ips", {}, fast_stats, 0, 2, fast_stats)
      expect(comp.color).to eq("32")
    end

    it "returns 31 (red) for worst" do
      comp = make_comparison("ips", {}, slow_stats, 1, 2, fast_stats)
      # worst? depends on offset == total - 1 and slowdown > 1
      expect(comp.color).to eq("31").or eq(";0")
    end

    it "returns ;0 (neutral) when no baseline" do
      comp = make_comparison("ips", {}, fast_stats, 0, 1, nil)
      expect(comp.color).to eq(";0")
    end
  end

  describe "#comp_short with color" do
    it "returns plain text by default" do
      comp = make_comparison("ips", {method: "fast"}, fast_stats, 0, 1, fast_stats)
      expect(comp.comp_short).not_to include("\e[")
    end

    it "wraps in ANSI color when color: true" do
      comp = make_comparison("ips", {method: "fast"}, fast_stats, 0, 2, fast_stats)
      result = comp.comp_short(color: true)
      expect(result).to start_with("\e[32m")
      expect(result).to end_with("\e[0m")
    end

    it "wraps slower entries in red when color: true" do
      comp = make_comparison("ips", {method: "slow"}, slow_stats, 1, 2, fast_stats)
      result = comp.comp_short(color: true)
      expect(result).to include("\e[")
      expect(result).to end_with("\e[0m")
    end
  end

  describe "#comp_bar" do
    it "returns a full solid bar for best" do
      comp = make_comparison("ips", {method: "fast"}, fast_stats, 0, 2, fast_stats)
      result = comp.comp_bar(width: 10)
      expect(result).to eq("██████████")
    end

    it "returns a full solid bar when no baseline" do
      comp = make_comparison("ips", {method: "only"}, fast_stats, 0, 1, nil)
      result = comp.comp_bar(width: 10)
      expect(result).to eq("██████████")
    end

    it "returns a partial bar with shading for slower entries" do
      comp = make_comparison("ips", {method: "slow"}, slow_stats, 1, 2, fast_stats)
      result = comp.comp_bar(width: 10)
      expect(result).to include("█")
      expect(result).to include("░")
      expect(result.length).to eq(10)
    end

    it "returns a full solid bar for overlapping entries" do
      comp = make_comparison("ips", {method: "same"}, same_stats, 1, 2, fast_stats)
      result = comp.comp_bar(width: 10)
      expect(result).to eq("██████████")
    end

    it "wraps in ANSI color when color: true" do
      comp = make_comparison("ips", {method: "fast"}, fast_stats, 0, 2, fast_stats)
      result = comp.comp_bar(width: 10, color: true)
      expect(result).to start_with("\e[32m")
      expect(result).to end_with("\e[0m")
    end

    it "returns plain text when color: false" do
      comp = make_comparison("ips", {method: "fast"}, fast_stats, 0, 2, fast_stats)
      result = comp.comp_bar(width: 10, color: false)
      expect(result).not_to include("\e[")
    end
  end

  describe "#colorize" do
    it "wraps string in ANSI color code" do
      comp = make_comparison("ips", {method: "fast"}, fast_stats, 0, 2, fast_stats)
      expect(comp.colorize("hello")).to eq("\e[32mhello\e[0m")
    end
  end

  describe "#[]" do
    let(:label) { {method: "fast", data: "nil"} }
    let(:comp) { make_comparison("ips", label, fast_stats, 0, 1, fast_stats) }

    it "returns metric for :metric" do
      expect(comp[:metric]).to eq("ips")
    end

    it "returns label for :label" do
      expect(comp[:label]).to eq(label)
    end

    it "returns label values for label keys" do
      expect(comp[:method]).to eq("fast")
      expect(comp[:data]).to eq("nil")
    end
  end
end
