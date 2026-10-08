# frozen_string_literal: true

module RecordingStudioMetrics
  module Calculators
    class Base
      def self.for(definition)
        case definition.metric_type
        when :count then Count
        when :sum then Sum
        when :average then Average
        when :breakdown then Breakdown
        when :timeseries then Timeseries
        when :custom then Custom
        else
          raise Errors::CalculationError, "Unsupported metric type #{definition.metric_type}"
        end
      end

      def initialize(definition, relation, context, params)
        @definition = definition
        @relation = relation
        @context = context
        @params = params
      end

      def call
        raise NotImplementedError
      end

      private

      attr_reader :definition, :relation, :context, :params

      def filtered_relation
        @filtered_relation ||= apply_filters(relation)
      end

      def apply_filters(current)
        requested = stringify_keys(params[:filters] || {})
        unknown = requested.keys.map(&:to_sym) - definition.filters.map(&:name)
        raise Errors::InvalidFilter, "Unknown filters: #{unknown.join(', ')}" if unknown.any?

        definition.filters.reduce(current) do |rel, filter|
          raw = requested.key?(filter.name.to_s) ? requested[filter.name.to_s] : filter.default
          next rel if raw.nil? && filter.default.nil?

          filter.apply(rel, raw, context)
        end
      end

      def stringify_keys(hash)
        hash.each_with_object({}) { |(key, value), memo| memo[key.to_s] = value }
      end

      def numeric_or_zero(value)
        value.nil? ? 0 : value
      end

      def result(value: nil, data: nil, extra: {})
        Result.new(
          metric: definition.identifier,
          type: definition.result_type,
          value: value,
          data: data,
          unit: definition.unit,
          title: definition.title || definition.name.to_s.humanize,
          description: definition.description,
          filters: params[:filters] || {},
          timezone: context.timezone,
          period: extra[:period],
          interval: extra[:interval],
          calculated_at: Time.current,
          metadata: extra.except(:period, :interval)
        )
      end
    end
  end
end
