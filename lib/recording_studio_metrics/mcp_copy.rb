# frozen_string_literal: true

require_relative "mcp_copy/copy"

module RecordingStudioMetrics
  # Registers Metrics named MCP tools when Recording Studio MCP is loaded.
  # This gem does not depend on it. Hosts that skip MCP keep execute and the API only.
  module McpCopy
    DEFAULT_API = :operations
    KINDS = %i[index show].freeze
    TYPES = {}.freeze
    TITLES = Copy::TITLES
    DESCRIPTIONS = Copy::DESCRIPTIONS
    INPUTS = Copy::INPUTS
    OUTPUTS = Copy::OUTPUTS
    INDEX_DESCRIPTION = Copy::INDEX_DESCRIPTION
    SHOW_DESCRIPTION = Copy::SHOW_DESCRIPTION

    module_function

    def mcp_available?
      defined?(::RecordingStudioMcp) && ::RecordingStudioMcp.respond_to?(:register_tool)
    end

    def mcp
      ::RecordingStudioMcp
    end

    def register!
      return unless mcp_available?

      register_types
      register_tools
    end

    def tool_names(api: DEFAULT_API)
      KINDS.map { |kind| tool_name(api, kind) }
    end

    def tool_name(api, kind)
      RecordingStudioMetrics::Api.metrics_endpoint_name(api, kind).to_s
    end

    def register_types
      return unless mcp.respond_to?(:register_type)

      TYPES.each do |type, description|
        mcp.register_type(type: type, description: description)
      end
    end

    def register_tools
      apis_to_register.each do |api|
        KINDS.each { |kind| register_named_tool(api, kind) }
      end
    end

    def register_named_tool(api, kind)
      mcp.register_tool(**tool_registration(api, kind))
    end

    def tool_registration(api, kind)
      {
        name: tool_name(api, kind),
        endpoint: tool_name(api, kind).to_sym,
        title: TITLES.fetch(kind),
        description: DESCRIPTIONS.fetch(kind),
        input: INPUTS.fetch(kind),
        output: OUTPUTS.fetch(kind)
      }
    end

    def apis_to_register
      RecordingStudioMetrics::Api.registered_apis
    end
    private_class_method :apis_to_register
  end
end
