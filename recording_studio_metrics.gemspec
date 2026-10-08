# frozen_string_literal: true

require_relative "lib/recording_studio_metrics/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_metrics"
  spec.version     = RecordingStudioMetrics::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_metrics"
  spec.summary     = "Shared metrics and analytics engine for Recording Studio"
  spec.description = "Register metrics once for Recording Studio recordables and Active Record " \
                     "models, then execute them consistently for Admin, API, jobs, and host apps."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib,docs}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
end
