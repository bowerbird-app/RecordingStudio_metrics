# frozen_string_literal: true

class MetricsAnalyticsScreen < RecordingStudioAdmin::Screen
  key "metrics_analytics"
  title "Metrics analytics"
  blast_radius :root

  summary do
    label "Members"
    value RecordingStudioMetrics::Admin.summary_value("members.total")
  end

  chart do
    title "Registrations"
    type :line
    series RecordingStudioMetrics::Admin.chart_series_proc(
      "members.registrations",
      interval: :month
    )
  end

  widget "metrics.members.total"
  widget "metrics.members.registrations"

  filter :status, values: %w[active invited suspended], param: :status
end
