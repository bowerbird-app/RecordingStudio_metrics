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

  def test_discovery_hides_metrics_the_api_authorize_hook_denies
    RecordingStudioMetrics.register(
      :accounts,
      model: ExampleRecord,
      blast_radius: :site,
      api_authorize: ->(_context) { false }
    ) do
      count :total, expose: { api: [:admin] }
    end
    RecordingStudioMetrics.register(:members, model: ExampleRecord) do
      count :total, expose: { api: [:admin] }
    end

    identifiers = RecordingStudioMetrics::Api::DiscoveryHandler.call(api_context)[:metrics].map { |row| row[:identifier] }
    assert_equal ["members.total"], identifiers
  end

  def test_discovery_lists_site_metrics_when_api_authorize_allows
    RecordingStudioMetrics.register(
      :accounts,
      model: ExampleRecord,
      blast_radius: :site,
      api_authorize: ->(context) { context.api_key == :admin }
    ) do
      count :total, expose: { api: [:admin] }
    end

    identifiers = RecordingStudioMetrics::Api::DiscoveryHandler.call(api_context)[:metrics].map { |row| row[:identifier] }
    assert_equal ["accounts.total"], identifiers
  end

  def test_discovery_keeps_site_metrics_hidden_without_api_authorize
    RecordingStudioMetrics.register(:accounts, model: ExampleRecord, blast_radius: :site) do
      count :total, expose: { api: [:admin] }
    end

    identifiers = RecordingStudioMetrics::Api::DiscoveryHandler.call(api_context)[:metrics].map { |row| row[:identifier] }
    assert_empty identifiers
  end

  def test_execute_denies_when_api_authorize_returns_false
    RecordingStudioMetrics.register(
      :accounts,
      model: ExampleRecord,
      blast_radius: :site,
      api_authorize: ->(_context) { false }
    ) do
      count :total, expose: { api: [:admin] }
    end

    error = assert_raises(RecordingStudioMetrics::Errors::AuthorizationError) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(api_context(resource: "accounts", name: "total"))
    end
    assert_equal "Not authorized to run this metric", error.public_message
  end

  def test_execute_denies_site_metrics_without_api_authorize
    RecordingStudioMetrics.register(:accounts, model: ExampleRecord, blast_radius: :site) do
      count :total, expose: { api: [:admin] }
    end

    assert_raises(RecordingStudioMetrics::Errors::AuthorizationError) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(api_context(resource: "accounts", name: "total"))
    end
  end

  def test_execute_uses_site_scope_when_api_authorize_allows
    RecordingStudioMetrics.register(
      :accounts,
      model: ExampleRecord,
      blast_radius: :site,
      api_authorize: ->(_context) { true }
    ) do
      count :total, expose: { api: [:admin] }
    end

    captured_context = nil
    stub_result = RecordingStudioMetrics::Result.new(metric: "accounts.total", type: :scalar, value: 4)
    execute = lambda do |_identifier, context:, **|
      captured_context = context
      stub_result
    end

    RecordingStudioMetrics.stub(:execute, execute) do
      payload = RecordingStudioMetrics::Api::ExecuteHandler.call(api_context(resource: "accounts", name: "total"))
      assert_equal 4, payload[:value]
    end

    assert_equal :site, captured_context.scope
    assert captured_context.site_authorized?
  end

  def test_execute_leaves_root_metrics_on_from_api_context
    RecordingStudioMetrics.register(:members, model: ExampleRecord) do
      count :total, expose: { api: [:admin] }
    end

    captured_context = nil
    stub_result = RecordingStudioMetrics::Result.new(metric: "members.total", type: :scalar, value: 1)
    execute = lambda do |_identifier, context:, **|
      captured_context = context
      stub_result
    end

    RecordingStudioMetrics.stub(:execute, execute) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(api_context(resource: "members", name: "total"))
    end

    assert_equal :root, captured_context.scope
    refute captured_context.site_authorized?
  end

  def test_error_mapping_is_a_no_op_without_rs_api
    refute defined?(RecordingStudioApi), "gem tests must not open RecordingStudioApi"

    error = RecordingStudioMetrics::Errors::UnknownMetric.new("x")
    assert_same error, RecordingStudioMetrics::Api.map_to_api_error(error)
  end

  private

  class ExampleRecord
    def self.column_names
      %w[id workspace_id]
    end
  end

  def api_context(resource: "accounts", name: "total")
    grant = Struct.new(:actor).new(:client)
    root = Struct.new(:id, :recordable_id).new("root-1", "ws-1")
    Struct.new(:access_grant, :access_recording, :root_recording, :params, :api_key, keyword_init: true).new(
      access_grant: grant,
      access_recording: nil,
      root_recording: root,
      params: { resource: resource, name: name },
      api_key: :admin
    )
  end
end
