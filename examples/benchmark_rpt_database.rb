require "benchmark/sweet"
require "more_core_extensions/all"
require "active_record"

# For various versions of rails, compare `Model.all.first` vs `Model.all.to_a.first`
#
# To work across versions, we need to run this multiple times (with different Gemfile each run)
#
# meta data of :version is stored to be able to distinguish the version across each of the runs
#
# options:
#   DATABASE_URL
#     link to the database
#
#     DATABASE_URL=postgres://user@password:localhost/user_benchmark
#
#   SAVE_FILE
#     a save file contains the values from the various invocations.
#     This uses the method `save_file`, which is optional. But without it, it won't compare across versions.
#
#     running this script multiple times will only use the first value obtained
#     But running this with different metadata (i.e. AR version) will run again and compare across the versions
#
#     default             : write to a save file named "{this script's name}.json"
#     SAVE_FILE=file.json : write to a save file named "file.json"
#
#   FORCE
#     This tells the script to overwrite previously run identical metadata
#     It uses the `force: true` option to share with benchmark that this behavior is desired
#
#     FORCE=true  :overwrite the previous values for this script
#     FORCE=false : default behavior. don't run multiple times for the same metadata
#

# version 5.2.1
#
# grouping 6.0.2.2 (100 records)
#
#  method     | ips                | memsize
# ------------+--------------------+---------------------
#  first      | 2945.9 i/s         | 9808 bytes
#  to_a.first | 1204.7 i/s - 2.45x | 68200 bytes - 6.95x
#
#  NOTE: the results are in color

ActiveRecord::Base.establish_connection(ENV.fetch('DATABASE_URL') { "postgres://localhost/user_benchmark" })
ActiveRecord::Migration.verbose = false

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
  end
  #add_index :users, :name

  create_table :accounts, force: true do |t|
    t.string :name
  end
end

class User < ActiveRecord::Base; end
class Account < ActiveRecord::Base; end

if User.count == 0
  puts "Creating 100 users"
  100.times { |i| User.create name: "user #{i}" }
end

#in the table cells, it typically displays the value and units. this lambda is adding in colors (based upon best/worst)
VALUE_TO_S  = ->(m) { m.comp_short("\e[#{m.color}m#{m.central_tendency.round(1)} #{m.units}\e[0m") }

# These are the various items that will be compared
#
# metrics is the metric that is actually run
# memory
# warmup - run the tests for this many seconds before running the actual benchmark (for ips)
# time   - run the tests for this many seconds (for ips)
# quied  - display the ips run information
# force  - defined above. this is allowing the command line to change this value (default: false)
Benchmark.items(metrics: %w(ips memsize), memory: 3, warmup: 1, time: 3, quiet: false, force: ENV["FORCE"] == "true") do |x|
  # for all examples, store this metadata with the row
  # metadata is stored in the savefile along with the method name and benchmarks.
  # future runs of the script that have a different version of AR will be stored as separate benchmarks
  # this allows comparison across multiple versions
  #
  # If you are applying a patch for different behavior, or you're running against head, consider using something more comples:
  #
  # this can be an array. with something like version: [ActiveRecord.version.to_s, ENV["PATCH"], ENV["SHA"]].compact.join(".")
  x.metadata version: ActiveRecord.version.to_s

  # compare_by is a display parameter
  #
  # this is used to know which metadata is different and which are the same
  # the best and worst value is determined across this criteria
  #
  # so if you want to show a different list for each version, add it to the list
  # This typically will include the group and either the column or the row header
  #
  # defaults to unique by method (and always unique by metric)
  x.compare_by { |label, _| [label[:count], label[:version]] }

  # these next two cases are marked with count=100. Use row, column or grouping to group these
  # These values tend to be in the compare_by block. because running on 100 values is different than 0. (but not always the case)
  x.metadata count: "100" do
    x.report("first") { User.all.first }
    x.report("to_a.first") { User.all.to_a.first }
  end

  x.metadata count: "0" do
    x.report("first") { Account.all.first }
    x.report("to_a.first") { Account.all.to_a.first }
  end

  # Note, often the report title is the same as the code, in those cases just pass the name
  # x.report("Account.all.to_a.first")
  # x.report("Account.all.to_a.first")

  # display only. parameters
  # these can be symbols or lambdas
  # grouping is the value for determining what data goes into each table (default - only 1 table)
  # row is the title on the left hand side (default: all metadata)
  # column header is the metric that was captured (i.e.: ips or metrics) (default: metric name)
  # value is the text that is displayed in the cell of the table (default: "central_tendancy units")
  x.report_with grouping: ->(l){ "#{l[:version]} (#{l[:count]} records)"}, row: :method, column: :metric, value: VALUE_TO_S

  # defined above. benchmark sweet pretty much depends upon this json file
  x.save_file ENV["SAVE_FILE"] ? ENV["SAVE_FILE"] : $0.sub(/\.rb$/, '.json')
end
