# frozen_string_literal: true

# Trashable 0.16 removed Recording.recording_studio_trashable_kept_sql.
# Accessible 0.41, Admin 2.13, and API 0.23 still call it. kept_sql is the replacement.
Rails.application.reloader.to_prepare do
  RecordingStudio::Recording.define_singleton_method(:recording_studio_trashable_kept_sql) do |table = "recording_studio_recordings"|
    RecordingStudio.kept_sql(table)
  end
end
