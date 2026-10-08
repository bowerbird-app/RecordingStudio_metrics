# frozen_string_literal: true

require "digest"
require "json"

module RecordingStudioMetrics
  class Definition
    RESULT_TYPES = %i[scalar timeseries breakdown].freeze
    MEASUREMENTS = %i[count sum average custom].freeze
    BLAST_RADII = %i[recording root site].freeze
    INTERVALS = %i[hour day week month year].freeze

    attr_reader :resource,
                :name,
                :model,
                :metric_type,
                :result_type,
                :field,
                :unit,
                :title,
                :description,
                :intervals,
                :default_interval,
                :preferred_chart,
                :filters,
                :scope,
                :scope_attribute,
                :calculator,
                :blast_radius,
                :cache_for,
                :cacheable,
                :exposed_apis,
                :source_location,
                :measurement,
                :grouping,
                :semantics,
                :value_field,
                :cumulative

    def initialize(**attrs)
      attrs.each { |key, value| instance_variable_set("@#{key}", value) }
      @name = name.to_sym
      @resource = resource.to_sym
      @metric_type = metric_type.to_sym
      @result_type = (result_type || inferred_result_type).to_sym
      @intervals = Array(intervals).map(&:to_sym)
      @filters = Array(filters)
      @blast_radius = (blast_radius || :root).to_sym
      @cacheable = true if cacheable.nil?
      @exposed_apis = Array(exposed_apis).map(&:to_sym)
      @measurement = (measurement || inferred_measurement).to_sym
      @grouping = grouping&.to_sym
      @unit ||= default_unit
      validate!
    end

    def identifier
      "#{resource}.#{name}"
    end

    def version
      Digest::SHA256.hexdigest(JSON.generate(metadata))[0, 12]
    end

    def exposed_to_api?(api)
      return false if api.nil?

      exposed_apis.include?(api.to_sym) ||
        RecordingStudioMetrics.configuration.exposed_to_api?(identifier, api: api)
    end

    def supports_interval?(interval)
      intervals.include?(interval.to_sym)
    end

    def filter_for(filter_name)
      filters.find { |filter| filter.name == filter_name.to_sym }
    end

    def metadata
      {
        identifier: identifier,
        resource: resource,
        name: name,
        title: title || name.to_s.humanize,
        description: description,
        result_type: result_type,
        metric_type: metric_type,
        measurement: measurement,
        grouping: grouping,
        unit: unit,
        field: field,
        supported_intervals: intervals,
        default_interval: default_interval,
        preferred_chart: preferred_chart,
        filters: filters.map(&:metadata),
        blast_radius: blast_radius,
        cacheable: cacheable,
        cache_for: cache_for,
        exposed_apis: exposed_apis,
        semantics: semantics,
        value_field: value_field,
        cumulative: cumulative
      }.compact
    end

    private

    def inferred_result_type
      case metric_type
      when :timeseries then :timeseries
      when :breakdown then :breakdown
      else :scalar
      end
    end

    def inferred_measurement
      case metric_type
      when :sum then :sum
      when :average then :average
      when :custom then :custom
      else :count
      end
    end

    def default_unit
      measurement == :count ? "count" : nil
    end

    def validate!
      raise ArgumentError, "model is required for #{identifier}" unless model
      raise ArgumentError, "Unsupported result type #{result_type}" unless RESULT_TYPES.include?(result_type)
      raise ArgumentError, "Unsupported blast_radius #{blast_radius}" unless BLAST_RADII.include?(blast_radius)

      unknown_intervals = intervals - INTERVALS
      raise ArgumentError, "Unsupported intervals #{unknown_intervals}" if unknown_intervals.any?

      raise ArgumentError, "#{metric_type} metrics require a field" if field_required? && field.nil?
      return unless numeric_measurement? && value_field.nil?

      raise ArgumentError, "#{metric_type} #{measurement} metrics require a value_field"
    end

    def field_required?
      %i[sum average breakdown timeseries].include?(metric_type)
    end

    def numeric_measurement?
      %i[sum average].include?(measurement) && %i[breakdown timeseries].include?(metric_type)
    end
  end
end
