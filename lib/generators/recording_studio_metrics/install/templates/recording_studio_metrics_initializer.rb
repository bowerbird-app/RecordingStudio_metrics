# frozen_string_literal: true

RecordingStudioMetrics.configure do |config|
  config.default_timezone = "UTC"
  config.max_timeseries_buckets = 400
  config.cache_enabled = true
end
