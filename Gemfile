# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_metrics.gemspec
gemspec

# recording_studio is not published to RubyGems; resolve the gemspec pin from GitHub.
gem "recording_studio", "~> 7.8", github: "bowerbird-app/RecordingStudio", tag: "v7.8.0"

# flat_pack is not published to RubyGems. Recording Studio 7.8 allows >= 0.1.315.
# This checkout uses flat_pack 0.2.
gem "flat_pack", "~> 0.2", github: "bowerbird-app/flatpack", tag: "v0.2.0"

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "minitest-mock"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
