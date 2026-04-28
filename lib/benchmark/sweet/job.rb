module Benchmark
  module Sweet
    # abstract notion of a job
    class Job
      include Benchmark::Sweet::IPS
      include Benchmark::Sweet::Memory
      include Benchmark::Sweet::Queries

      # metrics calculated by the ips test suite
      IPS_METRICS      = %w(ips).freeze
      # metrics calculated by the memory test suite
      MEMORY_METRICS   = %w(memsize memsize_retained objects objects_retained strings strings_retained).freeze
      # metrics calculated by the database test suite
      DATABASE_METRICS = %w(rows queries ignored ignored cached).freeze
      ALL_METRICS      = (IPS_METRICS + MEMORY_METRICS + DATABASE_METRICS).freeze
      HIGHER_BETTER    = %w(ips).freeze

      # @returns [Array<Job::Item>] list of report items to run
      attr_reader :items
      # @returns [Hash<String,Hash<String,Stat>>] entries[name][metric] = value
      attr_reader :entries

      # @option options :quiet    [Boolean] true to suppress the display of interim test calculations
      # @option options :warmup   [Number]  For ips tests, the amount of time to warmup
      # @option options :time     [Number]  For ips tests, the amount of time to the calculations
      # @option options :metrics  [String|Symbol,Array<String|Symbol] list of metrics to run
      # TODO: :confidence
      attr_reader :options

      # lambda used to group metrics that should be compared
      # The lambda takes the label as an argument and returns a unique object per comparison group 
      # NOTE: This lambda takes a label hash as an argument
      #       While other lambdas in this api take a comparison object
      # a symbol is assumed to refer to the label
      # @return [Nil|Lambda] lambda for grouping
      attr_reader :grouping

      def initialize(options = {})
        @options = options
        @options[:metrics] ||= IPS_METRICS.dup
        validate_metrics(@options[:metrics])
        @items = []
        @entries = {}
        @symbolize_keys = false
        # load / save
        @filename = nil
        # display
        @grouping = nil
        @report_options = {}
        @report_block = nil
        @skip_unremarkable = false
        @format = :markdown
        @report_output = nil
        # current item metadata
        @meta = {}
      end

      def configure(options)
        @options.merge!(options)
      end

      # @returns [Boolean] true to run iterations per second tests
      def ips? ; (relevant_metric_names & IPS_METRICS).any?; end
      # @returns [Boolean] true to run memory tests
      def memory? ; (relevant_metric_names & MEMORY_METRICS).any?; end
      # @returns [Boolean] true to run database queries tests
      def database? ; (relevant_metric_names & DATABASE_METRICS).any?; end

      # @returns  [Boolean] true to suppress the display of interim test calculations
      def quiet?; options[:quiet]; end

      # @returns  [Boolean] true to run tests for data that has already been processed
      def force?; options[:force]; end

      # @returns [Array<String>] List of metrics to compare
      def relevant_metric_names; options[:metrics]; end

      # items to run (typical benchmark/benchmark-ips use case)
      def item(label, action = nil, &block)
        # could use Benchmark::IPS::Job::Entry
        current_meta = label.kind_of?(Hash) ? @meta.merge(label) : @meta.merge(method: label)
        @items << Item.new(normalize_label(current_meta), action || block)
      end
      alias report item

      def metadata(options)
        @old_meta = @meta
        @meta = @meta.merge(options)
        return unless block_given?
        yield
        @meta = @old_meta
      end

      def save_file(filename = $PROGRAM_NAME.sub(/\.rb$/, '.json'))
        @filename = filename
      end

      # Set the report output format (:markdown, :html, or a class)
      def format(fmt = nil)
        @format = fmt if fmt
        @format
      end

      # Set the report output destination (nil = stdout, filename = file)
      def report_output(filename = nil)
        @report_output = filename if filename
        @report_output
      end

      def save_sql(filename, explain: true)
        @sql_filename = filename
        @sql_entries = {}
        @sql_explain = explain
      end

      # &block - a lambda that accepts a label and a stats object
      # returns a unique object for each set of metrics that should be compared with each other
      #
      # unfortunatly, this currently has a different signature than all other lambdas
      # at this time, there are no comparisons created yet. so it is hard to pass one in
      # example:
      #   x.compare_by { |label, value| label[:data] }
      #   x.compare_by :data
      #
      def compare_by(*symbol, &block)
        @compare_by_keys = symbol unless symbol.empty?
        @grouping = symbol.empty? ? block : Proc.new { |label, _value| symbol.map { |s| label[s] } }
      end

      # Skip comparisons where all entries are within error of each other
      def skip_unremarkable!
        @skip_unremarkable = true
      end

      # Setup the testing framework
      # TODO: would be easier to debug if these were part of run_report
      # @keyword :grouping [Symbol|lambda|nil] proc with parameters label, stat that generates grouping names
      #          defaults to the compare_by value
      # @keyword :sort [Boolean] true to sort the rows (default false). NOTE: grouping names ARE sorted
      # @keyword :row [Symbol|lambda] a lambda (default - display the full label)
      # @keyword :column [Symbol|lambda] (default :metric)
      # @keyword :value  (default :comp_short - the value and delta)
      #          for color, consider passing `value: ->(m){ m.comp_short("\033[#{m.color}m#{m[field]}\e[0m") }`
      def report_with(args = {}, &block)
        @report_options = args
        @report_block = block
        # Assume the display grouping is the same as comparison grouping unless an explicit value was provided
        if !args.key?(:grouping) && @grouping
          args[:grouping] = @grouping.respond_to?(:call) ? -> v { @grouping.call(v.label, v.stats) } : @grouping
        end
      end

      # report results
      def add_entry(label, metric, stat)
        (@entries[metric] ||= {})[label] = stat.respond_to?(:central_tendency) ? stat : create_stats(stat)
      end

      def entry_stat(label, metric)
        @entries.dig(metric, label)
      end

      # Filter entries by label values for reporting. Does not modify stored data.
      # Hash: inclusion filter. Block: custom predicate on label.
      # Examples:
      #   filter config: %w[mp1 mp3 ltree]
      #   filter { |label| !label[:operation].start_with?("ancestor_ids") }
      #   filter(config: %w[mp1 mp3]) { |label| label[:operation] != "ancestor_ids cached" }
      def filter(criteria = nil, &block)
        @filter_criteria = criteria
        @filter_block = block
      end

      def relevant_entries
        entries = relevant_metric_names.map { |n| [n, @entries[n]] }
        return entries unless @filter_criteria || @filter_block

        entries.map do |metric_name, metric_entries|
          filtered = metric_entries.select do |label, _stat|
            next false if @filter_criteria && !@filter_criteria.all? { |k, v| Array(v).include?(label[k].to_s) }
            next false if @filter_block && !@filter_block.call(label)
            true
          end
          [metric_name, filtered]
        end
      end
      # serialization

      def load_entries(filename = @filename)
        # ? have ips save / load their own data?
        return unless filename && File.exist?(filename)
        require "json"

        JSON.load(IO.read(filename)).each do |v|
          n = normalize_label(v["name"].transform_keys(&:to_sym))
          add_entry n, v["metric"], v["samples"]
        end

      end

      def write_sql(filename = @sql_filename)
        return unless filename && @sql_entries&.any?

        all_labels = @sql_entries.keys
        all_keys = all_labels.first.keys
        constant_keys = all_keys.select { |k| all_labels.map { |l| l[k] }.uniq.size == 1 }
        varying_keys = all_keys - constant_keys

        File.open(filename, "w") do |f|
          constant_keys.each { |k| f.puts "# #{k}: #{all_labels.first[k]}" }
          f.puts ""

          @sql_entries.each do |label, queries|
            header = varying_keys.map { |k| label[k] }.join(": ")
            f.puts "== #{header} =="

            if queries.empty?
              f.puts "(no queries)"
            else
              # Group by normalized SQL to dedup, keep first raw entry for EXPLAIN
              grouped = queries.each_with_object({}) do |(raw_sql, binds), hash|
                normalized = normalize_sql(raw_sql)
                hash[normalized] ||= { count: 0, raw_sql: raw_sql, binds: binds }
                hash[normalized][:count] += 1
              end

              grouped.each do |normalized, info|
                prefix = info[:count] > 1 ? "(#{info[:count]}x) " : ""
                f.puts "SQL: #{prefix}#{normalized}"
                if @sql_explain
                  explain_sql(info[:raw_sql], info[:binds]).each { |line| f.puts "PLAN: #{line}" }
                end
              end
            end
            f.puts ""
          end
        end

      end

      def save_entries(filename = @filename)
        return unless filename
        require "json"

        data = @entries.flat_map do |metric_name, metric_values|
          metric_values.map do |label, stat|
            {
              'name'    => label,
              'metric'  => metric_name,
              'samples' => stat.samples,
            }
          end
        end

        IO.write(filename, JSON.pretty_generate(data) << "\n")
      end

      def run
        return if items.empty?

        # run metrics if they are requested and haven't run yet
        # only run the suites that provide the data the user needs.
        # if the first node has the data, assumes all do
        #
        # TODO: may want to override these values
        run_ips     if ips?      && (force? || !@entries.dig(IPS_METRICS.first, items.first.label))
        run_memory  if memory?   && (force? || !@entries.dig(MEMORY_METRICS.first, items.first.label))
        run_queries if database? && (force? || @sql_filename || !@entries.dig(DATABASE_METRICS.first, items.first.label))
      end

      # ? metric => label(:version, :method) => stats
      # ? label(:metric, :version, :method) => stats
      # @returns [Hash<String,Hash<String,Comparison>>] Same as entries, but contains comparisons not Stats
      def run_report
        comparison_values.tap do |results|
          write_report(results)
        end
      end

      def write_report(comparisons)
        formatter = resolve_formatter
        formatter.grouping = @report_options[:grouping]
        formatter.row = @report_options[:row] if @report_options[:row]
        formatter.column = @report_options[:column] if @report_options[:column]
        formatter.sort = @report_options[:sort] if @report_options[:sort]
        formatter.cell = @report_options[:cell] if @report_options[:cell] && formatter.respond_to?(:cell=)
        formatter.bar = @report_options[:bar] if @report_options[:bar] && formatter.respond_to?(:bar=)
        formatter.line = @report_options[:line] if @report_options[:line] && formatter.respond_to?(:line=)
        formatter.scatter = @report_options[:scatter] if @report_options[:scatter] && formatter.respond_to?(:scatter=)
        formatter.value = @report_options[:value] if @report_options[:value]
        formatter.baseline = @report_options[:baseline] if @report_options[:baseline] && formatter.respond_to?(:baseline=)
        formatter.title = File.basename(@report_output.to_s, ".*") if @report_output && formatter.respond_to?(:title=)

        io = case @report_output
             when nil, "-" then $stdout
             else File.open(@report_output, "w")
             end
        formatter.render(comparisons, io)
      ensure
        io.close if io.is_a?(File)
      end

      # of note, this groups with @grouping (defined by group_by)
      # but then all data continues to the next step
      # this allows you to make comparisons across rows / columns / grouping
      def comparison_values
        baseline_match = resolve_baseline(@report_options[:baseline])

        relevant_entries.flat_map do |metric_name, metric_entries|
          partitioned_metrics = grouping ? metric_entries.group_by(&grouping) : {nil => metric_entries}
          partitioned_metrics.flat_map do |_grouping_name, grouped_metrics|
            sorted = grouped_metrics.sort_by { |_n, e| e.central_tendency }
            sorted.reverse! if HIGHER_BETTER.include?(metric_name)

            _best_label, best_stats = sorted.first
            _worst_label, worst_stats = sorted.last
            total = sorted.count

            reference_stats = if baseline_match
              _label, stats = grouped_metrics.find { |label, _| baseline_match.all? { |k, v| label[k].to_s == v.to_s } }
              stats
            end

            comparisons = sorted.each_with_index.map { |(label, stats), i| Comparison.new(metric_name, label, stats, i, total, best_stats, worst: worst_stats, reference: reference_stats) }
            @skip_unremarkable && comparisons.size > 1 && comparisons.first&.all_same? ? [] : comparisons
          end
        end
      end

      private

      # Resolve baseline to a label match hash.
      # Hash: use as-is. String: derive the key from column/row vs compare_by.
      # The baseline key is whichever of column/row is NOT in compare_by
      # (i.e., the dimension that varies within a comparison group).
      def resolve_baseline(baseline)
        return baseline if baseline.is_a?(Hash)
        return unless baseline

        key = if @compare_by_keys
          column = @report_options[:column]
          row = @report_options[:row]
          if column && !@compare_by_keys.include?(column)
            column
          elsif row && !@compare_by_keys.include?(row)
            row
          end
        end
        key ||= @report_options[:column]

        key ? {key => baseline} : nil
      end

      def resolve_formatter
        case @format
        when :html
          require "benchmark/sweet/html_report"
          Benchmark::Sweet::HtmlReport.new
        when :chart
          require "benchmark/sweet/chart_report"
          Benchmark::Sweet::ChartReport.new
        when :markdown
          require "benchmark/sweet/markdown_report"
          Benchmark::Sweet::MarkdownReport.new
        when Class
          @format.new
        else
          @format
        end
      end

      def validate_metrics(metric_options)
        if !(invalid = metric_options - ALL_METRICS).empty?
          $stderr.puts "unknown metrics: #{invalid.join(", ")}"
          $stderr.puts "choose: #{(ALL_METRICS).join(", ")}"
          raise IllegalArgument, "unknown metric: #{invalid.join(", ")}"
        end
      end

      # Normalize label hash values to strings so labels match after JSON round-trip
      def normalize_label(label)
        label.transform_values(&:to_s)
      end

      def create_stats(samples)
        Benchmark::IPS::Stats::SD.new(Array(samples))
      end

      def normalize_sql(sql)
        sql
          .gsub(/'[^']*'/, "?")                    # quoted strings
          .gsub(/= \d+/, "= ?")                    # = 123
          .gsub(/IN \([\d, ]+\)/, "IN (?)")        # IN (1, 2, 3)
          .gsub(/LIMIT \d+/, "LIMIT ?")            # LIMIT 1
          .gsub(/OFFSET \d+/, "OFFSET ?")          # OFFSET 5
          .gsub(/VALUES \([^)]+\)/, "VALUES (?)")  # VALUES (...)
      end

      def explain_sql(sql, binds = nil)
        conn = ActiveRecord::Base.connection
        if binds&.any?
          conn.exec_query("EXPLAIN #{sql}", "EXPLAIN", binds).rows.map { |r| r.join(" ") }
        else
          conn.explain(sql).strip.split("\n")
        end
      rescue => e
        ["EXPLAIN failed: #{e.message}"]
      end
    end
  end
end
