# frozen_string_literal: true

require "test_helper"

class ContextTest < Minitest::Test
  def test_requires_actor_or_system
    error = assert_raises(RecordingStudioMetrics::Errors::MissingContext) do
      RecordingStudioMetrics::Context.new(scope: :root, workspace_id: "ws-1")
    end
    assert_match(/actor or system/, error.message)
  end

  def test_site_scope_fails_closed_without_flag
    assert_raises(RecordingStudioMetrics::Errors::AuthorizationError) do
      RecordingStudioMetrics::Context.new(actor: :admin, scope: :site)
    end
  end

  def test_root_scope_requires_workspace_anchor
    assert_raises(RecordingStudioMetrics::Errors::MissingContext) do
      RecordingStudioMetrics::Context.new(actor: :admin, scope: :root)
    end
  end

  def test_recording_scope_requires_access_recording
    assert_raises(RecordingStudioMetrics::Errors::MissingContext) do
      RecordingStudioMetrics::Context.new(actor: :admin, scope: :recording)
    end
  end

  def test_scope_key_includes_authorization_identity
    first = RecordingStudioMetrics::Context.new(actor: :a, scope: :root, workspace_id: "one")
    second = RecordingStudioMetrics::Context.new(actor: :a, scope: :root, workspace_id: "two")

    refute_equal first.scope_key, second.scope_key
  end

  def test_from_api_defaults_to_root_and_not_site
    api_context = Struct.new(:access_grant, :access_recording, :root_recording, :api_key).new(
      Struct.new(:actor).new(:client),
      nil,
      nil,
      "admin"
    )

    context = RecordingStudioMetrics::Context.from_api(api_context, workspace_id: "ws-1")
    assert_equal :root, context.scope
    refute context.site_authorized?
  end
end
