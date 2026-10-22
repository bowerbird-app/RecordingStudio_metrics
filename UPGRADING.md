# Upgrading RecordingStudioMetrics

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
