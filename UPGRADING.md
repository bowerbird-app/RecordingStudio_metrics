# Upgrading RecordingStudioMetrics

## Current dummy pins

Gem version stays `0.8.0`. The root and dummy Gemfiles pin Recording Studio `v6.7.0` and FlatPack `v0.1.356`. The dummy also pins Accessible `v0.31.0`, API `v0.22.1`, Moveable `v4.1.1`, Icons `v0.2.1`, Admin `v2.13.0`, Logs `v0.7.4`, Trashable `v0.14.0`, Cache `v0.6.3`, and Root Switchable `v0.15.0`. The gemspec still requires `recording_studio` `>= 6.1.0`.

## Upgrading to 0.8.0

`0.8.0` keeps metric registration, `execute`, API exposure, and Admin result adapters.
It removes `RecordingStudioMetrics::Admin.widget`. Metrics does not authorize Admin or
Accessible. Update the host dependency to `recording_studio_metrics`, `~> 0.8.0`.

1. No migrations in this gem.
2. Existing `execute`, `scalar_value`, `chart_series`, `summary_value`, `chart_series_proc`,
   and `attach_filters` calls keep current behaviour.
3. Replace `RecordingStudioMetrics::Admin.widget(...)` with an Admin widget registered by
   the owning gem or host. Pass `RecordingStudioMetrics::Admin.summary_value` or
   `chart_series_proc` into that widget. `api_authorize:` stays on the registering gem.
4. At the `0.8.0` release, this repository’s dummy host pinned Recording Studio `v6.5.0`,
   FlatPack `v0.1.341`, Accessible `v0.24.2`, API `v0.18.4`, Moveable `v4.1.1`, Icons `v0.2.1`,
   Logs `v0.7.4`, Trashable `v0.12.3`, Cache `v0.6.1`, Root Switchable `v0.11.3`, and Admin `v2.8.2`.
   Current pins are in the section above. Gemspec still requires `recording_studio` `>= 6.1.0`.
   Recording Studio `6.5.0` and later need `config.authorize_write`.
   The dummy delegates that gate to Accessible (`:edit` on the root, Access writes via
   `AccessCreationContext` or `:admin`). It does not use `actor.present?` or
   `allow_unauthorized_writes`.

If you are still on `0.7.3` or older, complete that release's notes first.

## Upgrading to 0.7.3

`0.7.3` does not change metric registration, `execute`, API exposure, or Admin helper contracts.
Update the host dependency to `recording_studio_metrics`, `~> 0.7.3`.

1. No migrations in this gem.
2. Existing metric, API, and Admin calls keep current behaviour.
3. Hosts should resolve Rails `8.1.4.1` (or newer patch). This repository’s lockfiles use Rails `8.1.4.1`, Rack `3.2.8`, Loofah `2.25.3`, Nokogiri `1.19.7`, and `rails-html-sanitizer` `1.7.2`. Dummy `net-ssh` stays `7.3.8`. Companion GitHub tags are unchanged from `0.7.2`.

If you are still on `0.7.2` or older, complete that release's notes first.

## Upgrading to 0.7.2

`0.7.2` does not change metric registration, `execute`, API exposure, or Admin helper contracts.
The gemspec still requires `recording_studio` `>= 6.1.0`. Update the host dependency to
`recording_studio_metrics`, `~> 0.7.2`.

1. No migrations in this gem.
2. Existing metric, API, and Admin calls keep current behaviour.
3. This repository’s dummy host pins Recording Studio `v6.3.0`, FlatPack `v0.1.341`,
   Accessible `v0.24.0`, API `v0.17.1` (not `v0.18.1`; that tag needs Moveable), Logs `v0.7.2`, Trashable `v0.12.0`,
   Cache `v0.6.1`, Root Switchable `v0.11.3`, and Admin `v2.8.2`. Admin `2.8.2`
   needs Recording Studio `>= 6.3.0` and FlatPack `>= 0.1.341`. Match those tags
   if you want the dummy companion set.
4. Root Switchable `0.11+` accepts `nil`, `false`, a layout name String, or
   `call(controller:)`. The dummy no longer sets `config.layout = :application_layout`.

If you are still on `0.7.1` or older, complete that release's notes first.

## Upgrading to 0.7.1

`0.7.1` does not change metric registration, `execute`, API exposure, or Admin helper contracts.
Update the host dependency to `recording_studio_metrics`, `~> 0.7.1`.

1. No migrations in this gem.
2. Existing metric, API, and Admin calls keep current behaviour.
3. The dummy host pins Logs tag `v0.7.1` (`recording_studio >= 6.1.0`,
   `recording_studio_metrics >= 0.6.1, < 1.0`) and no longer ships
   `test/support/widen_recording_studio_requirement.rb`. Hosts that already
   resolve Recording Studio `>= 6.1.0` do not need that file.

