# frozen_string_literal: true

class Project < ApplicationRecord
  belongs_to :workspace
  has_many :project_images, dependent: :destroy
end
