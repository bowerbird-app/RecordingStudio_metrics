# frozen_string_literal: true

require "test_helper"

class AuthorizeWriteTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "write-gate-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @workspace = Workspace.create!(name: "Write Gate #{SecureRandom.hex(4)}")
    Current.actor = @user
    @root = RecordingStudio.root_recording_for(@workspace)
  end

  teardown do
    Current.actor = nil
  end

  test "signed-in actor without a grant cannot record a child" do
    assert_raises(RecordingStudio::AuthorizationError) do
      RecordingStudio.record!(
        action: "created",
        recordable: Folder.new(name: "Denied #{SecureRandom.hex(4)}"),
        root_recording: @root,
        parent_recording: @root,
        actor: @user
      )
    end
  end

  test "bootstrap owner can record a child under the root" do
    grant_admin!(@user, @root)

    event = RecordingStudio.record!(
      action: "created",
      recordable: Folder.new(name: "Allowed #{SecureRandom.hex(4)}"),
      root_recording: @root,
      parent_recording: @root,
      actor: @user
    )

    assert_equal @root, event.recording.parent_recording
  end
end
