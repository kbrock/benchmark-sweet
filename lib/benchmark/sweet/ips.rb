module Benchmark
  module Sweet
    module IPS
      def run_ips
        require "benchmark/ips"
        rpt = Benchmark.ips(warmup: options[:warmup], time: options[:time], quiet: options[:quiet]) do |x|
          items.each { |e| x.item(e.label, e.action || e.block) }
          #x.compare! if compare
        end
        rpt.entries.each do |entry|
          add_entry(entry.label, "ips", entry.stats)
        end
      end
    end
  end
end
