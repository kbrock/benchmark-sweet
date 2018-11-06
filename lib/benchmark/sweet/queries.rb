module Benchmark
  module Sweet
    module Queries
      def run_queries
        items.each do |entry|
          values = ::Benchmark::Sweet::Queries::QueryCounter.count(&entry.block) # { entry.call_times(1) }
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

        # TODO: possibly setup a single subscribe and use a context/thread local to properly count metrics
        def count(&block)
          @instances = {cache_count: 0, ignored_count: 0, sql_count: 0, instance_count: 0}
          ActiveSupport::Notifications.subscribed(callback_proc, /active_record/, &block)
          @instances
        end
      end
    end
  end
end
