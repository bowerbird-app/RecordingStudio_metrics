# Recording Studio kit pin update

Copied addons now start on the Support host-kit floor.

- Gemspec: `add_dependency "recording_studio", ">= 6.1.0"`
- Dummy GitHub tags: Recording Studio `v6.3.0`, Accessible `v0.24.0`, Root Switchable `v0.11.3`, API `v0.17.1`, Admin `v2.8.2`, Logs `v0.7.2`, Trashable `v0.12.0`, Cache `v0.6.1`, FlatPack tag `v0.1.341`
- Root and dummy Rails locks both `8.1.4`
- Authenticated dummy layout: `recording_studio_layout` plus FlatPack CSS/JS
- Hooks and BaseService come from core; do not copy them into a new addon
- Recordable declarations remain required
