RSpec.describe Benchmark::Sweet::Item do
  describe "#initialize" do
    it "stores label and action" do
      label = {method: "test"}
      action = -> { 1 + 1 }
      item = described_class.new(label, action)
      expect(item.label).to eq(label)
      expect(item.action).to eq(action)
    end

    it "falls back to label[:method] when no action given" do
      label = {method: "1 + 1"}
      item = described_class.new(label)
      expect(item.action).to eq("1 + 1")
    end
  end

  describe "#block" do
    it "returns the action directly when it is a proc" do
      action = -> { 42 }
      item = described_class.new({method: "test"}, action)
      expect(item.block).to eq(action)
      expect(item.block.call).to eq(42)
    end

    it "compiles a string action into a callable proc" do
      item = described_class.new({method: "test"}, "1 + 1")
      expect(item.block).to be_a(Proc)
      expect(item.block.call).to eq(2)
    end
  end
end
