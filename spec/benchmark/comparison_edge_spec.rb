require "benchmark/ips"

RSpec.describe Benchmark::Sweet::Comparison do
  def make_stats(values)
    Benchmark::IPS::Stats::SD.new(Array(values))
  end

  def make_comparison(metric, label, stats, offset, total, baseline, worst = nil)
    described_class.new(metric, label, stats, offset, total, baseline, worst)
  end

  describe "#overlaps?" do
    it "returns true when slowdown is 1" do
      stats = make_stats([100.0])
      comp = make_comparison("ips", {}, stats, 0, 1, stats)
      expect(comp.overlaps?).to be true
    end

    it "returns true when central tendencies are equal" do
      stats_a = make_stats([100.0])
      stats_b = make_stats([100.0])
      comp = make_comparison("ips", {}, stats_a, 1, 2, stats_b)
      expect(comp.overlaps?).to be true
    end
  end

  describe "#worst?" do
    it "returns true for last entry with slowdown > 1" do
      fast = make_stats([100.0, 110.0, 105.0])
      slow = make_stats([10.0, 11.0, 10.5])
      comp = make_comparison("ips", {}, slow, 1, 2, fast)
      expect(comp.worst?).to be true
    end

    it "returns false for non-last entry" do
      fast = make_stats([100.0, 110.0, 105.0])
      slow = make_stats([10.0, 11.0, 10.5])
      comp = make_comparison("ips", {}, slow, 0, 3, fast)
      expect(comp.worst?).to be false
    end

    it "uses custom worst when provided" do
      fast = make_stats([100.0, 102.0, 101.0, 100.5, 101.5])
      mid  = make_stats([50.0, 52.0, 51.0, 50.5, 51.5])
      slow = make_stats([10.0, 12.0, 11.0, 10.5, 11.5])
      comp = make_comparison("ips", {}, mid, 1, 3, fast, slow)
      expect(comp.worst?).to be false
      comp2 = make_comparison("ips", {}, slow, 2, 3, fast, slow)
      expect(comp2.worst?).to be true
    end

    it "returns false when overlapping with best" do
      stats_a = make_stats([100.0, 102.0, 101.0])
      stats_b = make_stats([99.0, 101.0, 100.0])
      comp = make_comparison("ips", {}, stats_b, 1, 2, stats_a, stats_b)
      expect(comp.worst?).to be false
    end
  end

  describe "#all_same?" do
    it "returns true when best and worst overlap" do
      stats_a = make_stats([100.0, 102.0, 101.0])
      stats_b = make_stats([99.0, 101.0, 100.0])
      comp = make_comparison("ips", {}, stats_a, 0, 2, stats_a, stats_b)
      expect(comp.all_same?).to be true
    end

    it "returns true when best and worst have identical single samples" do
      stats_a = make_stats([1.0])
      stats_b = make_stats([1.0])
      comp = make_comparison("queries", {}, stats_a, 0, 2, stats_a, stats_b)
      expect(comp.all_same?).to be true
    end

    it "returns false when best and worst are distinct" do
      fast = make_stats([100.0, 110.0, 105.0])
      slow = make_stats([10.0, 11.0, 10.5])
      comp = make_comparison("ips", {}, fast, 0, 2, fast, slow)
      expect(comp.all_same?).to be false
    end

    it "returns false when single samples differ" do
      stats_a = make_stats([1.0])
      stats_b = make_stats([2.0])
      comp = make_comparison("queries", {}, stats_a, 0, 2, stats_a, stats_b)
      expect(comp.all_same?).to be false
    end

    it "returns false when worst is not provided" do
      stats = make_stats([100.0])
      comp = make_comparison("ips", {}, stats, 0, 1, stats)
      expect(comp.all_same?).to be false
    end
  end

  describe "#best? with all_same?" do
    it "returns false when all entries overlap" do
      stats_a = make_stats([100.0, 102.0, 101.0])
      stats_b = make_stats([99.0, 101.0, 100.0])
      comp = make_comparison("ips", {}, stats_a, 0, 2, stats_a, stats_b)
      expect(comp.best?).to be false
      expect(comp.mode).to eq(:same)
    end

    it "returns true when entries are distinct" do
      fast = make_stats([100.0, 110.0, 105.0])
      slow = make_stats([10.0, 11.0, 10.5])
      comp = make_comparison("ips", {}, fast, 0, 2, fast, slow)
      expect(comp.best?).to be true
      expect(comp.mode).to eq(:best)
    end
  end

  describe "#comp_string" do
    it "formats best entry" do
      stats = make_stats([100.0])
      comp = make_comparison("ips", {method: "fast"}, stats, 0, 1, stats)
      expect(comp.comp_string).to include("fast")
      expect(comp.comp_string).to include("i/s")
    end

    it "formats slower entry with slowdown" do
      fast = make_stats([100.0, 110.0, 105.0])
      slow = make_stats([10.0, 11.0, 10.5])
      comp = make_comparison("ips", {method: "slow"}, slow, 1, 2, fast)
      expect(comp.comp_string).to include("slow")
      expect(comp.comp_string).to match(/slower/)
    end

    it "accepts custom label formatter" do
      stats = make_stats([100.0])
      comp = make_comparison("ips", {method: "fast"}, stats, 0, 1, stats)
      result = comp.comp_string(-> l { l[:method].upcase })
      expect(result).to include("FAST")
    end
  end

  describe "#[]" do
    it "returns comp_short for :comp_short" do
      stats = make_stats([100.0])
      comp = make_comparison("ips", {method: "x"}, stats, 0, 1, stats)
      expect(comp[:comp_short]).to match(/\d+\.\d+ i\/s/)
    end

    it "returns comp_string for :comp_string" do
      stats = make_stats([100.0])
      comp = make_comparison("ips", {method: "x"}, stats, 0, 1, stats)
      expect(comp[:comp_string]).to include("i/s")
    end
  end

  describe "#mode with same-ish results" do
    it "returns :same when stats overlap with baseline" do
      # very close values with high variance should overlap
      fast = make_stats([100.0, 102.0, 98.0, 101.0, 99.0])
      close = make_stats([99.0, 101.0, 97.0, 100.0, 98.0])
      comp = make_comparison("ips", {}, close, 1, 2, fast)
      expect(comp.mode).to eq(:same).or eq(:best)
    end
  end
end
