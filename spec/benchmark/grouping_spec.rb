require "benchmark/ips"

RSpec.describe Benchmark::Sweet do
  def make_stats(values)
    Benchmark::IPS::Stats::SD.new(Array(values))
  end

  def make_comparison(metric, label, stats, offset = 0, total = 1, baseline = stats)
    Benchmark::Sweet::Comparison.new(metric, label, stats, offset, total, baseline)
  end

  describe ".symbol_to_proc" do
    it "creates a proc from a symbol" do
      p = described_class.symbol_to_proc(:name)
      comp = make_comparison("ips", {name: "fast"}, make_stats([100.0]))
      expect(p.call(comp)).to eq("fast")
    end

    it "creates a proc from a string" do
      p = described_class.symbol_to_proc("name")
      comp = make_comparison("ips", {"name" => "fast"}, make_stats([100.0]))
      expect(p.call(comp)).to eq("fast")
    end

    it "creates a joining proc from an array" do
      p = described_class.symbol_to_proc([:shape, :db])
      comp = make_comparison("ips", {shape: "wide", db: "pg"}, make_stats([100.0]))
      expect(p.call(comp)).to eq("wide_pg")
    end

    it "supports custom join separator" do
      p = described_class.symbol_to_proc([:shape, :db], join: " / ")
      comp = make_comparison("ips", {shape: "wide", db: "pg"}, make_stats([100.0]))
      expect(p.call(comp)).to eq("wide / pg")
    end

    it "returns array without join when join is nil" do
      p = described_class.symbol_to_proc([:shape, :db], join: nil)
      comp = make_comparison("ips", {shape: "wide", db: "pg"}, make_stats([100.0]))
      expect(p.call(comp)).to eq(["wide", "pg"])
    end

    it "passes through a lambda unchanged" do
      lam = -> v { v[:method] }
      expect(described_class.symbol_to_proc(lam)).to equal(lam)
    end
  end

  describe ".group" do
    let(:comps) do
      [
        make_comparison("ips", {shape: "wide", method: "a"}, make_stats([100.0])),
        make_comparison("ips", {shape: "wide", method: "b"}, make_stats([50.0])),
        make_comparison("ips", {shape: "deep", method: "a"}, make_stats([80.0])),
      ]
    end

    it "yields all records when grouping is nil" do
      groups = []
      described_class.group(comps, nil) { |name, records| groups << [name, records] }
      expect(groups.length).to eq(1)
      expect(groups.first[0]).to be_nil
      expect(groups.first[1].length).to eq(3)
    end

    it "groups by symbol" do
      groups = []
      described_class.group(comps, :shape) { |name, records| groups << [name, records.length] }
      expect(groups.map(&:first)).to contain_exactly("wide", "deep")
    end

    it "filters out nil grouping values" do
      comps_with_nil = comps + [make_comparison("ips", {method: "c"}, make_stats([10.0]))]
      groups = []
      described_class.group(comps_with_nil, :shape) { |name, records| groups << [name, records.length] }
      # the entry without :shape should be filtered
      expect(groups.length).to eq(2)
    end

    it "sorts groups when sort: true" do
      groups = []
      described_class.group(comps, :shape, sort: true) { |name, _| groups << name }
      expect(groups).to eq(groups.sort)
    end
  end

  describe ".table" do
    let(:stats_fast) { make_stats([1000.0]) }
    let(:stats_slow) { make_stats([500.0]) }

    it "yields table rows when block given" do
      comps = [
        make_comparison("ips", {method: "fast", data: "nil"}, stats_fast),
        make_comparison("ips", {method: "slow", data: "nil"}, stats_slow, 1, 2, stats_fast),
      ]

      tables = []
      described_class.table(comps, row: :method, column: :data) do |header, rows|
        tables << [header, rows]
      end
      expect(tables.length).to eq(1)
      expect(tables.first[1].length).to eq(2)
    end

    it "groups tables by grouping parameter" do
      comps = [
        make_comparison("ips", {method: "a", shape: "wide"}, stats_fast),
        make_comparison("ips", {method: "a", shape: "deep"}, stats_slow),
      ]

      headers = []
      described_class.table(comps, grouping: :shape, row: :method) do |header, _|
        headers << header
      end
      expect(headers).to contain_exactly("wide", "deep")
    end
  end
end