If you are still on `0.7.0` or older, complete that release's notes first.

## Upgrading to 0.7.0

`0.7.0` requires Recording Studio `>= 6.1.0`. Flatpack must be `>= 0.1.315`. This repository pins Flatpack ref `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (`0.1.319`). Update the host dependency to `recording_studio_metrics`, `~> 0.7.0`.

1. No migrations in this gem.
2. Metric registration, `execute`, API exposure, and Admin helpers keep their current contracts.
3. `RecordingStudioMetrics.configuration.layout` defaults to `nil`. `nil` uses `RecordingStudio.configuration.layout`, then `recording_studio/default_layout`. Assign a layout name, `false`, or a callable that accepts `controller:`.
4. Call `recording_studio_layout` on engine and host controllers. Do not include `RecordingStudio::UsesDefaultLayout` and do not hard-code `layout "recording_studio/default_layout"`.
5. The default layout renders one `FlatPack::PageTitle` from `content_for :title` and `content_for :subtitle`. Remove a second page-level title from the view.
6. Set the back and close buttons with `flat_pack_page_nav(round: true, style: :default, back_href:, back_tooltip:, anchor_href:, anchor_tooltip:)`. `recording_studio_page_nav` is gone.
7. Register right-side actions with `register_page_nav`. `recording_studio_page_nav_right` remains for custom HTML that is not a button, such as the root switch dropdown.
8. `FlatPack::Card::Component` no longer accepts `style:`. Pass `background:`, `border:`, and `shadow:`.
9. Root Switchable `v0.9.0` still renders `FlatPack::PageNav` with `anchor_label:` and a card `style:`. The dummy overrides `recording_studio_root_switchable/root_switches/show` so that page uses `flat_pack_page_nav` and `background:`.

The dummy still pins companion gems whose gemspecs require `recording_studio` `< 5`. Logs `v0.7.0` also requires `recording_studio_metrics` `~> 0.6.1`, which rejects `0.7.0`. `test/support/widen_recording_studio_requirement.rb` relaxes those requirements before Bundler resolves, so the dummy can boot Recording Studio `6.1.0` and this gem. A host that already depends on those versions does not need that file.

If you are still on `0.6.1` or older, complete that release's notes first.

## Upgrading to 0.6.1

`0.6.1` adds an optional `scope_value:` on `RecordingStudioMetrics.register`.
Update the host dependency to `recording_studio_metrics`, `~> 0.6.1`.

1. No migrations in this gem.
2. Existing metrics keep current behaviour (`scope_value: :workspace_id`).
   The scope column is still compared to `Context#resolved_workspace_id`
   (`workspace_id`, else the root or access recording's recordable id).
3. Pass `scope_value: :root_recording_id` only when the model's
   `scope_attribute` stores the root recording's id (`root_recording.id`),
   not the workspace/recordable id. The value still comes from the
   already-authorized context. If that context has no root recording, Metrics
   does not fall back to `workspace_id`; it raises the usual authorization
   error unless an `authorized_relation` is already on the context.
4. Any other `scope_value` raises `ArgumentError` at registration.

If you are still on `0.6.0` or older, complete that release's notes first.

## Upgrading to 0.6.0

`0.6.0` adds per-metric rollup options and fails closed on bad dates, unknown
definition keys, and invalid config. Update the host dependency to
`recording_studio_metrics`, `~> 0.6.0`.

1. No migrations in this gem.
2. New registration options default to current behaviour:
   - `bucket_timezone:` — IANA zone for time-series buckets. Omit it to keep
     using the request/context timezone.
   - `fill_gaps:` — `true` for count and sum (empty buckets stay `0`). Set
     `false` to omit empty buckets. Average still does not zero-fill.
   - `removal_column:` — column used for population-at-end counts. Default
     `deleted_at`. Pass `trashed_at` for Trashable models.
3. An invalid context timezone and a non-time `start_at`/`end_at` value now
   raise `RecordingStudioMetrics::Errors::InvalidDateRange` instead of
   `ArgumentError` or `TypeError`.
4. Unknown keys on a metric definition raise `ArgumentError` at registration.
5. `config/recording_studio_metrics.yml` is still optional. A missing file is
   ignored; invalid YAML raises.
6. The engine no longer ships a template pages migration, a Tailwind `@source`
   installer, or a `head :ok` home route.

If you are still on `0.5.0` or older, complete that release's notes in
`CHANGELOG.md` first.
