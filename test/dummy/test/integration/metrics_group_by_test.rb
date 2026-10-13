# frozen_string_literal: true

require "test_helper"

class MetricsGroupByTest < ActiveSupport::TestCase
  setup do
    @original_min_group_size = RecordingStudioMetrics.configuration.min_group_size
    @alpha = Workspace.create!(name: "Alpha #{SecureRandom.hex(4)}")
    @beta = Workspace.create!(name: "Beta #{SecureRandom.hex(4)}")
    @actor = User.find_by(email: "admin@admin.com") || User.create!(
      email: "metrics-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )

    Member.create!(workspace: @alpha, status: "active", country: "AU", created_at: Time.utc(2026, 7, 10))
    Member.create!(workspace: @alpha, status: "active", country: "US", created_at: Time.utc(2026, 8, 10))
    Member.create!(workspace: @alpha, status: "invited", country: "AU", created_at: Time.utc(2026, 9, 2))
    Member.create!(workspace: @beta, status: "active", country: "US", created_at: Time.utc(2026, 8, 1))
    Project.create!(workspace: @alpha, title: "Done", storage_bytes: 100, completed: true)
    Project.create!(workspace: @alpha, title: "Open", storage_bytes: 50, completed: false)
  end

  teardown do
    RecordingStudioMetrics.configuration.min_group_size = @original_min_group_size
  end

  test "scalar count splits by group and keeps the ungrouped total" do
    RecordingStudioMetrics.configuration.min_group_size = 1
    result = execute("members.total", group_by: "country")

    assert_equal 3, result.value
    assert_equal :country, result.group_by
    assert_equal [{ key: "AU", value: 2 }, { key: "US", value: 1 }], result.groups
    assert_nil result.other
  end

  test "groups below the minimum size merge into other and totals still add up" do
    RecordingStudioMetrics.configuration.min_group_size = 2
    result = execute("members.total", group_by: "country")

    assert_equal [{ key: "AU", value: 2 }], result.groups
    assert_equal({ groups: 1, value: 1 }, result.other)
    assert_equal result.value, result.groups.sum { |group| group[:value] } + result.other[:value]
    refute_includes result.as_json.to_s, "US"
  end

  test "default minimum group size hides every group in a small workspace" do
    result = execute("members.total", group_by: "country")

    assert_equal 5, RecordingStudioMetrics.configuration.min_group_size
    assert_empty result.groups
    assert_equal({ groups: 2, value: 3 }, result.other)
  end

  test "average merges small groups weighted by row count" do
    RecordingStudioMetrics.configuration.min_group_size = 2
    merged = execute("projects.storage", group_by: "completed")
    assert_empty merged.groups
    assert_in_delta 75.0, merged.other[:value]

    RecordingStudioMetrics.configuration.min_group_size = 1
    split = execute("projects.storage", group_by: "completed")
    assert_equal [{ key: false, value: 50.0 }, { key: true, value: 100.0 }], split.groups
  end

  test "time series split by group across from/to and interval, with real counts" do
    RecordingStudioMetrics.configuration.min_group_size = 2
    result = execute(
      "members.registrations",
      group_by: "country",
      interval: :month,
      start_at: Time.utc(2026, 7, 1),
      end_at: Time.utc(2026, 10, 1)
    )

    assert_equal [1, 1, 1], result.data.map { |row| row[:value] }
    assert_equal ["AU"], result.groups.map { |group| group[:key] }
    assert_equal [1, 0, 1], result.groups.first[:data].map { |row| row[:value] }
    assert_equal 1, result.other[:groups]
    assert_equal [0, 1, 0], result.other[:data].map { |row| row[:value] }
  end

  test "group_by works with declared filters" do
    RecordingStudioMetrics.configuration.min_group_size = 1
    result = execute(
      "members.registrations",
      group_by: "country",
      interval: :month,
      start_at: Time.utc(2026, 7, 1),
      end_at: Time.utc(2026, 10, 1),
      filters: { status: "active" }
    )

    series = result.groups.to_h { |group| [group[:key], group[:data].map { |row| row[:value] }] }
    assert_equal({ "AU" => [1, 0, 0], "US" => [0, 1, 0] }, series)
  end

  test "grouping stays workspace scoped" do
    RecordingStudioMetrics.configuration.min_group_size = 1
    result = execute("members.total", group_by: "country", workspace: @beta)

    assert_equal [{ key: "US", value: 1 }], result.groups
  end

  test "unsupported group_by values are rejected" do
    assert_raises(RecordingStudioMetrics::Errors::InvalidGroupBy) do
      execute("members.total", group_by: "workspace_id")
    end
    assert_raises(RecordingStudioMetrics::Errors::InvalidGroupBy) do
      execute("projects.total", group_by: "completed")
    end
  end

  test "results without group_by are unchanged" do
    payload = execute("members.total").as_json

    assert_equal 3, payload[:value]
    refute payload.key?(:groups)
    refute payload.key?(:other)
  end

  private

  def execute(identifier, workspace: @alpha, **params)
    context = RecordingStudioMetrics::Context.new(actor: @actor, scope: :root, workspace_id: workspace.id, timezone: "UTC")
    RecordingStudioMetrics.execute(identifier, context: context, cache: false, **params)
  end
end
