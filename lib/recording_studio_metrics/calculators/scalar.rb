# frozen_string_literal: true

module RecordingStudioMetrics
  module Calculators
    # Shared scalar flow for count, sum, and average, with optional group_by.
    class Scalar < Base
      def calculate
        value = coerce(aggregate(filtered_relation))
        return result(value: value) unless group_field

        result(value: value, grouping: grouped_values)
      end

      private

      def grouped_values
        grouped = filtered_relation.group(group_field)
        counts = grouped.distinct.count
        values = aggregate(grouped)
        kept, small = split_groups(counts)
        groups = kept.map { |key| { key: key, value: coerce(values[key]) } }
        grouping(groups, merged_value(values, counts, small))
      end

      def merged_value(values, counts, keys)
        return if keys.empty?

        { groups: keys.size, value: coerce(merge_values(values, counts, keys)) }
      end
    end
  end
end
