# frozen_string_literal: true

module RecordingStudioMetrics
  module Calculators
    class Breakdown < Base
      def call
        field = definition.field
        raise Errors::InvalidFilter, "breakdown field is required" if field.nil?

        counts = filtered_relation.group(field).distinct.count
        data = counts.map { |key, value| { key: key, value: value } }.sort_by { |row| row[:key].to_s }
        result(data: data)
      end
    end
  end
end
