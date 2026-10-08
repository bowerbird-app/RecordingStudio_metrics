# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioMetrics.instance_variable_get(:@configuration)
    RecordingStudioMetrics.instance_variable_set(:@configuration, RecordingStudioMetrics::Configuration.new)
  end

  def teardown
    RecordingStudioMetrics.configuration.hooks.clear!
    RecordingStudioMetrics.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_before_and_after_initialize_initializers_run_hooks
    before_called = false
    after_called = false

    RecordingStudioMetrics.configuration.hooks.before_initialize { |_engine| before_called = true }
    RecordingStudioMetrics.configuration.hooks.after_initialize { |_engine| after_called = true }

    find_initializer("recording_studio_metrics.before_initialize").block.call(Object.new)
    find_initializer("recording_studio_metrics.after_initialize").block.call(Object.new)

    assert before_called
    assert after_called
  end

  def test_load_config_merges_config_sources_and_runs_on_configuration_hook
    hook_called = false
    hook_payload = nil
    RecordingStudioMetrics.configuration.hooks.on_configuration do |cfg|
      hook_called = true
      hook_payload = cfg
    end

    xcfg = Struct.new(:recording_studio_metrics).new({ cache_enabled: false })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { default_timezone: "Australia/Brisbane", max_timeseries_buckets: 12 }
      end
    end.new(app_config)

    find_initializer("recording_studio_metrics.load_config").block.call(app)

    assert hook_called
    assert_equal RecordingStudioMetrics.configuration, hook_payload
    assert_equal "Australia/Brisbane", RecordingStudioMetrics.configuration.default_timezone
    assert_equal 12, RecordingStudioMetrics.configuration.max_timeseries_buckets
    assert_equal false, RecordingStudioMetrics.configuration.cache_enabled
  end

  def test_engine_does_not_monkey_patch_models_or_controllers
    names = RecordingStudioMetrics::Engine.initializers.map(&:name)

    refute_includes names, "recording_studio_metrics.apply_model_extensions"
    refute_includes names, "recording_studio_metrics.apply_controller_extensions"
    refute RecordingStudioMetrics::Engine.respond_to?(:apply_model_extensions)
  end

  private

  def find_initializer(name)
    RecordingStudioMetrics::Engine.initializers.find { |initializer| initializer.name == name }
  end
end
