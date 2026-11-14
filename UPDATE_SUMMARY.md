# Recording Studio kit pin update

Copied addons now start on the Support host-kit floor.

- Gemspec: `add_dependency "recording_studio", ">= 6.1.0"`
- Dummy GitHub tags: Recording Studio `v6.10.0`, Accessible `v0.37.0`, Root Switchable `v0.15.0`, API `v0.23.1`, Moveable `v4.1.1`, Icons `v0.2.1`, Admin `v2.13.0`, Logs `v0.7.4`, Trashable `v0.14.1`, Cache `v0.6.3`, FlatPack tag `v0.1.366`
- Root and dummy Rails locks both `8.1.4`
- Authenticated dummy layout: `recording_studio_layout` plus FlatPack CSS/JS
- Hooks and BaseService come from core; do not copy them into a new addon
- Recordable declarations remain required
