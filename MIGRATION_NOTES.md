# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio `>= 6.1.0` (GitHub tag `v6.3.0` in the root and dummy Gemfiles)
- Accessible dummy tag `v0.24.0` and Root Switchable dummy tag `v0.11.3`
- Admin dummy tag `v2.8.2` and Logs dummy tag `v0.7.2`
- Trashable dummy tag `v0.12.0` (`require: false`) and Cache dummy tag `v0.6.1`
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
