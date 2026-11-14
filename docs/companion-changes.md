# Companion gem changes

RecordingStudioMetrics integrates only through extension points the companion gems already expose. This run does not open PRs on those repositories.

## RecordingStudio_api (v0.23.1)

Done here: `RecordingStudioMetrics::Api.register!(api:)` calls `RecordingStudioApi.register_endpoint` for GET-only `metrics` and `metrics/:resource/:name`. Handlers call `discover` / `execute`. Unknown, unauthorized, and invalid-filter errors are raised as `RecordingStudioApi::NotFoundError`, `AuthorizationError`, and `InvalidActionInputError` so `ApiController` maps them to 404 / 403 / 422. The dummy pin is GitHub tag `v0.23.1`. That tag needs Moveable `~> 4.0`, Logs, and Trashable; the dummy pins Moveable `v4.1.1` and Icons `v0.2.1` with `require: false`.

1. Dispatch registered endpoints by HTTP verb as well as path. **Done in RS_API v0.6.7+** (`registered_endpoint_request_match` uses `match(path:, http_verb:)`). Metrics stays GET-only by registration, not because the dispatcher ignores the verb.

Needed from the API gem:

2. Optional: a documented hook to attach OpenAPI query parameters for filters/interval/start/end without putting that logic in each handler. (This gem currently passes an `openapi[:parameters]` array on the execute endpoint.)
3. Optional: `RegisteredEndpointsController` support for handler `{ json:, status: }` results. Status codes currently require raising the API error classes above.

## RecordingStudio_admin (v2.13.0)

Done here: `RecordingStudioMetrics::Admin` converts results into scalar values and `{ name:, data: [{ x:, y: }] }` series. It does not construct `RecordingStudioAdmin::Widget` or authorize Admin. The dummy host builds Admin widgets with Admin's Widget API and `summary_value` / `chart_series_proc`. `Admin.attach_filters(screen, identifier, only:)` maps chosen metric filters onto `Screen.filter` and passes chosen filter values into `execute`. The dummy app registers a `MetricsAnalyticsScreen` that uses those public APIs. The dummy pin is GitHub tag `v2.13.0`. Admin `v2.13.0` also loads RecordingStudio_logs. The dummy pin for Logs is GitHub tag `v0.7.4`.

Needed from the Admin gem:

1. `RecordingStudioAdmin::Screen.metric_card(identifier, **)` and `metric_chart(identifier, **)` DSL methods that call the metrics execution service. Screen currently has `summary`, `chart`, `widget`, and `query` only.
2. Optional: a first-class filter bridge so a declared metric filter can be attached as a screen filter without copying filter metadata by hand. (`Admin.attach_filters(..., only:)` is the host-side workaround.)

## RecordingStudio_cache (v0.6.3)

Done here: when Cache is loaded and the context has a Recording (`id` + `root_recording_id`), fetches use `RecordingStudioCache.fetch` with a vary hash that includes metric id, definition version, authorization scope, filters, interval, and timezone.

The dummy pin is GitHub tag `v0.6.3`. Hosts with access should add the gem.

Needed from the Cache gem:

1. A non-recording fetch API for site-wide metrics (no Recording object). Site-wide metrics currently fall back to `Rails.cache` so we do not invent a fake recording key.

## Recording Studio core

No core change is required to register metrics. Recordable-owning gems call `RecordingStudioMetrics.register` from their own initializers. When a grouped metric's keys are opaque (ids, UUIDs), the owning gem passes `labels:` on that definition. Follow-up work in gems such as RecordingStudio_terms_and_conditions adopts this hook. Metrics does not resolve those records itself.
