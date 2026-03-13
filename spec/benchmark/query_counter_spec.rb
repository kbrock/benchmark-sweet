require "benchmark/ips"

RSpec.describe Benchmark::Sweet::Queries::QueryCounter do
  def make_counter(**opts)
    described_class.new(**opts)
  end

  def sql_payload(sql, name: nil, binds: nil, record_count: nil)
    payload = {}
    payload[:sql] = sql if sql
    payload[:name] = name
    payload[:type_casted_binds] = binds
    payload[:record_count] = record_count if record_count
    payload
  end

  describe "#callback" do
    it "counts regular SQL queries" do
      counter = make_counter
      counter.callback("sql.active_record", nil, nil, nil, sql_payload("SELECT * FROM t"))
      expect(counter.get[:sql_count]).to eq(1)
    end

    it "counts cached queries separately" do
      counter = make_counter
      counter.callback("sql.active_record", nil, nil, nil, sql_payload("SELECT 1", name: "CACHE"))
      expect(counter.get[:cache_count]).to eq(1)
      expect(counter.get[:sql_count]).to eq(0)
    end

    it "counts SCHEMA statements as ignored" do
      counter = make_counter
      counter.callback("sql.active_record", nil, nil, nil, sql_payload("SELECT 1", name: "SCHEMA"))
      expect(counter.get[:ignored_count]).to eq(1)
      expect(counter.get[:sql_count]).to eq(0)
    end

    it "counts BEGIN as ignored" do
      counter = make_counter
      counter.callback("sql.active_record", nil, nil, nil, sql_payload("BEGIN"))
      expect(counter.get[:ignored_count]).to eq(1)
    end

    it "counts COMMIT as ignored" do
      counter = make_counter
      counter.callback("sql.active_record", nil, nil, nil, sql_payload("COMMIT"))
      expect(counter.get[:ignored_count]).to eq(1)
    end

    it "counts ROLLBACK as ignored" do
      counter = make_counter
      counter.callback("sql.active_record", nil, nil, nil, sql_payload("ROLLBACK"))
      expect(counter.get[:ignored_count]).to eq(1)
    end

    it "counts SAVEPOINT as ignored" do
      counter = make_counter
      counter.callback("sql.active_record", nil, nil, nil, sql_payload("SAVEPOINT active_record_1"))
      expect(counter.get[:ignored_count]).to eq(1)
    end

    it "counts RELEASE as ignored" do
      counter = make_counter
      counter.callback("sql.active_record", nil, nil, nil, sql_payload("RELEASE SAVEPOINT active_record_1"))
      expect(counter.get[:ignored_count]).to eq(1)
    end

    it "tracks instance count from record_count" do
      counter = make_counter
      counter.callback("sql.active_record", nil, nil, nil, { record_count: 5 })
      expect(counter.get[:instance_count]).to eq(5)
    end

    it "accumulates instance counts" do
      counter = make_counter
      counter.callback("sql.active_record", nil, nil, nil, { record_count: 3 })
      counter.callback("sql.active_record", nil, nil, nil, { record_count: 7 })
      expect(counter.get[:instance_count]).to eq(10)
    end

    it "accumulates sql counts" do
      counter = make_counter
      counter.callback("sql.active_record", nil, nil, nil, sql_payload("SELECT 1"))
      counter.callback("sql.active_record", nil, nil, nil, sql_payload("SELECT 2"))
      expect(counter.get[:sql_count]).to eq(2)
    end
  end

  describe "capture_sql" do
    it "does not capture SQL by default" do
      counter = make_counter
      counter.callback("sql.active_record", nil, nil, nil, sql_payload("SELECT 1"))
      expect(counter.get).not_to have_key(:sql_queries)
    end

    it "captures SQL when enabled" do
      counter = make_counter(capture_sql: true)
      counter.callback("sql.active_record", nil, nil, nil, sql_payload("SELECT 1", binds: [42]))
      queries = counter.get[:sql_queries]
      expect(queries.length).to eq(1)
      expect(queries.first).to eq(["SELECT 1", [42]])
    end

    it "does not capture ignored queries" do
      counter = make_counter(capture_sql: true)
      counter.callback("sql.active_record", nil, nil, nil, sql_payload("BEGIN"))
      expect(counter.get[:sql_queries]).to be_empty
    end

    it "does not capture cached queries" do
      counter = make_counter(capture_sql: true)
      counter.callback("sql.active_record", nil, nil, nil, sql_payload("SELECT 1", name: "CACHE"))
      expect(counter.get[:sql_queries]).to be_empty
    end
  end

  describe "#clear" do
    it "resets all counts" do
      counter = make_counter
      counter.callback("sql.active_record", nil, nil, nil, sql_payload("SELECT 1"))
      counter.clear
      expect(counter.get[:sql_count]).to eq(0)
    end

    it "resets sql_queries when capturing" do
      counter = make_counter(capture_sql: true)
      counter.callback("sql.active_record", nil, nil, nil, sql_payload("SELECT 1"))
      counter.clear
      expect(counter.get[:sql_queries]).to be_empty
    end
  end

  describe "#get_clear" do
    it "returns current values and resets" do
      counter = make_counter
      counter.callback("sql.active_record", nil, nil, nil, sql_payload("SELECT 1"))
      result = counter.get_clear
      expect(result[:sql_count]).to eq(1)
      expect(counter.get[:sql_count]).to eq(0)
    end
  end
end
