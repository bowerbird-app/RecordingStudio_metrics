# frozen_string_literal: true

require "test_helper"

class RegistryTest < Minitest::Test
  class ExampleRecord
    def self.column_names
      %w[id workspace_id status created_at country verified storage_bytes]
    end
  end

  def setup
    RecordingStudioMetrics.registry.reset!
  end

  def teardown
    RecordingStudioMetrics.registry.reset!
  end

  def test_register_standard_and_custom_metrics
    RecordingStudioMetrics.register(:users, model: ExampleRecord) do
      count :total, title: "Total users"
      timeseries :registrations, field: :created_at, intervals: %i[day month]
      custom :complex, result_type: :scalar do |relation, _context|
        relation.count
      end
    end

    assert_equal %w[users.complex users.registrations users.total],
                 RecordingStudioMetrics.definitions.map(&:identifier).sort
    assert_equal :scalar, RecordingStudioMetrics.find("users.total").result_type
    assert_equal :timeseries, RecordingStudioMetrics.find("users.registrations").result_type
    assert_equal :custom, RecordingStudioMetrics.find("users.complex").metric_type
  end

  def test_duplicate_identifiers_are_rejected
    RecordingStudioMetrics.register(:users, model: ExampleRecord) do
      count :total
    end

    error = assert_raises(RecordingStudioMetrics::Errors::DuplicateRegistration) do
      RecordingStudioMetrics.register(:users, model: ExampleRecord) do
        count :active
      end
    end
    assert_match(/already registered/, error.message)
  end

  def test_duplicate_metric_names_in_one_block_are_rejected
    assert_raises(RecordingStudioMetrics::Errors::DuplicateRegistration) do
      RecordingStudioMetrics.register(:users, model: ExampleRecord) do
        count :total
        count :total
      end
    end
  end

  def test_for_resource_and_find
    RecordingStudioMetrics.register(:users, model: ExampleRecord) do
      count :total
      count :verified, scope: ->(relation) { relation }
    end

    assert_equal 2, RecordingStudioMetrics.for_resource(:users).size
    assert_nil RecordingStudioMetrics.find("missing.total")
  end

  def test_discovery_metadata_does_not_calculate
    RecordingStudioMetrics.register(:users, model: ExampleRecord) do
      timeseries :registrations,
                 field: :created_at,
                 intervals: %i[day week],
                 default_interval: :week,
                 preferred_chart: :line,
                 title: "Registrations" do
        filter :country, field: :country, type: :string
      end
    end

    context = RecordingStudioMetrics::Context.new(actor: :a, scope: :root, workspace_id: "ws-1")
    metadata = RecordingStudioMetrics.discover(context: context).first
    assert_equal "users.registrations", metadata[:identifier]
    assert_equal :timeseries, metadata[:result_type]
    assert_equal %i[day week], metadata[:supported_intervals]
    assert_equal :country, metadata[:filters].first[:name]
    refute metadata.key?(:value)
  end

  def test_registration_does_not_expose_api_access
    RecordingStudioMetrics.register(:users, model: ExampleRecord) do
      count :total
    end

    context = RecordingStudioMetrics::Context.new(actor: :a, scope: :root, workspace_id: "ws-1")
    assert_empty RecordingStudioMetrics.discover(context: context, api: :admin)
    RecordingStudioMetrics.expose_to_api("users.total", api: :admin)
    assert_equal(
      ["users.total"],
      RecordingStudioMetrics.discover(context: context, api: :admin).map { |row| row[:identifier] }
    )
  end

  def test_discover_without_context_is_empty
    RecordingStudioMetrics.register(:users, model: ExampleRecord) do
      count :total, expose: { api: [:admin] }
    end

    assert_empty RecordingStudioMetrics.discover
    assert_empty RecordingStudioMetrics.discover(api: :admin)
  end

  def test_registration_reload_replaces_resource
    RecordingStudioMetrics.register(:users, model: ExampleRecord) do
      count :total
    end

    RecordingStudioMetrics.registry.stub(:reloading?, true) do
      RecordingStudioMetrics.register(:users, model: ExampleRecord) do
        count :total
        count :active
      end
    end

    assert_equal %w[users.active users.total], RecordingStudioMetrics.definitions.map(&:identifier).sort
  end
end
