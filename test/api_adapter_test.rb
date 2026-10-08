# frozen_string_literal: true

require "test_helper"

class ApiAdapterTest < Minitest::Test
  def setup
    RecordingStudioMetrics.registry.reset!
    RecordingStudioMetrics.reset_configuration!
  end

  def teardown
    RecordingStudioMetrics.registry.reset!
    RecordingStudioMetrics.reset_configuration!
  end

  def test_discovery_without_a_usable_context_fails_closed
    assert_empty RecordingStudioMetrics.discover(context: nil, api: :admin)
  end

  def test_handlers_are_thin_wrappers
    source = File.read(File.expand_path("../lib/recording_studio_metrics/api.rb", __dir__))

    assert_includes source, "RecordingStudioMetrics.discover"
    assert_includes source, "RecordingStudioMetrics.execute"
    refute_includes source, "relation.count"
  end

  def test_endpoints_are_get_only
    source = File.read(File.expand_path("../lib/recording_studio_metrics/api.rb", __dir__))

    assert_includes source, "http_verb: :get"
    refute_includes source, "http_verb: :post"
  end

  def test_openapi_documents_execute_query_params
    source = File.read(File.expand_path("../lib/recording_studio_metrics/api.rb", __dir__))

    %w[filters interval start end timezone].each do |name|
      assert_includes source, "name: \"#{name}\""
    end
  end

  def test_error_mapping_is_a_no_op_without_rs_api
    refute defined?(RecordingStudioApi), "gem tests must not open RecordingStudioApi"

    error = RecordingStudioMetrics::Errors::UnknownMetric.new("x")
    assert_same error, RecordingStudioMetrics::Api.map_to_api_error(error)
  end
end
