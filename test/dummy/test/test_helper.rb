# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"
require_relative "support/accessible_write_helpers"

class ActiveSupport::TestCase
  include AccessibleWriteHelpers
end

class ActionDispatch::IntegrationTest
  include AccessibleWriteHelpers
end
