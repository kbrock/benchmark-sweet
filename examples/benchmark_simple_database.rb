require "benchmark/sweet"
require "active_record"
#
# label               | ips               | queries  | rows
#---------------------+-------------------+----------+----------------------
# User.all.first      | 3185.3 i/s        | 1.0 objs | 1.0 objs
# User.all.to_a.first | 977.1 i/s - 3.26x | 1.0 objs | 100.0 objs - 100.00x


#ActiveRecord::Base.establish_connection(ENV.fetch('DATABASE_URL') { "postgres://localhost/user_benchmark" })
ActiveRecord::Base.establish_connection(ENV.fetch('DATABASE_URL') { "sqlite3::memory:" })
ActiveRecord::Migration.verbose = false

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
  end
  #add_index :users, :name

  create_table :dogs, force: true do |t|
    t.string :name
  end
end

class User < ActiveRecord::Base ;end
class Dog < ActiveRecord::Base ;end

if User.count == 0
  puts "Creating 100 users"
  100.times { |i| User.create name: "user #{i}" }
  puts "Creating 1 dog"
  Dog.create name: "the dog"
end

Benchmark.items(metrics: %w(ips queries rows)) do |x|
  x.metadata version: ActiveRecord.version.to_s

  x.report(model: "User", method: "all.first") { User.all.first }
  x.report(model: "User", method: "all.to_a.first") { User.all.to_a.first }

  x.report(model: "Dog", method: "all.first") { Dog.all.first }
  x.report(model: "Dog", method: "all.to_a.first") { Dog.all.to_a.first }

  # metric names across the top (column)
  # method names down the side (rows)
  x.report_with row: [:method], column: [:metric], grouping: :model, sort: true
  x.save_file if ENV["SAVE_FILE"].to_s =~ /t/i
end
