# frozen_string_literal: true

require "test_helper"

class OccupancyRecord < ApplicationRecord
  self.table_name = "occupancy_records"
end

class TimeseriesOptionsTest < ActiveSupport::TestCase
  setup do
    DummyMetricsCatalog.load!
    create_occupancy_table
    register_occupancy_metrics

    @workspace = Workspace.create!(name: "Options #{SecureRandom.hex(4)}")
    @actor = User.create!(
      email: "metrics-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
  end

  teardown do
    ActiveRecord::Base.connection.drop_table(:occupancy_records, if_exists: true)
    DummyMetricsCatalog.load!
  end

  test "bucket_timezone utc rolls up timestamps on utc days" do
    OccupancyRecord.create!(
      workspace_id: @workspace.id,
      created_at: Time.utc(2026, 10, 9, 2, 0, 0)
    )

    start_at = Time.utc(2026, 10, 7)
    end_at = Time.utc(2026, 10, 11)
    context_zone = "America/Los_Angeles"

    request_tz = counts_by_date("occupancy.arrivals", context_zone, start_at: start_at, end_at: end_at)
    utc_buckets = counts_by_date("occupancy.utc_arrivals", context_zone, start_at: start_at, end_at: end_at)

    assert_equal 1, request_tz.fetch("2026-10-08")
    assert_equal 0, request_tz.fetch("2026-10-09")
    assert_equal 0, utc_buckets.fetch("2026-10-08")
    assert_equal 1, utc_buckets.fetch("2026-10-09")
  end

  test "fill_gaps false omits empty buckets" do
    OccupancyRecord.create!(
      workspace_id: @workspace.id,
      created_at: Time.utc(2026, 10, 8, 12)
    )

    filled = counts_by_date(
      "occupancy.arrivals",
      "UTC",
      start_at: Time.utc(2026, 10, 7),
      end_at: Time.utc(2026, 10, 10)
    )
    sparse = counts_by_date(
      "occupancy.sparse_arrivals",
      "UTC",
      start_at: Time.utc(2026, 10, 7),
      end_at: Time.utc(2026, 10, 10)
    )

    assert_equal(%w[2026-10-07 2026-10-08 2026-10-09], filled.keys)
    assert_equal 0, filled.fetch("2026-10-07")
    assert_equal 1, filled.fetch("2026-10-08")
    assert_equal({ "2026-10-08" => 1 }, sparse)
  end

  test "population at end respects deleted_at by default" do
    OccupancyRecord.create!(
      workspace_id: @workspace.id,
      created_at: Time.utc(2026, 7, 10),
      deleted_at: nil
    )
    OccupancyRecord.create!(
      workspace_id: @workspace.id,
      created_at: Time.utc(2026, 8, 10),
      deleted_at: Time.utc(2026, 9, 5)
    )

    result = RecordingStudioMetrics.execute(
      "occupancy.headcount",
      context: root_context("UTC"),
      interval: :month,
      start_at: Time.utc(2026, 7, 1),
      end_at: Time.utc(2026, 10, 1),
      cache: false
    )

    assert_equal [1, 2, 1], result.data.map { |row| row[:value] }
  end

  test "population at end can use a trashed_at removal column" do
    OccupancyRecord.create!(
      workspace_id: @workspace.id,
      created_at: Time.utc(2026, 7, 10),
      trashed_at: nil
    )
    OccupancyRecord.create!(
      workspace_id: @workspace.id,
      created_at: Time.utc(2026, 8, 10),
      trashed_at: Time.utc(2026, 9, 5)
    )

    result = RecordingStudioMetrics.execute(
      "occupancy.trashable_headcount",
      context: root_context("UTC"),
      interval: :month,
      start_at: Time.utc(2026, 7, 1),
      end_at: Time.utc(2026, 10, 1),
      cache: false
    )

    assert_equal [1, 2, 1], result.data.map { |row| row[:value] }
  end

  private

  def create_occupancy_table
    ActiveRecord::Base.connection.create_table(:occupancy_records, force: true) do |table|
      table.uuid :workspace_id, null: false
      table.datetime :deleted_at
      table.datetime :trashed_at
      table.timestamps
    end
    OccupancyRecord.reset_column_information
  end

  def register_occupancy_metrics
    RecordingStudioMetrics.register(
      :occupancy,
      model: OccupancyRecord,
      scope_attribute: :workspace_id,
      blast_radius: :root
    ) do
      timeseries :arrivals,
                 field: :created_at,
                 intervals: %i[day],
                 default_interval: :day
      timeseries :utc_arrivals,
                 field: :created_at,
                 intervals: %i[day],
                 default_interval: :day,
                 bucket_timezone: "UTC"
      timeseries :sparse_arrivals,
                 field: :created_at,
                 intervals: %i[day],
                 default_interval: :day,
                 fill_gaps: false
      timeseries :headcount,
                 field: :created_at,
                 intervals: %i[month],
                 default_interval: :month,
                 cumulative: true
      timeseries :trashable_headcount,
                 field: :created_at,
                 intervals: %i[month],
                 default_interval: :month,
                 cumulative: true,
                 removal_column: :trashed_at
    end
  end

  def counts_by_date(identifier, zone, start_at:, end_at:)
    result = RecordingStudioMetrics.execute(
      identifier,
      context: root_context(zone),
      interval: :day,
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
