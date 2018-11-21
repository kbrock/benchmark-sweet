require 'benchmark/sweet'
require 'active_support/all'
require "more_core_extensions/all" # [].tabelize

# ruby version 2.4.4
#
#  method      | nil_ips                | str_ips       | nil_memsize        | str_memsize
# -------------+------------------------+---------------+--------------------+-------------
#  ?split:[]   | 52393098.1 i/s         | 1500442.2 i/s | 40.0 bytes         | 360.0 bytes
#  &&split||[] | 46384117.7 i/s - 1.13x | 1476738.0 i/s | 40.0 bytes         | 360.0 bytes
#  &.split||[] | 46135131.5 i/s - 1.14x | 1482862.7 i/s | 40.0 bytes         | 360.0 bytes
#  to_s.split  | 6213504.6 i/s - 8.43x  | 1481689.6 i/s | 80.0 bytes - 2.00x | 360.0 bytes

NSTRING    = nil
DELIMITER  = '/'.freeze
STRING     = "ab/cd/ef/gh".freeze
if ARGV.include?("--color")
VALUE_TO_S = lambda do |m|
  if m.best? || m.overlaps?
    "\033[32m#{m.comp_short}\e[0m"
  elsif m.offset == m.total-1 # worst
    "\033[31m#{m.comp_short}\e[0m"
  else
    m.comp_short
  end
end
else
VALUE_TO_S = -> m { m.comp_short }
end
COL_TO_S = -> (m) { "#{m.label[:data] || "nil"}_#{m.metric}" }

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

  # V1
  x.report_with grouping: :version, row: :method, column: COL_TO_S

  # V3
  # comparisons are made, but no grouping and organization is available. Note, arity == 1
  x.report_with do |comparisons|
    Benchmark::Sweet.table(comparisons, grouping: :version, row: :method, column: COL_TO_S, value: VALUE_TO_S) do |table_header, rows|
      puts "", "ruby #{:version} #{table_header}", ""
      puts rows.tableize(:columns => rows.first.keys)
    end
  end

  x.save_file (ENV["SAVE_FILE"] == "true") ? $0.sub(/\.rb$/, '.json') : ENV["SAVE_FILE"] if ENV["SAVE_FILE"]
end
