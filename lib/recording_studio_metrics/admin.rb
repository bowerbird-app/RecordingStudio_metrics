# frozen_string_literal: true

module RecordingStudioMetrics
  module Admin
    module_function

    def execute(identifier, admin_context:, **params)
      context = context_from_admin(admin_context, **params)
      RecordingStudioMetrics.execute(
        identifier,
        context: context,
        **params.slice(:interval, :start_at, :end_at, :filters, :cache)
      )
    end

    def scalar_value(identifier, admin_context:, **params)
      execute(identifier, admin_context: admin_context, **params).value
    end

    def chart_series(identifier, admin_context:, name: nil, **params)
      result = execute(identifier, admin_context: admin_context, **params)
      series_name = name || result.title
      points = Array(result.data).map { |row| [row[:date] || row["date"], row[:value] || row["value"]] }
      [{ name: series_name, data: points }]
    end

    def summary_value(identifier, **params)
      lambda { |admin_context|
        scalar_value(identifier, admin_context: admin_context, **params)
      }
    end

    def chart_series_proc(identifier, **params)
      lambda { |admin_context|
        chart_series(identifier, admin_context: admin_context, **params)
      }
    end

    def widget(identifier, type: :number, **options)
      raise LoadError, "RecordingStudioAdmin is not available" unless defined?(RecordingStudioAdmin::Widget)

      definition = RecordingStudioMetrics.registry.fetch(identifier)
      build_admin_widget(definition, identifier, type, options)
    end

    def attach_filters(screen_class, identifier)
      definition = RecordingStudioMetrics.registry.fetch(identifier)
      definition.filters.each do |filter|
        screen_class.filter(filter.name, **admin_filter_options(filter))
      end
    end

    def admin_filter_options(filter)
      options = { param: filter.name, label: filter.label }
      options[:values] = filter.options if filter.options.any?
      options
    end

    def context_from_admin(admin_context, **params)
      return admin_context if admin_context.is_a?(Context)

      scope = params[:scope] || admin_context.try(:blast_radius) || :root
      Context.new(
        actor: admin_actor(admin_context),
        system: params[:system] || false,
        scope: scope,
        access_recording: admin_context.try(:access_recording) || admin_context.try(:recording),
        root_recording: admin_context.try(:root_recording),
        timezone: params[:timezone] || admin_context.try(:timezone),
        workspace_id: params[:workspace_id] || admin_workspace_id(admin_context),
        authorized_relation: params[:authorized_relation],
        site_authorized: params.fetch(:site_authorized, false)
      )
    end

    def admin_actor(admin_context)
      admin_context.try(:current_actor) || admin_context.try(:actor) || admin_context.try(:user)
    end

    def admin_workspace_id(admin_context)
      recordable = admin_context.try(:access_recordable)
      recordable.try(:id) if recordable.respond_to?(:id)
    end

    def build_admin_widget(definition, identifier, type, options)
      key = options.delete(:key) || "metrics.#{identifier}"
      blast_radius = options.delete(:blast_radius)
      title_value = options.delete(:title) || definition.title || definition.name.to_s.humanize
      chart_type_value = options.delete(:chart_type) || definition.preferred_chart || :line
      execute_params = options.slice(:interval, :start_at, :end_at, :filters, :scope, :workspace_id, :site_authorized)

      RecordingStudioAdmin::Widget.new(key, blast_radius: blast_radius) do
        type type
        title title_value
        if type.to_sym == :chart
          chart_type chart_type_value
          series lambda { |admin_context|
            RecordingStudioMetrics::Admin.chart_series(identifier, admin_context: admin_context, **execute_params)
          }
        else
          value lambda { |admin_context|
            RecordingStudioMetrics::Admin.scalar_value(identifier, admin_context: admin_context, **execute_params)
          }
        end
      end
    end
  end
end
