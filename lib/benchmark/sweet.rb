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

    def self.print_table(header_name, header_value, table_rows)
      puts "", "#{header_name} #{header_value}", "" if header_value
      to_table(table_rows)
    end

    def self.to_table(arr)
      col_counts = arr.map { |row| row.size }.uniq
      standardize_size(arr, col_counts) if col_counts.size > 1

      field_sizes = Hash.new
      arr.each { |row| field_sizes.merge!(row => row.map { |iterand| iterand[1].to_s.gsub(/\e\[[^m]+m/, '').length } ) }

      column_sizes = arr.reduce([]) do |lengths, row|
        row.each_with_index.map { |iterand, index| [lengths[index] || 0, field_sizes[row][index]].max }
      end

      format = column_sizes.collect {|n| "%#{n}s" }.join(" | ")
      format += "\n"

      printf format, *arr[0].each_with_index.map { |el, i| " "*(column_sizes[i] - field_sizes[arr[0]][i] ) + el[0].to_s }

      printf format, *column_sizes.collect { |w| "-" * w }

      arr.each { |line| printf format, *line.each_with_index.map { |el, i| " "*(column_sizes[i] - field_sizes[line][i] ) + el[1].to_s } }
    end

    def self.standardize_size(arr, col_counts)
      max_col_count = col_counts.max
      col_names = arr.find { |row| row.count == max_col_count }.map(&:first)
      arr.each do |line|
        next if line.count == max_col_count

        larr = line.to_a
        full_line = col_names.select { |c| !larr.map(&:first).include?(c) }.flat_map { |col| larr.insert(col_names.index(col), [col, ""]) }
        arr.map! { |l| l == line ? full_line.to_h : l }
      end
    end
  end
  extend Benchmark::Sweet
end
