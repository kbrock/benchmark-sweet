require "benchmark/sweet"
require "more_core_extensions/all"
require "active_record"

# version 5.2.1
#
#  method              | ips               | memsize
# ---------------------+-------------------+---------------------------------
#  User.all.first      | 3323.7 i/s        | 10632.0 bytes
#  User.all.to_a.first | 972.3 i/s - 3.42x | 100448.0 bytes - 9.45x
#
#  NOTE: the results are in color

ActiveRecord::Base.establish_connection(ENV.fetch('DATABASE_URL') { "postgres://localhost/user_benchmark" })
ActiveRecord::Migration.verbose = false

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
  end
  #add_index :users, :name
end

class User < ActiveRecord::Base ;end

if User.count == 0
  puts "Creating 100 users"
  100.times { |i| User.create name: "user #{i}" }
end

VALUE_TO_S  = Benchmark::Sweet.color_symbol_to_proc(:comp_short)

Benchmark.items(metrics: %w(ips memsize), memory: 3, warmup: 1, time: 3, quiet: false, force: ENV["FORCE"] == "true") do |x|
  x.metadata version: ActiveRecord.version.to_s
  x.report("User.all.first") { User.all.first }
  x.report("User.all.to_a.first") { User.all.to_a.first }

  x.report_with grouping: :version, row: :method, column: :metric, value: VALUE_TO_S

  x.save_file (ENV["SAVE_FILE"] == "true") ? $0.sub(/\.rb$/, '.json') : ENV["SAVE_FILE"] if ENV["SAVE_FILE"]
end
