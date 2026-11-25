# frozen_string_literal: true

module RecordingStudioMetrics
  module McpCopy
    module Copy
      INDEX_TITLE = "List metrics"
      SHOW_TITLE = "Run a metric"
      INDEX_OUTPUT = "Catalog entries this connection can run."
      SHOW_OUTPUT = "The result of that metric."
      TITLES = {
        index: INDEX_TITLE,
        show: SHOW_TITLE
      }.freeze
      OUTPUTS = {
        index: INDEX_OUTPUT,
        show: SHOW_OUTPUT
      }.freeze
      FILTERS_RESOURCE =
        "Catalog filter. Pass resource (filters.resource=users) to list one resource. " \
        "Unknown keys are rejected."
      EXECUTE_FILTERS =
        "Declared metric filters only, as one object. Unknown names are rejected. " \
        "Scope is this connection. Do not send a workspace id."
      INTERVAL = "Time-series bucket size: hour, day, week, month, or year."
      START = "Inclusive period start (ISO-8601). Aliases: start_at, from. Must match from when both are sent."
      FROM = "Alias for start. Must match start when both are sent."
      END_AT = "Exclusive period end (ISO-8601). Aliases: end_at, to. Must match to when both are sent."
      TO = "Alias for end. Must match end when both are sent."
      GROUP_BY =
        "Split results by one catalog group_by column. Groups below min_group_size rows " \
        "merge into other. Unsupported values are rejected."
      TIMEZONE = "IANA timezone for bucket boundaries."
      RESOURCE = "Metric resource, such as users. Take it from the list-metrics tool."
      NAME = "Metric name, such as total. Take it from the list-metrics tool."
      INDEX_INPUT = {
        "filters" => { description: FILTERS_RESOURCE }
      }.freeze
      SHOW_INPUT = {
        "resource" => { description: RESOURCE },
        "name" => { description: NAME },
        "filters" => { description: EXECUTE_FILTERS },
        "interval" => { description: INTERVAL },
        "start" => { description: START },
        "from" => { description: FROM },
        "end" => { description: END_AT },
        "to" => { description: TO },
        "group_by" => { description: GROUP_BY },
        "timezone" => { description: TIMEZONE }
      }.freeze
      INPUTS = {
        index: INDEX_INPUT,
        show: SHOW_INPUT
      }.freeze
      INDEX_DESCRIPTION = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
        Returns metrics this connection can run. Each entry includes identifier, unit, group_by,
        supported_intervals, date_range, timezone, and freshness. Pass filters.resource to limit
        the catalog to one resource. Scope comes from this connection. Do not send a workspace id.
        Use this before you run a metric.
      TEXT
      SHOW_DESCRIPTION = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
        Runs one registered metric. Pass resource and name from the list-metrics tool
        (members and total for members.total). Optional filters, interval, start, from, end, to,
        group_by, and timezone. Scope comes from this connection. Do not send a workspace id.
        Groups below min_group_size rows merge into other. GET only.
      TEXT
      DESCRIPTIONS = {
        index: INDEX_DESCRIPTION,
        show: SHOW_DESCRIPTION
      }.freeze
    end
  end
end
