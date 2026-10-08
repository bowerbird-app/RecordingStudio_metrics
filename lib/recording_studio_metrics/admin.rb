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

    def widget(identifier, type: :number, **options)
      raise LoadError, "RecordingStudioAdmin is not available" unless defined?(RecordingStudioAdmin::Widget)

      definition = RecordingStudioMetrics.registry.fetch(identifier)
      RecordingStudioAdmin::Widget.new(options.delete(:key) || "metrics.#{identifier}", **options) do
        type type
        title options[:title] || definition.title || definition.name.to_s.humanize
        if type.to_sym == :chart
          chart_type options[:chart_type] || definition.preferred_chart || :line
          series lambda { |admin_context|
            RecordingStudioMetrics::Admin.chart_series(identifier, admin_context: admin_context)
          }
        else
          value lambda { |admin_context|
            RecordingStudioMetrics::Admin.scalar_value(identifier, admin_context: admin_context)
          }
        end
      end
    end

    def context_from_admin(admin_context, **params)
      return admin_context if admin_context.is_a?(Context)

      scope = params[:scope] || admin_context.try(:blast_radius) || :root
      Context.new(
        actor: admin_context.try(:actor) || admin_context.try(:user),
        system: params[:system] || false,
        scope: scope,
        access_recording: admin_context.try(:recording) || admin_context.try(:access_recording),
        root_recording: admin_context.try(:root_recording),
        timezone: params[:timezone] || admin_context.try(:timezone),
        workspace_id: params[:workspace_id],
        authorized_relation: params[:authorized_relation],
        site_authorized: params.fetch(:site_authorized, scope.to_sym == :site)
      )
    end
  end
end
