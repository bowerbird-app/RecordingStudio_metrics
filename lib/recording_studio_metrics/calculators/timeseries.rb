# frozen_string_literal: true

module RecordingStudioMetrics
  module Calculators
    class Timeseries < Base
      def call
        interval = (params[:interval] || definition.default_interval || definition.intervals.first)&.to_sym
        unless definition.supports_interval?(interval)
          raise Errors::UnsupportedInterval, "Interval #{interval} is not supported"
        end

        window = TimeWindow.new(
          interval: interval,
          start_at: params[:start_at] || default_start_at(interval),
          end_at: params[:end_at] || context.timestamp,
          timezone: context.timezone,
          max_buckets: RecordingStudioMetrics.configuration.max_timeseries_buckets,
          max_period: RecordingStudioMetrics.configuration.max_reporting_period
        )

        grouped = aggregate(window)
        fill = fill_missing?(definition.measurement)
        data = window.buckets.map do |bucket|
          value = grouped[bucket_key(bucket, window)]
          value = numeric_or_zero(value) if fill
          { date: window.format(bucket), value: value }
        end

        result(
          data: data,
          extra: {
            interval: interval,
            period: window.period_metadata,
            semantics: definition.semantics || "records_created_during_period"
          }
        )
      end

      private

      def aggregate(window)
        rel = filtered_relation.where(definition.field => window.start_at...window.end_at)
        trunc = truncation_sql(window)
        rows = case definition.measurement
               when :sum
                 rel.group(Arel.sql(trunc)).sum(definition.field)
               when :average
                 rel.group(Arel.sql(trunc)).average(definition.field)
               else
                 rel.group(Arel.sql(trunc)).distinct.count
               end

        rows.each_with_object({}) do |(key, value), memo|
          time = coerce_bucket_time(key, window)
          memo[window.format(time)] = definition.measurement == :average ? value&.to_f : numeric_or_zero(value)
        end
      end

      def truncation_sql(window)
        connection = relation.klass.connection
        table = relation.klass.quoted_table_name
        column = relation.klass.connection.quote_column_name(definition.field)
        interval = connection.quote(window.pg_interval)
        tz = connection.quote(window.timezone.tzinfo.identifier)
        "date_trunc(#{interval}, #{table}.#{column}, #{tz})"
      end

      def coerce_bucket_time(key, window)
        return key.in_time_zone(window.timezone) if key.respond_to?(:in_time_zone)
        return window.timezone.parse(key.to_s) if key.present?

        window.start_at
      end

      def bucket_key(bucket, window)
        window.format(bucket)
      end

      def fill_missing?(measurement)
        %i[count sum].include?(measurement)
      end

      def default_start_at(interval)
        case interval.to_sym
        when :hour then 24.hours.ago
        when :day then 30.days.ago
        when :week then 12.weeks.ago
        when :month then 12.months.ago
        else 5.years.ago
        end
      end
    end
  end
end
