# frozen_string_literal: true

require "test_helper"

class McpCopyTest < Minitest::Test
  FORBIDDEN = [
    "RecordingStudio::", "Access", "Accessible", ":edit", ":view", "permission", "role",
    "Admin", "staff"
  ].freeze

  def setup
    RecordingStudioMetrics::Api.reset_registered_apis!
  end

  def teardown
    RecordingStudioMetrics::Api.reset_registered_apis!
  end

  def test_register_is_a_no_op_when_mcp_is_not_loaded
    RecordingStudioMetrics::McpCopy.stub(:mcp_available?, false) do
      assert_nil RecordingStudioMetrics::McpCopy.register!
    end
  end

  def test_register_is_a_no_op_when_register_tool_is_missing
    fake = Object.new

    RecordingStudioMetrics::McpCopy.stub(:mcp, fake) do
      RecordingStudioMetrics::McpCopy.stub(:mcp_available?, false) do
        refute_respond_to fake, :register_tool
        assert_nil RecordingStudioMetrics::McpCopy.register!
      end
    end
  end

  def test_register_declares_named_tools_without_recordable_types
    fake = RecordingMcp.new
    RecordingStudioMetrics::Api.registered_apis << :operations

    RecordingStudioMetrics::McpCopy.stub(:mcp_available?, true) do
      RecordingStudioMetrics::McpCopy.stub(:mcp, fake) do
        RecordingStudioMetrics::McpCopy.register!
        RecordingStudioMetrics::McpCopy.register!
      end
    end

    assert_empty fake.types
    expected = RecordingStudioMetrics::McpCopy.tool_names
    assert_equal %w[operations_metrics_index operations_metrics_show], expected
    assert_equal expected, fake.tools.keys
    expected.each do |name|
      tool = fake.tools.fetch(name)
      kind = name.end_with?("_index") ? :index : :show
      assert_equal name.to_sym, tool[:endpoint]
      refute tool.key?(:type)
      refute tool.key?(:operation)
      refute tool.key?(:action)
      assert_equal RecordingStudioMetrics::McpCopy::TITLES.fetch(kind), tool[:title]
      assert_equal RecordingStudioMetrics::McpCopy::DESCRIPTIONS.fetch(kind), tool[:description]
      assert_equal RecordingStudioMetrics::McpCopy::INPUTS.fetch(kind), tool[:input]
      assert_equal RecordingStudioMetrics::McpCopy::OUTPUTS.fetch(kind), tool[:output]
      refute_empty tool[:description]
      refute_empty tool[:output]
      FORBIDDEN.each { |phrase| refute_includes tool[:description], phrase }
    end
  end

  def test_register_covers_each_api_the_host_registered
    fake = RecordingMcp.new
    RecordingStudioMetrics::Api.registered_apis << :admin
    RecordingStudioMetrics::Api.registered_apis << :public

    RecordingStudioMetrics::McpCopy.stub(:mcp_available?, true) do
      RecordingStudioMetrics::McpCopy.stub(:mcp, fake) do
        RecordingStudioMetrics::McpCopy.register!
      end
    end

    assert_equal %w[
      admin_metrics_index admin_metrics_show
      public_metrics_index public_metrics_show
    ], fake.tools.keys
  end

  def test_register_skips_tools_until_an_api_endpoint_is_registered
    fake = RecordingMcp.new

    RecordingStudioMetrics::McpCopy.stub(:mcp_available?, true) do
      RecordingStudioMetrics::McpCopy.stub(:mcp, fake) do
        RecordingStudioMetrics::McpCopy.register!
      end
    end

    assert_empty fake.tools
    assert_empty fake.types
  end

  def test_tool_names_default_to_operations_for_host_include
    names = RecordingStudioMetrics::McpCopy.tool_names

    assert_equal %w[operations_metrics_index operations_metrics_show], names
    assert_equal %w[admin_metrics_index admin_metrics_show],
                 RecordingStudioMetrics::McpCopy.tool_names(api: :admin)
    names.each { |name| assert_match(/\A[A-Za-z][A-Za-z0-9_.-]*\z/, name) }
  end

  def test_mcp_copy_present_for_every_tool
    RecordingStudioMetrics::McpCopy::KINDS.each do |kind|
      assert RecordingStudioMetrics::McpCopy::TITLES.fetch(kind)
      assert RecordingStudioMetrics::McpCopy::DESCRIPTIONS.fetch(kind)
      assert RecordingStudioMetrics::McpCopy::INPUTS.fetch(kind)
      assert RecordingStudioMetrics::McpCopy::OUTPUTS.fetch(kind)
    end
    assert_includes RecordingStudioMetrics::McpCopy::INDEX_DESCRIPTION, "this connection"
    assert_includes RecordingStudioMetrics::McpCopy::SHOW_DESCRIPTION, "Do not send a workspace id"
  end

  def test_gemspec_does_not_depend_on_recording_studio_mcp
    gemspec = File.read(File.expand_path("../recording_studio_metrics.gemspec", __dir__))
    entry = File.read(File.expand_path("../lib/recording_studio_metrics.rb", __dir__))
    engine = File.read(File.expand_path("../lib/recording_studio_metrics/engine.rb", __dir__))

    refute_includes gemspec, "recording_studio_mcp"
    refute_includes entry, 'require "recording_studio_mcp"'
    assert_includes engine, 'require_relative "mcp_copy"'
    assert_includes engine, 'initializer "recording_studio_metrics.mcp"'
    assert_includes engine, "McpCopy.register!"
  end

  class RecordingMcp
    attr_reader :types, :tools

    def initialize
      @types = []
      @tools = {}
    end

    def register_type(**registration)
      types << registration
    end

    def register_tool(**registration)
      tools[registration.fetch(:name)] = registration
    end
  end
end
