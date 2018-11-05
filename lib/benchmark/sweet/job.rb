module Benchmark
  module Sweet
    # abstract notion of a job
    class Job
      include Benchmark::Sweet::IPS
      include Benchmark::Sweet::Memory
      include Benchmark::Sweet::Queries

      IPS_METRICS      = %w(ips).freeze
      MEMORY_METRICS   = %w(memsize  memsize_retained  objects  objects_retained  strings  strings_retained).freeze
      DATABASE_METRICS = %w(queries_objects queries_count queries_other queries_cache).freeze
      ALL_METRICS      = (IPS_METRICS + MEMORY_METRICS + DATABASE_METRICS).freeze
      HIGHER_BETTER    = %w(ips).freeze

      # @returns [Array<Job::Item>] list of report items to run
      attr_reader :items
      # @returns [Hash<String,Hash<String,Stat>>] entries[name][metric] = value
      attr_reader :entries

      # @option options :quiet    [Boolean]
      # @option options :time     [Number]
      # @option options :warmup   [Number]
      # @option options :ips      [Boolean]
      # @option options :memory   [Boolean]
      # @option options :database [Boolean]
      # @option options :stats    [Symbol] :sd for standard deviation, :bootstrap for Kalibera (default :sd)
      # TODO: :confidence
      attr_reader :options

      # lambda used to group metrics that should be compared
      # The lambda takes the label as an argument and returns a unique object per comparison group 
      # @return [Nil|Lambda] lambda for grouping
      attr_reader :grouping

      # # lambda that takes a label and produces a string for reports 
      # # @return [Lambda] lambda to convert an item's label to the screen (default: to_s)
      # attr_reader :labeling

      # L_TO_S = -> l { l.to_s }

      def initialize(options = {})
        @options = options
        @items = []
        @entries = {}
        #@compare = false
        @symbolize_keys = false
        # load / save
        @filename = nil
        # display lambdas
        # @labeling = L_TO_S
        @grouping = nil
        @reporting = nil
      end

      def configure(options)
        @options.merge!(options)
      end

      # @returns [Boolean] true to run iterations per second tests
      def ips? ; !(relevant_metric_names & IPS_METRICS).empty? ; end
      # @returns [Boolean] true to run memory tests
      def memory? ; !(relevant_metric_names & MEMORY_METRICS).empty? ; end
      # @returns [Boolean] true to run database queries tests
      def database? ; !(relevant_metric_names & DATABASE_METRICS).empty? ; end

      # TODO: override reporting instead?
      # @returns  [Boolean] true to compare results
      #def compare? ; @compare ; end
      def quiet? ; options[:quiet] ; end
      def force? ; options[:force] ; end

      # @returns [Array<String>] List of metrics to compare
      def relevant_metric_names ; options[:metrics] ; end

      # items to run (typical benchmark/benchmark-ips use case)
      def item(label, action = nil, &block)
        # could use Benchmark::IPS::Job::Entry
        @items << Item.new(label, action || block)
      end
      alias report item

      def save_file(filename)
        @filename = filename
      end

      # def compare!
      #   @compare = true
      # end

      def compare_by(&block)
        @grouping = block
      end

      def report_with(&block)
        @reporting = block
      end

      # def label_with(&block)
      #   @labeling = block
      # end

      # if we are using symbols as keys for our labels
      def labels_have_symbols!
        @symbolize_keys = true
      end

      # report results
      def add_entry(label, metric, stat)
        (@entries[metric] ||= {})[label] = stat.respond_to?(:central_tendency) ? stat : create_stats(stat)
      end

      def entry_stat(label, metric)
        @entries.dig(metric, label)
      end

      def relevant_entries
        relevant_metric_names.map { |n| [n, @entries[n] ] }
      end
      # serialization

      def load_entries(filename = @filename)
        # ? have ips save / load their own data?
        return unless filename && File.exist?(filename)
        require "json"

        JSON.load(IO.read(filename)).each do |v|
          n = v["name"]
          n.symbolize_keys! if n.kind_of?(Hash) && @symbolize_keys
          add_entry n, v["metric"], v["samples"]
        end

        #puts "have #{@entries.flat_map(&:count).inject(&:+)} #{}"
      end

      def save_entries(filename = @filename)
        return unless filename
        require "json"

        # sanity checking
        symbol_key   = false
        symbol_value = false

        data = @entries.flat_map do |metric_name, metric_values|
          metric_values.map do |label, stat|
            # warnings
            symbol_key    ||= label.kind_of?(Hash) && label.keys.detect { |key| key.kind_of?(Symbol) }
            symbol_values ||= label.kind_of?(Hash) && label.values.detect { |v| v.nil? || v.kind_of?(Symbol) }
            {
              'name'    => label,
              'metric'  => metric_name,
              'samples' => stat.samples,
              # extra data like measured_us, iter, and others?
            }
          end
        end

        puts if symbol_key || symbol_value
        puts "Warning: Please use strings or numbers for label hash values (not nils or symbols). Symbols are not JSON friendly."
        if symbol_key && !@symbolize_keys
          puts "Warning: Please add labels_have_symbols! to properly support labels with symbols as keys."
          puts "Warning: Please require active support for symbols as keys." unless defined?(ActiveSupport)
        end
        IO.write(filename, JSON.pretty_generate(data) << "\n")
      end

      def run
        # run metrics if they are requested and haven't run yet
        # may want to override these values
        run_ips     if ips?      && (force? || !@entries.dig(IPS_METRICS.first, items.first.label))
        run_memory  if memory?   && (force? || !@entries.dig(MEMORY_METRICS.first, items.first.label))
        run_queries if database? && (force? || !@entries.dig(DATABASE_METRICS.first, items.first.label))
      end

      # ? metric => label(:version, :method) => stats
      # ? label(:metric, :version, :method) => stats
      # @returns [Hash<String,Hash<String,Comparison>>] Same as entries, but contains comparisons not Stats
      def run_report
        return unless @reporting # || compare?

        results = comparison_values
        if @reporting
          @reporting.call(results)
        else
          ips_compare_report(results)
        end
        results
      end

      def ips_compare_report(comparions)
        last_metric = nil
        last_grouping = nil
        results.each do |comparison|
          if last_metric != comparison.metric
            last_metric = comparison.metric
            last_grouping = nil
            $stdout.puts "", "Comparing #{last_metric}", ""
          end
          if grouping
            if (grouping_name = grouping.call(comparison.label, comparison.stats)) != last_grouping
              last_grouping = grouping_name
              $stout.puts "", grouping_name.to_s, grouping_name.to_s.gsub(/./,'-'), ""
          end
          $stdout.puts report.comp_string
        end
      end

      def comparison_values
        relevant_entries.flat_map do |metric_name, metric_entries|
          partitioned_metrics = grouping ? metric_entries.group_by(&grouping) : {nil => metric_entries}
          partitioned_metrics.flat_map do |grouping_name, grouped_metrics|
            sorted = grouped_metrics.sort_by { |n, e| e.central_tendency }
            sorted.reverse! if HIGHER_BETTER.include?(metric_name)

            _best_label, best_stats = sorted.first
            total = sorted.count

            # TODO: fix ranking. i / total doesn't work as well when there is only 1 entry or some entries are the same
            sorted.each_with_index.map { |(label, stats), i| Comparison.new(metric_name, label, i, total, stats, best_stats) }
          end
        end
      end
      private

      def create_stats(samples)
        Benchmark::IPS::Stats::SD.new(Array(samples))
      end
    end
  end
end
