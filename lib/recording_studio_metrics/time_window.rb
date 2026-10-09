# frozen_string_literal: true

module RecordingStudioMetrics
  class TimeWindow
    STEPPERS = {
      hour: :advance_hour,
      day: :advance_day,
      week: :advance_week,
      month: :advance_month,
      year: :advance_year
    }.freeze

    def initialize(interval:, start_at:, end_at:, timezone:, max_buckets:, max_period:)
      @interval = interval.to_sym
      @timezone = Time.find_zone!(timezone)
      @max_buckets = max_buckets
      @max_period = max_period
      @start_at = coerce(start_at)
      @end_at = coerce(end_at)
      validate!
    end

    attr_reader :interval, :start_at, :end_at, :timezone

    def buckets
      cursor = truncate(start_at)
      finish = end_at
      values = []
      while cursor < finish
        values << cursor
        cursor = advance(cursor)
        raise Errors::InvalidDateRange, "time series exceeds #{@max_buckets} buckets" if values.size > @max_buckets
      end
      values
    end

    def bucket_end(bucket)
      advance(bucket)
    end

    def pg_interval
      interval.to_s
    end

    def format(time)
      zoned = time.in_time_zone(timezone)
      interval == :hour ? zoned.iso8601 : zoned.strftime("%Y-%m-%d")
    end

    def period_metadata
      {
        start: start_at.iso8601,
        end: end_at.iso8601,
        boundary: "start_inclusive_end_exclusive"
      }
    end

    private

    def validate!
      raise Errors::InvalidDateRange, "start_at and end_at are required" unless start_at && end_at
      raise Errors::InvalidDateRange, "end_at must be after start_at" unless end_at > start_at

      return unless (end_at - start_at) > @max_period

      raise Errors::InvalidDateRange, "reporting period exceeds the configured maximum"
    end

    def coerce(value)
      return if value.nil?
      return coerce_string(value) if value.is_a?(String)
      return timezone.at(value) if value.respond_to?(:to_time)

      timezone.parse(value.to_s)
    rescue ArgumentError
      raise Errors::InvalidDateRange, "invalid time value"
    end

    def coerce_string(value)
      parsed = timezone.parse(value)
      raise Errors::InvalidDateRange, "invalid time value" if parsed.nil?

      parsed
    rescue ArgumentError
      raise Errors::InvalidDateRange, "invalid time value"
    end

    def truncate(time)
      zoned = time.in_time_zone(timezone)
      case interval
      when :hour then zoned.beginning_of_hour
      when :day then zoned.beginning_of_day
      when :week then zoned.beginning_of_week(:monday)
      when :month then zoned.beginning_of_month
      when :year then zoned.beginning_of_year
      else zoned
      end
    end

    def advance(time)
      case interval
      when :hour then time + 1.hour
      when :day then time + 1.day
      when :week then time + 1.week
      when :month then time + 1.month
      when :year then time + 1.year
      end
    end
  end
end
