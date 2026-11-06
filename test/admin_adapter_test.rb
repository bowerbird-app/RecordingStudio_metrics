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
      points = series.dig(0, :data)
      points.each do |point|
        assert_instance_of Hash, point
        assert_includes point.keys, :x
        assert_includes point.keys, :y
      end
      assert_equal(
        [{ name: "Registrations", data: [{ x: "2026-07-01", y: 3 }, { x: "2026-08-01", y: 5 }] }],
        series
      )
    end
  end

  def test_site_authorization_is_not_implied_by_site_scope
    admin_context = Struct.new(:actor, :root_recording, :timezone).new(:user, nil, "UTC")

    assert_raises(RecordingStudioMetrics::Errors::AuthorizationError) do
      RecordingStudioMetrics::Admin.context_from_admin(admin_context, scope: :site)
    end
  end

  def test_admin_adapter_does_not_construct_admin_widgets
    refute RecordingStudioMetrics::Admin.respond_to?(:widget)
    refute RecordingStudioMetrics::Admin.respond_to?(:build_admin_widget)

    source = File.read(File.expand_path("../lib/recording_studio_metrics/admin.rb", __dir__))
    refute_match(/RecordingStudioAdmin/, source)
  end

  def test_execute_passes_chosen_screen_filter_values
    RecordingStudioMetrics.registry.reset!
    RecordingStudioMetrics.register(:users, model: Class.new) do
      count :total do
        filter :status, field: :status, type: :enum, options: %w[active invited]
      end
    end

    admin_context = Struct.new(:current_actor) do
      def filter_value(key)
        { status: "active" }[key.to_sym]
      end
    end.new(:user)

    captured = nil
    RecordingStudioMetrics.stub(:execute, lambda { |identifier, **kwargs|
      captured = [identifier, kwargs]
      RecordingStudioMetrics::Result.new(metric: identifier, type: :scalar, title: "Total", value: 1)
    }) do
      RecordingStudioMetrics::Admin.scalar_value("users.total", admin_context: admin_context, workspace_id: "ws-1")
    end

    assert_equal "users.total", captured[0]
    assert_equal({ status: "active" }, captured[1][:filters])
  ensure
    RecordingStudioMetrics.registry.reset!
  end
end
