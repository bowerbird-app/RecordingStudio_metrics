# frozen_string_literal: true

require "test_helper"

class MetricsGroupLabelsTest < ActiveSupport::TestCase
  COUNTRY_LABELS = lambda { |values, column|
    next {} unless column.to_s == "country"

    names = { "AU" => "Australia", "US" => "United States", "NZ" => "", "GB" => "   " }
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
    Member.create!(workspace: @alpha, status: "active", country: "GB", created_at: Time.utc(2026, 9, 4))
    Member.create!(workspace: @alpha, status: "active", country: "CA", created_at: Time.utc(2026, 9, 5))
    Project.create!(workspace: @alpha, title: "Done", storage_bytes: 100, completed: true)
    Project.create!(workspace: @alpha, title: "Open", storage_bytes: 50, completed: false)

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
      breakdown :explodes, field: :country, labels: ->(*) { raise "nope" }
    end

    RecordingStudioMetrics.register(
      :labelled_projects,
      model: Project,
      scope_attribute: :workspace_id,
      blast_radius: :root
    ) do
      average :storage,
              field: :storage_bytes,
              group_by: [:completed],
              labels: ->(_values, _column) { { "true" => "Done", "false" => "Open" } }
    end
  end

  teardown do
    RecordingStudioMetrics.configuration.min_group_size = @original_min_group_size
    DummyMetricsCatalog.load!
  end

  test "labelled breakdown includes key, label, and value" do
    result = execute("labelled_members.by_country")
    by_key = result.data.to_h { |row| [row[:key], row] }

    assert_equal({ key: "AU", label: "Australia", value: 2 }, by_key["AU"])
    assert_equal %i[key label value], by_key["AU"].keys
    assert_equal({ key: "US", label: "United States", value: 1 }, by_key["US"])
    assert_equal({ key: "NZ", value: 1 }, by_key["NZ"])
    assert_equal({ key: "GB", value: 1 }, by_key["GB"])
    assert_equal({ key: "CA", value: 1 }, by_key["CA"])

    json = JSON.parse(result.as_json.to_json)
    au = json["data"].find { |row| row["key"] == "AU" }
    assert_equal %w[key label value], au.keys
    assert_equal "Australia", au["label"]
    assert_equal 2, au["value"]
    refute json["data"].find { |row| row["key"] == "CA" }.key?("label")
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

    au = labelled.groups.find { |row| row[:key] == "AU" }
    assert_equal({ key: "AU", label: "Australia", value: 2 }, au)
    assert_equal %i[key label value], au.keys
    refute labelled.groups.find { |row| row[:key] == "NZ" }.key?(:label)
    refute labelled.groups.find { |row| row[:key] == "CA" }.key?(:label)

    json = JSON.parse(labelled.as_json.to_json)
    assert_equal "Australia", json["groups"].find { |row| row["key"] == "AU" }["label"]

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

    assert_equal [{ key: "AU", label: "Australia", value: 2 }], result.groups
    assert_equal({ groups: 4, value: 4 }, result.other)
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
    assert_equal %i[key label data], au.keys
    assert_equal "Australia", au[:label]
    assert_equal [1, 0, 1], au[:data].map { |row| row[:value] }
    nz = result.groups.find { |row| row[:key] == "NZ" }
    refute nz.key?(:label)
    assert nz[:data].is_a?(Array)
  end

  test "time series other bucket has no label" do
    RecordingStudioMetrics.configuration.min_group_size = 2
    result = execute(
      "labelled_members.registrations",
      group_by: "country",
      interval: :month,
      start_at: Time.utc(2026, 7, 1),
      end_at: Time.utc(2026, 10, 1)
    )

    assert_equal [{ key: "AU", label: "Australia" }], result.groups.map { |row| row.slice(:key, :label) }
    refute result.other.key?(:label)
    assert_equal [0, 1, 3], result.other[:data].map { |row| row[:value] }
  end

  test "string keys label boolean group values" do
    RecordingStudioMetrics.configuration.min_group_size = 1
    result = execute("labelled_projects.storage", group_by: "completed")
    labels = result.groups.to_h { |row| [row[:key], row[:label]] }

    assert_equal({ false => "Open", true => "Done" }, labels)
  end

  test "labels is called once with the kept group values" do
    calls = []
    RecordingStudioMetrics.register(
      :label_calls,
      model: Member,
      scope_attribute: :workspace_id,
      blast_radius: :root
    ) do
      count :total, group_by: [:country], labels: lambda { |values, column|
        calls << [values, column]
        { "AU" => "Australia" }
      }
    end

    RecordingStudioMetrics.configuration.min_group_size = 2
    result = execute("label_calls.total", group_by: "country")

    assert_equal [[["AU"], :country]], calls
    assert_equal "Australia", result.groups.first[:label]
    refute result.other.key?(:label)
  end

  test "dummy labelled breakdown uses the country names" do
    result = execute("members.by_country_labelled")
    by_key = result.data.to_h { |row| [row[:key], row[:label]] }

    assert_equal "Australia", by_key["AU"]
    assert_equal "United States", by_key["US"]
    assert_nil by_key["CA"]
  end

  test "a labels callable that does not return a Hash fails closed" do
    assert_raises(RecordingStudioMetrics::Errors::CalculationError) do
      execute("labelled_members.broken")
    end
  end

  test "a raising labels callable becomes a calculation error" do
    error = assert_raises(RecordingStudioMetrics::Errors::CalculationError) do
      execute("labelled_members.explodes")
    end

    assert_equal "nope", error.message
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
