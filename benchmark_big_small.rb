require "benchmark/sweet"
require "active_support/all"
require "more_core_extensions/all" # [].tabelize

# output:
#
#ruby version 2.4.4
#
#  method     | nil_ips               | str_ips       | nil_memsize        | str_memsize
# ------------+-----------------------+---------------+--------------------+-------------
#  ?split:[]  | 54245346.4 i/s        | 1565988.8 i/s | 40.0 bytes         | 360.0 bytes
#  to_s.split | 6329087.9 i/s - 8.57x | 1520690.3 i/s | 80.0 bytes - 2.00x | 360.0 bytes

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
  # if we are using built in reporting, a little nicer to display just the method name for the label:

  # custom reporting - all the comparisons are done, we just need to group / display the data
  x.report_with do |comparisons|
    # group by version
    Benchmark::Sweet.group(comparisons, :version, sort: true) do |group_header, group_comparisons|
      # group by metric
      Benchmark::Sweet.group(group_comparisons, -> m { m.metric} , sort: true) do |table_header, table_comparisons|
        puts "", "ruby #{group_header} #{table_header}", ""
        # produce array, each represents a different method (row label)
        rows = Benchmark::Sweet.group(table_comparisons, :method).map do |row_header, row_comparisons|
          # build each row's hash. left most label = method
          row_comparisons.each_with_object(:method => row_header) do |m, row|
            # build each row's column: header is $label_$metric, and value is short comparison value
            row[m.label[:data]] = m.comp_short
          end
        end
        # print table results (thanks more_core_extensions)
        puts rows.tableize(:columns => rows.first.keys)
      end
    end
  end

  x.save_file ENV["SAVE_FILE"] if ENV["SAVE_FILE"]
end
