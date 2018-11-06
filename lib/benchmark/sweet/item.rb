module Benchmark
  module Sweet
    # borrowed heavily from Benchmark::IPS::Job::Entry
    # may be able to fallback on that - will need to generate a &block friendly proc for that structure
    class Item
      attr_reader :label, :action
      def initialize(label, action = nil)
        @label = label
        @action = action || @label #raise("Item needs an action")
      end

      def block
        @block ||= action.kind_of?(String) ? compile(action) : action
      end

      # to use with Job::Entry...
      # def call_once ; call_times(1) ; end
      # def callback_proc
      #   lambda(&method(:call_once))
      # end
      def compile(str)
        eval <<-CODE
          Proc.new do
            #{str}
          end
        CODE
      end
    end
  end
end
