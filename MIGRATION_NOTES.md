# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio `>= 6.1.0` (GitHub tag `v6.1.0` in the root and dummy Gemfiles)
- Accessible dummy tag `v0.18.0` and Root Switchable dummy tag `v0.9.0`
- Admin dummy tag `v2.7.0` and Logs dummy tag `v0.7.0`
- Trashable dummy tag `v0.11.0` (`require: false`) and Cache dummy tag `v0.5.0`
- FlatPack ref `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (`0.1.319`)
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
