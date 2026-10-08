# frozen_string_literal: true

require "test_helper"

class ApiAdapterTest < Minitest::Test
  FakeApiContext = Struct.new(:api_client, :credential, :access_recording, :access_grant, :root_recording, :params,
                              keyword_init: true) do
    def api_key
      "admin"
    end
  end

  FakeClient = Struct.new(:api_key)

  def setup
    RecordingStudioMetrics.registry.reset!
    RecordingStudioMetrics.reset_configuration!
  end

  def teardown
    RecordingStudioMetrics.registry.reset!
    RecordingStudioMetrics.reset_configuration!
  end

  def test_discovery_handler_hides_unexposed_metrics
    model = Class.new
    RecordingStudioMetrics.register(:users, model: model) do
      count :total
    end

    payload = RecordingStudioMetrics::Api::DiscoveryHandler.call(api_context)
    assert_equal [], payload[:metrics]
  end

  def test_execute_handler_requires_explicit_exposure
    model = Class.new
    RecordingStudioMetrics.register(:users, model: model) do
      count :total
    end

    payload = RecordingStudioMetrics::Api::ExecuteHandler.call(api_context(resource: "users", name: "total"))
    assert_equal "authorization_error", payload.dig(:error, :code)
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

  private

  def api_context(resource: nil, name: nil)
    FakeApiContext.new(
      api_client: FakeClient.new("admin"),
      credential: nil,
      access_recording: nil,
      access_grant: Struct.new(:actor).new(:client),
      root_recording: nil,
      params: { resource: resource, name: name }
    )
  end
end
