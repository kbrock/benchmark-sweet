# frozen_string_literal: true

module Benchmark
  module Sweet
    class ChartReport
      attr_accessor :grouping, :row, :column, :sort, :column_sort, :value, :title, :baseline, :cell
      # bar/line/scatter: metric names (Symbol or Array) for chart type mapping
      attr_accessor :bar, :line, :scatter

      def initialize
        @grouping = nil
        @row = :label
        @column = :metric
        @sort = false
        @value = nil # unused for charts, kept for interface compatibility
        @title = "Benchmark Report"
        @baseline = nil
        @cell = nil
        @bar = nil
        @line = nil
        @scatter = nil
      end

      def render(comparisons, io)
        charts = []

        Benchmark::Sweet.table(comparisons, grouping: grouping, row: row, column: column, cell: cell, value: -> c { c }, sort: sort) do |header_value, table_rows|
          next if table_rows.empty?
          if @cell
            charts << build_multi_metric_chart(header_value, table_rows)
          else
            charts << build_chart_data(header_value, table_rows)
          end
        end

        io.puts wrap_document(title, charts)
      end

      private

      def build_chart_data(header_value, table_rows)
        headers = Benchmark::Sweet.column_headers(table_rows, baseline: @baseline, column_sort: @column_sort)
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

      # Build chart when cell: :metric is set. Each cell is a hash of {metric => Comparison}.
      # bar/line attrs control which metric renders as which type.
      def build_multi_metric_chart(header_value, table_rows)
        headers = Benchmark::Sweet.column_headers(table_rows, baseline: @baseline, column_sort: @column_sort)
        row_key = headers.first
        column_keys = headers[1..]

        labels = table_rows.map { |r| r[row_key].to_s }

        all_metrics = Array(@bar) + Array(@line) + Array(@scatter)
        axis_ids = all_metrics.each_with_index.to_h { |m, i| [m.to_s, "y#{i > 0 ? i : ""}"] }
        positions = all_metrics.each_with_index.to_h { |m, i| [m.to_s, i.even? ? "left" : "right"] }

        line_metrics = Array(@line)
        scatter_metrics = Array(@scatter)

        datasets = []
        scales = {}

        column_keys.each do |col|
          all_metrics.each do |metric|
            metric_s = metric.to_s
            chart_type = if scatter_metrics.include?(metric) then "scatter"
                         elsif line_metrics.include?(metric) then "line"
                         else "bar"
                         end
            axis_id = axis_ids[metric_s]

            values = table_rows.map do |r|
              c = r[col]&.dig(metric_s)
              next nil unless c
              c.ratio ? c.ratio.round(4) : c.central_tendency.round(2)
            end
            next if values.all?(&:nil?)

            sample = table_rows.lazy.filter_map { |r| r[col]&.dig(metric_s) }.first
            ds = { label: "#{col} #{metric_s}", data: values, type: chart_type, yAxisID: axis_id }
            ds[:fill] = false if chart_type == "line"
            ds[:borderWidth] = 2 if chart_type == "line"
            datasets << ds

            axis_title = sample&.ratio ? "relative to #{@baseline}" : (sample&.units || "")
            scales[axis_id] ||= { position: positions[metric_s], title: axis_title, beginAtZero: true }
          end
        end

        {
          title: header_value.to_s,
          labels: labels,
          datasets: datasets,
          scales: scales,
        }
      end

      def escape(str)
        str.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
      end

      def charts_js(charts)
        js = +""
        charts.each_with_index do |chart, i|
          canvas_id = "chart-#{i}"
          scales_js = if chart[:scales]
            chart[:scales].map do |id, cfg|
              "#{id}: { position: #{cfg[:position].inspect}, beginAtZero: true, title: { display: true, text: #{cfg[:title].inspect} } }"
            end.join(", ")
          else
            "y: { beginAtZero: true, title: { display: true, text: #{(chart[:units] || "").inspect} } }"
          end
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
                scales: { #{scales_js} }
              }
            });
          JS
        end
        js
      end

      def datasets_json(datasets)
        entries = datasets.map do |ds|
          data_str = ds[:data].map { |v| v.nil? ? "null" : v.to_s }.join(", ")
          parts = ["label: #{ds[:label].inspect}", "data: [#{data_str}]"]
          parts << "type: #{ds[:type].inspect}" if ds[:type]
          parts << "yAxisID: #{ds[:yAxisID].inspect}" if ds[:yAxisID]
          case ds[:type]
          when "line"
            parts << "fill: false"
            parts << "borderWidth: 2"
          when "scatter"
            parts << "pointRadius: 5"
            parts << "showLine: false"
          end
          "{ #{parts.join(", ")} }"
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
