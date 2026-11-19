# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio `>= 7.0`, `< 8.0` (GitHub tag `v7.8.0`, `~> 7.8`, in the root and dummy Gemfiles)
- Accessible dummy tag `v0.55.0` and Root Switchable dummy tag `v0.16.1`
- Admin dummy tag `v2.19.1` and Logs dummy tag `v0.8.2`
- API dummy tag `v1.19.0`, Moveable dummy tag `v6.0.3` (`require: false`), Icons dummy tag `v0.4.2` (`require: false`)
- Trashable dummy tag `v1.2.3` (`require: false`) and Cache dummy tag `v0.7.1`
- FlatPack GitHub tag `v0.2.0` (`~> 0.2`). Hosts on FlatPack 0.1.x can stay there.
- Hosts MUST run the Recording Studio 7.4, 7.5 and 7.7 migrations if they have not. This dummy does not copy those migrations.
- Dummy `config/recording_studio_api.yml` is present with `shared: {}` so API 1.19 can boot
- Hosts moving to FlatPack 0.2 remove the manual `flat_pack/heroicons` importmap pin and any `flat-pack--icon` controller registration. The dummy importmap does not pin heroicons.
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
