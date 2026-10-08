# frozen_string_literal: true

require "test_helper"

class AdminAdapterTest < Minitest::Test
  def test_chart_series_shape_is_consumer_agnostic
    result = RecordingStudioMetrics::Result.new(
      metric: "users.registrations",
      type: :timeseries,
      title: "Registrations",
      data: [{ date: "2026-07-01", value: 3 }, { date: "2026-08-01", value: 5 }]
    )
    admin_context = Struct.new(:actor, :root_recording, :timezone).new(:user, nil, "UTC")
    RecordingStudioMetrics.stub(:execute, result) do
      series = RecordingStudioMetrics::Admin.chart_series(
        "users.registrations",
        admin_context: admin_context,
        workspace_id: "ws-1"
      )
      assert_equal [{ name: "Registrations", data: [["2026-07-01", 3], ["2026-08-01", 5]] }], series
    end
  end

  def test_widget_builder_requires_admin_gem
    error = assert_raises(LoadError) do
      RecordingStudioMetrics::Admin.widget("users.total")
    end
    assert_match(/RecordingStudioAdmin is not available/, error.message)
  end
end
