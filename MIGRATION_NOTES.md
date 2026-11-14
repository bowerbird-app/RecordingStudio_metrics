# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio `>= 6.1.0` (GitHub tag `v6.14.0` in the root and dummy Gemfiles)
- Accessible dummy tag `v0.41.0` and Root Switchable dummy tag `v0.15.0`
- Admin dummy tag `v2.13.1` and Logs dummy tag `v0.7.5`
- API dummy tag `v0.23.3`, Moveable dummy tag `v4.2.0` (`require: false`), Icons dummy tag `v0.2.1` (`require: false`)
- Trashable dummy tag `v0.16.0` (`require: false`) and Cache dummy tag `v0.6.3`
- FlatPack GitHub tag `v0.1.374`
- Dummy copies Recording Studio migration `20261114090000_add_root_recording_id_to_recording_studio_events` so events store `root_recording_id`
- Public RubyGems and GitHub access for dependency installation

## Verification

Install both bundles and run the complete gem and dummy app test path:

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

Run the dummy app from its directory for browser verification:

```bash
cd test/dummy
bin/dev
```

Use the [FlatPack repository](https://github.com/bowerbird-app/flatpack) and the live FlatPack demo linked from the top-level README for current component documentation.
