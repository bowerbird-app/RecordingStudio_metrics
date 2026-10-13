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
    RecordingStudioMetrics.reset_configuration!
  end

  def teardown
    RecordingStudioMetrics.registry.reset!
    RecordingStudioMetrics.reset_configuration!
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

  def test_catalog_entries_expose_defaults_for_existing_registrations
    RecordingStudioMetrics.register(:users, model: ExampleRecord) do
      count :total
      breakdown :by_country, field: :country
      timeseries :registrations, field: :created_at, intervals: %i[day week]
    end

    entries = RecordingStudioMetrics.discover(context: catalog_context).to_h { |row| [row[:name], row] }

    assert_equal "count", entries[:total][:unit]
    assert_empty entries[:total][:group_by]
    assert_equal [:country], entries[:by_country][:group_by]
    assert_equal({ supported: false }, entries[:total][:date_range])
    assert_equal true, entries[:registrations][:date_range][:supported]
    assert_equal 366.days.to_i, entries[:registrations][:date_range][:max_period_seconds]
    assert_equal 400, entries[:registrations][:date_range][:max_buckets]
    assert_equal %i[day week], entries[:registrations][:supported_intervals]
    assert_equal "UTC", entries[:total][:timezone]
    assert_equal({ cached: true, max_age_seconds: 300 }, entries[:total][:freshness])
  end

  def test_catalog_entries_reflect_registration_and_configuration
    RecordingStudioMetrics.configure { |config| config.default_timezone = "Asia/Manila" }
    RecordingStudioMetrics.register(:users, model: ExampleRecord) do
      count :total, cache_for: 60
      count :live, cacheable: false
      sum :revenue, field: :amount, unit: "PHP", group_by: %i[plan], freshness: { updated: "nightly" }
    end

    entries = RecordingStudioMetrics.discover(context: catalog_context).to_h { |row| [row[:name], row] }

    assert_equal "Asia/Manila", entries[:total][:timezone]
    assert_equal({ cached: true, max_age_seconds: 60 }, entries[:total][:freshness])
    assert_equal({ cached: false }, entries[:live][:freshness])
    assert_equal "PHP", entries[:revenue][:unit]
    assert_equal [:plan], entries[:revenue][:group_by]
    assert_equal({ updated: "nightly" }, entries[:revenue][:freshness])
  end

  def test_discover_filters_by_resource
    RecordingStudioMetrics.register(:users, model: ExampleRecord) { count :total }
    RecordingStudioMetrics.register(:members, model: ExampleRecord) { count :total }

    rows = RecordingStudioMetrics.discover(context: catalog_context, resource: "users")
    identifiers = rows.map { |row| row[:identifier] }
    assert_equal ["users.total"], identifiers
    assert_empty RecordingStudioMetrics.discover(context: catalog_context, resource: :missing)
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

  def test_api_authorize_is_stored_on_the_resource
    check = ->(_context) { true }
    RecordingStudioMetrics.register(:users, model: ExampleRecord, api_authorize: check) do
      count :total
    end

    assert_same check, RecordingStudioMetrics.registry.api_authorize_for(:users)
    assert_nil RecordingStudioMetrics.registry.api_authorize_for(:missing)
  end

  def test_api_authorize_must_be_callable
    error = assert_raises(ArgumentError) do
      RecordingStudioMetrics.register(:users, model: ExampleRecord, api_authorize: :staff) do
        count :total
      end
    end
    assert_match(/api_authorize must be callable/, error.message)
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

  private

  def catalog_context
    RecordingStudioMetrics::Context.new(actor: :a, scope: :root, workspace_id: "ws-1")
  end
end
