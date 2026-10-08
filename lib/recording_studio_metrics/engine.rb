# frozen_string_literal: true

module RecordingStudioMetrics
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioMetrics

    initializer "recording_studio_metrics.before_initialize", before: "recording_studio_metrics.load_config" do |_app|
      RecordingStudioMetrics.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_metrics.load_config" do |app|
      if app.respond_to?(:config_for)
        begin
          yaml = begin
            app.config_for(:recording_studio_metrics)
          rescue StandardError
            nil
          end
          RecordingStudioMetrics.configuration.merge!(yaml) if yaml.respond_to?(:each)
        rescue StandardError
          nil
        end
      end

      if app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_metrics)
        xcfg = app.config.x.recording_studio_metrics
        if xcfg.respond_to?(:to_h)
          RecordingStudioMetrics.configuration.merge!(xcfg.to_h)
        else
          begin
            hash = {}
            xcfg.each_pair { |key, value| hash[key] = value } if xcfg.respond_to?(:each_pair)
            RecordingStudioMetrics.configuration.merge!(hash) if hash.any?
          rescue StandardError
            nil
          end
        end
      end

      RecordingStudioMetrics.configuration.hooks.run(:on_configuration, RecordingStudioMetrics.configuration)
    end

    initializer "recording_studio_metrics.after_initialize", after: "recording_studio_metrics.load_config" do |_app|
      RecordingStudioMetrics.configuration.hooks.run(:after_initialize, self)
    end
  end
end
