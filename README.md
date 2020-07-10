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

## Example 1

### Code

```ruby
require "benchmark/sweet"
require "active_support/all"
require "more_core_extensions/all" # [].tabelize

NSTRING = nil
DELIMITER='/'.freeze
STRING="ab/cd/ef/gh".freeze

Benchmark.items(metrics: %w(ips memsize)) do |x|
  x.metadata data: "nil" do
    x.report("to_s.split") { NSTRING.to_s.split(DELIMITER)           }
    x.report("?split:[]")  { NSTRING ? NSTRING.split(DELIMITER) : [] }
  end
  x.metadata data: "str" do
    x.report("to_s.split") { STRING.to_s.split(DELIMITER)          }
    x.report("?split:[]")  { STRING ? STRING.split(DELIMITER) : [] }
  end

  # partition the data by data value (nil vs string)
  # that way we're not comparing a split on a nil vs a split on a populated string
  compare_by :data

  # each row is a different method (via `row: :method`)
  # each column is by data type (via `column: :data` - specified via `metadata data: "nil"`)
  x.report_with grouping: :metric, sort: true, row: :method, column: :data
end
```

#### `compare_by`

The code takes a different amount of time to process a `nil` vs a string. So the values
are given metadata with the appropriate data used (i.e.: `metadata data: "nil"`).
The benchmark is then told that the results need to be partitioned by `data` (i.e.: `compare_by :data`).

The multipliers are only comparing values with the same data value and do not compare `"string"` values with `"nil"` values.

Values for method labels (e.g.: `"to_s.split"`) and metrics (e.g.: `ips`) are already part of the partition.

#### `grouping`

In this example, each metric is considered distinct so each metric is given a
unique table (i.e.: `grouping: :metric`)

Metrics of `ips` and `memsize` are calculated (i.e.: `metrics: %w(ips memsize)`)

#### `row`

A different method is given per row (i.e. `row: :method`)

#### `column`

The other axis for the columns is the type of data passed (i.e.: `column: :data`)
This is not a native value, it is specified when the items are specified (e.g.:`metadata data: "nil"`)

### example output

#### metric ips

 method     | nil                   | str
------------|-----------------------|---------------
`?split:[]` | 7090539.2 i/s         | 1322010.9 i/s
`to_s.split`| 3703981.6 i/s - 1.91x | 1311153.9 i/s

#### metric memsize

 method     | nil                | str
------------|--------------------|-------------
`?split:[]` | 40.0 bytes         | 360.0 bytes
`to_s.split`| 80.0 bytes - 2.00x | 360.0 bytes


## Example 2

### Code

```ruby
require "benchmark/sweet"
require "active_support/all"
require "more_core_extensions/all" # [].tabelize

NSTRING = nil
DELIMITER='/'.freeze
STRING="ab/cd/ef/gh".freeze

Benchmark.items(metrics: %w(ips memsize), memory: 3, warmup: 1, time: 1, quiet: false, force: ENV["FORCE"] == "true") do |x|
  x.metadata version: RUBY_VERSION
  x.metadata data: "nil" do
    x.report("to_s.split") { NSTRING.to_s.split(DELIMITER)           }
    x.report("?split:[]")  { NSTRING ? NSTRING.split(DELIMITER) : [] }
  end
  x.metadata data: "str" do
    x.report("to_s.split") { STRING.to_s.split(DELIMITER)          }
    x.report("?split:[]")  { STRING ? STRING.split(DELIMITER) : [] }
  end

  # partition the data by ruby version and data present
  # that way we're not comparing a split on a nil vs a split on a populated string
  x.compare_by :version, :data
if ENV["CONDENSED"].to_s == "true"
  x.report_with grouping: :version, sort: true, row: :method, column: [:data, :metric]
else
  x.report_with grouping: [:version, :metric], sort: true, row: :method, column: :data
end

  x.save_file $PROGRAM_NAME.sub(/\.rb$/, '.json')
end
```

