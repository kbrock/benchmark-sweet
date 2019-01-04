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
    # @param grouping [Symbol|Array<Symbol>|Proc] Proc passed to group_by to partition records.
    #  Accepts Comparison, returns an object to partition. returns nil to filter from the list
    # @keyword sort [Boolean] true to sort by the grouping value (default false)
    #   Proc accepts the label to generate custom summary text
    def self.group(base, grouping, sort: false, &block)
      if grouping.nil?
        yield nil, base
        return
      end

      grouping = symbol_to_proc(grouping)

      label_records = base.group_by(&grouping).select { |value, comparisons| !value.nil? }
      label_records = label_records.sort_by(&:first) if sort

      label_records.each(&block)
    end

    def self.table(base, grouping: nil, sort: false, row: :label, column: :metric, value: :comp_short)

      header_name = grouping.respond_to?(:call) ? "grouping" : grouping
      column = symbol_to_proc(column)
      value = symbol_to_proc(value)

      group(base, grouping, sort: true) do |header_value, table_comparisons|
        row_key = row.kind_of?(Symbol) || row.kind_of?(String) ? row : "label"
        table_rows = group(table_comparisons, row, sort: sort).map do |row_header, row_comparisons|
          row_comparisons.each_with_object({row_key => row_header}) do |comparison, row_data|
            row_data[column.call(comparison)] = value.call(comparison)
          end
        end
        if block_given?
          yield header_value, table_rows
        else
          print_table(header_name, header_value, table_rows)
        end
      end
    end

    # proc produced: -> (comparison) { comparison.method }
    def self.symbol_to_proc(field, join: "_")
      if field.kind_of?(Symbol) || field.kind_of?(String)
        field_name = field
        -> v { v[field_name] }
      elsif field.kind_of?(Array)
        field_names = field
        if join
          -> v { field_names.map { |gn| v[gn].to_s }.join(join) }
        else
          -> v { field_names.map { |gn| v[gn] } }
        end
      else
        field
      end
    end

    # @param field [Symbol] field to display in color
    def self.color_symbol_to_proc(field)
      lambda do |m|
        if m.best? || m.overlaps?
          "\e[32m#{m[field]}\e[0m"
        elsif m.offset == m.total-1
          "\e[31m#{m[field]}\e[0m"
        else
          "\e[00m#{m[field]}\e[0m"
        end
      end
    end

    def self.print_table(header_name, header_value, table_rows)
      require "more_core_extensions" # defines tableize
      puts "", "#{header_name} #{header_value}", "" if header_value
      # passing colummns to make sure table keeps the same column order
      puts table_rows.tableize(:columns => table_rows.first.keys)
    end
  end
  extend Benchmark::Sweet
end
