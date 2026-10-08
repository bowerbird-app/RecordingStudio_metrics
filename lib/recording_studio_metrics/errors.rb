# frozen_string_literal: true

module RecordingStudioMetrics
  module Errors
    class Error < StandardError
      def error_code
        self.class.name.split("::").last.underscore
      end

      def as_json(*)
        { error: { code: error_code, message: public_message } }
      end

      def public_message
        message
      end
    end

    class UnknownMetric < Error
      def public_message
        "Metric not found"
      end
    end

    class DuplicateRegistration < Error; end
    class InvalidFilter < Error; end
    class UnsupportedInterval < Error; end
    class InvalidDateRange < Error; end
    class MissingContext < Error; end

    class AuthorizationError < Error
      def public_message
        "Not authorized to run this metric"
      end
    end

    class InvalidCustomResult < Error; end

    class CalculationError < Error
      def public_message
        "Metric calculation failed"
      end
    end
  end
end
