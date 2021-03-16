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
    def items(options = {memory: true, ips: true})
      job = ::Benchmark::Sweet::Job.new(options)

      yield job

      job.load_entries
      job.run
      job.save_entries

      job.run_report

      job # both items and entries are useful
    end

    # report helper methods
    # these are the building blocks for the reports printed.
    # These can be used to create different tables

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

      label_records = base.group_by(&grouping).select { |value, _comparisons| !value.nil? }
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
        table_cols = normalize_data(table_rows) unless table_cols.count == 1
        print_table(header_name, header_value, table_rows, table_cols)
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

    def self.print_table(header_name, header_value, rows, cols)
      puts
      puts cols.inspect
      puts
      puts "#{header_name} #{header_value}", "" if header_value
      to_table(rows, cols)
    end

    COLOR_ESCAPE = /\e\[[^m]+m/
    def self.to_table(rows, cols)

      rows.each do |row|
        field_sizes[row] = cols.map { |col| row[col].to_s.gsub(COLOR_ESCAPE, '').length }
      end
      field_sizes[cols] = cols.map { |col| col.to_s.gsub(COLOR_ESCAPE, '').length }

      column_sizes = rows.reduce([]) do |lengths, row|
        row.each_with_index.map { |_iterand, index| [lengths[index] || 0, field_sizes[row][index]].max }
      end

      format  = " "
      format += "\e[32m%#{column_sizes.first}s | "
      format += column_sizes[1..-1].collect {|n| "%-#{n}s" }.join(" | ")
      format += "\n"

      printf format, *cols

      printf format, *column_sizes.collect { |w| "-" * w }
      rows.each do |row|
        data  = [row[cols[0]]]
        data += cols[1..-1].each_with_index.map { |el, i| row[el].to_s + " "*(column_sizes[i+1] - field_sizes[row][i+1] ) }
        printf format, *data
      end
    end

     def self.normalize_data(rows)
      cols = []
      rows.each { |r| cols |= r.keys }
      rows.each { |r| cols.each { |k| r[k] ||= nil } }
      cols
    end
  end
  extend Benchmark::Sweet
end
