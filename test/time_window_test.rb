# frozen_string_literal: true

require "test_helper"

class TimeWindowTest < Minitest::Test
  def test_hour_day_week_year_buckets
    hour = window(interval: :hour, start_at: Time.utc(2026, 1, 1, 0), end_at: Time.utc(2026, 1, 1, 3))
    assert_equal 3, hour.buckets.size

    day = window(interval: :day, start_at: Time.utc(2026, 1, 1), end_at: Time.utc(2026, 1, 4))
    assert_equal 3, day.buckets.size

    week = window(interval: :week, start_at: Time.utc(2026, 1, 5), end_at: Time.utc(2026, 1, 26))
    assert_equal Time.utc(2026, 1, 5).in_time_zone("UTC").beginning_of_week(:monday), week.buckets.first
    assert_equal 3, week.buckets.size

    year = window(
      interval: :year,
      start_at: Time.utc(2024, 1, 1),
      end_at: Time.utc(2026, 1, 1),
      max_period: 800.days
    )
    assert_equal(%w[2024-01-01 2025-01-01], year.buckets.map { |bucket| year.format(bucket) })
  end

  def test_dst_spring_forward_keeps_local_hour_boundaries
    zone = "America/New_York"
    window = RecordingStudioMetrics::TimeWindow.new(
      interval: :hour,
      start_at: Time.find_zone!(zone).local(2026, 3, 8, 0, 0, 0),
      end_at: Time.find_zone!(zone).local(2026, 3, 8, 6, 0, 0),
      timezone: zone,
      max_buckets: 24,
      max_period: 2.days
    )

    hours = window.buckets.map { |bucket| bucket.in_time_zone(zone).hour }
    assert_includes hours, 0
    assert_includes hours, 3
    refute_includes hours, 2
  end

  def test_timezone_day_boundary
    window = RecordingStudioMetrics::TimeWindow.new(
      interval: :day,
      start_at: Time.utc(2026, 1, 1, 14),
      end_at: Time.utc(2026, 1, 3, 12),
      timezone: "Australia/Sydney",
      max_buckets: 10,
      max_period: 10.days
    )

    dates = window.buckets.map { |bucket| window.format(bucket) }
    assert_equal %w[2026-01-02 2026-01-03], dates
  end

  def test_iso8601_strings_parse_in_the_request_timezone
    zone = Time.find_zone!("America/Los_Angeles")
    window = RecordingStudioMetrics::TimeWindow.new(
      interval: :day,
      start_at: "2026-10-01",
      end_at: "2026-10-04T15:30:00",
      timezone: "America/Los_Angeles",
      max_buckets: 10,
      max_period: 10.days
    )

    assert_equal zone.local(2026, 10, 1, 0, 0, 0), window.start_at
    assert_equal zone.local(2026, 10, 4, 15, 30, 0), window.end_at
    dates = window.buckets.map { |bucket| window.format(bucket) }
    assert_equal %w[2026-10-01 2026-10-02 2026-10-03 2026-10-04], dates

    zoned = RecordingStudioMetrics::TimeWindow.new(
      interval: :day,
      start_at: "2026-01-01T14:00:00Z",
      end_at: "2026-01-03T12:00:00Z",
      timezone: "Australia/Sydney",
      max_buckets: 10,
      max_period: 10.days
    )
    assert_equal Time.utc(2026, 1, 1, 14), zoned.start_at
    assert_equal Time.utc(2026, 1, 3, 12), zoned.end_at
    sydney_dates = zoned.buckets.map { |bucket| zoned.format(bucket) }
    assert_equal %w[2026-01-02 2026-01-03], sydney_dates
  end

  def test_unparseable_strings_raise_invalid_date_range
    ["not-a-date", "2026-13-40", ""].each do |garbage|
      start_error = assert_raises(RecordingStudioMetrics::Errors::InvalidDateRange) do
        window(interval: :day, start_at: garbage, end_at: Time.utc(2026, 10, 4))
      end
      assert_equal "invalid time value", start_error.message

      finish_error = assert_raises(RecordingStudioMetrics::Errors::InvalidDateRange) do
        window(interval: :day, start_at: Time.utc(2026, 10, 1), end_at: garbage)
      end
      assert_equal "invalid time value", finish_error.message
    end
  end

  def test_max_bucket_limit
    error = assert_raises(RecordingStudioMetrics::Errors::InvalidDateRange) do
      window(interval: :hour, start_at: Time.utc(2026, 1, 1), end_at: Time.utc(2026, 1, 3), max_buckets: 3).buckets
    end
    assert_match(/exceeds 3 buckets/, error.message)
  end

  private

  def window(interval:, start_at:, end_at:, max_buckets: 400, max_period: 400.days)
    RecordingStudioMetrics::TimeWindow.new(
      interval: interval,
      start_at: start_at,
      end_at: end_at,
      timezone: "UTC",
      max_buckets: max_buckets,
      max_period: max_period
    )
  end
end
