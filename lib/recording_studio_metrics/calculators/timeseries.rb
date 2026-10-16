# frozen_string_literal: true

module RecordingStudioMetrics
  module Calculators
    class Timeseries < Base
      def calculate
        interval = resolved_interval
        window = build_window(interval)
        data = series(window, aggregate(window))

        result(
          data: data,
          extra: {
            interval: interval,
            period: window.period_metadata,
            semantics: definition.semantics || "records_created_during_period"
          },
          grouping: group_field ? grouped_series(window) : {}
        )
      end

      private

      def series(window, values)
        fill = fill_missing?(definition.measurement)
        window.buckets.map do |bucket|
          value = values[bucket_key(bucket, window)]
          value = numeric_or_zero(value) if fill
          { date: window.format(bucket), value: value }
        end
      end

      # Splits created-during-period buckets by group_field. The min group size is
      # applied to each group's row count across the whole requested period.
      def grouped_series(window)
        rel = filtered_relation.where(definition.field => period_range(window))
        kept, small = split_groups(rel.group(group_field).distinct.count)
        cells = rel.group(Arel.sql(truncation_sql(window)), group_field)
        values = index_cells(measure(cells), window)
        counts = definition.measurement == :average ? index_cells(cells.distinct.count, window) : values

        groups = kept.map { |key| { key: key, data: series(window, values.transform_values { |row| row[key] }) } }
        other = merged_series(window, values, counts, small) if small.any?
        grouping(groups, other)
      end

      def merged_series(window, values, counts, keys)
        merged = values.to_h do |bucket, row|
          present = keys.select { |key| row.key?(key) }
          [bucket, present.empty? ? nil : merge_values(row, counts[bucket], present)]
        end
        { groups: keys.size, data: series(window, merged) }
      end

      def index_cells(rows, window)
        rows.each_with_object({}) do |((bucket, key), value), memo|
          formatted = window.format(coerce_bucket_time(bucket, window))
          (memo[formatted] ||= {})[key] = coerce_aggregate(value)
        end
      end

      def resolved_interval
        interval = (params[:interval] || definition.default_interval || definition.intervals.first)&.to_sym
        unless definition.supports_interval?(interval)
          raise Errors::UnsupportedInterval, "Interval #{interval} is not supported"
        end

        interval
      end

      def build_window(interval)
        TimeWindow.new(
          interval: interval,
          start_at: params[:start_at] || default_start_at(interval),
          end_at: params[:end_at] || context.timestamp,
          timezone: context.timezone,
          max_buckets: RecordingStudioMetrics.configuration.max_timeseries_buckets,
          max_period: RecordingStudioMetrics.configuration.max_reporting_period
        )
      end

      def aggregate(window)
        return population_at_end(window) if definition.population_at_end?

        created_during_period(window)
      end

      def created_during_period(window)
        rel = filtered_relation.where(definition.field => period_range(window))
        rows = grouped_values(rel, window)
        index_rows(rows, window)
      end

      # A date column casts a timestamp bound down to a date, which drops the day
      # containing a non-midnight end. Compare calendar days in the window
      # timezone, and include that end day unless end_at is exactly midnight.
      def period_range(window)
        return window.start_at...window.end_at unless date_column?

        start_day = zoned_date(window.start_at, window)
        finish = window.end_at.in_time_zone(window.timezone)
        end_day = finish.to_date
        end_day += 1 unless midnight?(finish)
        start_day...end_day
      end

      def zoned_date(time, window)
        time.in_time_zone(window.timezone).to_date
      end

      def midnight?(time)
        time.hour.zero? && time.min.zero? && time.sec.zero? && time.subsec.zero?
      end

      def date_column?
        relation.klass.columns_hash[definition.field.to_s]&.type == :date
      end

      def population_at_end(window)
        rel = filtered_relation
        window.buckets.each_with_object({}) do |bucket, memo|
          bucket_end = window.bucket_end(bucket)
          scoped = existed_at(rel, bucket_end)
          memo[window.format(bucket)] = coerce_aggregate(measure(scoped))
        end
      end

      def existed_at(rel, bucket_end)
        table = rel.arel_table
        scoped = rel.where(table[definition.field].lt(bucket_end))
        return scoped unless deleted_column?(rel)

        deleted = table[:deleted_at]
        scoped.where(deleted.eq(nil).or(deleted.gteq(bucket_end)))
      end

      def deleted_column?(rel)
        rel.klass.column_names.include?("deleted_at")
      end

      def grouped_values(rel, window)
        trunc = truncation_sql(window)
        grouped = rel.group(Arel.sql(trunc))
        measure(grouped)
      end

      def measure(scope)
        case definition.measurement
        when :sum
          scope.sum(numeric_field)
        when :average
          scope.average(numeric_field)
        else
          scope.distinct.count
        end
      end

      def numeric_field
        definition.value_field || definition.field
      end

      def index_rows(rows, window)
        rows.each_with_object({}) do |(key, value), memo|
          time = coerce_bucket_time(key, window)
          memo[window.format(time)] = coerce_aggregate(value)
        end
      end

      def coerce_aggregate(value)
        definition.measurement == :average ? value&.to_f : numeric_or_zero(value)
      end

      def truncation_sql(window)
        connection = relation.klass.connection
        table = relation.klass.quoted_table_name
        column = connection.quote_column_name(definition.field)
        adapter = Adapters.for_connection(connection)
        interval = window.pg_interval
        if date_column?
          adapter.truncate_date_sql(connection, table, column, interval)
        else
          adapter.truncate_sql(connection, table, column, interval, window.timezone.tzinfo.identifier)
        end
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
