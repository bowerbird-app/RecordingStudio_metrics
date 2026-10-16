# frozen_string_literal: true

require "test_helper"

class MetricsGroupLabelsTest < ActiveSupport::TestCase
  COUNTRY_LABELS = lambda { |values, column|
    next {} unless column.to_s == "country"

    names = { "AU" => "Australia", "US" => "United States", "NZ" => "" }
    names.slice(*values.map(&:to_s))
  }

  setup do
    @original_min_group_size = RecordingStudioMetrics.configuration.min_group_size
    @alpha = Workspace.create!(name: "Alpha #{SecureRandom.hex(4)}")
    @actor = User.find_by(email: "admin@admin.com") || User.create!(
      email: "metrics-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )

    Member.create!(workspace: @alpha, status: "active", country: "AU", created_at: Time.utc(2026, 7, 10))
    Member.create!(workspace: @alpha, status: "active", country: "US", created_at: Time.utc(2026, 8, 10))
    Member.create!(workspace: @alpha, status: "invited", country: "AU", created_at: Time.utc(2026, 9, 2))
    Member.create!(workspace: @alpha, status: "active", country: "NZ", created_at: Time.utc(2026, 9, 3))

    RecordingStudioMetrics.register(
      :labelled_members,
      model: Member,
      scope_attribute: :workspace_id,
      blast_radius: :root
    ) do
      count :total, group_by: %i[country status], labels: COUNTRY_LABELS
      breakdown :by_country, field: :country, labels: COUNTRY_LABELS
      timeseries :registrations,
                 field: :created_at,
                 intervals: %i[month],
                 default_interval: :month,
                 group_by: %i[country],
                 labels: COUNTRY_LABELS
      breakdown :broken, field: :country, labels: ->(_values, _column) { :not_a_hash }
    end
  end

  teardown do
    RecordingStudioMetrics.configuration.min_group_size = @original_min_group_size
    DummyMetricsCatalog.load!
  end

  test "labelled breakdown includes label next to the raw key" do
    result = execute("labelled_members.by_country")
    by_key = result.data.to_h { |row| [row[:key], row] }

    assert_equal "Australia", by_key["AU"][:label]
    assert_equal "United States", by_key["US"][:label]
    assert_equal 2, by_key["AU"][:value]
    refute by_key["NZ"].key?(:label)
  end

  test "unlabelled breakdown rows keep only key and value" do
    result = execute("members.by_country")

    result.data.each do |row|
      assert_equal %i[key value], row.keys
    end
  end

  test "labelled group_by scalar includes label and keeps unlabeled output unchanged" do
    RecordingStudioMetrics.configuration.min_group_size = 1
    labelled = execute("labelled_members.total", group_by: "country")
    unlabelled = execute("members.total", group_by: "country")

    assert_equal "Australia", labelled.groups.find { |row| row[:key] == "AU" }[:label]
    labelled.groups.each { |row| assert row.key?(:key) }
    refute labelled.groups.find { |row| row[:key] == "NZ" }.key?(:label)

    unlabelled.groups.each do |row|
      refute row.key?(:label)
      assert_equal %i[key value], row.keys
    end
  end

  test "as_json omits label when the definition has no labels callable" do
    RecordingStudioMetrics.configuration.min_group_size = 1
    payload = execute("members.total", group_by: "country").as_json

    payload[:groups].each { |row| refute row.key?(:label) }
  end

  test "other stays unlabeled when small groups merge" do
    RecordingStudioMetrics.configuration.min_group_size = 2
    result = execute("labelled_members.total", group_by: "country")

    assert_equal "Australia", result.groups.find { |row| row[:key] == "AU" }[:label]
    refute result.groups.any? { |row| row[:key] == "US" }
    assert result.other[:groups].positive?
    refute result.other.key?(:label)
    refute result.other.key?(:key)
  end

  test "labelled time series groups include label beside key and data" do
    RecordingStudioMetrics.configuration.min_group_size = 1
    result = execute(
      "labelled_members.registrations",
      group_by: "country",
      interval: :month,
      start_at: Time.utc(2026, 7, 1),
      end_at: Time.utc(2026, 10, 1)
    )

    au = result.groups.find { |row| row[:key] == "AU" }
    assert_equal "Australia", au[:label]
    assert au[:data].is_a?(Array)
    nz = result.groups.find { |row| row[:key] == "NZ" }
    refute nz.key?(:label)
  end

  test "dummy named-country breakdown uses labels from the catalog" do
    result = execute("members.by_country_named")
    by_key = result.data.to_h { |row| [row[:key], row[:label]] }

    assert_equal "Australia", by_key["AU"]
    assert_equal "United States", by_key["US"]
  end

  test "a labels callable that does not return a Hash fails closed" do
    assert_raises(RecordingStudioMetrics::Errors::CalculationError) do
      execute("labelled_members.broken")
    end
  end

  private

  def execute(identifier, **params)
    context = RecordingStudioMetrics::Context.new(
      actor: @actor,
      scope: :root,
      workspace_id: @alpha.id,
      timezone: "UTC"
    )
    RecordingStudioMetrics.execute(identifier, context: context, cache: false, **params)
  end
end
