# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_metrics.gemspec
gemspec

# recording_studio is not published to RubyGems; resolve the gemspec pin from GitHub.
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.5.0"

# flat_pack is not published to RubyGems. Recording Studio 6.5.0 and Admin 2.8.2
# require >= 0.1.341. FlatPack is not on RubyGems; pin a GitHub tag.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.341"

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
