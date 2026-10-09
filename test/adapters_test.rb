# frozen_string_literal: true

require "test_helper"

class AdaptersTest < Minitest::Test
  FakeConnection = Struct.new(:adapter_name) do
    def quote(value)
      "'#{value}'"
    end
  end

  def test_postgresql_date_trunc_sql
    connection = FakeConnection.new("PostgreSQL")
    sql = RecordingStudioMetrics::Adapters.for_connection(connection).truncate_sql(
      connection,
      "members",
      "created_at",
      "month",
      "UTC"
    )

    assert_equal "date_trunc('month', members.created_at, 'UTC')", sql
  end

  def test_postgresql_date_column_truncates_without_a_timezone
    connection = FakeConnection.new("PostgreSQL")
    sql = RecordingStudioMetrics::Adapters::Postgresql.truncate_date_sql(
      connection,
      "usage_daily_metrics",
      "metric_date",
      "day"
    )

    assert_equal "date_trunc('day', usage_daily_metrics.metric_date::timestamp)::date", sql
  end

  def test_unknown_adapter_fails_closed
    connection = FakeConnection.new("SQLite")

    assert_raises(RecordingStudioMetrics::Errors::CalculationError) do
      RecordingStudioMetrics::Adapters.for_connection(connection)
    end
  end
end
