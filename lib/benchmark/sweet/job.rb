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
        @options[:metrics] ||= IPS_METRICS + %w()
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
        # current item metadata
        @meta = {}
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

      # @returns  [Boolean] true to suppress the display of interim test calculations
      def quiet? ; options[:quiet] ; end

      # @returns  [Boolean] true to run tests for data that has already been processed
      def force? ; options[:force] ; end

      # @returns [Array<String>] List of metrics to compare
      def relevant_metric_names ; options[:metrics] ; end

      # items to run (typical benchmark/benchmark-ips use case)
      def item(label, action = nil, &block)
        # could use Benchmark::IPS::Job::Entry
        current_meta = label.kind_of?(Hash) ? @meta.merge(label) : @meta.merge(method: label)
        @items << Item.new(current_meta, action || block)
      end
      alias report item

      def metadata(options)
        @old_meta = @meta
        @meta = @meta.merge(options)
        return unless block_given?
        yield
        @meta = @old_meta
      end

      def save_file(filename)
        @filename = filename
      end

      # &block - a lambda that accepts a label and a stats object
      # returns a unique object for each set of metrics that should be compared with each other
      #
      # example:
      #   x.compare_by { |label, value| label[:data] }
      #   x.compare_by :data
      #
      def compare_by(*symbol, &block)
        @grouping = symbol.empty? ? block : Proc.new { |label, value| symbol.map { |s| label[s] } }
      end

      # Setup the testing framework
      # TODO: would be easier to debug if these were part of run_report
      # @keyword :grouping [Symbol|Block] proc with parameters label, stat that generates grouping names
      # @keyword :sort [Boolean] true to sort the rows (default false). NOTE: grouping names ARE sorted
      # @keyword :row [Symbol|lambda] a lambda (default - display the full label)
      # @keyword :column (default - metric)
      # @keyword :value  (default comp_short / value and difference information)
      def report_with(args = {}, &block)
        @report_options = args
        @report_block = block
        # Assume the display grouping is the same as comparison grouping unless an explicit value was provided
        if !args.key?(:grouping) && @grouping
          args[:grouping] = @grouping.respond_to?(:call) ? -> v { @grouping.call(v.label, v.stats) } : @grouping
        end
      end

      # if we are using symbols as keys for our labels
      def labels_have_symbols!
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
          n.symbolize_keys!
          add_entry n, v["metric"], v["samples"]
        end

      end

      def save_entries(filename = @filename)
        return unless filename
        require "json"

        # sanity checking
        symbol_value = false

        data = @entries.flat_map do |metric_name, metric_values|
          metric_values.map do |label, stat|
            # warnings
            symbol_values ||= label.kind_of?(Hash) && label.values.detect { |v| v.nil? || v.kind_of?(Symbol) }
            {
              'name'    => label,
              'metric'  => metric_name,
              'samples' => stat.samples,
              # extra data like measured_us, iter, and others?
            }
          end
        end

        puts "", "Warning: Please use strings or numbers for label hash values (not nils or symbols). Symbols are not JSON friendly." if symbol_value
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
        comparison_values.tap do |results|
          display_report(results)
        end
      end

      def display_report(comparisons)
        if !@report_block || @report_block.arity == 2
          Benchmark::Sweet.table(comparisons, **@report_options, &@report_block)
        else
          @report_block.call(comparisons)
        end
      end

      # of note, this groups with @grouping (defined by group_by)
      # but then all data continues to the next step
      # this allows you to make comparisons across rows / columns / grouping
      def comparison_values
        relevant_entries.flat_map do |metric_name, metric_entries|
          # TODO: map these to Comparison(metric_name, label, stats) So we only have 1 type of lambda
          partitioned_metrics = grouping ? metric_entries.group_by(&grouping) : {nil => metric_entries}
          partitioned_metrics.flat_map do |grouping_name, grouped_metrics|
            sorted = grouped_metrics.sort_by { |n, e| e.central_tendency }
            sorted.reverse! if HIGHER_BETTER.include?(metric_name)

            _best_label, best_stats = sorted.first
            total = sorted.count

            # TODO: fix ranking. i / total doesn't work as well when there is only 1 entry or some entries are the same
            sorted.each_with_index.map { |(label, stats), i| Comparison.new(metric_name, label, stats, i, total, best_stats) }
          end
        end
      end

      private

      def validate_metrics(metric_options)
        if !(invalid = metric_options - ALL_METRICS).empty?
          $stderr.puts "unknown metrics: #{invalid.join(", ")}"
          $stderr.puts "choose: #{(ALL_METRICS).join(", ")}"
          raise IllegalArgument, "unknown metric: #{invalid.join(", ")}"
        end
      end

      def create_stats(samples)
        Benchmark::IPS::Stats::SD.new(Array(samples))
      end
    end
  end
end
