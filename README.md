# RecordingStudioMetrics

Shared metrics and analytics for Recording Studio recordables and ordinary Active Record models. Define a metric once, then execute it from Admin, API, jobs, host dashboards, and MCP tools.

This gem is the calculation engine. It does not render charts, authenticate callers, or own recordable business logic.

Companion pins used by the dummy host: Recording Studio dummy GitHub tag `v4.6.0`, Accessible dummy GitHub tag `v0.18.0`, Root Switchable dummy GitHub tag `v0.9.0`, API dummy GitHub tag `v0.7.0`, Admin dummy GitHub tag `v2.3.0`, Trashable dummy GitHub tag `v0.10.0` (`require: false`), Cache dummy GitHub tag `v0.5.0`, FlatPack dummy GitHub tag `v0.1.209`.

## Architecture

- **Definitions** — registered in the gem that owns the model (`RecordingStudioMetrics.register`).
- **Calculations** — `RecordingStudioMetrics.execute` runs one identifier against a trusted context.
- **Presentation** — Admin, host views, or agents format the result. This gem returns JSON-ready result objects, not chart library config.
- **API exposure** — opt-in. Registration never publishes an endpoint.

## Installation

```ruby
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics"
```

```bash
bundle install
bin/rails generate recording_studio_metrics:install
```

## Configuration

```ruby
RecordingStudioMetrics.configure do |config|
  config.default_timezone = "UTC"
  config.max_timeseries_buckets = 400
  config.max_reporting_period = 366.days
  config.cache_enabled = true
  config.default_cache_ttl = 5.minutes
end
```

## Registering metrics

Recordable-owning gems register from their own initializer. Do not put business-specific metrics in this gem, and do not patch models.

Simple:

```ruby
RecordingStudioMetrics.register(:members, model: Member, scope_attribute: :workspace_id) do
  count :total, title: "Total members"
end

result = RecordingStudioMetrics.execute(
  "members.total",
  context: RecordingStudioMetrics::Context.new(actor: current_user, scope: :root, workspace_id: workspace.id)
)
result.value
```

Complex (child recordings, no N+1):

```ruby
RecordingStudioMetrics.register(:projects, model: Project, scope_attribute: :workspace_id) do
  custom :with_images, result_type: :scalar do |relation, _context|
    relation.where(id: ProjectImage.select(:project_id)).distinct.count
  end
end
```

Custom calculators receive the already-authorized relation. Use that relation. Do not start from `Model.all`.

## Standard types

`count`, `sum`, `average`, `breakdown`, `timeseries`, plus `custom`. Measurement and grouping stay separate: a time series can count rows or sum a field (`measurement: :sum`).

Filters must be declared. Unknown names, unknown operators, and undeclared columns are rejected. Values are bound as query parameters.

Time series use half-open windows (`start` inclusive, `end` exclusive), chronological buckets, and zero-fill for count/sum gaps. Timestamp columns use timezone-aware `date_trunc` on PostgreSQL. `date` columns truncate the calendar value with no timezone (`date_trunc(interval, column::timestamp)::date`). Their filter runs from the calendar day of `start_at` through the day that contains `end_at`, and stops on `end_at`'s own day when that instant is midnight, so coarser buckets do not pull in days outside the window. `start_at` and `end_at` accept a time or a string parsed in the request timezone; a string that does not parse raises `RecordingStudioMetrics::Errors::InvalidDateRange`. Missing periods for averages stay empty (`nil`), not a fake zero. Creation-in-period is not the same as population-at-end-of-period; set `semantics:` when you mean the latter.

## Scope and authorization

Trusted `RecordingStudioMetrics::Context` only. Scope is never taken from metric filters or API query params.

| Scope | Required |
| --- | --- |
| `recording` | access recording or authorized relation |
| `root` | root recording, workspace id, or authorized relation |
| `site` | `site_authorized: true` |

Missing actor/system identity, scope, or workspace isolation fails closed. Root metrics never include other workspaces. Site metrics require an explicit site flag.

## Discovery

```ruby
RecordingStudioMetrics.definitions
RecordingStudioMetrics.find("members.total")
RecordingStudioMetrics.for_resource(:members)
RecordingStudioMetrics.discover(context: context, api: :admin)
RecordingStudioMetrics.discover(context: context, api: :admin, resource: :members)
```

Discovery does not calculate. `discover(api:)` returns only metrics exposed to that named API. `resource:` limits the catalog to one resource; the API catalog takes `filters[resource]=members`.

