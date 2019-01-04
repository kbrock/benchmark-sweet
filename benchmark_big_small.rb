require "benchmark/sweet"
require "active_support/all"
require "more_core_extensions/all" # [].tabelize

# output:
#
# [:version] 2.3.7
#
#  method     | nil_ips               | str_ips       | nil_memsize        | str_memsize
# ------------+-----------------------+---------------+--------------------+-------------
#  ?split:[]  | 51574246.6 i/s        | 1434943.3 i/s | 40.0 bytes         | 360.0 bytes
#  to_s.split | 5707766.1 i/s - 9.04x | 1411708.0 i/s | 80.0 bytes - 2.00x | 360.0 bytes
#
# [:version] 2.4.4
#
#  method     | nil_ips               | str_ips       | nil_memsize        | str_memsize
# ------------+-----------------------+---------------+--------------------+-------------
#  ?split:[]  | 51740193.6 i/s        | 1411882.2 i/s | 40.0 bytes         | 360.0 bytes
#  to_s.split | 5887968.5 i/s - 8.79x | 1347822.1 i/s | 80.0 bytes - 2.00x | 360.0 bytes
#
#
#
# (CONDENSED=true) output:
#
# [:metric, :version] ips_2.3.7
#
#  method      | nil                    | str
# -------------+------------------------+---------------
#  ?split:[]   | 51825798.8 i/s         | 1407946.4 i/s
#  &&split||[] | 46730725.8 i/s - 1.11x | 1413355.3 i/s
#  to_s.split  | 5685237.1 i/s - 9.12x  | 1396494.3 i/s
#
# [:metric, :version] ips_2.4.4
#
#  method      | nil                    | str
# -------------+------------------------+---------------
#  ?split:[]   | 51559454.4 i/s         | 1438780.8 i/s
#  &.split||[] | 46446196.0 i/s - 1.11x | 1437665.3 i/s
#  &&split||[] | 43356335.6 i/s - 1.19x | 1434466.6 i/s
#  to_s.split  | 5835694.7 i/s - 8.84x  | 1427819.0 i/s
#
# [:metric, :version] memsize_2.3.7
#
#  method      | nil                | str
# -------------+--------------------+-------------
#  ?split:[]   | 40.0 bytes         | 360.0 bytes
#  &&split||[] | 40.0 bytes         | 360.0 bytes
#  to_s.split  | 80.0 bytes - 2.00x | 360.0 bytes
#
# [:metric, :version] memsize_2.4.4
#
#  method      | nil                | str
# -------------+--------------------+-------------
#  ?split:[]   | 40.0 bytes         | 360.0 bytes
#  &&split||[] | 40.0 bytes         | 360.0 bytes
#  &.split||[] | 40.0 bytes         | 360.0 bytes
#  to_s.split  | 80.0 bytes - 2.00x | 360.0 bytes

NSTRING = nil
DELIMITER='/'.freeze
STRING="ab/cd/ef/gh".freeze

Benchmark.items(metrics: %w(ips memsize), memory: 3, warmup: 1, time: 1, quiet: false, force: ENV["FORCE"] == "true") do |x|
  x.metadata version: RUBY_VERSION
  x.metadata data: "nil" do
    x.report("to_s.split",  "NSTRING.to_s.split(DELIMITER)")
    x.report("?split:[]",   "NSTRING ? NSTRING.split(DELIMITER) : []")
  end
  x.metadata data: :str do
    x.report("to_s.split",  "STRING.to_s.split(DELIMITER)")
    x.report("?split:[]",   "STRING ? STRING.split(DELIMITER) : []")
  end

  # partition the data by ruby version and data present
  # that way we're not comparing a split on a nil vs a split on a populated string
  x.compare_by :version, :data
if ENV["CONDENSED"].to_s == "true"
  x.report_with grouping: :version, sort: true, row: :method, column: [:data, :metric]
else
  x.report_with grouping: [:version, :metric], sort: true, row: :method, column: :data
end

  x.save_file (ENV["SAVE_FILE"] == "true") ? $0.sub(/\.rb$/, '.json') : ENV["SAVE_FILE"] if ENV["SAVE_FILE"]
end
