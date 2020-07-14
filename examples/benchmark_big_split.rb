require 'benchmark/sweet'
require 'active_support/all'

# version 2.3.7
#
#  method      | nil_ips                | str_ips       | nil_memsize        | str_memsize
# -------------+------------------------+---------------+--------------------+-------------
#  ?split:[]   | 51825798.8 i/s         | 1407946.4 i/s | 40.0 bytes         | 360.0 bytes
#  &&split||[] | 46730725.8 i/s - 1.11x | 1413355.3 i/s | 40.0 bytes         | 360.0 bytes
#  to_s.split  | 5685237.1 i/s - 9.12x  | 1396494.3 i/s | 80.0 bytes - 2.00x | 360.0 bytes
#
# version 2.4.4
#
#  method      | nil_ips                | str_ips       | nil_memsize        | str_memsize
# -------------+------------------------+---------------+--------------------+-------------
#  ?split:[]   | 51559454.4 i/s         | 1438780.8 i/s | 40.0 bytes         | 360.0 bytes
#  &.split||[] | 46446196.0 i/s - 1.11x | 1437665.3 i/s | 40.0 bytes         | 360.0 bytes
#  &&split||[] | 43356335.6 i/s - 1.19x | 1434466.6 i/s | 40.0 bytes         | 360.0 bytes
#  to_s.split  | 5835694.7 i/s - 8.84x  | 1427819.0 i/s | 80.0 bytes - 2.00x | 360.0 bytes

NSTRING    = nil
DELIMITER  = '/'.freeze
STRING     = "ab/cd/ef/gh".freeze

Benchmark.items(metrics: %w(ips memsize), memory: 3, warmup: 1, time: 3, quiet: false, force: ENV["FORCE"] == "true") do |x|
  x.metadata version: RUBY_VERSION
  x.metadata data: "nil" do
    x.report("to_s.split",  "NSTRING.to_s.split(DELIMITER)")
    x.report("?split:[]",   "NSTRING ? NSTRING.split(DELIMITER) : []")
    x.report("&&split||[]", "NSTRING && NSTRING.split(DELIMITER) || []")
    x.report("&.split||[]", "NSTRING&.split(DELIMITER) || []") if RUBY_VERSION >= "2.4"
  end

  x.metadata data: "str" do
    x.report("to_s.split",  "STRING.to_s.split(DELIMITER)")
    x.report("?split:[]",   "STRING ? STRING.split(DELIMITER) : []")
    x.report("&&split||[]", "STRING && STRING.split(DELIMITER) || []")
    x.report("&.split||[]", "STRING&.split(DELIMITER) || []") if RUBY_VERSION >= "2.4"
  end

  # partition the data by ruby version and whether data is present
  # that way we're only comparing similar values
  # note: this is not necessarily the correlation to how the data is displayed
  x.compare_by :version, :data
  x.report_with grouping: [:metric, :version], row: :method, column: [:data], value: :comp_short

  x.save_file (ENV["SAVE_FILE"] == "true") ? $0.sub(/\.rb$/, '.json') : ENV["SAVE_FILE"] if ENV["SAVE_FILE"]
end
