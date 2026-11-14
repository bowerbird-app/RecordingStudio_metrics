# Recording Studio kit pin update

Copied addons now start on the Support host-kit floor.

- Gemspec: `add_dependency "recording_studio", ">= 6.1.0"`
- Dummy GitHub tags: Recording Studio `v6.14.0`, Accessible `v0.41.0`, Root Switchable `v0.15.0`, API `v0.23.3`, Moveable `v4.2.0`, Icons `v0.2.1`, Admin `v2.13.1`, Logs `v0.7.5`, Trashable `v0.16.0`, Cache `v0.6.3`, FlatPack tag `v0.1.374`
- Root and dummy Rails locks both `8.1.4`
- Authenticated dummy layout: `recording_studio_layout` plus FlatPack CSS/JS
- Hooks and BaseService come from core; do not copy them into a new addon
- Recordable declarations remain required
