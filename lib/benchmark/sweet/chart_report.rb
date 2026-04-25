# frozen_string_literal: true

module Benchmark
  module Sweet
    class ChartReport
      attr_accessor :grouping, :row, :column, :sort, :value, :title, :baseline

      def initialize
        @grouping = nil
        @row = :label
        @column = :metric
        @sort = false
        @value = nil # unused for charts, kept for interface compatibility
        @title = "Benchmark Report"
        @baseline = nil
      end

      def render(comparisons, io)
        charts = []

        Benchmark::Sweet.table(comparisons, grouping: grouping, row: row, column: column, value: -> c { c }, sort: sort) do |header_value, table_rows|
          next if table_rows.empty?
          charts << build_chart_data(header_value, table_rows)
        end

        io.puts wrap_document(title, charts)
      end

      private

      def build_chart_data(header_value, table_rows)
        headers = table_rows.flat_map(&:keys).uniq
        row_key = headers.first
        column_keys = headers[1..]

        labels = table_rows.map { |r| r[row_key].to_s }

        use_ratio = table_rows.any? { |r| column_keys.any? { |c| r[c]&.ratio } }

        datasets = column_keys.map do |col|
          values = table_rows.map do |r|
            c = r[col]
            next nil unless c
            use_ratio ? c.ratio&.round(4) : c.central_tendency.round(2)
          end
          { label: col.to_s, data: values }
        end

        units = if use_ratio
                  "relative to #{@baseline}"
                else
                  sample = table_rows.lazy.filter_map { |r| column_keys.lazy.filter_map { |c| r[c] }.first }.first
                  sample&.units || ""
                end

        {
          title: header_value.to_s,
          labels: labels,
          datasets: datasets,
          units: units,
        }
      end

      def escape(str)
        str.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
      end

      def charts_js(charts)
        js = +""
        charts.each_with_index do |chart, i|
          canvas_id = "chart-#{i}"
          js << <<~JS
            new Chart(document.getElementById('#{canvas_id}'), {
              type: 'bar',
              data: {
                labels: #{chart[:labels].map(&:to_s).inspect},
                datasets: #{datasets_json(chart[:datasets])}
              },
              options: {
                responsive: true,
                plugins: {
                  title: {
                    display: true,
                    text: #{chart[:title].inspect},
                    font: { size: 14, weight: '600' }
                  },
                  legend: { position: 'top' }
                },
                scales: {
                  y: {
                    beginAtZero: true,
                    title: {
                      display: true,
                      text: #{chart[:units].inspect}
                    }
                  }
                }
              }
            });
          JS
        end
        js
      end

      def datasets_json(datasets)
        entries = datasets.map do |ds|
          data_str = ds[:data].map { |v| v.nil? ? "null" : v.to_s }.join(", ")
          "{ label: #{ds[:label].inspect}, data: [#{data_str}] }"
        end
        "[#{entries.join(", ")}]"
      end

      def wrap_document(doc_title, charts)
        canvases = charts.each_with_index.map do |_chart, i|
          "    <div class=\"chart-container\"><canvas id=\"chart-#{i}\"></canvas></div>"
        end.join("\n")

        <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="utf-8">
            <title>#{escape(doc_title)}</title>
            <script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
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
              .chart-container {
                margin: 1.5rem 0;
                position: relative;
                height: 400px;
              }
            </style>
          </head>
          <body>
            <h1>#{escape(doc_title)}</h1>
          #{canvases}
            <script>
          #{charts_js(charts)}
            </script>
          </body>
          </html>
        HTML
      end
    end
  end
end
