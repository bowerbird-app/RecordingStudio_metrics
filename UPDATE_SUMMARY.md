# Recording Studio kit pin update

Copied addons now start on the Support host-kit floor.

- Gemspec: `add_dependency "recording_studio", ">= 7.0", "< 8.0"`
- Dummy GitHub tags: Recording Studio `v7.4.0`, Accessible `v0.45.1`, Root Switchable `v0.16.0`, API `v1.2.1`, Moveable `v6.0.0`, Icons `v0.4.0`, Admin `v2.18.0`, Logs `v0.8.0`, Trashable `v1.0.0`, Cache `v0.7.0`, FlatPack tag `v0.1.377`
- Root and dummy Rails locks both `8.1.4`
- Authenticated dummy layout: `recording_studio_layout` plus FlatPack CSS/JS
- Hooks and BaseService come from core; do not copy them into a new addon
- Recordable declarations remain required
