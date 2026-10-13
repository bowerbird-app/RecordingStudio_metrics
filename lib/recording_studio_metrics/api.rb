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
        description: "Inclusive period start (ISO-8601). Aliases: start_at, from.",
        schema: { type: "string", format: "date-time" }
      },
      {
        name: "from",
        in: "query",
        required: false,
        description: "Alias for start. Must match start when both are provided.",
        schema: { type: "string", format: "date-time" }
      },
      {
        name: "end",
        in: "query",
        required: false,
        description: "Exclusive period end (ISO-8601). Aliases: end_at, to.",
        schema: { type: "string", format: "date-time" }
      },
      {
        name: "to",
        in: "query",
        required: false,
        description: "Alias for end. Must match end when both are provided.",
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
          description: "Each entry includes unit, group_by, supported_intervals, date_range, timezone, and freshness.",
          tags: ["Metrics"],
          parameters: DiscoveryHandler::OPENAPI_PARAMETERS
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

    def context_from_api(api_context, definition:, **overrides)
      hook = RecordingStudioMetrics.registry.api_authorize_for(definition.resource)
      if hook
        return unless hook.call(api_context)

        overrides = overrides.merge(scope: :site, site_authorized: true) if definition.blast_radius == :site
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
      FILTERS = %w[resource].freeze

      OPENAPI_PARAMETERS = [
        {
          name: "filters",
          in: "query",
          required: false,
          description: "Catalog filters. Supported: resource (filters[resource]=users). Unknown names are rejected.",
          schema: {
            type: "object",
            properties: { resource: { type: "string" } },
            additionalProperties: false
          }
        }
      ].freeze

      def self.call(api_context)
        api = api_context.api_key
        metrics = []
        resource_filter = requested_resource(api_context.params)
        definitions = if resource_filter
                        RecordingStudioMetrics.for_resource(resource_filter)
                      else
                        RecordingStudioMetrics.definitions
                      end

        definitions.group_by(&:resource).each do |resource, resource_definitions|
          exposed = resource_definitions.select { |definition| definition.exposed_to_api?(api) }
          next if exposed.empty?

          context = Api.context_from_api(api_context, definition: exposed.first)
          next unless context

          metrics.concat(
            RecordingStudioMetrics.discover(context: context, api: api, resource: resource)
          )
        end

        { metrics: metrics }
      rescue Errors::Error => e
        Api.raise_mapped!(e)
      end

      # Catalog filters use the same `filters` object as metric execution.
      # Returns the requested resource name, or nil when unfiltered.
      def self.requested_resource(params)
        raw = params[:filters] || {}
        raise Errors::InvalidFilter, "filters must be an object" unless raw.respond_to?(:each_pair)

        filters = raw.each_pair.to_h { |key, value| [key.to_s, value] }
        unknown = filters.keys - FILTERS
        raise Errors::InvalidFilter, "Unknown filters: #{unknown.join(', ')}" if unknown.any?

        filters["resource"].presence&.to_s
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

        context = Api.context_from_api(api_context, definition: definition, timezone: api_context.params[:timezone])
        raise Errors::AuthorizationError, "metric is not authorized on this API" unless context

        result = RecordingStudioMetrics.execute(
          identifier,
          context: context,
          interval: api_context.params[:interval],
          start_at: Api.period_bound(api_context.params, primary: :start, alias_key: :from, legacy: :start_at),
          end_at: Api.period_bound(api_context.params, primary: :end, alias_key: :to, legacy: :end_at),
          filters: api_context.params[:filters] || {}
        )
        result.as_json
      rescue Errors::Error => e
        Api.raise_mapped!(e)
      end
    end

    # Resolve start/end query bounds. `from` aliases `start` and `to` aliases `end`.
    # Conflicting primary+alias values raise InvalidDateRange; matching values are accepted.
    # Legacy start_at/end_at remain fallbacks when neither primary nor alias is present.
    def period_bound(params, primary:, alias_key:, legacy:)
      primary_value = params[primary]
      alias_value = params[alias_key]

      if !primary_value.nil? && !alias_value.nil? && primary_value != alias_value
        raise Errors::InvalidDateRange,
              "#{primary} and #{alias_key} must match when both are provided"
      end

      primary_value || alias_value || params[legacy]
    end
  end
end
