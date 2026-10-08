# frozen_string_literal: true

RecordingStudioMetrics.configure do |config|
  config.default_timezone = "UTC"
  config.max_timeseries_buckets = 400
  config.cache_enabled = true
end

Rails.application.config.to_prepare do
  RecordingStudioMetrics.registry.reset!

  RecordingStudioMetrics.register(
    :members,
    model: Member,
    scope_attribute: :workspace_id,
    blast_radius: :root
  ) do
    count :total, title: "Total members", expose: { api: [:admin] }

    count :active,
          title: "Active members",
          scope: ->(relation) { relation.where(status: "active") }

    count :site_total,
          title: "Members (site)",
          blast_radius: :site,
          expose: { api: [:admin] }

    timeseries :registrations,
               field: :created_at,
               intervals: %i[hour day week month year],
               default_interval: :month,
               preferred_chart: :line,
               title: "Member registrations" do
      filter :status, field: :status, type: :enum, options: %w[active invited suspended]
      filter :verified, field: :verified, type: :boolean
      filter :country, field: :country, type: :string
      filter :created_at, field: :created_at, type: :date_range
      filter :age, field: :age, type: :numeric_range
      filter :country_prefix, type: :string, handler: lambda { |relation, value, _context|
        relation.where("country LIKE ?", "#{ActiveRecord::Base.sanitize_sql_like(value)}%")
      }
    end

    timeseries :headcount,
               field: :created_at,
               intervals: %i[day week month year],
               default_interval: :month,
               semantics: "population_at_end_of_period",
               title: "Member headcount"

    breakdown :by_country, field: :country, title: "Members by country"
  end

  RecordingStudioMetrics.register(
    :projects,
    model: Project,
    scope_attribute: :workspace_id,
    blast_radius: :root
  ) do
    count :total, title: "Total projects"
    sum :storage_used, field: :storage_bytes, title: "Storage used", unit: "bytes"
    average :storage, field: :storage_bytes, title: "Average project storage"

    breakdown :storage_by_completed,
              field: :completed,
              measurement: :sum,
              value_field: :storage_bytes,
              title: "Storage by completion"

    breakdown :average_storage_by_completed,
              field: :completed,
              measurement: :average,
              value_field: :storage_bytes,
              title: "Average storage by completion"

    timeseries :storage,
               field: :created_at,
               measurement: :sum,
               value_field: :storage_bytes,
               intervals: %i[day week month year],
               default_interval: :month,
               title: "Storage added"

    timeseries :average_storage,
               field: :created_at,
               measurement: :average,
               value_field: :storage_bytes,
               intervals: %i[day week month year],
               default_interval: :month,
               title: "Average storage added"

    custom :with_images, result_type: :scalar, title: "Projects with images" do |relation, _context|
      relation.where(id: ProjectImage.select(:project_id)).distinct.count
    end

    custom :average_images, result_type: :scalar, title: "Average images per project" do |relation, _context|
      parent_count = relation.distinct.count
      next 0 if parent_count.zero?

      image_count = ProjectImage.where(project_id: relation.select(:id)).count
      image_count.to_f / parent_count
    end

    custom :complete, result_type: :scalar, title: "Completed projects with images" do |relation, _context|
      relation.where(completed: true).where(id: ProjectImage.select(:project_id)).distinct.count
    end
  end

  RecordingStudioMetrics.register(
    :folders,
    model: Folder,
    blast_radius: :root
  ) do
    count :total, title: "Folders in workspace"
  end

  RecordingStudioMetrics.expose_to_api("members.total", api: :admin)
  RecordingStudioMetrics.expose_to_api("members.registrations", api: :admin)
  RecordingStudioMetrics.expose_to_api("projects.total", api: :admin)
  RecordingStudioMetrics.expose_to_api("projects.with_images", api: :admin)

  if defined?(RecordingStudioAdmin::Widget)
    RecordingStudioMetrics::Admin.attach_filters(MetricsAnalyticsScreen, "members.registrations")
    RecordingStudioAdmin.register_widget(
      RecordingStudioMetrics::Admin.widget("members.total", blast_radius: :root)
    )
    RecordingStudioAdmin.register_widget(
      RecordingStudioMetrics::Admin.widget(
        "members.registrations",
        type: :chart,
        blast_radius: :root,
        interval: :month
      )
    )
    RecordingStudioAdmin.register_screen(MetricsAnalyticsScreen)
  end
end
