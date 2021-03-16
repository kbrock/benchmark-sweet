module Benchmark
  module Sweet
    class Display
      class Table
        # Move this logic out of comparison.rb into a Display object (possibly not in a subclass)
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

      @default_options = {
        :color             => true,
        :commmas           => false,
        :justification???  => (:left | :right)
      }

      #              v--- what is this (should probably be list of Comparison objects)
      def generate(data, cols, options = {})
        new.generate
      end

      def initialize

      end

      def generate

      end
    end
  end
end
