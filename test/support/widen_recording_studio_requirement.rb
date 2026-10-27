# frozen_string_literal: true

# Sibling gems pinned by the dummy still declare recording_studio < 5.
# Bundler reads those gemspecs during install and again during boot.
# Widen only a requirement that rejects 6.1.0.
module WidenRecordingStudioRequirement
  TARGET = Gem::Version.new("6.1.0")
  WIDENED = ">= 4.1"

  module SpecificationPatch
    def add_dependency(name, *requirements)
      super(name, *WidenRecordingStudioRequirement.rewrite(name, requirements))
    end

    def add_runtime_dependency(name, *requirements)
      super(name, *WidenRecordingStudioRequirement.rewrite(name, requirements))
    end
  end

  def self.rewrite(name, requirements)
    return requirements unless name.to_s == "recording_studio"

    parts = requirements.dup
    options = parts.last.is_a?(Hash) ? parts.pop : nil
    return requirements if parts.empty?
    return requirements if Gem::Requirement.new(parts).satisfied_by?(TARGET)

    widened = [WIDENED]
    options ? widened + [options] : widened
  end
end

Gem::Specification.prepend(WidenRecordingStudioRequirement::SpecificationPatch)
