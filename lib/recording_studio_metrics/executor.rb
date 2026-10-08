# frozen_string_literal: true

module RecordingStudioMetrics
  class Executor
    def self.call(identifier, context:, **params)
      new(identifier, context: context, **params).call
    end

    def initialize(identifier, context:, interval: nil, start_at: nil, end_at: nil, filters: {}, cache: true)
      @identifier = identifier.to_s
      @context = context
      @params = {
        interval: interval,
        start_at: start_at,
        end_at: end_at,
        filters: filters || {}
      }
      @use_cache = cache
    end

    def call
      definition = RecordingStudioMetrics.registry.fetch(@identifier)
      relation = Authorization.base_relation(definition, @context)
      compute = lambda do
        Calculators::Base.for(definition).new(definition, relation, @context, @params).call
      end

      if @use_cache
        Cache.fetch(definition, @context, @params, &compute)
      else
        compute.call
      end
    end
  end
end
