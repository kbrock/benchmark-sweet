require "benchmark/sweet"
require "active_support/all"

#  method             | NIL                    | EMPTY                  | FULL
# --------------------+------------------------+------------------------+------------------------
#  x&.empty?          | 13752904.8 i/s         | 13089322.9 i/s         | 13352488.3 i/s
#  !x && x.empty?     | 13334422.1 i/s         | 12019275.5 i/s - 1.14x | 11882260.1 i/s - 1.16x
#  x.blank?           | 11889050.9 i/s - 1.16x | 11673162.3 i/s - 1.18x | 12039255.2 i/s - 1.14x
#  x.nil? || x.empty? | 11620573.1 i/s - 1.18x | 10676420.2 i/s - 1.29x | 10048254.7 i/s - 1.37x
#  x.try!(:empty)     | 6240643.7 i/s - 2.20x  | 3962583.3 i/s - 3.47x  | 4071200.6 i/s - 3.38x
#  x.try(:empty)      | 6044172.3 i/s - 2.28x  | 2385145.0 i/s - 5.76x  | 2454406.3 i/s - 5.60x
#  x.empty?           |                        | 13743969.3 i/s         | 13754672.4 i/s

ANIL=nil
EMPTY=[].freeze
FULL=["a"].freeze

Benchmark.items(metrics: %w(ips)) do |x|
  x.metadata version: RUBY_VERSION
  x.metadata data: 'NIL' do
    x.report("x.nil? || x.empty?") { ANIL.nil? || ANIL.empty? }
    x.report("!x && x.empty?")     { !ANIL || ANIL.empty? }
    x.report("x&.empty?")          { ANIL&.empty? }
    x.report("x.try!(:empty)")     { ANIL.try!(:empty?) }
    x.report("x.try(:empty)")      { ANIL.try(:empty?) }
    x.report("x.blank?")           { ANIL.blank? }
  end

  x.metadata data: 'EMPTY' do
    x.report("x.nil? || x.empty?") { EMPTY.nil? || EMPTY.empty? }
    x.report("!x && x.empty?")     { !EMPTY || EMPTY.empty? }
    x.report("x&.empty?")          { EMPTY&.empty? }
    x.report("x.try!(:empty)")     { EMPTY.try!(:empty?) }
    x.report("x.try(:empty)")      { EMPTY.try(:empty?) }
    x.report("x.blank?")           { EMPTY.blank? }
    # base case
    x.report("x.empty?")           { EMPTY.empty? }
  end

  x.metadata data: 'FULL' do
    x.report("x.nil? || x.empty?") { FULL.nil? || FULL.empty? }
    x.report("!x && x.empty?")     { !FULL || FULL.empty? }
    x.report("x&.empty?")          { FULL&.empty? }
    x.report("x.try!(:empty)")     { FULL.try!(:empty?) }
    x.report("x.try(:empty)")      { FULL.try(:empty?) }
    x.report("x.blank?")           { FULL.blank? }
    # base case
    x.report("x.empty?")           { FULL.empty? }
  end

  x.compare_by :data
  x.report_with grouping: nil, row: :method, column: :data

  x.save_file (ENV["SAVE_FILE"] == "true") ? $0.sub(/\.rb$/, '.json') : ENV["SAVE_FILE"] if ENV["SAVE_FILE"]
end
