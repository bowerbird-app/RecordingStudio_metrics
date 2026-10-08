# frozen_string_literal: true

require "test_helper"

class MetricsExecutionTest < ActiveSupport::TestCase
  setup do
    @alpha = Workspace.create!(name: "Alpha #{SecureRandom.hex(4)}")
    @beta = Workspace.create!(name: "Beta #{SecureRandom.hex(4)}")
    @actor = users(:one) if respond_to?(:users)
    @actor ||= User.find_by(email: "admin@admin.com") || User.create!(
      email: "metrics-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )

    travel_to Time.utc(2026, 9, 15, 12, 0, 0) do
      Member.create!(workspace: @alpha, status: "active", country: "AU", verified: true, created_at: Time.utc(2026, 7, 10))
      Member.create!(workspace: @alpha, status: "active", country: "US", verified: false, created_at: Time.utc(2026, 8, 10))
      Member.create!(workspace: @alpha, status: "invited", country: "AU", verified: false, created_at: Time.utc(2026, 9, 2))
      Member.create!(workspace: @beta, status: "active", country: "GB", verified: true, created_at: Time.utc(2026, 8, 1))

      @imaged = Project.create!(workspace: @alpha, title: "Imaged", storage_bytes: 100, completed: true)
      ProjectImage.create!(project: @imaged, file_size: 40)
      ProjectImage.create!(project: @imaged, file_size: 60)
      Project.create!(workspace: @alpha, title: "Empty", storage_bytes: 50, completed: false)
      Project.create!(workspace: @beta, title: "Other", storage_bytes: 999, completed: true)
    end
  end

  test "simple count is workspace scoped" do
    result = RecordingStudioMetrics.execute("members.total", context: root_context(@alpha))
    assert_equal 3, result.value
    assert_equal :scalar, result.type
  end

  test "cross-workspace isolation" do
    alpha = RecordingStudioMetrics.execute("members.total", context: root_context(@alpha))
    beta = RecordingStudioMetrics.execute("members.total", context: root_context(@beta))

    assert_equal 3, alpha.value
    assert_equal 1, beta.value
  end

  test "site scope fails closed without site authorization" do
    assert_raises(RecordingStudioMetrics::Errors::AuthorizationError) do
      RecordingStudioMetrics::Context.new(actor: @actor, scope: :site, workspace_id: @alpha.id)
    end
  end

  test "site-wide count requires explicit authorization" do
    result = RecordingStudioMetrics.execute(
      "members.total",
      context: RecordingStudioMetrics::Context.new(
        actor: @actor,
        scope: :site,
        site_authorized: true,
        timezone: "UTC"
      )
    )

    assert_operator result.value, :>=, 4
  end

  test "query parameters cannot broaden scope" do
    assert_raises(RecordingStudioMetrics::Errors::InvalidFilter) do
      RecordingStudioMetrics.execute(
        "members.total",
        context: root_context(@alpha),
        filters: { workspace_id: @beta.id }
      )
    end
  end

  test "unknown filters are rejected" do
    assert_raises(RecordingStudioMetrics::Errors::InvalidFilter) do
      RecordingStudioMetrics.execute(
        "members.registrations",
        context: root_context(@alpha),
        interval: :month,
        start_at: Time.utc(2026, 7, 1),
        end_at: Time.utc(2026, 10, 1),
        filters: { sql: "1=1" }
      )
    end
  end

  test "sql injection strings are parameterized field filters" do
    result = RecordingStudioMetrics.execute(
      "members.registrations",
      context: root_context(@alpha),
      interval: :month,
      start_at: Time.utc(2026, 7, 1),
      end_at: Time.utc(2026, 10, 1),
      filters: { country: "AU' OR '1'='1" }
    )
    assert_equal 0, result.data.sum { |row| row[:value] }
  end

  test "boolean and enum filters" do
    result = RecordingStudioMetrics.execute(
      "members.registrations",
      context: root_context(@alpha),
      interval: :month,
      start_at: Time.utc(2026, 7, 1),
      end_at: Time.utc(2026, 10, 1),
      filters: { verified: true, status: "active" }
    )

    assert_equal 1, result.data.sum { |row| row[:value] }
  end

  test "time series fills empty months and uses half-open bounds" do
    result = RecordingStudioMetrics.execute(
      "members.registrations",
      context: root_context(@alpha),
      interval: :month,
      start_at: Time.utc(2026, 7, 1),
      end_at: Time.utc(2026, 10, 1)
    )

    dates = result.data.map { |row| row[:date] }
    assert_equal %w[2026-07-01 2026-08-01 2026-09-01], dates
    assert_equal [1, 1, 1], result.data.map { |row| row[:value] }
  end

  test "unsupported interval is rejected" do
    assert_raises(RecordingStudioMetrics::Errors::UnsupportedInterval) do
      RecordingStudioMetrics.execute(
        "members.registrations",
        context: root_context(@alpha),
        interval: :minute,
        start_at: Time.utc(2026, 7, 1),
        end_at: Time.utc(2026, 8, 1)
      )
    end
  end

  test "custom metrics use the authorized parent relation" do
    with_images = RecordingStudioMetrics.execute("projects.with_images", context: root_context(@alpha))
    average = RecordingStudioMetrics.execute("projects.average_images", context: root_context(@alpha))
    complete = RecordingStudioMetrics.execute("projects.complete", context: root_context(@alpha))
    storage = RecordingStudioMetrics.execute("projects.storage_used", context: root_context(@alpha))

    assert_equal 1, with_images.value
    assert_in_delta 1.0, average.value
    assert_equal 1, complete.value
    assert_equal 150, storage.value
  end

  test "join duplicates do not inflate parent counts" do
    result = RecordingStudioMetrics.execute("projects.with_images", context: root_context(@alpha))
    assert_equal 1, result.value
  end

  test "empty datasets return zero rather than failing" do
    empty = Workspace.create!(name: "Empty #{SecureRandom.hex(4)}")
    result = RecordingStudioMetrics.execute("members.total", context: root_context(empty))
    assert_equal 0, result.value
  end

  test "average of empty dataset is nil not a fake zero failure" do
    empty = Workspace.create!(name: "Empty avg #{SecureRandom.hex(4)}")
    result = RecordingStudioMetrics.execute("projects.storage", context: root_context(empty))
    assert_nil result.value
  end

  test "breakdown groups only declared fields" do
    result = RecordingStudioMetrics.execute("members.by_country", context: root_context(@alpha))
    keys = result.data.map { |row| row[:key] }
    assert_includes keys, "AU"
    assert_includes keys, "US"
    refute_includes keys, "GB"
  end

  test "custom metric cannot run without a trusted context" do
    assert_raises(RecordingStudioMetrics::Errors::MissingContext) do
      RecordingStudioMetrics.execute("projects.with_images", context: nil)
    end
  end

  test "discovery distinguishes exposed metrics" do
    all = RecordingStudioMetrics.definitions.map(&:identifier)
    exposed = RecordingStudioMetrics.discover(context: root_context(@alpha), api: :admin).map { |row| row[:identifier] }

    assert_includes all, "members.total"
    assert_includes exposed, "members.total"
    refute_includes exposed, "projects.storage_used"
    refute_includes exposed, "members.site_total"
  end

  private

  def root_context(workspace)
    RecordingStudioMetrics::Context.new(
      actor: @actor,
      scope: :root,
      workspace_id: workspace.id,
      timezone: "UTC"
    )
  end
end
