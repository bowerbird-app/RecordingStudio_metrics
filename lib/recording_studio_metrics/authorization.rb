# frozen_string_literal: true

module RecordingStudioMetrics
  module Authorization
    module_function

    def authorize!(definition, context)
      raise Errors::MissingContext, "execution context is required" unless context

      context.validate!

      if definition.blast_radius == :site && !(context.scope == :site && context.site_authorized?)
        raise Errors::AuthorizationError, "site-level authorization is required"
      end

      return unless context.scope == :site && !context.site_authorized?

      raise Errors::AuthorizationError, "site-level authorization is required"
    end

    def discoverable?(definition, context)
      authorize!(definition, context)
      true
    rescue Errors::Error
      false
    end

    def base_relation(definition, context)
      authorize!(definition, context)
      relation = context.authorized_relation || definition.model.all
      unless relation.klass <= definition.model || definition.model <= relation.klass
        raise Errors::AuthorizationError, "authorized relation does not match metric model"
      end

      scoped = apply_scope(relation, definition, context)
      raise Errors::AuthorizationError, "authorized scope could not be established" if scoped.nil?

      scoped
    end

    def apply_scope(relation, definition, context)
      isolated = isolate_context_scope(relation, definition, context)
      apply_metric_scope(isolated, definition, context)
    end

    def isolate_context_scope(relation, definition, context)
      return relation if context.scope == :site

      apply_root_or_recording_scope(relation, definition, context)
    end

    def apply_metric_scope(relation, definition, context)
      scope = definition.scope
      return relation unless scope

      scoped = if scope.arity == 1
                 scope.call(relation)
               else
                 scope.call(relation, context)
               end
      raise Errors::AuthorizationError, "metric scope discarded the authorized relation" if scoped.nil?

      scoped
    end

    def apply_root_or_recording_scope(relation, definition, context)
      attribute = inferred_scope_attribute(definition, relation)
      workspace_id = context.resolved_workspace_id

      if context.scope == :recording && recordable_model?(definition.model)
        return recording_relation(relation, context)
      end

      return relation.where(attribute => workspace_id) if attribute && workspace_id

      if recordable_model?(definition.model) && context.root_recording
        return recordable_root_relation(relation, context)
      end

      return relation if context.authorized_relation

      raise Errors::AuthorizationError, "unable to isolate workspace scope for #{definition.identifier}"
    end

    def inferred_scope_attribute(definition, relation)
      name = definition.scope_attribute || :workspace_id
      name if relation.klass.column_names.include?(name.to_s)
    end

    def recordable_model?(model)
      model.respond_to?(:recording_studio_recordable) ||
        (defined?(RecordingStudio) && RecordingStudio.respond_to?(:recordable_type?) &&
          RecordingStudio.recordable_type?(model.name))
    rescue StandardError
      false
    end

    def recording_relation(relation, context)
      recording = context.access_recording
      raise Errors::AuthorizationError, "recording scope requires an access recording" unless recording

      record_id = recording_recordable_id(recording)
      if record_id && relation.klass.column_names.include?("id")
        return relation.where(id: record_id)
      end

      raise Errors::AuthorizationError, "recording scope could not isolate a record"
    end

    def recording_recordable_id(recording)
      id = recording.try(:recordable_id)
      return id if id.present?

      recording.try(:recordable).try(:id)
    end

    def recordable_root_relation(relation, context)
      root = context.root_recording
      recordings = RecordingStudio::Recording.where(
        root_recording_id: root.id,
        recordable_type: relation.klass.name
      )
      relation.where(id: recordings.select(:recordable_id))
    end
  end
end
