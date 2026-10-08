# frozen_string_literal: true

require "test_helper"

class MetricsFilterInjectionTest < ActiveSupport::TestCase
  test "filter field names cannot select arbitrary columns" do
    definition = RecordingStudioMetrics.find("members.total")
    filter = RecordingStudioMetrics::Filter.new(:created_at, field: :password_digest, type: :string)
    relation = Member.all

    assert_raises(RecordingStudioMetrics::Errors::InvalidFilter) do
      filter.apply(relation, "secret", nil)
    end
    assert_nil definition.filter_for(:password_digest)
  end
end
