# frozen_string_literal: true

module RecordingStudioMetrics
  class DSL
    attr_reader :metrics, :scope_attribute

    def initialize(resource, model:, blast_radius: :root, scope: nil, scope_attribute: nil, **resource_options)
      @resource = resource.to_sym
      @model = model
      @blast_radius = blast_radius
      @scope = scope
      @scope_attribute = scope_attribute
      @resource_options = resource_options
      @metrics = []
    end

    def count(name, **, &)
      add(:count, name, result_type: :scalar, **, &)
    end

    def sum(name, **, &)
      add(:sum, name, result_type: :scalar, **, &)
    end

    def average(name, **, &)
      add(:average, name, result_type: :scalar, **, &)
    end

    def breakdown(name, **, &)
      add(:breakdown, name, result_type: :breakdown, grouping: :category, **, &)
    end

    def timeseries(name, **options, &)
      add(
        :timeseries,
        name,
        result_type: :timeseries,
        grouping: :time,
        intervals: options[:intervals] || %i[day week month year],
        **options,
        &
      )
    end

    def custom(name, result_type:, **, &calculator)
      raise ArgumentError, "custom metrics require a block" unless calculator

      add(:custom, name, result_type: result_type, calculator: calculator, **)
    end

    def resource_scope
      @scope
    end

    private

    def add(metric_type, name, **options, &block)
      filters = []
      if block && metric_type != :custom
        collector = FilterCollector.new
        collector.instance_eval(&block)
        filters = collector.filters
      end
      Array(options.delete(:filter)).each { |filter| filters << filter } if options[:filter]
      filters.concat(Array(options.delete(:filters))) if options[:filters]

      if options[:expose]
        expose = options.delete(:expose)
        apis = expose.is_a?(Hash) ? (expose[:api] || expose["api"] || expose[:apis]) : expose
        options[:exposed_apis] = Array(apis)
      end

      definition = Definition.new(
        resource: @resource,
        name: name,
        model: @model,
        metric_type: metric_type,
        blast_radius: options.delete(:blast_radius) || @blast_radius,
        scope: options.delete(:scope) || @scope,
        scope_attribute: options.delete(:scope_attribute) || @scope_attribute,
        filters: filters,
        source_location: caller_locations(2, 1)&.first,
        **options
      )
      if @metrics.any? { |metric| metric.name == definition.name }
        raise Errors::DuplicateRegistration, "Metric #{definition.identifier} is already registered"
      end

      @metrics << definition
    end

    class FilterCollector
      attr_reader :filters

      def initialize
        @filters = []
      end

      def filter(name, **)
        @filters << Filter.new(name, **)
      end
    end
  end
end
