RSpec.describe Benchmark::Sweet, ".column_headers" do
  def column_headers(table_rows, **opts)
    Benchmark::Sweet.column_headers(table_rows, **opts)
  end

  let(:table_rows) do
    [
      {"op" => "read", "mp1" => 100, "mp3" => 200, "ltree" => 150},
      {"op" => "write", "mp1" => 50, "mp3" => 80, "ltree" => 60},
    ]
  end

  it "returns row key first" do
    expect(column_headers(table_rows).first).to eq("op")
  end

  it "preserves insertion order by default" do
    expect(column_headers(table_rows)).to eq(%w[op mp1 mp3 ltree])
  end

  it "sorts alphabetically with column_sort: true" do
    expect(column_headers(table_rows, column_sort: true)).to eq(%w[op ltree mp1 mp3])
  end

  it "pins baseline first with column_sort: true" do
    expect(column_headers(table_rows, column_sort: true, baseline: "mp1")).to eq(%w[op mp1 ltree mp3])
  end

  it "accepts a lambda for custom ordering" do
    reverse = ->(cols) { cols.sort_by(&:to_s).reverse }
    expect(column_headers(table_rows, column_sort: reverse)).to eq(%w[op mp3 mp1 ltree])
  end

  it "skips baseline pinning when lambda provided" do
    reverse = ->(cols) { cols.sort_by(&:to_s).reverse }
    expect(column_headers(table_rows, column_sort: reverse, baseline: "mp1")).to eq(%w[op mp3 mp1 ltree])
  end

  it "drops columns where every row is nil" do
    rows = [
      {"op" => "read", "mp1" => 100, "mp3" => 200, "ltree" => nil},
      {"op" => "write", "mp1" => 50, "mp3" => 80, "ltree" => nil},
    ]
    expect(column_headers(rows)).to eq(%w[op mp1 mp3])
  end

  it "keeps columns with at least one non-nil value" do
    rows = [
      {"op" => "read", "mp1" => 100, "ltree" => nil},
      {"op" => "write", "mp1" => 50, "ltree" => 60},
    ]
    expect(column_headers(rows)).to eq(%w[op mp1 ltree])
  end
end
