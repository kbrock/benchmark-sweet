require "benchmark/sweet"
require "more_core_extensions/all"
require "active_record"
#
# label               | ips               | queries  | rows
#---------------------+-------------------+----------+----------------------
# User.all.first      | 3185.3 i/s        | 1.0 objs | 1.0 objs
# User.all.to_a.first | 977.1 i/s - 3.26x | 1.0 objs | 100.0 objs - 100.00x


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

Benchmark.items(metrics: %w(ips queries rows)) do |x|
  x.report("User.all.first")
  x.report("User.all.to_a.first")

  x.report_with row: :method, column: :metric
  x.save_file (ENV["SAVE_FILE"] == "true") ? $0.sub(/\.rb$/, '.json') : ENV["SAVE_FILE"] if ENV["SAVE_FILE"]
end
