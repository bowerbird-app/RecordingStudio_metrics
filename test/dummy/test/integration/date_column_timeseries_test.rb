# frozen_string_literal: true

require "test_helper"

class UsageDailyMetric < ApplicationRecord
  self.table_name = "usage_daily_metrics"
end

class DateColumnTimeseriesTest < ActiveSupport::TestCase
  setup do
    DummyMetricsCatalog.load!
    create_usage_table
    register_usage_metric

    @workspace = Workspace.create!(name: "Daily #{SecureRandom.hex(4)}")
    @actor = User.create!(
      email: "metrics-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
  end

  teardown do
    ActiveRecord::Base.connection.drop_table(:usage_daily_metrics, if_exists: true)
    DummyMetricsCatalog.load!
  end

  test "date column series includes today in the default window" do
    travel_to Time.utc(2026, 10, 9, 17, 0, 0) do
      UsageDailyMetric.create!(workspace_id: @workspace.id, metric_date: Date.new(2026, 9, 8))
      UsageDailyMetric.create!(workspace_id: @workspace.id, metric_date: Date.new(2026, 9, 9))
      UsageDailyMetric.create!(workspace_id: @workspace.id, metric_date: Date.new(2026, 10, 8))
      UsageDailyMetric.create!(workspace_id: @workspace.id, metric_date: Date.new(2026, 10, 9))

      by_date = counts_by_date("usage_daily.calls", "UTC")

      assert_equal 1, by_date.fetch("2026-09-09")
      assert_equal 1, by_date.fetch("2026-10-08")
      assert_equal 1, by_date.fetch("2026-10-09")
      assert_nil by_date["2026-09-08"]
      assert_nil by_date["2026-10-10"]
    end
  end

  test "date column week and month intervals stay inside the window" do
    [Date.new(2026, 10, 5), Date.new(2026, 10, 6), Date.new(2026, 10, 7),
     Date.new(2026, 10, 9), Date.new(2026, 10, 10), Date.new(2026, 10, 11)].each do |day|
      UsageDailyMetric.create!(workspace_id: @workspace.id, metric_date: day)
    end

    start_at = Time.utc(2026, 10, 7)
    end_at = Time.utc(2026, 10, 9, 12)

    week = counts_by_date("usage_daily.calls", "UTC", interval: :week, start_at: start_at, end_at: end_at)
    month = counts_by_date("usage_daily.calls", "UTC", interval: :month, start_at: start_at, end_at: end_at)

    assert_equal({ "2026-10-05" => 2 }, week.select { |_date, value| value.positive? })
    assert_equal({ "2026-10-01" => 2 }, month.select { |_date, value| value.positive? })
  end

  test "date column rows stay on their calendar day in each timezone" do
    UsageDailyMetric.create!(workspace_id: @workspace.id, metric_date: Date.new(2026, 10, 8))
    UsageDailyMetric.create!(workspace_id: @workspace.id, metric_date: Date.new(2026, 10, 9))

    %w[America/Los_Angeles Asia/Manila].each do |zone|
      placed = counts_by_date(
        "usage_daily.calls",
        zone,
        start_at: Time.utc(2026, 10, 1),
        end_at: Time.utc(2026, 10, 12)
      ).select { |_date, value| value.positive? }.keys

      assert_equal %w[2026-10-08 2026-10-09], placed, zone
    end
  end

  test "timestamp column series still follows the request timezone" do
    Member.create!(
      workspace: @workspace,
      status: "active",
      country: "AU",
      verified: true,
      created_at: Time.utc(2026, 10, 9, 2, 0, 0)
    )

    los_angeles = counts_by_date(
      "members.registrations",
      "America/Los_Angeles",
      start_at: Time.utc(2026, 10, 7),
      end_at: Time.utc(2026, 10, 11)
    )
    manila = counts_by_date(
      "members.registrations",
      "Asia/Manila",
      start_at: Time.utc(2026, 10, 7),
      end_at: Time.utc(2026, 10, 11)
    )

    assert_equal 1, los_angeles.fetch("2026-10-08")
    assert_equal 0, los_angeles.fetch("2026-10-09")
    assert_equal 0, manila.fetch("2026-10-08")
    assert_equal 1, manila.fetch("2026-10-09")
  end

  test "string bounds are parsed for a timeseries" do
    Member.create!(
      workspace: @workspace,
      status: "active",
      country: "AU",
      verified: true,
      created_at: Time.utc(2026, 8, 10, 12)
    )

    by_date = counts_by_date(
      "members.registrations",
      "UTC",
      start_at: "2026-08-10",
      end_at: "2026-08-11T00:00:00Z"
    )

    assert_equal 1, by_date.fetch("2026-08-10")
    assert_nil by_date["2026-08-11"]
  end

  test "garbage series bounds raise invalid date range" do
    error = assert_raises(RecordingStudioMetrics::Errors::InvalidDateRange) do
      RecordingStudioMetrics.execute(
        "members.registrations",
        context: root_context("UTC"),
        interval: :day,
        start_at: "not-a-date",
        end_at: "2026-10-10",
        cache: false
      )
    end

    assert_equal "invalid time value", error.message
  end

  private

  def create_usage_table
    ActiveRecord::Base.connection.create_table(:usage_daily_metrics, force: true) do |table|
      table.uuid :workspace_id, null: false
      table.date :metric_date, null: false
      table.timestamps
    end
    UsageDailyMetric.reset_column_information
  end

  def register_usage_metric
    RecordingStudioMetrics.register(
      :usage_daily,
      model: UsageDailyMetric,
      scope_attribute: :workspace_id,
      blast_radius: :root
    ) do
      timeseries :calls,
                 field: :metric_date,
                 intervals: %i[day week month],
                 default_interval: :day,
                 title: "Daily calls"
    end
  end

  def counts_by_date(identifier, zone, interval: :day, start_at: nil, end_at: nil)
    result = RecordingStudioMetrics.execute(
      identifier,
      context: root_context(zone),
      interval: interval,
      start_at: start_at,
      end_at: end_at,
      cache: false
    )
    result.data.to_h { |row| [row[:date], row[:value]] }
  end

  def root_context(zone)
    RecordingStudioMetrics::Context.new(
      actor: @actor,
      scope: :root,
      workspace_id: @workspace.id,
      timezone: zone
    )
  end
end
