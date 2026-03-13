# Benchmark::Sweet

Time tends not to be consistent across multiple runs, but numbers of queries or the number of objects allocated tend to be more similar.

This gem allows the user to collect all three of these benchmarks using a single framework similar to the benchmark and benchmark-ips syntax.

Sometimes a benchmark needs to be collected across multiple runs using different gem versions or using different ruby versions. This can be done as well.

Lastly, this allows multiple axes of comparisons to be performed. Example: instead of measuring multiple split implementations, it allows measuring these implementations using empty strings and long strings so a bigger picture can be obtained.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'benchmark-sweet'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install benchmark-sweet

## How it works

### Labels

Every benchmark item has a **label** — a Hash of metadata that identifies it. Labels are built
from `metadata` and the name passed to `report`:

```ruby
x.metadata version: RUBY_VERSION
x.metadata data: "nil" do
  x.report("to_s.split") { ... }
end
# produces label: {version: "3.4.8", data: "nil", method: "to_s.split"}
```

These label keys (`version`, `data`, `method`) are not reserved words — they are whatever
metadata you choose. The same keys are then used with `compare_by` and `report_with` to
control comparisons and display.

### `compare_by` — which items to compare

`compare_by` partitions results into comparison groups. Within each group, items are ranked
best to worst and slowdown factors are calculated. Items in different groups are never
compared against each other.

Method names and metrics are always part of the partition implicitly.

```ruby
x.compare_by :data
```

**Why this matters:** splitting a nil is much faster than splitting a string. Without
`compare_by :data`, the string case would show as "slower" — but it's a different workload,
not a worse implementation.

### `report_with` — how to display the results

`report_with` controls the table layout using four parameters:

- **`grouping`** — a separate table is generated for each unique value (default: one table for everything)
- **`row`** — what goes on the left side of each row (default: the full label)
- **`column`** — what goes across the top as column headers (default: `:metric`)
- **`value`** — what appears in each cell (default: `:comp_short` — value with slowdown)

Each accepts a Symbol (label key), an Array of Symbols (joined to make compound headers),
or a lambda for custom formatting.

The rest of this README shows one example data set displayed multiple ways by changing
only `report_with`, so you can see how each parameter affects the output.

## Example: same data, different views

### The benchmark

Two split implementations, tested on both nil and string data, measuring ips and memsize:

```ruby
require "benchmark/sweet"

NSTRING = nil
DELIMITER = '/'.freeze
STRING = "ab/cd/ef/gh".freeze

Benchmark.items(metrics: %w(ips memsize)) do |x|
  x.metadata data: "nil" do
    x.report("to_s.split") { NSTRING.to_s.split(DELIMITER)           }
    x.report("?split:[]")  { NSTRING ? NSTRING.split(DELIMITER) : [] }
  end
  x.metadata data: "str" do
    x.report("to_s.split") { STRING.to_s.split(DELIMITER)          }
    x.report("?split:[]")  { STRING ? STRING.split(DELIMITER) : [] }
  end

  x.compare_by :data
  x.report_with ...  # <-- we'll vary this part below
end
```

This produces 8 data points (2 methods x 2 data types x 2 metrics). The `compare_by :data`
ensures nil-vs-nil and str-vs-str comparisons — never nil-vs-str.

Now let's see how `report_with` changes the presentation of these same 8 data points.

---

### View 1: a table per metric

```ruby
x.report_with grouping: :metric, row: :method, column: :data, sort: true
```

- **`grouping: :metric`** — one table for `ips`, another for `memsize`
- **`row: :method`** — each method gets its own row
- **`column: :data`** — nil and str become column headers

#### metric ips

```
     method |                   nil |           str
------------|------------------------|---------------
 ?split:[]  | 7090539.2 i/s          | 1322010.9 i/s
 to_s.split | 3703981.6 i/s - 1.91x  | 1311153.9 i/s
```

#### metric memsize

```
     method |                nil |         str
------------|--------------------|--------------
 ?split:[]  | 40.0 bytes         | 360.0 bytes
 to_s.split | 80.0 bytes - 2.00x | 360.0 bytes
```

Each table is small and focused. The slowdown `1.91x` only compares methods within the same
data type (nil column), because `compare_by :data` keeps them separate.

---

### View 2: everything in one table

```ruby
x.report_with row: :method, column: [:data, :metric], sort: true
```

- **no `grouping`** — all data in one table
- **`column: [:data, :metric]`** — combines data and metric into compound column headers like `nil_ips`, `str_memsize`

```
     method |             nil_ips |           str_ips |        nil_memsize |     str_memsize
------------|---------------------|-------------------|--------------------|----------------
 ?split:[]  | 7090539.2 i/s       | 1322010.9 i/s     | 40.0 bytes         | 360.0 bytes
 to_s.split | 3703981.6 i/s - 1.91x | 1311153.9 i/s   | 80.0 bytes - 2.00x | 360.0 bytes
```

One wide table — useful for comparing all dimensions at a glance.

---

### View 3: a table per data type

```ruby
x.report_with grouping: :data, row: :method, column: :metric, sort: true
```

- **`grouping: :data`** — one table for nil, another for str
- **`column: :metric`** — ips and memsize become columns

