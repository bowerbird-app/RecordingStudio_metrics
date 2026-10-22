# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioMetrics.configuration
    RecordingStudioMetrics.reset_configuration!
  end

  def teardown
    RecordingStudioMetrics.configuration.hooks.clear!
    RecordingStudioMetrics.configuration = @original_configuration
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

  def test_load_config_ignores_a_missing_yaml_file
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      config_for_called = false
      app_config = Struct.new(:x).new(nil)
      app = Struct.new(:config, :root).new(app_config, dir)
      app.define_singleton_method(:config_for) do |_name|
        config_for_called = true
      end

      find_initializer("recording_studio_metrics.load_config").block.call(app)

      refute config_for_called
      assert_equal "UTC", RecordingStudioMetrics.configuration.default_timezone
    end
  end

  def test_load_config_raises_on_invalid_yaml
    Dir.mktmpdir do |dir|
      yaml_path = File.join(dir, "config", "recording_studio_metrics.yml")
      FileUtils.mkdir_p(File.dirname(yaml_path))
      File.write(yaml_path, "{")
      app_config = Struct.new(:x).new(nil)
      app = Struct.new(:config, :root) do
        def config_for(_name)
          YAML.load_file(File.join(root, "config", "recording_studio_metrics.yml"))
        end
      end.new(app_config, dir)

      assert_raises(Psych::SyntaxError) do
        find_initializer("recording_studio_metrics.load_config").block.call(app)
      end
    end
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
