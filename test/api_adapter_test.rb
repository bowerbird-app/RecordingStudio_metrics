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

  def test_handlers_call_discover_and_execute
    RecordingStudioMetrics.register(:members, model: ExampleRecord) do
      count :total, expose: { api: [:admin] }
    end

    identifiers = RecordingStudioMetrics::Api::DiscoveryHandler.call(api_context)[:metrics].map { |row| row[:identifier] }
    assert_equal ["members.total"], identifiers

    captured = {}
    stub_result = RecordingStudioMetrics::Result.new(metric: "members.total", type: :scalar, value: 9)
    execute = lambda do |identifier, **kwargs|
      captured = kwargs.merge(identifier: identifier)
      stub_result
    end

    payload = nil
    RecordingStudioMetrics.stub(:execute, execute) do
      payload = RecordingStudioMetrics::Api::ExecuteHandler.call(api_context(resource: "members", name: "total"))
    end

    assert_equal "members.total", captured[:identifier]
    assert_equal 9, payload[:value]
  end

  def test_endpoints_are_get_only
    assert_equal :get, RecordingStudioMetrics::Api::HTTP_VERB
    refute_equal :post, RecordingStudioMetrics::Api::HTTP_VERB
  end

  def test_register_requires_recording_studio_api
    error = assert_raises(LoadError) { RecordingStudioMetrics::Api.register!(api: :admin) }
    assert_match(/RecordingStudioApi is not available/, error.message)
  end

  def test_openapi_documents_execute_query_params
    names = RecordingStudioMetrics::Api::EXECUTE_OPENAPI_PARAMETERS.map { |parameter| parameter[:name] }

    %w[filters interval start from end to timezone group_by].each do |name|
      assert_includes names, name
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

  def test_from_to_aliases_match_start_end
    RecordingStudioMetrics.register(:members, model: ExampleRecord) do
      count :total, expose: { api: [:admin] }
    end

    captured = {}
    stub_result = RecordingStudioMetrics::Result.new(metric: "members.total", type: :scalar, value: 1)
    execute = lambda do |_identifier, **kwargs|
      captured = kwargs
      stub_result
    end

    start_value = "2026-01-01T00:00:00Z"
    end_value = "2026-02-01T00:00:00Z"

    RecordingStudioMetrics.stub(:execute, execute) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(
        api_context(resource: "members", name: "total", params: { start: start_value, end: end_value })
      )
    end
    start_end_bounds = captured.slice(:start_at, :end_at)

    RecordingStudioMetrics.stub(:execute, execute) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(
        api_context(resource: "members", name: "total", params: { from: start_value, to: end_value })
      )
    end
    from_to_bounds = captured.slice(:start_at, :end_at)

    assert_equal start_end_bounds, from_to_bounds
    assert_equal start_value, from_to_bounds[:start_at]
    assert_equal end_value, from_to_bounds[:end_at]
  end

  def test_matching_start_and_from_are_accepted
    RecordingStudioMetrics.register(:members, model: ExampleRecord) do
      count :total, expose: { api: [:admin] }
    end

    captured = {}
    stub_result = RecordingStudioMetrics::Result.new(metric: "members.total", type: :scalar, value: 1)
    execute = lambda do |_identifier, **kwargs|
      captured = kwargs
      stub_result
    end

    value = "2026-03-01T00:00:00Z"
    RecordingStudioMetrics.stub(:execute, execute) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(
        api_context(resource: "members", name: "total",
                    params: { start: value, from: value, end: "2026-04-01T00:00:00Z" })
      )
    end

    assert_equal value, captured[:start_at]
  end

  def test_conflicting_start_and_from_raises_invalid_date_range
    RecordingStudioMetrics.register(:members, model: ExampleRecord) do
      count :total, expose: { api: [:admin] }
    end

    error = assert_raises(RecordingStudioMetrics::Errors::InvalidDateRange) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(
        api_context(
          resource: "members",
          name: "total",
          params: { start: "2026-01-01T00:00:00Z", from: "2026-02-01T00:00:00Z" }
        )
      )
    end
    assert_match(/start and from must match/, error.message)
  end

  def test_conflicting_end_and_to_raises_invalid_date_range
    RecordingStudioMetrics.register(:members, model: ExampleRecord) do
      count :total, expose: { api: [:admin] }
    end

    error = assert_raises(RecordingStudioMetrics::Errors::InvalidDateRange) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(
        api_context(
          resource: "members",
          name: "total",
          params: { end: "2026-01-01T00:00:00Z", to: "2026-02-01T00:00:00Z" }
        )
      )
    end
    assert_match(/end and to must match/, error.message)
  end

  def test_start_end_params_unchanged_without_aliases
    RecordingStudioMetrics.register(:members, model: ExampleRecord) do
      count :total, expose: { api: [:admin] }
    end

    captured = {}
    stub_result = RecordingStudioMetrics::Result.new(metric: "members.total", type: :scalar, value: 1)
    execute = lambda do |_identifier, **kwargs|
      captured = kwargs
      stub_result
    end

    RecordingStudioMetrics.stub(:execute, execute) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(
        api_context(
          resource: "members",
          name: "total",
          params: { start: "2026-05-01T00:00:00Z", end: "2026-06-01T00:00:00Z", interval: "day" }
        )
      )
    end

    assert_equal "2026-05-01T00:00:00Z", captured[:start_at]
    assert_equal "2026-06-01T00:00:00Z", captured[:end_at]
    assert_equal "day", captured[:interval]
  end

  def test_error_mapping_is_a_no_op_without_rs_api
    refute defined?(RecordingStudioApi), "gem tests must not open RecordingStudioApi"

    error = RecordingStudioMetrics::Errors::UnknownMetric.new("x")
    assert_same error, RecordingStudioMetrics::Api.map_to_api_error(error)
  end

  def test_discovery_filters_catalog_by_resource
    RecordingStudioMetrics.register(:users, model: ExampleRecord) do
      count :total, expose: { api: [:admin] }
    end
    RecordingStudioMetrics.register(:members, model: ExampleRecord) do
      count :total, expose: { api: [:admin] }
    end

    handler = RecordingStudioMetrics::Api::DiscoveryHandler
    filtered = handler.call(api_context(params: { filters: { resource: "users" } }))
    unfiltered = handler.call(api_context)

    assert_equal(["users.total"], filtered[:metrics].map { |row| row[:identifier] })
    assert_equal %w[members.total users.total], unfiltered[:metrics].map { |row| row[:identifier] }.sort
  end

  def test_discovery_resource_filter_for_unknown_resource_is_empty
    RecordingStudioMetrics.register(:users, model: ExampleRecord) do
      count :total, expose: { api: [:admin] }
    end

    context = api_context(params: { filters: { "resource" => "nope" } })
    payload = RecordingStudioMetrics::Api::DiscoveryHandler.call(context)
    assert_empty payload[:metrics]
  end

  def test_discovery_rejects_unknown_catalog_filters
    RecordingStudioMetrics.register(:users, model: ExampleRecord) do
      count :total, expose: { api: [:admin] }
    end

    error = assert_raises(RecordingStudioMetrics::Errors::InvalidFilter) do
      RecordingStudioMetrics::Api::DiscoveryHandler.call(api_context(params: { filters: { country: "PH" } }))
    end
    assert_includes error.message, "country"
  end

  def test_discovery_entries_include_catalog_fields
    RecordingStudioMetrics.register(:users, model: ExampleRecord) do
      count :total, expose: { api: [:admin] }
    end

    row = RecordingStudioMetrics::Api::DiscoveryHandler.call(api_context)[:metrics].first
    %i[unit group_by supported_intervals date_range timezone freshness].each do |key|
      assert row.key?(key), "expected catalog entry to include #{key}"
    end
  end

  def test_execute_passes_group_by_through
    RecordingStudioMetrics.register(:members, model: ExampleRecord) do
      count :total, group_by: [:country], expose: { api: [:admin] }
    end

    captured = {}
    stub_result = RecordingStudioMetrics::Result.new(metric: "members.total", type: :scalar, value: 1)
    execute = lambda do |_identifier, **kwargs|
      captured = kwargs
      stub_result
    end

    RecordingStudioMetrics.stub(:execute, execute) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(
        api_context(resource: "members", name: "total", params: { group_by: "country" })
      )
    end

    assert_equal "country", captured[:group_by]
  end

  private

  class ExampleRecord
    def self.column_names
      %w[id workspace_id]
    end
  end

  def api_context(resource: "accounts", name: "total", params: {})
    grant = Struct.new(:actor).new(:client)
    root = Struct.new(:id, :recordable_id).new("root-1", "ws-1")
    Struct.new(:access_grant, :access_recording, :root_recording, :params, :api_key, keyword_init: true).new(
      access_grant: grant,
      access_recording: nil,
      root_recording: root,
      params: { resource: resource, name: name }.merge(params),
      api_key: :admin
    )
  end
end
