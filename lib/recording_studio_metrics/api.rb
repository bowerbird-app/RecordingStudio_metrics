# frozen_string_literal: true

module RecordingStudioMetrics
  module Api
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
          tags: ["Metrics"]
        }
      )
    end

    def metrics_endpoint_name(api, kind)
      :"#{api}_metrics_#{kind}"
    end

    class DiscoveryHandler
      def self.call(api_context)
        context = begin
          Context.from_api(api_context)
        rescue RecordingStudioMetrics::Errors::Error
          nil
        end
        metrics = RecordingStudioMetrics.discover(context: context, api: api_context.api_key)
        { metrics: metrics }
      rescue RecordingStudioMetrics::Errors::Error => e
        e.as_json
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

        context = Context.from_api(api_context, timezone: api_context.params[:timezone])
        result = RecordingStudioMetrics.execute(
          identifier,
          context: context,
          interval: api_context.params[:interval],
          start_at: api_context.params[:start] || api_context.params[:start_at],
          end_at: api_context.params[:end] || api_context.params[:end_at],
          filters: api_context.params[:filters] || {}
        )
        result.as_json
      rescue RecordingStudioMetrics::Errors::Error => e
        e.as_json
      end
    end
  end
end
