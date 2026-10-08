# frozen_string_literal: true

module RecordingStudioMetrics
  module Calculators
    class Breakdown < Base
      def calculate
        field = definition.field
        raise Errors::InvalidFilter, "breakdown field is required" if field.nil?

        grouped = filtered_relation.group(field)
        values = aggregate_values(grouped)
        data = values.map { |key, value| { key: key, value: coerce(value) } }.sort_by { |row| row[:key].to_s }
        result(data: data)
      end

      private

      def aggregate_values(grouped)
        case definition.measurement
        when :sum
          grouped.sum(numeric_field)
        when :average
          grouped.average(numeric_field)
        else
          grouped.distinct.count
        end
      end

      def numeric_field
        definition.value_field || definition.field
      end

      def coerce(value)
        return value&.to_f if definition.measurement == :average

        numeric_or_zero(value)
      end
    end
  end
end