#### data nil

```
     method |                   ips |            memsize
------------|-----------------------|-------------------
 ?split:[]  | 7090539.2 i/s         | 40.0 bytes
 to_s.split | 3703981.6 i/s - 1.91x | 80.0 bytes - 2.00x
```

#### data str

```
     method |           ips |     memsize
------------|---------------|------------
 ?split:[]  | 1322010.9 i/s | 360.0 bytes
 to_s.split | 1311153.9 i/s | 360.0 bytes
```

Now each table shows "how do these methods compare for this particular input?" —
all metrics side by side for the same workload.

---

### Summary

The same data, three different views — controlled entirely by `report_with`:

| View | `grouping` | `row` | `column` | Result |
|------|-----------|-------|----------|--------|
| 1 | `:metric` | `:method` | `:data` | table per metric, data across top |
| 2 | *(none)* | `:method` | `[:data, :metric]` | one wide table |
| 3 | `:data` | `:method` | `:metric` | table per data type, metrics across top |

The rule: every label key must appear in exactly one of `grouping`, `row`, or `column`
(`:metric` is included automatically if not specified). Changing which key goes where
reshapes the table.

## Cross-version comparisons with `save_file`

Add `version` metadata and use `save_file` to accumulate results across multiple runs:

```ruby
Benchmark.items(metrics: %w(ips memsize)) do |x|
  x.metadata version: RUBY_VERSION
  x.metadata data: "nil" do
    x.report("to_s.split") { NSTRING.to_s.split(DELIMITER)           }
    x.report("?split:[]")  { NSTRING ? NSTRING.split(DELIMITER) : [] }
  end
  x.metadata data: "str" do
    x.report("to_s.split") { STRING.to_s.split(DELIMITER)          }
    x.report("?split:[]")  { STRING ? STRING.split(DELIMITER) : [] }
  end

  x.compare_by :version, :data
  x.report_with grouping: [:version, :metric], sort: true, row: :method, column: :data
  x.save_file
end
```

#### `save_file`

Creates a JSON file that persists results across runs. When called without arguments,
the filename defaults to the script name with a `.json` extension (e.g., `split.rb` → `split.json`).
You can also pass an explicit path: `x.save_file "custom_results.json"`.

Run once with Ruby 3.3, then again with Ruby 3.4 — the file accumulates both. Another
common use is recording `ActiveRecord.version` to compare across gem versions.

Running with `force: true` will re-run and overwrite previously saved data for the same metadata.

#### `compare_by`

Adding `:version` to `compare_by` means Ruby 3.3 results are only compared against other 3.3
results, and 3.4 against 3.4. Note that `version` and `data` are not reserved words — they are
just the metadata keys we chose.

#### Output — one table per version and metric

##### [:version, :metric] 3.3.0_ips

```
     method |                   nil |           str
------------|-----------------------|---------------
 ?split:[]  | 10146134.2 i/s        | 1284159.2 i/s
 to_s.split | 4232772.3 i/s - 2.40x | 1258665.8 i/s
```

##### [:version, :metric] 3.3.0_memsize

```
     method |                nil |         str
------------|--------------------|--------------
 ?split:[]  | 40.0 bytes         | 360.0 bytes
 to_s.split | 80.0 bytes - 2.00x | 360.0 bytes
```

##### [:version, :metric] 3.4.0_ips

```
     method |                   nil |           str
------------|-----------------------|---------------
 ?split:[]  | 10012873.4 i/s        | 1377320.5 i/s
 to_s.split | 4557456.3 i/s - 2.20x | 1350562.6 i/s
```

#### Condensed alternative

To see everything in fewer tables, combine data and metric into columns and group by version only:

```ruby
x.report_with grouping: :version, sort: true, row: :method, column: [:data, :metric]
```

##### version 3.3.0

```
     method |             nil_ips |           str_ips |        nil_memsize |     str_memsize
------------|---------------------|-------------------|--------------------|----------------
 ?split:[]  | 10146134.2 i/s      | 1284159.2 i/s     | 40.0 bytes         | 360.0 bytes
 to_s.split | 4232772.3 i/s - 2.40x | 1258665.8 i/s   | 80.0 bytes - 2.00x | 360.0 bytes
```

As you might notice, the number of objects created for the runs are the same across versions.
But the ips numbers may vary — letting you spot performance regressions.

## Custom value formatting

Use the `value` parameter to customize cell display. This adds ANSI colors (green for best, red for worst):

```ruby
VALUE_TO_S = ->(m) { m.comp_short("\e[#{m.color}m#{m.central_tendency.round(1)} #{m.units}\e[0m") }
x.report_with row: :method, column: :metric, value: VALUE_TO_S
```

## Options

```ruby
Benchmark.items(
  metrics: %w(ips memsize),  # which metrics to measure (default: %w(ips))
  memory: 3,                 # number of memory profiling runs (default: 1)
  warmup: 1,                 # IPS warmup seconds
  time: 3,                   # IPS measurement seconds
  quiet: false,              # suppress interim output
  force: true,               # re-run even if saved data exists
) do |x|
  # ...
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kbrock/benchmark-sweet.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
