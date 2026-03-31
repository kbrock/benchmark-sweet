require 'benchmark/sweet'

STRING = "Hello, World! This is a benchmark test string."

Benchmark.items(metrics: %w(ips), warmup: 1, time: 2, quiet: true, force: true) do |x|
  x.report("downcase")    { STRING.downcase }
  x.report("swapcase")    { STRING.swapcase }
  x.report("reverse")     { STRING.reverse }
  x.report("tr")          { STRING.tr('aeiou', '*') }
  x.report("gsub")        { STRING.gsub(/[aeiou]/, '*') }

  x.report_with row: :method, column: :metric,
    value: ->(m) { m.comp_bar(color: true) }
end