#### `save_file`

Creates a json save file which saves the timings across multiple runs.
This is used along with the `version` metadata to record different results per ruby version.
Another common use is to record ActiveRecord version or a gem's version.

This is run with two different versions of ruby.
Interim values are stored in the save_file.

Running with environment variable `FORCE` will force running this again. (i.e.: `force: ENV["force"] == true`)

Depending upon the environment variable `CONDENSED`, there are two types of output.

#### `compare_by`

We introduce `version` as metadata for the tests. Adding `version` to the comparison
says that we should only compare values for the same version of ruby (along with the same data).

If you note `version` and `data` are not reserved words, instead, they are just what metadata we
decided to pass in.

### Example 2 output

#### [:version, :metric] 2.3.7_ips

 method     | nil                   | str
------------|-----------------------|---------------
 `?split:[]`| 10146134.2 i/s        | 1284159.2 i/s
`to_s.split`| 4232772.3 i/s - 2.40x | 1258665.8 i/s

#### [:version, :metric] 2.3.7_memsize

 method     | nil                | str
------------|--------------------|-------------
 `?split:[]`| 40.0 bytes         | 360.0 bytes
`to_s.split`| 80.0 bytes - 2.00x | 360.0 bytes

#### [:version, :metric] 2.4.6_ips

 method     | nil                   | str
------------|-----------------------|---------------
 `?split:[]`| 10012873.4 i/s        | 1377320.5 i/s
`to_s.split`| 4557456.3 i/s - 2.20x | 1350562.6 i/s

#### [:version, :metric] 2.4.6_memsize

 method     | nil                | str
------------|--------------------|-------------
 `?split:[]`| 40.0 bytes         | 360.0 bytes
`to_s.split`| 80.0 bytes - 2.00x | 360.0 bytes

#### [:version, :metric] 2.5.5_ips

 method     | nil                   | str
------------|-----------------------|---------------
 `?split:[]`| 7168109.1 i/s         | 1357046.0 i/s
`to_s.split`| 3779969.3 i/s - 1.90x | 1328072.4 i/s

#### [:version, :metric] 2.5.5_memsize

 method     | nil                | str
------------|--------------------|-------------
 `?split:[]`| 40.0 bytes         | 360.0 bytes
`to_s.split`| 80.0 bytes - 2.00x | 360.0 bytes


### Example 2 CONDENSED output

running with `CONDENSED=true` calls with a different `report_with`

As you might notice, the number of objects created for the runs are the same.
But for some reason, the `nil` split case is slower for ruby 2.5.5.

#### version 2.3.7

 method     | nil_ips               | str_ips       | nil_memsize        | str_memsize
------------|-----------------------|---------------|--------------------|-------------
 `?split:[]`| 10146134.2 i/s        | 1284159.2 i/s | 40.0 bytes         | 360.0 bytes
`to_s.split`| 4232772.3 i/s - 2.40x | 1258665.8 i/s | 80.0 bytes - 2.00x | 360.0 bytes

#### version 2.4.6

 method     | nil_ips               | str_ips       | nil_memsize        | str_memsize
------------|-----------------------|---------------|--------------------|-------------
 `?split:[]`| 10012873.4 i/s        | 1377320.5 i/s | 40.0 bytes         | 360.0 bytes
`to_s.split`| 4557456.3 i/s - 2.20x | 1350562.6 i/s | 80.0 bytes - 2.00x | 360.0 bytes

#### version 2.5.5

 method     | nil_ips               | str_ips       | nil_memsize        | str_memsize
------------|-----------------------|---------------|--------------------|-------------
 `?split:[]`| 7168109.1 i/s         | 1357046.0 i/s | 40.0 bytes         | 360.0 bytes
`to_s.split`| 3779969.3 i/s - 1.90x | 1328072.4 i/s | 80.0 bytes - 2.00x | 360.0 bytes

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kbrock/benchmark-sweet.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
