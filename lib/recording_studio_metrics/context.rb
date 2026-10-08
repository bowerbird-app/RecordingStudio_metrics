# frozen_string_literal: true

module RecordingStudioMetrics
  class Context
    SCOPES = %i[recording root site].freeze

    attr_reader :actor,
                :scope,
                :access_recording,
                :root_recording,
                :timezone,
                :workspace_id,
                :authorized_relation,
                :timestamp,
                :extras

    def initialize(
      scope:, actor: nil,
      system: false,
      access_recording: nil,
      root_recording: nil,
      timezone: nil,
      workspace_id: nil,
      authorized_relation: nil,
      site_authorized: false,
      timestamp: nil,
      **extras
    )
      @actor = actor
      @system = system
      @scope = scope.to_sym
      @access_recording = access_recording
      @root_recording = root_recording
      @timezone = timezone.presence || RecordingStudioMetrics.configuration.default_timezone
      @workspace_id = workspace_id
      @authorized_relation = authorized_relation
      @site_authorized = site_authorized
      @timestamp = timestamp || Time.current
      @extras = extras
      validate!
    end

    def system?
      @system
    end

    def site_authorized?
      @site_authorized == true
    end

    def scope_key
      [
        scope,
        actor_key,
        recording_id_for(access_recording),
        recording_id_for(root_recording),
        resolved_workspace_id,
        site_authorized?
      ].join(":")
    end

    def resolved_workspace_id
      workspace_id.presence ||
        recordable_id(root_recording) ||
        recordable_id(access_recording)
    end

    def validate!
      raise Errors::MissingContext, "scope is required" unless SCOPES.include?(scope)
      raise Errors::MissingContext, "actor or system identity is required" if actor.nil? && !system?
      raise Errors::MissingContext, "timezone is required" if timezone.blank?

      Time.find_zone!(timezone)

      case scope
      when :site
        raise Errors::AuthorizationError, "site-level authorization is required" unless site_authorized?
      when :root
        if root_recording.nil? && workspace_id.nil? && authorized_relation.nil?
          raise Errors::MissingContext, "root scope requires a root recording, workspace id, or authorized relation"
        end
      when :recording
        if access_recording.nil? && authorized_relation.nil?
          raise Errors::MissingContext, "recording scope requires an access recording or authorized relation"
        end
      end
    end

    def self.from_api(api_context, **overrides)
      grant = api_context.respond_to?(:access_grant) ? api_context.access_grant : nil
      actor = if grant.respond_to?(:actor)
                grant.actor
              else
                api_context.try(:api_client)
              end
      new(
        actor: actor,
        system: actor.nil?,
        scope: overrides.delete(:scope) || :root,
        access_recording: api_context.access_recording,
        root_recording: api_context.root_recording,
        timezone: overrides.delete(:timezone),
        site_authorized: overrides.delete(:site_authorized) || false,
        **overrides
      )
    end

    private

    def actor_key
      return "system" if system? && actor.nil?
      return actor.to_gid_param if actor.respond_to?(:to_gid_param)

      "#{actor.class}:#{actor.try(:id)}"
    end

    def recording_id_for(recording)
      recording.try(:id)
    end

    def recordable_id(recording)
      return unless recording

      recording.try(:recordable_id) || recording.try(:recordable).try(:id)
    end
  end
end
