# frozen_string_literal: true

module RecordingStudioMetrics
  class Result
    attr_reader :metric,
                :type,
                :value,
                :data,
                :unit,
                :title,
                :description,
                :filters,
                :timezone,
                :period,
                :interval,
                :calculated_at,
                :metadata

    def initialize(
      metric:,
      type:,
      value: nil,
      data: nil,
      unit: nil,
      title: nil,
      description: nil,
      filters: {},
      timezone: nil,
      period: nil,
      interval: nil,
      calculated_at: Time.current,
      metadata: {}
    )
      @metric = metric
      @type = type.to_sym
      @value = value
      @data = data
      @unit = unit
      @title = title
      @description = description
      @filters = filters
      @timezone = timezone
      @period = period
      @interval = interval
      @calculated_at = calculated_at
      @metadata = metadata
    end

    def as_json(*)
      payload = {
        metric: metric,
        type: type,
        unit: unit,
        title: title,
        description: description,
        filters: filters,
        timezone: timezone,
        period: period,
        interval: interval,
        calculated_at: calculated_at&.iso8601,
        metadata: metadata
      }
      if type == :scalar
        payload[:value] = value
      else
        payload[:data] = data
      end
      payload.compact
    end
  end
end
