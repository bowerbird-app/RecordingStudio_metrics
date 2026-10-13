# frozen_string_literal: true

module RecordingStudioMetrics
  module Calculators
    class Sum < Scalar
      private

      def aggregate(scope)
        scope.sum(definition.field)
      end

      def coerce(value)
        numeric_or_zero(value)
      end
    end
  end
end
