
# monkey patching until ips is updated
require 'benchmark/ips/stats/sd'
#require 'benchmark/ips/stats/bootstrap'

module Benchmark
  module IPS
    module Stats
      module StatsMetric
        # keep the samples so we can reconstruct this data in future runs
        # adding an accessor so we can get this data out to store in a json files
        attr_reader :samples
        def initialize(samples, *_)
          @samples = samples
          super
        end

        # MONKEY PATCH to handle ips (bigger numbers better) or others (smaller numbers better)
        def slowdown(baseline)
          if baseline.central_tendency > central_tendency
            [baseline.central_tendency.to_f / central_tendency, 0]
          else
            [central_tendency.to_f / baseline.central_tendency, 0]
          end
        end

        # Return entry's standard deviation of iteration per second in percentage.
        # @return [Float] +@ips_sd+ in percentage.
        def error_percentage
          100.0 * (error.to_f / central_tendency)
        end

        def overlaps?(baseline)
          baseline_low = baseline.central_tendency - baseline.error
          baseline_high = baseline.central_tendency + baseline.error
          my_high = central_tendency + error
          my_low  = central_tendency - error
          my_high > baseline_low && my_low < baseline_high
        end
      end
    end
  end
end

Benchmark::IPS::Stats::SD.send(:prepend, Benchmark::IPS::Stats::StatsMetric)

module Benchmark
  module Sweet
    class Comparison
      UNITS = {"ips" => "i/s", "memsize" => "bytes", "memsize_retained" => "bytes"}.freeze
      attr_reader :label, :metric, :stats, :baseline, :worst
      attr_reader :offset, :total
      def initialize(metric, label, stats, offset, total, baseline, worst = nil)
        @metric = metric
        @label = label
        @stats = stats
        @offset = offset
        @total = total
        @baseline = baseline
        @worst = worst
      end

      def [](field)
        case field
        when :metric      then metric
        when :comp_short  then comp_short
        when :comp_string then comp_string
        when :label       then label  # not sure if this one makes sense
        else label[field]
        end
      end

      def central_tendency ; stats.central_tendency ; end
      def error ; stats.error ; end
      def units ; UNITS[metric] || "objs" ; end

      def mode
        @mode ||= best? ? :best : overlaps? ? :same : diff_error ? :slowerish : :slower
      end

      def best? ; !baseline || (baseline == stats) ; end

      # @return true if it is basically the same as the best
      def overlaps?
        return @overlaps if defined?(@overlaps)
        @overlaps = slowdown == 1 ||
                      stats && baseline && (stats.central_tendency == baseline.central_tendency || stats.overlaps?(baseline))
      end

      def worst?
        @worst ? stats.overlaps?(@worst) : (total.to_i - 1 == offset.to_i) && slowdown.to_i > 1
      end

      def slowdown
        return @slowdown if @slowdown
        @slowdown, @diff_error = stats.slowdown(baseline)
        @slowdown
      end

      def diff_error
        @diff_error ||= (slowdown ; @diff_error)
      end

      # quick display

      def comp_string(l_to_s = nil)
        l_to_s ||= -> l { l.to_s }
        case mode
        when :best
          "%20s: %10.1f %s" % [l_to_s.call(label), central_tendency, units]
        when :same
          "%20s: %10.1f %s - same-ish: difference falls within error" % [l_to_s.call(label), central_tendency, units]
        when :slower 
          "%20s: %10.1f %s - %.2fx (± %.2f) slower" % [l_to_s.call(label), central_tendency, units, slowdown, error]
        when :slowerish
          "%20s: %10.1f %s - %.2fx slower" % [l_to_s.call(label), central_tendency, units, slowdown]
        end
      end

      # I tend to call with:
      #   c.comp_short("\033[#{c.color}m#{c.central_tendency.round(1)} #{c.units}\e[0m") # "\033[31m#{value}\e[0m"
      def comp_short(value = nil)
        value ||= "#{central_tendency.round(1)} #{units}"
        case mode
        when :best, :same
          value
        when :slower 
          "%s - %.2fx (± %.2f)" % [value, slowdown, error]
        when :slowerish
          "%s - %.2fx" % [value, slowdown]
        end
      end

      def color
        if !baseline
          ";0"
        elsif best? || overlaps?
          "32"
        elsif worst?
          "31"
        else
          ";0"
        end
      end
    end
  end
end
