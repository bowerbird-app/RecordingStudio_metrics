# frozen_string_literal: true

module RecordingStudioMetrics
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    recording_studio_layout { RecordingStudioMetrics.configuration.layout }
  end
end
