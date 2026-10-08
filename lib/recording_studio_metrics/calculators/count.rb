# frozen_string_literal: true

module RecordingStudioMetrics
  module Calculators
    class Count < Base
      def calculate
        result(value: filtered_relation.distinct.count)
      end
    end
  end
end
