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
                :metadata,
                :group_by,
                :groups,
                :other

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
      metadata: {},
      group_by: nil,
      groups: nil,
      other: nil
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
      @group_by = group_by
      @groups = groups
      @other = other
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
        metadata: metadata,
        group_by: group_by,
        groups: groups,
        other: other
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
