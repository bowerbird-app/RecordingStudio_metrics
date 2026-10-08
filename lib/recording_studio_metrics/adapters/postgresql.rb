# frozen_string_literal: true

module RecordingStudioMetrics
  module Adapters
    class Postgresql
      def self.truncate_sql(connection, table, column, interval, timezone)
        quoted_interval = connection.quote(interval)
        quoted_timezone = connection.quote(timezone)
        "date_trunc(#{quoted_interval}, #{table}.#{column}, #{quoted_timezone})"
      end
    end

    def self.for_connection(connection)
      name = connection.adapter_name.to_s
      return Postgresql if name.match?(/postg/i)

      raise Errors::CalculationError, "unsupported database adapter #{name}"
    end
  end
end
