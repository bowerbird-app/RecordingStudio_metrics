# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio `>= 6.1.0` (GitHub tag `v6.5.0` in the root and dummy Gemfiles)
- Accessible dummy tag `v0.24.2` and Root Switchable dummy tag `v0.11.3`
- Admin dummy tag `v2.8.2` (off the 2.5.1 host policy; left unchanged) and Logs dummy tag `v0.7.4`
- API dummy tag `v0.18.4`, Moveable dummy tag `v4.1.1` (`require: false`), Icons dummy tag `v0.2.1` (`require: false`)
- Trashable dummy tag `v0.12.3` (`require: false`) and Cache dummy tag `v0.6.1`
- FlatPack GitHub tag `v0.1.341`
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
