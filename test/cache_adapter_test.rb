# frozen_string_literal: true

require "test_helper"

class CacheAdapterTest < Minitest::Test
  FakeDefinition = Struct.new(:identifier, :version, :cacheable, :cache_for, keyword_init: true)

  def test_vary_includes_scope_and_filters
    definition = FakeDefinition.new(identifier: "users.total", version: "abc", cacheable: true, cache_for: 30)
    context = RecordingStudioMetrics::Context.new(actor: :a, scope: :root, workspace_id: "ws-1")
    vary = RecordingStudioMetrics::Cache.cache_vary(definition, context, filters: { country: "AU" }, interval: :month)

    assert_equal "users.total", vary[:metric]
    assert_equal context.scope_key, vary[:scope]
    assert_equal({ country: "AU" }, vary[:filters])
    assert_equal :month, vary[:interval]
  end

  def test_different_workspaces_do_not_share_vary_digest
    definition = FakeDefinition.new(identifier: "users.total", version: "abc", cacheable: true, cache_for: 30)
    one = RecordingStudioMetrics::Context.new(actor: :a, scope: :root, workspace_id: "ws-1")
    two = RecordingStudioMetrics::Context.new(actor: :a, scope: :root, workspace_id: "ws-2")
    digest_one = RecordingStudioMetrics::Cache.vary_digest(
      RecordingStudioMetrics::Cache.cache_vary(definition, one, {})
    )
    digest_two = RecordingStudioMetrics::Cache.vary_digest(
      RecordingStudioMetrics::Cache.cache_vary(definition, two, {})
    )

    refute_equal digest_one, digest_two
  end
end
