# frozen_string_literal: true

module RecordingStudioMetrics
  module Calculators
    class Custom < Base
      def calculate
        calculator = definition.calculator
        raise Errors::CalculationError, "custom calculator is missing" unless calculator

        raw = calculator.call(filtered_relation, context)
        normalize(raw)
      rescue Errors::Error
        raise
      rescue StandardError => e
        raise Errors::CalculationError, e.message
      end

      private

      def normalize(raw)
        case definition.result_type
        when :scalar
          value = raw.is_a?(Hash) ? (raw[:value] || raw["value"]) : raw
          unless value.nil? || value.is_a?(Numeric)
            raise Errors::InvalidCustomResult, "scalar custom metrics must return a numeric value"
          end

          result(value: value)
        when :timeseries, :breakdown
          data = raw.is_a?(Hash) ? (raw[:data] || raw["data"]) : raw
          unless data.respond_to?(:map)
            raise Errors::InvalidCustomResult, "#{definition.result_type} custom metrics must return data rows"
          end

          result(data: data)
        else
          raise Errors::InvalidCustomResult, "unsupported custom result type"
        end
      end
    end
  end
end
