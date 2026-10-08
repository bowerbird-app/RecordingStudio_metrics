# frozen_string_literal: true

require "recording_studio"
require "recording_studio_metrics/version"
require "recording_studio_metrics/errors"
require "recording_studio_metrics/configuration"
require "recording_studio_metrics/engine"
require "recording_studio_metrics/filter"
require "recording_studio_metrics/definition"
require "recording_studio_metrics/dsl"
require "recording_studio_metrics/registry"
require "recording_studio_metrics/context"
require "recording_studio_metrics/result"
require "recording_studio_metrics/authorization"
require "recording_studio_metrics/time_window"
require "recording_studio_metrics/adapters/postgresql"
require "recording_studio_metrics/calculators/base"
require "recording_studio_metrics/calculators/count"
require "recording_studio_metrics/calculators/sum"
require "recording_studio_metrics/calculators/average"
require "recording_studio_metrics/calculators/breakdown"
require "recording_studio_metrics/calculators/timeseries"
require "recording_studio_metrics/calculators/custom"
require "recording_studio_metrics/cache"
require "recording_studio_metrics/executor"
require "recording_studio_metrics/api"
require "recording_studio_metrics/admin"

module RecordingStudioMetrics
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def registry
      @registry ||= Registry.new
    end

    def register(resource, **, &)
      registry.register(resource, **, &)
    end

    def execute(identifier, context:, **params)
      Executor.call(identifier, context: context, **params)
    end

    def definitions
      registry.all
    end

    def find(identifier)
      registry.find(identifier)
    end

    def for_resource(resource)
      registry.for_resource(resource)
    end

    def discover(context: nil, api: nil)
      return [] if context.nil?

      catalog = definitions
      catalog = catalog.select { |definition| definition.exposed_to_api?(api) } if api
      catalog.select { |definition| Authorization.discoverable?(definition, context) }.map(&:metadata)
    end

    def expose_to_api(identifier, api: :public)
      configuration.expose_to_api(identifier, api: api)
    end
  end
end
