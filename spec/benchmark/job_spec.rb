require "benchmark/ips"
require "json"
require "tempfile"

RSpec.describe Benchmark::Sweet::Job do
  describe "#item / #report" do
    it "adds items with string labels" do
      job = described_class.new
      job.item("test_method") { }
      expect(job.items.length).to eq(1)
      expect(job.items.first.label[:method]).to eq("test_method")
    end

    it "adds items with hash labels" do
      job = described_class.new
      job.item(data: "nil", method: "split") { }
      expect(job.items.first.label).to eq({data: "nil", method: "split"})
    end

    it "normalizes symbol values to strings" do
      job = described_class.new
      job.item(data: :str, method: "split") { }
      expect(job.items.first.label[:data]).to eq("str")
    end

    it "normalizes nil values to strings" do
      job = described_class.new
      job.item(data: nil, method: "split") { }
      expect(job.items.first.label[:data]).to eq("")
    end
  end

  describe "#metadata" do
    it "merges metadata into subsequent items" do
      job = described_class.new
      job.metadata(version: "3.4")
      job.item("split") { }
      expect(job.items.first.label[:version]).to eq("3.4")
    end

    it "scopes metadata within a block" do
      job = described_class.new
      job.metadata(version: "3.4")
      job.metadata(data: "nil") do
        job.item("inner") { }
      end
      job.item("outer") { }

      expect(job.items[0].label[:data]).to eq("nil")
      expect(job.items[1].label).not_to have_key(:data)
      # version persists in both
      expect(job.items[0].label[:version]).to eq("3.4")
      expect(job.items[1].label[:version]).to eq("3.4")
    end
  end

  describe "#add_entry and #entry_stat" do
    it "stores and retrieves stats" do
      job = described_class.new
      label = {method: "test"}
      job.add_entry(label, "ips", [100.0, 110.0])
      stat = job.entry_stat(label, "ips")
      expect(stat).not_to be_nil
      expect(stat.central_tendency).to be_within(10).of(105.0)
    end

    it "preserves existing stats objects" do
      job = described_class.new
      label = {method: "test"}
      stats = Benchmark::IPS::Stats::SD.new([100.0])
      job.add_entry(label, "ips", stats)
      expect(job.entry_stat(label, "ips")).to equal(stats)
    end
  end

  describe "#comparison_values" do
    it "returns comparisons for all entries" do
      job = described_class.new(metrics: %w(ips))
      label_a = {method: "fast"}
      label_b = {method: "slow"}
      job.add_entry(label_a, "ips", [1000.0, 1100.0])
      job.add_entry(label_b, "ips", [500.0, 550.0])

      comparisons = job.comparison_values
      expect(comparisons.length).to eq(2)
      expect(comparisons.map(&:class).uniq).to eq([Benchmark::Sweet::Comparison])
    end

    it "ranks higher IPS as best" do
      job = described_class.new(metrics: %w(ips))
      job.add_entry({method: "fast"}, "ips", [1000.0])
      job.add_entry({method: "slow"}, "ips", [500.0])

      comparisons = job.comparison_values
      best = comparisons.find { |c| c.mode == :best }
      expect(best.label[:method]).to eq("fast")
    end

    it "ranks lower memsize as best" do
      job = described_class.new(metrics: %w(memsize))
      job.add_entry({method: "lean"}, "memsize", [40.0])
      job.add_entry({method: "heavy"}, "memsize", [400.0])

      comparisons = job.comparison_values
      best = comparisons.find { |c| c.mode == :best }
      expect(best.label[:method]).to eq("lean")
    end
  end

  describe "#compare_by" do
    it "partitions comparisons by symbol" do
      job = described_class.new(metrics: %w(ips))
      job.compare_by :data

      job.add_entry({method: "a", data: "nil"}, "ips", [1000.0])
      job.add_entry({method: "b", data: "nil"}, "ips", [500.0])
      job.add_entry({method: "c", data: "str"}, "ips", [200.0])
      job.add_entry({method: "d", data: "str"}, "ips", [100.0])

      comparisons = job.comparison_values
      # should have 2 :best entries (one per partition)
      bests = comparisons.select { |c| c.mode == :best }
      expect(bests.length).to eq(2)
      expect(bests.map { |c| c.label[:data] }.sort).to eq(["nil", "str"])
    end

    it "partitions comparisons by block" do
      job = described_class.new(metrics: %w(ips))
      job.compare_by { |label, _| label[:data] }

      job.add_entry({method: "a", data: "nil"}, "ips", [1000.0])
      job.add_entry({method: "b", data: "nil"}, "ips", [500.0])

      comparisons = job.comparison_values
      expect(comparisons.length).to eq(2)
    end
  end

  describe "serialization" do
    it "round-trips entries through save and load" do
      Tempfile.create(["benchmark", ".json"]) do |f|
        # save
        job1 = described_class.new(metrics: %w(ips))
        label = {method: "test", data: "nil"}
        job1.add_entry(label, "ips", [100.0, 110.0, 105.0])
        job1.save_entries(f.path)

        # load
        job2 = described_class.new(metrics: %w(ips))
        job2.load_entries(f.path)

        stat = job2.entry_stat(label, "ips")
        expect(stat).not_to be_nil
        expect(stat.central_tendency).to be_within(1).of(105.0)
      end
    end

    it "round-trips entries with symbol values" do
      Tempfile.create(["benchmark", ".json"]) do |f|
        job1 = described_class.new(metrics: %w(ips))
        # symbol values get normalized to strings at item creation,
        # but add_entry accepts any label — simulate normalized label
        label = {method: "test", data: "str"}
        job1.add_entry(label, "ips", [100.0])
        job1.save_entries(f.path)

        job2 = described_class.new(metrics: %w(ips))
        job2.load_entries(f.path)

        stat = job2.entry_stat(label, "ips")
        expect(stat).not_to be_nil
      end
    end

    it "does not load when file does not exist" do
      job = described_class.new(metrics: %w(ips))
      job.load_entries("/tmp/nonexistent_benchmark_file_#{$$}.json")
      expect(job.entries).to be_empty
    end
  end

  describe "metric detection" do
    it "detects ips metrics" do
      job = described_class.new(metrics: %w(ips))
      expect(job.ips?).to be true
      expect(job.memory?).to be false
      expect(job.database?).to be false
    end

    it "detects memory metrics" do
      job = described_class.new(metrics: %w(memsize objects))
      expect(job.ips?).to be false
      expect(job.memory?).to be true
    end

    it "detects database metrics" do
      job = described_class.new(metrics: %w(queries rows))
      expect(job.database?).to be true
    end

    it "raises on invalid metrics" do
      expect { described_class.new(metrics: %w(bogus)) }.to raise_error(NameError)
    end
  end
end