Each catalog entry includes `unit`, `group_by`, `supported_intervals`, `default_interval`, `date_range` (`supported`, `max_period_seconds`, `max_buckets`), `timezone` (the configured default; the `timezone` query param overrides it), and `freshness`. Registrations may set `group_by:`, `min_group_size:`, and `freshness:`. Without them `group_by` is empty and freshness reflects cache settings.

## Grouping

```ruby
count :total, group_by: %i[country status]
RecordingStudioMetrics.execute("members.total", context: context, group_by: "country")
```

`group_by` (API query param of the same name) must be one of the metric's catalog `group_by` columns, otherwise `InvalidGroupBy` (422). It works on count, sum, average, and created-during-period time series, with `from`/`to`/`interval` and filters. The result keeps the ungrouped `value` or `data` and adds `group_by`, `groups` (`[{ key:, value: }]`, or `[{ key:, data: [...] }]` for time series), and `other`.

Pass `labels:` on the definition when group keys need a human name (UUID version ids, and similar). The callable receives the kept values and the grouped column, and returns a Hash of raw value to string. Kept breakdown `data` rows and execute `groups` rows then include `label` next to `key`. Omit a value, or return a blank string, to leave that row unlabelled. Metrics does not look up other tables. Existing payloads stay the same when `labels:` is absent. `other` stays unlabelled.

```ruby
breakdown :by_version,
          field: :terms_version_id,
          labels: ->(values, _column) { Version.where(id: values).pluck(:id, :title).to_h }
# [{ key: "a1-uuid", label: "v2.1", value: 12 }, { key: "b2-uuid", value: 4 }]
```

Privacy: groups with fewer rows than `config.min_group_size` (default 5; per-metric `min_group_size:`) are merged into `other` (`{ groups: <merged group count>, value: }` or `{ groups:, data: }`) without their keys. Count and sum merge by addition and average by row-weighted mean, so kept groups plus `other` equal the total. For time series the threshold uses each group's rows across the whole requested period.

## API integration

Optional. Requires RecordingStudio_api. Endpoints are GET-only. RS_API v0.7.0 matches registered routes by HTTP verb as well as path.

```ruby
RecordingStudioMetrics.expose_to_api("members.total", api: :admin)
RecordingStudioMetrics::Api.register!(api: :admin)
```

Handlers only call `discover` / `execute` and raise RS_API error classes for 404 / 403 / 422. See `docs/companion-changes.md` for remaining companion hooks.

Execute query params: `filters`, `interval`, `start` (aliases: `from`, `start_at`), `end` (aliases: `to`, `end_at`), `timezone`. If `start` and `from` (or `end` and `to`) are both provided with different values, the request fails with `InvalidDateRange`.

Site-wide models (no workspace column) stay denied over the API unless the owning gem passes its own access check at registration:

```ruby
RecordingStudioMetrics.register(
  :users,
  model: User,
  blast_radius: :site,
  api_authorize: ->(context) { MyGem::Access.staff?(context.actor) }
) do
  count :total, title: "Everyone on the site", expose: { api: [:admin] }
end
```

`api_authorize` receives the RS_API request context. Falsy denies with 403 and hides the metric from discovery. Truthy on a `blast_radius: :site` resource grants site scope for that call. Omit it and `Context.from_api` behaves as before.

## Admin integration

Optional. Requires RecordingStudio_admin. Use `RecordingStudioMetrics::Admin.scalar_value` / `chart_series`, or `Admin.widget` to build a standalone Admin widget. Host screens can also use `summary_value`, `chart_series_proc`, and `attach_filters(..., only:)` against the existing Screen `summary` / `chart` / `widget` / `filter` API. Chosen screen filter values are passed into `execute`. Screen has no `metric_card` / `metric_chart` hook yet; do not monkey-patch Screen.

## Caching

Works without RecordingStudio_cache. When that gem is loaded and the context has a Recording, fetches use `RecordingStudioCache.fetch` with vary: identifier, definition version, authorization scope, filters, interval, timezone. Site-wide metrics without a Recording fall back to `Rails.cache`. Metrics may set `cache_for: 5.minutes` or `cacheable: false`. Cached values are only as fresh as the TTL.

## Performance

Prefer SQL aggregates. Bound reporting windows. Index `created_at` and workspace/root foreign keys used in filters. Custom metrics should `COUNT(DISTINCT parent.id)` when joining children.

## Testing

```bash
bundle exec rake test
bundle exec rake test:all
```

Dummy login: `admin@admin.com` / `Password`. Dummy GitHub tags are listed at the top of this README.
