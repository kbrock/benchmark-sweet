module Benchmark
  module Sweet
    class Comparison
      UNITS = {"ips" => "i/s", "memsize" => "bytes", "memsize_retained" => "bytes"}.freeze
      attr_reader :label, :metric, :stats, :best, :worst, :reference
      attr_reader :offset, :total
      def initialize(metric, label, stats, offset, total, best, worst: nil, reference: nil)
        @metric = metric
        @label = label
        @stats = stats
        @offset = offset
        @total = total
        @best = best
        @worst = worst
        @reference = reference
      end

      # Value relative to a named baseline. >1.0 = faster/better, <1.0 = slower/worse.
      def ratio
        return nil unless @reference
        stats.central_tendency / @reference.central_tendency
      end

      def [](field)
        case field
        when :metric      then metric
        when :comp_bar    then comp_bar
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

      # @return true if this is the best entry AND it is distinguishable from the worst
      def best? ; !best || (best == stats && !all_same?) ; end

      # @return true if it is basically the same as the best
      def overlaps?
        return @overlaps if defined?(@overlaps)
        @overlaps = slowdown == 1 ||
                      stats && best && (stats.central_tendency == best.central_tendency || stats.overlaps?(best))
      end

      def worst?
        return false if overlaps?
        if @worst
          stats.overlaps?(@worst)
        else
          slowdown == Float::INFINITY || (total.to_i - 1 == offset.to_i && slowdown > 1)
        end
      end

      # @return [Boolean] true if all entries in this comparison group overlap (no meaningful differences)
      def all_same?
        return false unless @worst && best
        (best.central_tendency == @worst.central_tendency) || best.overlaps?(@worst)
      end

      def slowdown
        return @slowdown if @slowdown
        @slowdown, @diff_error = stats.slowdown(best)
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

      def comp_short(value = nil, color: false)
        value ||= "#{central_tendency.round(1)} #{units}"
        result = case mode
        when :best, :same
          value
        when :slower
          "%s - %.2fx (± %.2f)" % [value, slowdown, error]
        when :slowerish
          "%s - %.2fx" % [value, slowdown]
        end
        color ? colorize(result) : result
      end

      def comp_bar(width: 20, color: false)
        fill = (best && !overlaps?) ? (width.to_f / slowdown).round : width
        fill = fill.clamp(0, width)
        shade = width - fill
        bar = "█" * fill + "░" * shade
        color ? colorize(bar) : bar
      end

      def color
        if !best
          ";0"
        elsif best? || overlaps?
          "32"
        elsif worst?
          "31"
        else
          ";0"
        end
      end

      def colorize(str)
        "\e[#{color}m#{str}\e[0m"
      end
    end
  end
end
