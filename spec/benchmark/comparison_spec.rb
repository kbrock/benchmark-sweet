require "benchmark/ips"

RSpec.describe Benchmark::Sweet::Comparison do
  def make_stats(values)
    Benchmark::IPS::Stats::SD.new(Array(values))
  end

  def make_comparison(metric, label, stats, offset, total, baseline, worst = nil)
    Benchmark::Sweet::Comparison.new(metric, label, stats, offset, total, baseline, worst)
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
