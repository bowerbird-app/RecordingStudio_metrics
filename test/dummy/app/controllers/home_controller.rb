# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    workspace = demo_workspace
    return if workspace.nil?

    context = RecordingStudioMetrics::Context.new(
      actor: current_user,
      scope: :root,
      workspace_id: workspace.id,
      timezone: "UTC"
    )
    @workspace = workspace
    @member_total = RecordingStudioMetrics.execute("members.total", context: context)
    @project_total = RecordingStudioMetrics.execute("projects.total", context: context)
    @projects_with_images = RecordingStudioMetrics.execute("projects.with_images", context: context)
    @average_images = RecordingStudioMetrics.execute("projects.average_images", context: context)
    @registrations = RecordingStudioMetrics.execute(
      "members.registrations",
      context: context,
      interval: :month,
      start_at: 3.months.ago.beginning_of_month,
      end_at: Time.current.beginning_of_month + 1.month
    )
  rescue RecordingStudioMetrics::Errors::Error
    @metrics_error = true
  end

  private

  def demo_workspace
    Workspace.find_by(name: "Studio Workspace") || Workspace.order(:created_at).first
  end
end
