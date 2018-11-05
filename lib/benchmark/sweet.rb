require "benchmark/sweet/version"
require "benchmark/sweet/ips"
require "benchmark/sweet/memory"
require "benchmark/sweet/queries"
require "benchmark/sweet/job"
require "benchmark/sweet/comparison"
require "benchmark/sweet/item"
require "benchmark/ips"

module Benchmark
  module Sweet
    # Your code goes here...
    def items(options = {memory: true, ips: true})
      job = ::Benchmark::Sweet::Job.new(options)

      yield job

      job.load_entries
      job.run
      job.save_entries

      job.run_report

      job # both items and entries are useful
    end

    # report helper method

    # @param base [Array<Comparison>}] array of comparisons
    # @param grouping [Symbol|Proc] Proc passed to group_by to partition records.
    #  Accepts Comparison, returns an object to partition. returns nil to filter from the list
    # @keyword sort [Boolean] true to sort by the grouping value (default false)
    #   Proc accepts the label to generate custom summary text
    def self.group(base, grouping, sort: false, &block)
      if grouping.nil?
        yield nil, base
        return
      end
      if grouping.kind_of?(Symbol)
        grouping_name = grouping
        grouping = -> v { v.label[grouping_name] }
      end
      label_records = base.group_by(&grouping).select { |value, comparisons| !value.nil? }
      label_records = label_records.sort_by(&:first) if sort

      label_records.each(&block)
    end

    # block = lambda |grouping_value, table_rows|
    #   puts "", "ruby #{:version} #{grouping_value}", ""
    #   puts table_rows.tableize(:columns => table_rows.first.keys)
    # end
    def self.table(base, grouping: nil, sort: false,
                         row:    -> v { v.label },
                         column: -> v { v.metric },
                         value:  -> v { v.comp_short }, &block)
      group(base, grouping, sort: true) do |table_header, table_comparisons|
        row_key = row.kind_of?(Symbol) || row.kind_of?(String) ? row : "label"
        table_rows = group(table_comparisons, row, sort: sort).map do |row_header, row_comparisons|
          row_comparisons.each_with_object({row_key => row_header}) do |comparison, row_data|
            row_data[column.call(comparison)] = value.call(comparison)
          end
        end
        yield table_header, table_rows
      end
    end
  end
  extend Benchmark::Sweet
end
