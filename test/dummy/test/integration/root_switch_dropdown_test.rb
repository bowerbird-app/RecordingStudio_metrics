# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class RootSwitchDropdownTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "sign in page uses the devise layout and is not squished by the default layout" do
    get new_user_session_path

    assert_response :success
    assert_includes response.body, "admin@admin.com"
    assert_includes response.body, "Password"
    assert_includes response.body, 'data-theme="rounded"'
    refute_includes response.body, "data-recording-studio-default-layout"
    refute_includes response.body, "mt-28"
    refute_includes response.body, "fixed inset-0"
  end

  test "home page renders the root switch dropdown trigger" do
    user = User.find_or_create_by!(email: "root-switch-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in user

    workspace = Workspace.create!(name: "Dropdown Workspace")
    RecordingStudio.root_recording_for(workspace)

    get root_path

    assert_response :success
    assert_includes response.body, workspace.name
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_select "h1", text: "Metrics Demo", count: 1
  end

  test "root switch page renders with the host default layout" do
    user = User.find_or_create_by!(email: "root-switch-page-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in user

    workspace = Workspace.create!(name: "Switch Page Workspace")
    RecordingStudio.root_recording_for(workspace)
    grant_view_on_workspace_roots!(user)

    get "/recording_studio_root_switchable/v1/root_switch?scope=all_workspaces"

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    refute_includes response.body, "flat-pack-sidebar-layout"
  end

  test "switching returns to the current page when it is a valid internal route" do
    user = User.find_or_create_by!(email: "root-switch-redirect-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in user

    source_workspace = Workspace.create!(name: "Source Workspace")
    target_workspace = Workspace.create!(name: "Target Workspace")
    target_root_recording = RecordingStudio.root_recording_for(target_workspace)
    RecordingStudio.root_recording_for(source_workspace)
    grant_view_on_workspace_roots!(user)

    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: target_root_recording.id,
        return_to: "/docs/install"
      }
    }

    assert_redirected_to "/docs/install"
  end

  test "internal_route? treats unknown paths as routing errors and known paths as internal" do
    assert internal_route?("/")
    assert internal_route?("/docs/install")
    refute internal_route?("/not-a-real-route")
  end

  test "switching falls back to home when return_to is not a valid internal route" do
    user = User.find_or_create_by!(email: "root-switch-fallback-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in user

    source_workspace = Workspace.create!(name: "Fallback Source Workspace")
    target_workspace = Workspace.create!(name: "Fallback Target Workspace")
    target_root_recording = RecordingStudio.root_recording_for(target_workspace)
    RecordingStudio.root_recording_for(source_workspace)
    grant_view_on_workspace_roots!(user)

    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: target_root_recording.id,
        return_to: "/not-a-real-route"
      }
    }

    assert_redirected_to "/"
  end

  private

  # Root Switchable 0.15 forbids the mounted switcher unless the actor can
  # view the current root. The dummy lists every workspace, so the current
  # root may be a seeded one this user does not own yet. Bootstrap only the
  # empty roots; seeded roots already have an owner, so grant :view through
  # that owner.
  def grant_view_on_workspace_roots!(user)
    Workspace.find_each do |workspace|
      recording = RecordingStudio.root_recording_for(workspace)
      next if RecordingStudioAccessible.authorized?(actor: user, recording: recording, role: :view)

      bootstrapped = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: user)
      next if bootstrapped.respond_to?(:success?) && bootstrapped.success?

      granted = RecordingStudioAccessible.grant_access(
        recording: recording,
        actor: user,
        role: :view,
        manager_actor: User.find_by!(email: "admin@admin.com")
      )
      raise granted.error if granted.respond_to?(:failure?) && granted.failure?
    end
  end
end
