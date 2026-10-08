# RecordingStudioMetrics

Shared metrics and analytics for Recording Studio recordables and ordinary Active Record models. Define a metric once, then execute it from Admin, API, jobs, host dashboards, and MCP tools.

This gem is the calculation engine. It does not render charts, authenticate callers, or own recordable business logic.

Companion pins used by the dummy host: Recording Studio dummy GitHub tag `v4.3.0`, Accessible dummy GitHub tag `v0.11.1`, Root Switchable dummy GitHub tag `v0.5.1`, API dummy GitHub tag `v0.6.7`, Admin dummy GitHub tag `v2.0.6`, FlatPack dummy GitHub tag `v0.1.209`. Cache dummy GitHub tag `v0.4.0` is documented for hosts that can clone that private repo; this dummy bundle does not lock it because CI cannot fetch it.

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

Time series use half-open windows (`start` inclusive, `end` exclusive), timezone-aware `date_trunc` on PostgreSQL, chronological buckets, and zero-fill for count/sum gaps. Missing periods for averages stay empty (`nil`), not a fake zero. Creation-in-period is not the same as population-at-end-of-period; set `semantics:` when you mean the latter.

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
```

Discovery does not calculate. `discover(api:)` returns only metrics exposed to that named API.

## API integration

Optional. Requires RecordingStudio_api. Endpoints are GET-only. RS_API v0.6.7 matches registered routes by HTTP verb as well as path.

```ruby
RecordingStudioMetrics.expose_to_api("members.total", api: :admin)
RecordingStudioMetrics::Api.register!(api: :admin)
```

Handlers only call `discover` / `execute` and raise RS_API error classes for 404 / 403 / 422. See `docs/companion-changes.md` for remaining companion hooks.

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
