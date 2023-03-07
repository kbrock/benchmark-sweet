module Benchmark
  module Sweet
    module Queries
      def run_queries
        cntr = ::Benchmark::Sweet::Queries::QueryCounter.new
        cntr.sub do
          items.each do |entry|
            entry.block.call
            values = cntr.get_clear
            add_entry entry.label, "rows",    values[:instance_count]
            add_entry entry.label, "queries", values[:sql_count]
            add_entry entry.label, "ignored", values[:ignored_count]
            add_entry entry.label, "cached",  values[:cache_count]
            unless options[:quiet]
              printf "%20s: %3d queries %5d ar_objects", entry.label, values[:sql_count], values[:instance_count]
              printf " (%d ignored)", values[:ignored_count] if values[:ignored_count] > 0
              puts
            end
          end
        end
      end

      # Derived from code found in http://stackoverflow.com/questions/5490411/counting-the-number-of-queries-performed
      #
      # This could get much more elaborate
      # results could be separated by payload[:statement_name] (sometimes nil) or payload[:class_name]
      # Could add explains for all queries (and determine index usage)
      class QueryCounter
        def self.count(&block)
          new.count(&block)
        end

        CACHE_STATEMENT    = "CACHE".freeze
        IGNORED_STATEMENTS = %w(CACHE SCHEMA).freeze
        IGNORED_QUERIES    = /^(?:ROLLBACK|BEGIN|COMMIT|SAVEPOINT|RELEASE)/.freeze

        def initialize
          clear
        end

        def callback(_name, _start, _finish, _id, payload)
          if payload[:sql]
            if payload[:name] == CACHE_STATEMENT
              @instance[:cache_count] += 1
            elsif IGNORED_STATEMENTS.include?(payload[:name]) || IGNORED_QUERIES.match(payload[:sql])
              @instances[:ignored_count] += 1
            else
              @instances[:sql_count] += 1
            end
          else
            @instances[:instance_count] += payload[:record_count]
          end
        end

        def callback_proc
          lambda(&method(:callback))
        end

        def clear
          @instances = {cache_count: 0, ignored_count: 0, sql_count: 0, instance_count: 0}
        end

        def get_clear; @instances.tap { clear }; end
        def get; @instances; end

        # either use 10.times { value = count(&block) }
        # or use
        # sub { 10.times { block.call; value = get_clear } }
        def count(&block)
          clear
          sub(&block)
          @instances
        end

        def sub(&block)
          ActiveSupport::Notifications.subscribed(callback_proc, /active_record/, &block)
        end
      end
    end
  end
end
