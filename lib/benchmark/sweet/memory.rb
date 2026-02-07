module Benchmark
  module Sweet
    module Memory
      def run_memory
        # I'd prefer to use benchmark/memory - but not sure if it bought us enough
        # require "benchmark/memory"
        # rpt = Benchmark.memory(quiet: options[:quiet]) do |x|
        #   items.each { |item| x.report(item.label, &item.block) }
        #   x.compare! if compare
        # end
        # rpt.entries.each do |e| 
        #   add_entry e.label, "memory",           e.measurement.memory.allocated
        #   add_entry e.label, "memory_retained",  e.measurement.memory.retained
        #   add_entry e.label, "objects",          e.measurement.objects.allocated
        #   add_entry e.label, "objects_retained", e.measurement.objects.retained
        #   add_entry e.label, "string",           e.measurement.string.allocated
        #   add_entry e.label, "string_retained",  e.measurement.string.retained
        # end
        require 'memory_profiler'
        $stdout.puts "Memory Profiling----------" unless quiet?

        items.each do |entry|
          name = entry.label

          $stdout.printf("%20s ", name.to_s) unless quiet?
          rpts = (options[:memory] || 1).times.map { MemoryProfiler.report(&entry.block) }
          tot_stat  = add_entry(name, "memsize",          rpts.map(&:total_allocated_memsize))
          totr_stat = add_entry name, "memsize_retained", rpts.map(&:total_retained_memsize)
          add_entry name, "objects",          rpts.map(&:total_allocated)
          add_entry name, "objects_retained", rpts.map(&:total_retained)
          str_stat  = add_entry(name, "strings",          rpts.map { |rpt| rpt.strings_allocated.size })
          strr_stat = add_entry(name, "strings_retained", rpts.map { |rpt| rpt.strings_retained.size })

          $stdout.printf("%10s  alloc/ret %10s  strings/ret\n",
                         "#{tot_stat.central_tendency}/#{totr_stat.central_tendency}",
                         "#{str_stat.central_tendency}/#{strr_stat.central_tendency}") unless quiet?
        end
      end      
    end
  end
end
