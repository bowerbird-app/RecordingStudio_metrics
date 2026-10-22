# frozen_string_literal: true

require "rails/generators"

module RecordingStudioMetrics
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs RecordingStudioMetrics engine into your application"

      class_option(
        :mount_path,
        type: :string,
        default: "/recording_studio_metrics",
        desc: "Route prefix used when mounting the engine"
      )

      def mount_engine
        route %(mount RecordingStudioMetrics::Engine, at: "#{options[:mount_path]}")
      end

      def copy_initializer
        template "recording_studio_metrics_initializer.rb", "config/initializers/recording_studio_metrics.rb"
      end

      def add_yaml_config
        prompt = "Would you like to add `config/recording_studio_metrics.yml` " \
                 "for environment-specific settings? [y/N]"
        return unless yes?(prompt)

        template "recording_studio_metrics.yml", "config/recording_studio_metrics.yml"
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end
    end
  end
end
