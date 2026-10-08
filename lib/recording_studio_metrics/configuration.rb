# frozen_string_literal: true

require "active_support/core_ext/numeric/time"

module RecordingStudioMetrics
  class Configuration
    attr_accessor :default_timezone,
                  :max_timeseries_buckets,
                  :max_reporting_period,
                  :cache_enabled,
                  :default_cache_ttl,
                  :cache_store
    attr_reader :hooks, :api_exposures

    def initialize
      @default_timezone = "UTC"
      @max_timeseries_buckets = 400
      @max_reporting_period = 366.days
      @cache_enabled = true
      @default_cache_ttl = 5.minutes
      @cache_store = nil
      @hooks = RecordingStudio::Hooks.new
      @api_exposures = Hash.new { |hash, key| hash[key] = Set.new }
    end

    def expose_to_api(identifier, api: :public)
      @api_exposures[api.to_sym] << identifier.to_s
    end

    def exposed_to_api?(identifier, api:)
      @api_exposures[api.to_sym].include?(identifier.to_s)
    end

    def to_h
      {
        default_timezone: default_timezone,
        max_timeseries_buckets: max_timeseries_buckets,
        max_reporting_period: max_reporting_period,
        cache_enabled: cache_enabled,
        default_cache_ttl: default_cache_ttl,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
    end
  end
end
