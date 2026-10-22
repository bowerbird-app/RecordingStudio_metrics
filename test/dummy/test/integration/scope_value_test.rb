# frozen_string_literal: true

require "test_helper"

class LogSummary < ApplicationRecord
  self.table_name = "log_summaries"
end

class ScopeValueTest < ActiveSupport::TestCase
  setup do
    DummyMetricsCatalog.load!
    create_summaries_table
    @actor = User.create!(
      email: "metrics-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @recording_id = SecureRandom.uuid
    @recordable_id = SecureRandom.uuid
    @root_recording = Struct.new(:id, :recordable_id).new(@recording_id, @recordable_id)

    LogSummary.create!(root_recording_id: @recording_id)
    LogSummary.create!(root_recording_id: @recording_id)
    LogSummary.create!(root_recording_id: @recordable_id)
  end

  teardown do
    ActiveRecord::Base.connection.drop_table(:log_summaries, if_exists: true)
    DummyMetricsCatalog.load!
  end

  test "opt-in scope_value filters by root recording id from context" do
    register_summaries(scope_value: :root_recording_id)

    result = RecordingStudioMetrics.execute("log_summaries.total", context: root_recording_context)

    assert_equal 2, result.value
  end

  test "default scope_value still uses resolved workspace id" do
    register_summaries

    result = RecordingStudioMetrics.execute("log_summaries.total", context: root_recording_context)

    assert_equal 1, result.value
  end

  test "opt-in with only workspace_id raises AuthorizationError" do
    register_summaries(scope_value: :root_recording_id)

    assert_raises(RecordingStudioMetrics::Errors::AuthorizationError) do
      RecordingStudioMetrics.execute(
        "log_summaries.total",
        context: RecordingStudioMetrics::Context.new(
          actor: @actor,
          scope: :root,
          workspace_id: @recordable_id,
          timezone: "UTC"
        )
      )
    end
  end

  test "opt-in without a root recording or workspace id fails closed" do
    register_summaries(scope_value: :root_recording_id)

    assert_raises(RecordingStudioMetrics::Errors::MissingContext) do
      RecordingStudioMetrics::Context.new(
        actor: @actor,
        scope: :root,
        timezone: "UTC"
      )
    end
  end

  test "opt-in with an authorized relation and no root recording uses that relation" do
    register_summaries(scope_value: :root_recording_id)

    result = RecordingStudioMetrics.execute(
      "log_summaries.total",
      context: RecordingStudioMetrics::Context.new(
        actor: @actor,
        scope: :root,
        authorized_relation: LogSummary.where(root_recording_id: @recording_id),
        timezone: "UTC"
      )
    )

    assert_equal 2, result.value
  end

  private

  def create_summaries_table
    ActiveRecord::Base.connection.create_table(:log_summaries, force: true) do |table|
      table.uuid :root_recording_id, null: false
    end
    LogSummary.reset_column_information
  end

  def register_summaries(scope_value: :workspace_id)
    RecordingStudioMetrics.register(
      :log_summaries,
      model: LogSummary,
      scope_attribute: :root_recording_id,
      scope_value: scope_value,
      blast_radius: :root
    ) do
      count :total, title: "Log rows"
    end
  end

  def root_recording_context
    RecordingStudioMetrics::Context.new(
      actor: @actor,
      scope: :root,
      root_recording: @root_recording,
      timezone: "UTC"
    )
  end
end
