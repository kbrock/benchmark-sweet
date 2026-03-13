require "benchmark/ips"
require "tempfile"

RSpec.describe Benchmark::Sweet::Job, "#write_sql" do
  def make_job
    described_class.new(metrics: %w(queries rows))
  end

  it "does nothing without save_sql" do
    job = make_job
    expect(job.write_sql).to be_nil
  end

  it "does nothing with no sql entries" do
    job = make_job
    job.save_sql("unused.sql")
    # no entries added
    expect(job.write_sql).to be_nil
  end

  it "writes sql entries to file" do
    Tempfile.create(["sql", ".sql"]) do |f|
      job = make_job
      job.save_sql(f.path)

      label = {config: "mp1", shape: "wide", operation: "descendants"}
      job.instance_variable_get(:@sql_entries)[label] = [
        ["SELECT * FROM t WHERE ancestry = '1'", nil],
      ]

      job.write_sql
      content = File.read(f.path)
      expect(content).to include("SQL:")
      expect(content).to include("SELECT * FROM t WHERE ancestry = ?")
    end
  end

  it "groups constant keys in header" do
    Tempfile.create(["sql", ".sql"]) do |f|
      job = make_job
      job.save_sql(f.path, explain: false)

      label1 = {config: "mp1", operation: "descendants"}
      label2 = {config: "mp1", operation: "children"}
      job.instance_variable_get(:@sql_entries)[label1] = [["SELECT 1", nil]]
      job.instance_variable_get(:@sql_entries)[label2] = [["SELECT 2", nil]]

      job.write_sql
      content = File.read(f.path)
      # config is constant across labels — goes in header
      expect(content).to include("# config: mp1")
      # operation varies — goes in section headers
      expect(content).to include("== descendants ==")
      expect(content).to include("== children ==")
    end
  end

  it "deduplicates repeated queries with count" do
    Tempfile.create(["sql", ".sql"]) do |f|
      job = make_job
      job.save_sql(f.path, explain: false)

      label = {operation: "test"}
      job.instance_variable_get(:@sql_entries)[label] = [
        ["SELECT * FROM t WHERE id = 1", nil],
        ["SELECT * FROM t WHERE id = 2", nil],
        ["SELECT * FROM t WHERE id = 3", nil],
      ]

      job.write_sql
      content = File.read(f.path)
      expect(content).to include("(3x)")
      # should only have one SQL line, not three
      expect(content.scan(/^SQL:/).length).to eq(1)
    end
  end

  it "writes (no queries) for empty query list" do
    Tempfile.create(["sql", ".sql"]) do |f|
      job = make_job
      job.save_sql(f.path, explain: false)

      label = {operation: "noop"}
      job.instance_variable_get(:@sql_entries)[label] = []

      job.write_sql
      content = File.read(f.path)
      expect(content).to include("(no queries)")
    end
  end

  it "does not add count prefix for single queries" do
    Tempfile.create(["sql", ".sql"]) do |f|
      job = make_job
      job.save_sql(f.path, explain: false)

      label = {operation: "test"}
      job.instance_variable_get(:@sql_entries)[label] = [
        ["SELECT * FROM t WHERE id = 1", nil],
      ]

      job.write_sql
      content = File.read(f.path)
      expect(content).not_to include("(1x)")
      expect(content).to include("SQL: SELECT * FROM t WHERE id = ?")
    end
  end
end
