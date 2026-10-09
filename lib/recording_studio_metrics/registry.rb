# frozen_string_literal: true

module RecordingStudioMetrics
  class Registry
    def initialize
      @metrics = {}
      @resources = {}
      @mutex = Mutex.new
    end

    def register(resource, model:, **, &block)
      raise ArgumentError, "a registration block is required" unless block

      dsl = DSL.new(resource, model: model, **)
      dsl.instance_eval(&block)
      store(resource, dsl)
      dsl.metrics
    end

    def find(identifier)
      @metrics[identifier.to_s]
    end

    def fetch(identifier)
      find(identifier) || raise(Errors::UnknownMetric, "Unknown metric #{identifier}")
    end

    def all
      @metrics.values
    end

    def for_resource(resource)
      @metrics.values.select { |definition| definition.resource == resource.to_sym }
    end

    def api_authorize_for(resource)
      @resources.dig(resource.to_sym, :api_authorize)
    end

    def reset!
      @mutex.synchronize do
        @metrics = {}
        @resources = {}
      end
    end

    private

    def store(resource, dsl)
      @mutex.synchronize do
        key = resource.to_sym
        replacing = @resources.key?(key) && reloading?
        if @resources.key?(key) && !replacing
          raise Errors::DuplicateRegistration,
                "Resource #{key} is already registered"
        end

        @metrics.reject! { |_identifier, definition| definition.resource == key } if replacing

        dsl.metrics.each do |definition|
          if @metrics.key?(definition.identifier)
            raise Errors::DuplicateRegistration, "Metric #{definition.identifier} is already registered"
          end

          @metrics[definition.identifier] = definition
        end
        @resources[key] = {
          model: dsl.instance_variable_get(:@model),
          scope: dsl.resource_scope,
          scope_attribute: dsl.scope_attribute,
          api_authorize: dsl.api_authorize
        }
      end
    end

    def reloading?
      defined?(Rails) && Rails.respond_to?(:application) && Rails.application &&
        Rails.application.config.respond_to?(:cache_classes) &&
        Rails.application.config.cache_classes == false
    end
  end
end
