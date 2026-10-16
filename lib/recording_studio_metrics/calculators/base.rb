# frozen_string_literal: true

module RecordingStudioMetrics
  module Calculators
    class Base
      def self.for(definition)
        case definition.metric_type
        when :count then Count
        when :sum then Sum
        when :average then Average
        when :breakdown then Breakdown
        when :timeseries then Timeseries
        when :custom then Custom
        else
          raise Errors::CalculationError, "Unsupported metric type #{definition.metric_type}"
        end
      end

      def initialize(definition, relation, context, params)
        @definition = definition
        @relation = relation
        @context = context
        @params = params
      end

      def call
        group_field
        calculate
      rescue Errors::Error
        raise
      rescue ActiveRecord::ActiveRecordError => e
        raise Errors::CalculationError, e.message
      end

      def calculate
        raise NotImplementedError
      end

      private

      attr_reader :definition, :relation, :context, :params

      def filtered_relation
        @filtered_relation ||= apply_filters(relation)
      end

      def apply_filters(current)
        requested = stringify_keys(params[:filters] || {})
        unknown = requested.keys.map(&:to_sym) - definition.filters.map(&:name)
        raise Errors::InvalidFilter, "Unknown filters: #{unknown.join(', ')}" if unknown.any?

        definition.filters.reduce(current) do |rel, filter|
          raw = requested.key?(filter.name.to_s) ? requested[filter.name.to_s] : filter.default
          next rel if raw.nil? && filter.default.nil?

          filter.apply(rel, raw, context)
        end
      end

      def stringify_keys(hash)
        hash.each_with_object({}) { |(key, value), memo| memo[key.to_s] = value }
      end

      def numeric_or_zero(value)
        value.nil? ? 0 : value
      end

      # The requested group_by column, validated against the metric's catalog list.
      def group_field
        return @group_field if defined?(@group_field)

        requested = params[:group_by]
        @group_field = nil
        return if requested.blank?

        @group_field = definition.group_by.find { |column| column.to_s == requested.to_s }
        raise Errors::InvalidGroupBy, "Unsupported group_by #{requested}" unless @group_field

        @group_field
      end

      # Splits group keys by row count. Groups below the minimum size are merged
      # into one unlabeled "other" bucket so small groups cannot be singled out.
      def split_groups(counts)
        threshold = definition.effective_min_group_size.to_i
        kept, small = counts.keys.partition { |key| counts[key] >= threshold }
        [kept.sort_by(&:to_s), small]
      end

      # Combined value for merged groups. Count and sum add up; average is weighted by row count.
      def merge_values(values, counts, keys)
        return keys.sum { |key| numeric_or_zero(values[key]) } unless definition.measurement == :average

        rows = keys.sum { |key| counts[key].to_i }
        return if rows.zero?

        keys.sum { |key| values[key].to_f * counts[key].to_i } / rows
      end

      def grouping(groups, other)
        { group_by: group_field, groups: labeled_rows(groups, group_field), other: other }
      end

      def labeled_rows(rows, column)
        return rows if definition.labels.nil? || rows.blank?

        names = definition.labels.call(rows.map { |row| row[:key] }, column)
        raise Errors::CalculationError, "labels must return a Hash" unless names.is_a?(Hash)

        rows.map { |row| with_label(row, names) }
      rescue Errors::Error, ActiveRecord::ActiveRecordError
        raise
      rescue StandardError => e
        raise Errors::CalculationError, e.message
      end

      def with_label(row, names)
        label = label_for(names, row[:key])
        return row if label.nil?

        { key: row[:key], label: label }.merge(row.except(:key))
      end

      def label_for(names, key)
        [key, key.to_s].uniq.each do |candidate|
          next unless names.key?(candidate)

          found = names[candidate]
          return found.to_s unless found.blank?
        end
        nil
      end

      def result(value: nil, data: nil, extra: {}, grouping: {})
        Result.new(
          metric: definition.identifier,
          type: definition.result_type,
          value: value,
          data: data,
          unit: definition.unit,
          title: definition.title || definition.name.to_s.humanize,
          description: definition.description,
          filters: params[:filters] || {},
          timezone: context.timezone,
          period: extra[:period],
          interval: extra[:interval],
          calculated_at: Time.current,
          metadata: extra.except(:period, :interval),
          **grouping
        )
      end
    end
  end
end
