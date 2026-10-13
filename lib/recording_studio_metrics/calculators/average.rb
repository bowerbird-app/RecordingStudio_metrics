# frozen_string_literal: true

module RecordingStudioMetrics
  module Calculators
    class Average < Scalar
      private

      def aggregate(scope)
        scope.average(definition.field)
      end

      def coerce(value)
        value&.to_f
      end
    end
  end
end
