# Recording Studio kit pin update

Copied addons now start on the Support host-kit floor.

- Gemspec: `add_dependency "recording_studio", ">= 7.0", "< 8.0"`
- Dummy GitHub tags: Recording Studio `v7.8.0`, Accessible `v0.55.0`, Root Switchable `v0.16.1`, API `v1.19.0`, Moveable `v6.0.3`, Icons `v0.4.2`, Admin `v2.19.1`, Logs `v0.8.2`, Trashable `v1.2.3`, Cache `v0.7.1`, FlatPack tag `v0.2.0`
- Root and dummy Rails locks both `8.1.4`
- Authenticated dummy layout: `recording_studio_layout` plus FlatPack CSS/JS
- Hooks and BaseService come from core; do not copy them into a new addon
- Recordable declarations remain required
