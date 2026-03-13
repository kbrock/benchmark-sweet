require "benchmark/ips"

RSpec.describe Benchmark::Sweet::Job do
  # normalize_sql is private, so we test through send
  def normalize(sql)
    job = described_class.new
    job.send(:normalize_sql, sql)
  end

  describe "#normalize_sql" do
    it "normalizes quoted strings" do
      expect(normalize("WHERE name = 'hello'")).to eq("WHERE name = ?")
    end

    it "normalizes quoted strings with escapes" do
      # Two adjacent quoted strings become two ?s — this is expected
      expect(normalize("WHERE name = 'it''s'")).to eq("WHERE name = ??")
    end

    it "normalizes integer comparisons" do
      expect(normalize("WHERE id = 42")).to eq("WHERE id = ?")
    end

    it "normalizes IN clauses with integers" do
      expect(normalize("WHERE id IN (1, 2, 3)")).to eq("WHERE id IN (?)")
    end

    it "normalizes LIMIT" do
      expect(normalize("SELECT * FROM t LIMIT 10")).to eq("SELECT * FROM t LIMIT ?")
    end

    it "normalizes OFFSET" do
      expect(normalize("SELECT * FROM t OFFSET 5")).to eq("SELECT * FROM t OFFSET ?")
    end

    it "normalizes VALUES" do
      expect(normalize("INSERT INTO t VALUES (1, 'hello', 3)")).to eq("INSERT INTO t VALUES (?)")
    end

    it "normalizes multiple patterns in one query" do
      sql = "SELECT * FROM t WHERE id = 5 AND name = 'foo' LIMIT 10"
      expect(normalize(sql)).to eq("SELECT * FROM t WHERE id = ? AND name = ? LIMIT ?")
    end

    it "preserves unmatched SQL" do
      sql = "SELECT * FROM t WHERE active = TRUE"
      expect(normalize(sql)).to eq(sql)
    end

    it "normalizes LIMIT and OFFSET together" do
      expect(normalize("SELECT * FROM t LIMIT 10 OFFSET 20")).to eq("SELECT * FROM t LIMIT ? OFFSET ?")
    end
  end
end
