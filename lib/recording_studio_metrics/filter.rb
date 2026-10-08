# frozen_string_literal: true

module RecordingStudioMetrics
  class Filter
    TYPES = %i[string enum boolean integer numeric_range date_range datetime_range].freeze

    attr_reader :name, :field, :type, :label, :default, :options, :handler, :operators

    def initialize(name, type:, field: nil, label: nil, default: nil, options: nil, handler: nil, operators: nil)
      @name = name.to_sym
      @field = field&.to_sym
      @type = type.to_sym
      @label = label || @name.to_s.humanize
      @default = default
      @options = Array(options)
      @handler = handler
      @operators = Array(operators).map(&:to_sym)
      validate_definition!
    end

    def apply(relation, raw_value, context)
      value = normalize(raw_value)
      return relation if value.nil? && default.nil?

      value = default if value.nil?

      return handler.call(relation, value, context) if handler

      raise Errors::InvalidFilter, "Filter #{name} has no field" if field.nil?

      raise Errors::InvalidFilter, "Filter #{name} field is not a permitted column" unless column_allowed?(relation)

      apply_field(relation, value)
    end

    def metadata
      {
        name: name,
        field: field,
        type: type,
        label: label,
        default: default,
        options: options,
        operators: operators.presence
      }.compact
    end

    private

    def validate_definition!
      raise ArgumentError, "Unsupported filter type #{type}" unless TYPES.include?(type)
      raise ArgumentError, "Filter #{name} needs a field or handler" if field.nil? && handler.nil?
    end

    def column_allowed?(relation)
      relation.klass.column_names.include?(field.to_s)
    end

    def normalize(value)
      return if value.nil? || value == ""

      case type
      when :boolean
        normalize_boolean(value)
      when :string, :enum
        normalize_string(value)
      when :integer
        Integer(value)
      when :numeric_range, :date_range, :datetime_range
        normalize_range(value)
      else
        value
      end
    rescue ArgumentError, TypeError
      raise Errors::InvalidFilter, "Invalid value for filter #{name}"
    end

    def normalize_boolean(value)
      return value if [true, false].include?(value)
      return true if %w[true 1].include?(value.to_s.downcase)
      return false if %w[false 0].include?(value.to_s.downcase)

      raise Errors::InvalidFilter, "Invalid boolean for filter #{name}"
    end

    def normalize_string(value)
      string = value.to_s
      if options.any? && options.none? { |option| option.to_s == string }
        raise Errors::InvalidFilter, "Unsupported value for filter #{name}"
      end

      string
    end

    def normalize_range(value)
      hash = value.respond_to?(:to_h) ? value.to_h.transform_keys(&:to_sym) : nil
      raise Errors::InvalidFilter, "Filter #{name} expects a range object" unless hash

      unknown = hash.keys - %i[min max start end gte lte gt lt]
      raise Errors::InvalidFilter, "Unsupported operators for filter #{name}" if unknown.any?

      hash
    end

    def apply_field(relation, value)
      case type
      when :boolean, :string, :enum, :integer
        relation.where(field => value)
      when :numeric_range
        apply_numeric_range(relation, value)
      when :date_range, :datetime_range
        apply_time_range(relation, value)
      else
        relation
      end
    end

    def apply_numeric_range(relation, value)
      min = value[:min] || value[:gte]
      max = value[:max] || value[:lte]
      rel = relation
      rel = rel.where(rel.arel_table[field].gteq(min)) unless min.nil?
      rel = rel.where(rel.arel_table[field].lteq(max)) unless max.nil?
      rel = rel.where(rel.arel_table[field].gt(value[:gt])) if value.key?(:gt)
      rel = rel.where(rel.arel_table[field].lt(value[:lt])) if value.key?(:lt)
      rel
    end

    def apply_time_range(relation, value)
      start_at = coerce_time(value[:start] || value[:min] || value[:gte])
      end_at = coerce_time(value[:end] || value[:max] || value[:lte])
      rel = relation
      rel = rel.where(rel.arel_table[field].gteq(start_at)) if start_at
      rel = rel.where(rel.arel_table[field].lt(end_at)) if end_at
      rel
    end

    def coerce_time(value)
      return if value.nil?
      return value if value.respond_to?(:to_time)

      Time.zone.parse(value.to_s) || Date.iso8601(value.to_s).in_time_zone
    rescue ArgumentError
      raise Errors::InvalidFilter, "Invalid date for filter #{name}"
    end
  end
end
