# frozen_string_literal: true

require "digest"
require "json"

module RecordingStudioMetrics
  module Cache
    module_function

    def fetch(definition, context, params)
      return yield unless cacheable?(definition)

      ttl = definition.cache_for || RecordingStudioMetrics.configuration.default_cache_ttl
      vary = cache_vary(definition, context, params)

      if recording_cache_available?(context)
        recording = context.access_recording || context.root_recording
        RecordingStudioCache.fetch(
          recording,
          "metrics:#{definition.identifier}",
          vary: vary,
          expires_in: ttl
        ) { yield }
      else
        rails_or_memory_fetch(definition, vary, ttl) { yield }
      end
    end

    def cacheable?(definition)
      return false unless RecordingStudioMetrics.configuration.cache_enabled
      return false if definition.cacheable == false
      return false if definition.cache_for == false

      true
    end

    def cache_vary(definition, context, params)
      {
        metric: definition.identifier,
        version: definition.version,
        scope: context.scope_key,
        filters: params[:filters] || {},
        start_at: params[:start_at],
        end_at: params[:end_at],
        interval: params[:interval],
        timezone: context.timezone
      }
    end

    def recording_cache_available?(context)
      defined?(RecordingStudioCache) &&
        !!(context.access_recording || context.root_recording)&.respond_to?(:root_recording_id)
    end

    def rails_or_memory_fetch(definition, vary, ttl)
      key = "recording_studio_metrics/#{definition.identifier}/#{vary_digest(vary)}"
      store = RecordingStudioMetrics.configuration.cache_store
      store ||= defined?(Rails) && Rails.respond_to?(:cache) && Rails.cache
      return yield unless store

      store.fetch(key, expires_in: ttl) { yield }
    end

    def vary_digest(vary)
      Digest::SHA256.hexdigest(JSON.generate(vary.as_json))[0, 16]
    end
  end
end
