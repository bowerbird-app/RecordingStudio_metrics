# frozen_string_literal: true

module RecordingStudioMetrics
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioMetrics

    initializer "recording_studio_metrics.before_initialize", before: "recording_studio_metrics.load_config" do |_app|
      RecordingStudioMetrics.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_metrics.load_config" do |app|
      if app.respond_to?(:config_for)
        yaml_path = if app.respond_to?(:paths) && (config_paths = app.paths["config"])
                      first = Array(config_paths.respond_to?(:existent) ? config_paths.existent : config_paths).first
                      File.join(first, "recording_studio_metrics.yml") if first
                    elsif app.respond_to?(:root) && app.root
                      File.join(app.root, "config", "recording_studio_metrics.yml")
                    end
        yaml = app.config_for(:recording_studio_metrics) if yaml_path.nil? || File.exist?(yaml_path)
        RecordingStudioMetrics.configuration.merge!(yaml) if yaml.respond_to?(:each)
      end

      if app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_metrics)
        xcfg = app.config.x.recording_studio_metrics
        if xcfg.respond_to?(:to_h)
          RecordingStudioMetrics.configuration.merge!(xcfg.to_h)
        elsif xcfg.respond_to?(:each_pair)
          hash = {}
          xcfg.each_pair { |key, value| hash[key] = value }
          RecordingStudioMetrics.configuration.merge!(hash) if hash.any?
        end
      end

      RecordingStudioMetrics.configuration.hooks.run(:on_configuration, RecordingStudioMetrics.configuration)
    end

    initializer "recording_studio_metrics.after_initialize", after: "recording_studio_metrics.load_config" do |_app|
      RecordingStudioMetrics.configuration.hooks.run(:after_initialize, self)
    end
  end
end
