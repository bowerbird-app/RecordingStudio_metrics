# frozen_string_literal: true

module RecordingStudioMetrics
  module Calculators
    class Count < Scalar
      private

      def aggregate(scope)
        scope.distinct.count
      end

      def coerce(value)
        value
      end
    end
  end
end
