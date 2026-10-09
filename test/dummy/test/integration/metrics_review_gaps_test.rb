# frozen_string_literal: true

require "test_helper"

class MetricsReviewGapsTest < ActiveSupport::TestCase
  setup do
    @alpha = Workspace.create!(name: "Alpha #{SecureRandom.hex(4)}")
    @beta = Workspace.create!(name: "Beta #{SecureRandom.hex(4)}")
    @actor = User.find_by(email: "admin@admin.com") || User.create!(
      email: "metrics-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )

    travel_to Time.utc(2026, 9, 15, 12, 0, 0) do
      Member.create!(workspace: @alpha, status: "active", country: "AU", verified: true, age: 30,
                     created_at: Time.utc(2026, 7, 10))
      Member.create!(workspace: @alpha, status: "active", country: "US", verified: false, age: 40,
                     created_at: Time.utc(2026, 8, 10))
      Member.create!(workspace: @alpha, status: "invited", country: "AU", verified: false, age: 20,
                     created_at: Time.utc(2026, 9, 2))
      Member.create!(workspace: @beta, status: "active", country: "GB", verified: true, age: 50,
                     created_at: Time.utc(2026, 8, 1))
      Member.create!(workspace: @beta, status: "active", country: "GB", verified: true, age: 51,
                     created_at: Time.utc(2026, 8, 2))
      Member.create!(workspace: @beta, status: "active", country: "GB", verified: true, age: 52,
                     created_at: Time.utc(2026, 8, 3))

      @imaged = Project.create!(workspace: @alpha, title: "Imaged", storage_bytes: 100, completed: true,
                                created_at: Time.utc(2026, 8, 10))
      ProjectImage.create!(project: @imaged, file_size: 40)
      Project.create!(workspace: @alpha, title: "Empty", storage_bytes: 50, completed: false,
                      created_at: Time.utc(2026, 8, 12))
      Project.create!(workspace: @beta, title: "Other", storage_bytes: 999, completed: true,
                      created_at: Time.utc(2026, 8, 1))
    end
  end

  test "scoped metric never replaces workspace isolation for count sum average breakdown and timeseries" do
    alpha = root_context(@alpha)
    beta = root_context(@beta)

    assert_equal 2, RecordingStudioMetrics.execute("members.active", context: alpha).value
    assert_equal 3, RecordingStudioMetrics.execute("members.active", context: beta).value

    assert_equal 150, RecordingStudioMetrics.execute("projects.storage_used", context: alpha).value
    assert_equal 999, RecordingStudioMetrics.execute("projects.storage_used", context: beta).value

    assert_in_delta 75.0, RecordingStudioMetrics.execute("projects.storage", context: alpha).value
    assert_in_delta 999.0, RecordingStudioMetrics.execute("projects.storage", context: beta).value

    alpha_keys = RecordingStudioMetrics.execute("members.by_country", context: alpha).data.map { |row| row[:key] }
    refute_includes alpha_keys, "GB"

    alpha_series = RecordingStudioMetrics.execute(
      "members.registrations",
      context: alpha,
      interval: :month,
      start_at: Time.utc(2026, 7, 1),
      end_at: Time.utc(2026, 10, 1)
    )
    assert_equal 3, alpha_series.data.sum { |row| row[:value] }
  end

  test "breakdown supports sum and average" do
    result = RecordingStudioMetrics.execute("projects.storage_by_completed", context: root_context(@alpha))
    by_key = result.data.to_h { |row| [row[:key], row[:value]] }
    assert_equal 100, by_key[true]
    assert_equal 50, by_key[false]

    averages = RecordingStudioMetrics.execute("projects.average_storage_by_completed", context: root_context(@alpha))
    avg_by_key = averages.data.to_h { |row| [row[:key], row[:value]] }
    assert_in_delta 100.0, avg_by_key[true]
    assert_in_delta 50.0, avg_by_key[false]
  end

  test "population at end of period counts records still present" do
    result = RecordingStudioMetrics.execute(
      "members.headcount",
      context: root_context(@alpha),
      interval: :month,
      start_at: Time.utc(2026, 7, 1),
      end_at: Time.utc(2026, 10, 1)
    )

    assert_equal "population_at_end_of_period", result.metadata[:semantics]
    assert_equal [1, 2, 3], result.data.map { |row| row[:value] }
  end

  test "numeric range date range and custom handler filters" do
    numeric = RecordingStudioMetrics.execute(
      "members.registrations",
      context: root_context(@alpha),
      interval: :month,
      start_at: Time.utc(2026, 7, 1),
      end_at: Time.utc(2026, 10, 1),
      filters: { age: { min: 25, max: 35 } }
    )
    assert_equal 1, numeric.data.sum { |row| row[:value] }

    dated = RecordingStudioMetrics.execute(
      "members.registrations",
      context: root_context(@alpha),
      interval: :month,
      start_at: Time.utc(2026, 7, 1),
      end_at: Time.utc(2026, 10, 1),
      filters: { created_at: { start: "2026-08-01", end: "2026-09-01" } }
    )
    assert_equal 1, dated.data.sum { |row| row[:value] }

    custom = RecordingStudioMetrics.execute(
      "members.registrations",
      context: root_context(@alpha),
      interval: :month,
      start_at: Time.utc(2026, 7, 1),
      end_at: Time.utc(2026, 10, 1),
      filters: { country_prefix: "A" }
    )
    assert_equal 2, custom.data.sum { |row| row[:value] }
  end

  test "hour day week and year timeseries plus sum and average series" do
    hour = RecordingStudioMetrics.execute(
      "members.registrations",
      context: root_context(@alpha),
      interval: :hour,
      start_at: Time.utc(2026, 8, 10, 0),
      end_at: Time.utc(2026, 8, 10, 6)
    )
    assert_equal 1, hour.data.sum { |row| row[:value] }

    day = RecordingStudioMetrics.execute(
      "members.registrations",
      context: root_context(@alpha),
      interval: :day,
      start_at: Time.utc(2026, 8, 9),
      end_at: Time.utc(2026, 8, 12)
    )
    assert_equal 1, day.data.sum { |row| row[:value] }

    week = RecordingStudioMetrics.execute(
      "members.registrations",
      context: root_context(@alpha),
      interval: :week,
      start_at: Time.utc(2026, 8, 3),
      end_at: Time.utc(2026, 8, 24)
    )
    assert_equal 1, week.data.sum { |row| row[:value] }

    year = RecordingStudioMetrics.execute(
      "members.registrations",
      context: root_context(@alpha),
      interval: :year,
      start_at: Time.utc(2026, 1, 1),
      end_at: Time.utc(2027, 1, 1)
    )
    assert_equal 3, year.data.sum { |row| row[:value] }

    storage = RecordingStudioMetrics.execute(
      "projects.storage_added",
      context: root_context(@alpha),
      interval: :month,
      start_at: Time.utc(2026, 8, 1),
      end_at: Time.utc(2026, 9, 1)
    )
    assert_equal 150, storage.data.sum { |row| row[:value] }

    average = RecordingStudioMetrics.execute(
      "projects.average_storage",
      context: root_context(@alpha),
      interval: :month,
      start_at: Time.utc(2026, 8, 1),
      end_at: Time.utc(2026, 9, 1)
    )
    assert_in_delta 75.0, average.data.first[:value]
  end

  test "null values are ignored by sum and average" do
    connection = ActiveRecord::Base.connection
    connection.change_column_null(:projects, :storage_bytes, true)
    Project.create!(workspace: @alpha, title: "Null storage", storage_bytes: nil, completed: false)

    sum = RecordingStudioMetrics.execute("projects.storage_used", context: root_context(@alpha))
    average = RecordingStudioMetrics.execute("projects.storage", context: root_context(@alpha))

    assert_equal 150, sum.value
    assert_in_delta 75.0, average.value
  ensure
    connection&.change_column_null(:projects, :storage_bytes, false, 0)
  end

  test "recordable model metrics use recordable_root_relation" do
    Current.actor = @actor
    root = RecordingStudio.root_recording_for(@alpha)
    folder = Folder.create!(name: "Docs #{SecureRandom.hex(4)}")
    RecordingStudio.record!(
      action: "created",
      recordable: folder,
      root_recording: root,
      parent_recording: root
    )
    other_root = RecordingStudio.root_recording_for(@beta)
    other_folder = Folder.create!(name: "Other #{SecureRandom.hex(4)}")
    RecordingStudio.record!(
      action: "created",
      recordable: other_folder,
      root_recording: other_root,
      parent_recording: other_root
    )

    result = RecordingStudioMetrics.execute(
      "folders.total",
      context: RecordingStudioMetrics::Context.new(
        actor: @actor,
        scope: :root,
        root_recording: root,
        timezone: "UTC"
      )
    )
    assert_equal 1, result.value
  ensure
    Current.actor = nil
  end

  test "recording scope fails closed without a recordable id" do
    recording = Struct.new(:id, :recordable_id, :root_recording_id).new("rec-1", nil, "root-1")

    assert_raises(RecordingStudioMetrics::Errors::AuthorizationError) do
      RecordingStudioMetrics.execute(
        "folders.total",
        context: RecordingStudioMetrics::Context.new(
          actor: @actor,
          scope: :recording,
          access_recording: recording,
          timezone: "UTC"
        )
      )
    end
  end

  test "recording scope isolates the access recordable" do
    Current.actor = @actor
    root = RecordingStudio.root_recording_for(@alpha)
    folder = Folder.create!(name: "Scoped #{SecureRandom.hex(4)}")
    recording = RecordingStudio.record!(
      action: "created",
      recordable: folder,
      root_recording: root,
      parent_recording: root
    ).recording
    Folder.create!(name: "Unlinked #{SecureRandom.hex(4)}")

    result = RecordingStudioMetrics.execute(
      "folders.total",
      context: RecordingStudioMetrics::Context.new(
        actor: @actor,
        scope: :recording,
        access_recording: recording,
        timezone: "UTC"
      )
    )
    assert_equal 1, result.value
  ensure
    Current.actor = nil
  end

  test "context based discovery hides unauthorized and uncontextual catalogs" do
    root = root_context(@alpha)
    identifiers = RecordingStudioMetrics.discover(context: root, api: :admin).map { |row| row[:identifier] }

    assert_includes identifiers, "members.total"
    refute_includes identifiers, "members.site_total"
    assert_empty RecordingStudioMetrics.discover(api: :admin)

    site = RecordingStudioMetrics::Context.new(actor: @actor, scope: :site, site_authorized: true, timezone: "UTC")
    site_ids = RecordingStudioMetrics.discover(context: site, api: :admin).map { |row| row[:identifier] }
    assert_includes site_ids, "members.site_total"
  end

  test "cache keys never share results across workspaces" do
    store = ActiveSupport::Cache::MemoryStore.new
    RecordingStudioMetrics.configuration.cache_store = store

    alpha = RecordingStudioMetrics.execute("projects.storage_used", context: root_context(@alpha))
    beta = RecordingStudioMetrics.execute("projects.storage_used", context: root_context(@beta))
    alpha_again = RecordingStudioMetrics.execute("projects.storage_used", context: root_context(@alpha))

    assert_equal 150, alpha.value
    assert_equal 999, beta.value
    assert_equal 150, alpha_again.value
  ensure
    RecordingStudioMetrics.configuration.cache_store = nil
  end

  test "database errors become calculation errors" do
    RecordingStudioMetrics.register(:broken, model: Member) do
      count :total, scope: ->(relation) { relation.where("not_a_column = 1") }
    end

    assert_raises(RecordingStudioMetrics::Errors::CalculationError) do
      RecordingStudioMetrics.execute("broken.total", context: root_context(@alpha), cache: false)
    end
  ensure
    DummyMetricsCatalog.load!
  end

  test "admin widget is a real Admin widget and analytics screen is registered" do
    assert defined?(RecordingStudioAdmin::Widget)
    assert_equal "2.0.2", RecordingStudioAdmin::VERSION

    widget = RecordingStudioMetrics::Admin.widget("members.total", workspace_id: @alpha.id, blast_radius: :root)
    assert_instance_of RecordingStudioAdmin::Widget, widget

    resolved = widget.resolve(root_context(@alpha))
    assert_equal 3, resolved.value

    screen = RecordingStudioAdmin.screen_for("metrics_analytics")
    assert_equal MetricsAnalyticsScreen, screen
    assert_equal %i[status], screen.filters.map { |filter| filter.key.to_sym }
    assert_includes screen.widget_keys, "metrics.members.total"
  end

  test "admin execute uses chosen screen filter values" do
    admin_context = RecordingStudioAdmin::Context.new(
      current_actor: @actor,
      filter_values: { status: "active" }
    )

    result = RecordingStudioMetrics::Admin.execute(
      "members.registrations",
      admin_context: admin_context,
      workspace_id: @alpha.id,
      interval: :month,
      start_at: Time.utc(2026, 7, 1),
      end_at: Time.utc(2026, 10, 1)
    )
    assert_equal 2, result.data.sum { |row| row[:value] }
  end

  test "api site metric with api_authorize true counts every row" do
    RecordingStudioMetrics.register(
      :site_members,
      model: Member,
      blast_radius: :site,
      api_authorize: ->(_context) { true }
    ) do
      count :total, expose: { api: [:admin] }
    end

    payload = RecordingStudioMetrics::Api::ExecuteHandler.call(api_context(resource: "site_members", name: "total"))
    assert_equal Member.count, payload[:value]
  ensure
    DummyMetricsCatalog.load!
  end

  test "api site metric with api_authorize false is forbidden" do
    RecordingStudioMetrics.register(
      :site_members,
      model: Member,
      blast_radius: :site,
      api_authorize: ->(_context) { false }
    ) do
      count :total, expose: { api: [:admin] }
    end

    assert_raises(RecordingStudioApi::AuthorizationError) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(api_context(resource: "site_members", name: "total"))
    end
  ensure
    DummyMetricsCatalog.load!
  end

  test "api site metric without api_authorize stays denied" do
    assert_raises(RecordingStudioApi::AuthorizationError) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(api_context(resource: "members", name: "site_total"))
    end
  end

  test "api root metrics stay workspace scoped when a site hook exists on another resource" do
    RecordingStudioMetrics.register(
      :site_members,
      model: Member,
      blast_radius: :site,
      api_authorize: ->(_context) { true }
    ) do
      count :total, expose: { api: [:admin] }
    end

    payload = RecordingStudioMetrics::Api::ExecuteHandler.call(api_context(resource: "members", name: "total"))
    assert_equal 3, payload[:value]

    discovered = RecordingStudioMetrics::Api::DiscoveryHandler.call(
      api_context(resource: "members", name: "total")
    )
    identifiers = discovered[:metrics].map { |row| row[:identifier] }
    assert_includes identifiers, "members.total"
    assert_includes identifiers, "site_members.total"
    refute_includes identifiers, "members.site_total"
  ensure
    DummyMetricsCatalog.load!
  end

  test "api discovery hides site metrics the api_authorize hook denies" do
    RecordingStudioMetrics.register(
      :site_members,
      model: Member,
      blast_radius: :site,
      api_authorize: ->(_context) { false }
    ) do
      count :total, expose: { api: [:admin] }
    end

    discovered = RecordingStudioMetrics::Api::DiscoveryHandler.call(
      api_context(resource: "site_members", name: "total")
    )
    identifiers = discovered[:metrics].map { |row| row[:identifier] }
    refute_includes identifiers, "site_members.total"
    assert_includes identifiers, "members.total"
  ensure
    DummyMetricsCatalog.load!
  end

  test "api handlers map errors to rs_api statuses" do
    assert defined?(RecordingStudioApi::NotFoundError)
    assert_equal "0.6.7", RecordingStudioApi::VERSION

    context = api_context(resource: "missing", name: "total")
    assert_raises(RecordingStudioApi::NotFoundError) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(context)
    end

    unauthorized = api_context(resource: "projects", name: "storage_used")
    assert_raises(RecordingStudioApi::AuthorizationError) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(unauthorized)
    end

    invalid = api_context(resource: "members", name: "total", filters: { injected: 1 })
    assert_raises(RecordingStudioApi::InvalidActionInputError) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(invalid)
    end
  end

  test "max timeseries buckets are enforced during execute" do
    previous = RecordingStudioMetrics.configuration.max_timeseries_buckets
    RecordingStudioMetrics.configuration.max_timeseries_buckets = 2

    assert_raises(RecordingStudioMetrics::Errors::InvalidDateRange) do
      RecordingStudioMetrics.execute(
        "members.registrations",
        context: root_context(@alpha),
        interval: :month,
        start_at: Time.utc(2026, 7, 1),
        end_at: Time.utc(2026, 10, 1)
      )
    end
  ensure
    RecordingStudioMetrics.configuration.max_timeseries_buckets = previous
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

  def api_context(resource:, name:, filters: nil)
    grant = Struct.new(:actor).new(@actor)
    params = { resource: resource, name: name }
    params[:filters] = filters if filters
    root = Struct.new(:id, :recordable_id).new("root-1", @alpha.id)
    Struct.new(:api_client, :credential, :access_recording, :access_grant, :root_recording, :params,
               keyword_init: true) do
      def api_key
        "admin"
      end
    end.new(
      api_client: @actor,
      credential: nil,
      access_recording: nil,
      access_grant: grant,
      root_recording: root,
      params: params
    )
  end
end
