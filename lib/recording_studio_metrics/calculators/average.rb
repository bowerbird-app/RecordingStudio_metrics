# frozen_string_literal: true

module RecordingStudioMetrics
  module Calculators
    class Average < Base
      def call
        value = filtered_relation.average(definition.field)
        result(value: value&.to_f)
      end
    end
  end
end
