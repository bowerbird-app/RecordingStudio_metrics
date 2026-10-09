# frozen_string_literal: true

module RecordingStudioMetrics
  module Api
    EXECUTE_OPENAPI_PARAMETERS = [
      {
        name: "filters",
        in: "query",
        required: false,
        description: "Declared metric filters only. Unknown names are rejected.",
        schema: { type: "object", additionalProperties: true }
      },
      {
        name: "interval",
        in: "query",
        required: false,
        description: "Time-series bucket size.",
        schema: { type: "string", enum: %w[hour day week month year] }
      },
      {
        name: "start",
        in: "query",
        required: false,
        description: "Inclusive period start (ISO-8601). Alias: start_at.",
        schema: { type: "string", format: "date-time" }
      },
      {
        name: "end",
        in: "query",
        required: false,
        description: "Exclusive period end (ISO-8601). Alias: end_at.",
        schema: { type: "string", format: "date-time" }
      },
      {
        name: "timezone",
        in: "query",
        required: false,
        description: "IANA timezone used for bucket boundaries.",
        schema: { type: "string" }
      }
    ].freeze

    module_function

    def register!(api: :public, prefix: "metrics")
      unless defined?(RecordingStudioApi) && RecordingStudioApi.respond_to?(:register_endpoint)
        raise LoadError, "RecordingStudioApi is not available"
      end

      RecordingStudioApi.register_endpoint(
        metrics_endpoint_name(api, :index),
        api: api,
        http_verb: :get,
        path: prefix,
        handler: DiscoveryHandler,
        openapi: {
          summary: "List metrics available to the caller",
          tags: ["Metrics"]
        }
      )

      RecordingStudioApi.register_endpoint(
        metrics_endpoint_name(api, :show),
        api: api,
        http_verb: :get,
        path: "#{prefix}/:resource/:name",
        handler: ExecuteHandler,
        openapi: {
          summary: "Execute a registered metric",
          tags: ["Metrics"],
          parameters: EXECUTE_OPENAPI_PARAMETERS
        }
      )
    end

    def metrics_endpoint_name(api, kind)
      :"#{api}_metrics_#{kind}"
    end

    def raise_mapped!(error)
      raise map_to_api_error(error)
    end

    def api_authorize_allows?(resource, api_context)
      hook = RecordingStudioMetrics.registry.api_authorize_for(resource)
      return true unless hook

      hook.call(api_context)
    end

    def context_from_api(api_context, definition: nil, **overrides)
      if definition &&
         definition.blast_radius == :site &&
         RecordingStudioMetrics.registry.api_authorize_for(definition.resource)
        overrides[:scope] = :site
        overrides[:site_authorized] = true
      end

      Context.from_api(api_context, **overrides)
    end

    def map_to_api_error(error)
      return error unless defined?(RecordingStudioApi)

      case error
      when Errors::UnknownMetric
        RecordingStudioApi::NotFoundError.new(error.public_message)
      when Errors::AuthorizationError, Errors::MissingContext
        RecordingStudioApi::AuthorizationError.new(error.public_message)
      else
        RecordingStudioApi::InvalidActionInputError.new(error.public_message)
      end
    end

    class DiscoveryHandler
      def self.call(api_context)
        context = Context.from_api(api_context)
        api = api_context.api_key
        metrics = RecordingStudioMetrics.discover(context: context, api: api).select do |metadata|
          Api.api_authorize_allows?(metadata[:resource], api_context)
        end

        hook_allowed_site_resources = RecordingStudioMetrics.definitions.filter_map do |definition|
          next unless definition.blast_radius == :site
          next unless RecordingStudioMetrics.registry.api_authorize_for(definition.resource)
          next unless Api.api_authorize_allows?(definition.resource, api_context)

          definition.resource
        end.uniq

        if hook_allowed_site_resources.any?
          site_context = Context.from_api(api_context, scope: :site, site_authorized: true)
          RecordingStudioMetrics.discover(context: site_context, api: api).each do |metadata|
            next unless hook_allowed_site_resources.include?(metadata[:resource])
            next if metrics.any? { |row| row[:identifier] == metadata[:identifier] }

            metrics << metadata
          end
        end

        { metrics: metrics }
      rescue Errors::Error => e
        Api.raise_mapped!(e)
      end
    end

    class ExecuteHandler
      def self.call(api_context)
        identifier = "#{api_context.params[:resource]}.#{api_context.params[:name]}"
        definition = RecordingStudioMetrics.find(identifier)
        raise Errors::UnknownMetric, identifier unless definition
        unless definition.exposed_to_api?(api_context.api_key)
          raise Errors::AuthorizationError, "metric is not exposed on this API"
        end
        unless Api.api_authorize_allows?(definition.resource, api_context)
          raise Errors::AuthorizationError, "metric is not authorized on this API"
        end

        context = Api.context_from_api(api_context, definition: definition, timezone: api_context.params[:timezone])
        result = RecordingStudioMetrics.execute(
          identifier,
          context: context,
          interval: api_context.params[:interval],
          start_at: api_context.params[:start] || api_context.params[:start_at],
          end_at: api_context.params[:end] || api_context.params[:end_at],
          filters: api_context.params[:filters] || {}
        )
        result.as_json
      rescue Errors::Error => e
        Api.raise_mapped!(e)
      end
    end
  end
end
