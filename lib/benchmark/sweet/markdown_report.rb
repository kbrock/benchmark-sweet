# frozen_string_literal: true

module Benchmark
  module Sweet
    class MarkdownReport
      attr_accessor :grouping, :row, :column, :sort, :value, :cell

      def initialize
        @grouping = nil
        @row = :label
        @column = :metric
        @sort = false
        @value = method(:render_cell)
        @cell = nil
      end

      def render(comparisons, io)
        Benchmark::Sweet.table(comparisons, grouping: grouping, row: row, column: column, cell: cell, value: -> c { c }, sort: sort) do |header_value, table_rows|
          next if table_rows.empty?
          print_table(header_value, table_rows, out: io)
        end
      end

      private

      def print_table(header_value, table_rows, out: $stdout)
        return if table_rows.empty?

        headers = Benchmark::Sweet.column_headers(table_rows)

        formatted_rows = table_rows.map do |row_data|
          headers.map do |key|
            val = row_data[key]
            if val.nil?
              ""
            elsif val.is_a?(Hash)
              val.values.map { |v| value.call(v, color: false) }.join(" | ")
            elsif val.is_a?(Benchmark::Sweet::Comparison)
              value.call(val, color: false)
            else
              val.to_s
            end
          end
        end

        widths = headers.each_with_index.map do |h, i|
          values_max = formatted_rows.map { |r| r[i].length }.max || 0
          [h.to_s.length, values_max, 3].max
        end

        pad = ->(str, width, right) {
          padding = " " * [width - str.length, 0].max
          right ? padding + str : str + padding
        }

        out.puts "", "#{header_value}", "" if header_value
        out.puts headers.each_with_index.map { |h, i| pad.call(h.to_s, widths[i], i > 0) }.join(" | ")
        out.puts widths.map { |w| "-" * w }.join("-|-")
        formatted_rows.each do |row_data|
          out.puts row_data.each_with_index.map { |v, i| pad.call(v, widths[i], i > 0) }.join(" | ")
        end
      end

      def render_cell(c, color: false)
        c.comp_short("#{format_number(c.central_tendency)} #{c.units}", color: color)
      end

      def format_number(num)
        whole, dec = num.round(1).to_s.split(".")
        formatted = whole.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
        dec && dec != "0" ? "#{formatted}.#{dec}" : formatted
      end
    end
  end
end
