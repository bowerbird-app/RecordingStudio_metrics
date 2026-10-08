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

    year = window(interval: :year, start_at: Time.utc(2024, 1, 1), end_at: Time.utc(2026, 1, 1))
    assert_equal %w[2024-01-01 2025-01-01], year.buckets.map { |bucket| year.format(bucket) }
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

  def test_max_bucket_limit
    error = assert_raises(RecordingStudioMetrics::Errors::InvalidDateRange) do
      window(interval: :hour, start_at: Time.utc(2026, 1, 1), end_at: Time.utc(2026, 1, 3), max_buckets: 3).buckets
    end
    assert_match(/exceeds 3 buckets/, error.message)
  end

  private

  def window(interval:, start_at:, end_at:, max_buckets: 400)
    RecordingStudioMetrics::TimeWindow.new(
      interval: interval,
      start_at: start_at,
      end_at: end_at,
      timezone: "UTC",
      max_buckets: max_buckets,
      max_period: 400.days
    )
  end
end
