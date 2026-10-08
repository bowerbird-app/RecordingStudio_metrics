# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioMetrics::Configuration.new
  end

  def test_merge_updates_known_attributes
    @configuration.merge!(default_timezone: "Australia/Brisbane", max_timeseries_buckets: 12, cache_enabled: false)

    assert_equal "Australia/Brisbane", @configuration.default_timezone
    assert_equal 12, @configuration.max_timeseries_buckets
    assert_equal false, @configuration.cache_enabled
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", cache_enabled: true)

    refute_respond_to @configuration, :unknown_key
    assert_equal true, @configuration.cache_enabled
  end

  def test_merge_with_non_enumerable_is_noop
    original = @configuration.to_h

    @configuration.merge!(nil)

    assert_equal original[:default_timezone], @configuration.default_timezone
    assert_equal original[:max_timeseries_buckets], @configuration.max_timeseries_buckets
  end

  def test_defaults
    assert_equal "UTC", @configuration.default_timezone
    assert_equal true, @configuration.cache_enabled
    assert_instance_of RecordingStudio::Hooks, @configuration.hooks
  end

  def test_expose_to_api_is_opt_in
    refute @configuration.exposed_to_api?("members.total", api: :admin)

    @configuration.expose_to_api("members.total", api: :admin)

    assert @configuration.exposed_to_api?("members.total", api: :admin)
    refute @configuration.exposed_to_api?("members.total", api: :public)
  end

  def test_merge_accepts_string_keys
    @configuration.merge!("default_timezone" => "UTC", "max_timeseries_buckets" => 9)

    assert_equal "UTC", @configuration.default_timezone
    assert_equal 9, @configuration.max_timeseries_buckets
  end

  def test_to_h_reports_registered_hook_counts
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.after_service { nil }

    result = @configuration.to_h

    assert_equal 2, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal 1, result.fetch(:hooks_registered).fetch(:after_service)
  end

  def test_configure_without_block_is_safe
    RecordingStudioMetrics.configure

    assert_kind_of RecordingStudioMetrics::Configuration, RecordingStudioMetrics.configuration
  end
end
