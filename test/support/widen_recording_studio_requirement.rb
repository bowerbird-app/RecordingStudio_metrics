# frozen_string_literal: true

# Sibling gems pinned by the dummy still reject this bundle.
# Logs v0.7.0 declares recording_studio < 5 and recording_studio_metrics ~> 0.6.1.
# Bundler reads those gemspecs during install and again during boot.
# Widen only a requirement that rejects the version this app resolves.
module WidenRecordingStudioRequirement
  RULES = {
    "recording_studio" => ["6.1.0", ">= 4.1"],
    "recording_studio_metrics" => ["0.7.0", ">= 0.6.1"]
  }.freeze

  module SpecificationPatch
    def add_dependency(name, *requirements)
      super(name, *WidenRecordingStudioRequirement.rewrite(name, requirements))
    end

    def add_runtime_dependency(name, *requirements)
      super(name, *WidenRecordingStudioRequirement.rewrite(name, requirements))
    end
  end

  def self.rewrite(name, requirements)
    rule = RULES[name.to_s]
    return requirements unless rule

    parts = requirements.dup
    options = parts.last.is_a?(Hash) ? parts.pop : nil
    return requirements if parts.empty?
    return requirements if Gem::Requirement.new(parts).satisfied_by?(Gem::Version.new(rule[0]))

    widened = [rule[1]]
    options ? widened + [options] : widened
  end
end

Gem::Specification.prepend(WidenRecordingStudioRequirement::SpecificationPatch)
