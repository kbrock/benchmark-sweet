# frozen_string_literal: true

module Benchmark
  module Sweet
    class HtmlReport
      attr_accessor :grouping, :row, :column, :sort, :value, :title, :cell, :baseline

      def initialize
        @grouping = nil
        @row = :label
        @column = :metric
        @sort = false
        @value = method(:render_cell)
        @title = "Benchmark Report"
        @cell = nil
        @baseline = nil
      end

      def render(comparisons, io)
        tables_html = []

        Benchmark::Sweet.table(comparisons, grouping: grouping, row: row, column: column, cell: cell, value: -> c { c }, sort: sort) do |header_value, table_rows|
          next if table_rows.empty?
          tables_html << render_table(header_value, table_rows)
        end

        io.puts wrap_document(title, tables_html.join("\n"))
      end

      private

      def render_table(header_value, table_rows)
        html = +""
        html << "    <h2>#{escape(header_value.to_s)}</h2>\n" if header_value

        headers = Benchmark::Sweet.column_headers(table_rows, baseline: @baseline)
        # With 2 data columns, every cell is best or worst — color is noise, just bold best.
        # With 3+, color helps scan for the best/worst across many options.
        use_color = headers.size > 3
        html << "    <table>\n"
        html << "      <thead><tr>\n"
        headers.each { |h| html << "        <th>#{escape(h.to_s)}</th>\n" }
        html << "      </tr></thead>\n"
        html << "      <tbody>\n"

        table_rows.each do |row_data|
          html << "      <tr>\n"
          headers.each_with_index do |key, i|
            val = row_data[key]
            if i == 0
              html << "        <td class=\"row-label\">#{escape(val.to_s)}</td>\n"
            elsif val.nil?
              html << "        <td></td>\n"
            elsif val.is_a?(Hash)
              html << val.values.map { |v| value.call(v, color: use_color) }.join
            elsif val.is_a?(Benchmark::Sweet::Comparison)
              html << value.call(val, color: use_color)
            else
              html << "        <td>#{escape(val.to_s)}</td>\n"
            end
          end
          html << "      </tr>\n"
        end

        html << "      </tbody>\n"
        html << "    </table>\n"
        html
      end

      def render_cell(c, color: true)
        ratio = c.ratio
        if ratio
          val = ratio == 1.0 ? "1x" : "%.1fx" % ratio
          tip = escape("#{format_number(c.central_tendency)} #{c.units}")
        else
          val = format_number(c.central_tendency)
          tip = escape(tooltip(c))
        end
        classes = ["metric", c.mode.to_s]
        classes << "worst" if c.worst? && !c.overlaps?

        style = color ? " style=\"color: #{css_color(c)}\"" : ""

        "        <td class=\"#{classes.join(' ')}\"#{style} title=\"#{tip}\">#{val}</td>\n"
      end

      def css_color(comparison)
        case comparison.mode
        when :best then "#1a7f37"
        when :same then "#1a7f37"
        when :slower then comparison.worst? ? "#cf222e" : "#656d76"
        when :slowerish then "#656d76"
        end
      end

      def tooltip(comparison)
        case comparison.mode
        when :best
          "best"
        when :same
          "same-ish (within error)"
        when :slower
          pct = (comparison.error / comparison.central_tendency * 100).round(1)
          "%.2fx slower (\u00b1 %s%%)" % [comparison.slowdown, pct]
        when :slowerish
          "%.2fx slower" % comparison.slowdown
        end
      end

      def escape(str)
        str.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
      end

      def format_number(num)
        whole, dec = num.round(1).to_s.split(".")
        formatted = whole.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
        dec && dec != "0" ? "#{formatted}.#{dec}" : formatted
      end

      def wrap_document(doc_title, body)
        <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="utf-8">
            <title>#{escape(doc_title)}</title>
            <style>
              body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
                background: #fff;
                color: #1f2328;
                max-width: 960px;
                margin: 2rem auto;
                padding: 0 1rem;
              }
              h1 { font-size: 1.5rem; font-weight: 600; }
              h2 { font-size: 1.1rem; font-weight: 600; margin-top: 2rem; color: #656d76; }
              table {
                border-collapse: collapse;
                width: 100%;
                margin: 0.5rem 0 1.5rem;
                font-size: 0.875rem;
              }
              th, td {
                padding: 0.4rem 0.75rem;
                text-align: right;
                border-bottom: 1px solid #d1d9e0;
              }
              th {
                font-weight: 600;
                color: #656d76;
                border-bottom: 2px solid #d1d9e0;
              }
              td.row-label {
                text-align: left;
                font-weight: 500;
              }
              td.metric { font-variant-numeric: tabular-nums; }
              td.best { font-weight: 600; }
            </style>
          </head>
          <body>
            <h1>#{escape(doc_title)}</h1>
          #{body}
          </body>
          </html>
        HTML
      end
    end
  end
end
