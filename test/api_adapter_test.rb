# frozen_string_literal: true

require "test_helper"

module RecordingStudioApi
  class NotFoundError < StandardError; end
  class AuthorizationError < StandardError; end
  class InvalidActionInputError < StandardError
    attr_reader :details

    def initialize(message = "Action input is invalid", details: [])
      super(message)
      @details = Array(details)
    end
  end
end unless defined?(RecordingStudioApi::NotFoundError)

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

  def test_discovery_without_a_usable_context_fails_closed
    assert_raises(RecordingStudioApi::AuthorizationError) do
      RecordingStudioMetrics::Api::DiscoveryHandler.call(api_context(root_recording: nil))
    end
    assert_empty RecordingStudioMetrics.discover(context: nil, api: :admin)
  end

  def test_execute_handler_requires_explicit_exposure
    model = Class.new
    RecordingStudioMetrics.register(:users, model: model) do
      count :total
    end

    assert_raises(RecordingStudioApi::AuthorizationError) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(api_context(resource: "users", name: "total"))
    end
  end

  def test_unknown_metric_maps_to_not_found
    assert_raises(RecordingStudioApi::NotFoundError) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(
        api_context(resource: "missing", name: "total", workspace_id: "ws-1")
      )
    end
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

  def test_error_status_mapping
    mapping = {
      RecordingStudioMetrics::Errors::UnknownMetric.new("x") => RecordingStudioApi::NotFoundError,
      RecordingStudioMetrics::Errors::AuthorizationError.new("no") => RecordingStudioApi::AuthorizationError,
      RecordingStudioMetrics::Errors::InvalidFilter.new("bad") => RecordingStudioApi::InvalidActionInputError
    }

    mapping.each do |error, klass|
      assert_instance_of klass, RecordingStudioMetrics::Api.map_to_api_error(error)
    end
  end

  private

  def api_context(resource: nil, name: nil, root_recording: :default)
    params = { resource: resource, name: name }
    recording = if root_recording == :default
                  Struct.new(:id, :recordable_id).new("root-1", "ws-1")
                else
                  root_recording
                end
    FakeApiContext.new(
      api_client: FakeClient.new("admin"),
      credential: nil,
      access_recording: nil,
      access_grant: Struct.new(:actor).new(:client),
      root_recording: recording,
      params: params
    )
  end
end
