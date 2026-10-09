# frozen_string_literal: true

module RecordingStudioMetrics
  module Adapters
    class Postgresql
      def self.truncate_sql(connection, table, column, interval, timezone)
        quoted_interval = connection.quote(interval)
        quoted_timezone = connection.quote(timezone)
        "date_trunc(#{quoted_interval}, #{table}.#{column}, #{quoted_timezone})"
      end

      # Date columns have no time of day. Truncate the calendar timestamp and
      # return a date so the bucket stays on that day in every timezone.
      def self.truncate_date_sql(connection, table, column, interval)
        quoted_interval = connection.quote(interval)
        "date_trunc(#{quoted_interval}, #{table}.#{column}::timestamp)::date"
      end
    end

    def self.for_connection(connection)
      name = connection.adapter_name.to_s
      return Postgresql if name.match?(/postg/i)

      raise Errors::CalculationError, "unsupported database adapter #{name}"
    end
  end
end
