# frozen_string_literal: true

module RecordingStudioMetrics
  module Calculators
    class Sum < Base
      def call
        result(value: numeric_or_zero(filtered_relation.sum(definition.field)))
      end
    end
  end
end
