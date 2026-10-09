# Companion gem changes

RecordingStudioMetrics integrates only through extension points the companion gems already expose. This run does not open PRs on those repositories.

## RecordingStudio_api (v0.6.7)

Done here: `RecordingStudioMetrics::Api.register!(api:)` calls `RecordingStudioApi.register_endpoint` for GET-only `metrics` and `metrics/:resource/:name`. Handlers call `discover` / `execute`. Unknown, unauthorized, and invalid-filter errors are raised as `RecordingStudioApi::NotFoundError`, `AuthorizationError`, and `InvalidActionInputError` so `ApiController` maps them to 404 / 403 / 422.

1. Dispatch registered endpoints by HTTP verb as well as path. **Done in RS_API v0.6.7** (`registered_endpoint_request_match` uses `match(path:, http_verb:)`). Metrics stays GET-only by registration, not because the dispatcher ignores the verb.

Needed from the API gem:

2. Optional: a documented hook to attach OpenAPI query parameters for filters/interval/start/end without putting that logic in each handler. (This gem currently passes an `openapi[:parameters]` array on the execute endpoint.)
3. Optional: `RegisteredEndpointsController` support for handler `{ json:, status: }` results. v0.6.7 still `render json:` only; status codes currently require raising the API error classes above.

## RecordingStudio_admin (v2.1.0)

Done here: `RecordingStudioMetrics::Admin` converts results into scalar values and `{ name:, data: }` series, builds a standalone `RecordingStudioAdmin::Widget` when Admin is loaded, maps chosen metric filters onto `Screen.filter` via `Admin.attach_filters(screen, identifier, only:)`, passes the screen's chosen filter values into `execute`, and supplies `summary_value` / `chart_series_proc` callables for existing Screen `summary` / `chart` DSLs. The dummy app registers a `MetricsAnalyticsScreen` that uses those public APIs. The dummy pin is GitHub tag `v2.1.0` (admin i18n release: view strings via Rails I18n with an English locale file in the gem; rendered English unchanged; no host migrations or locale initializer).

Needed from the Admin gem:

1. `RecordingStudioAdmin::Screen.metric_card(identifier, **)` and `metric_chart(identifier, **)` DSL methods that call the metrics execution service. Screen currently has `summary`, `chart`, `widget`, and `query` only.
2. Optional: a first-class filter bridge so a declared metric filter can be attached as a screen filter without copying filter metadata by hand. (`Admin.attach_filters(..., only:)` is the host-side workaround.)

## RecordingStudio_cache (v0.4.0)

Done here: when Cache is loaded and the context has a Recording (`id` + `root_recording_id`), fetches use `RecordingStudioCache.fetch` with a vary hash that includes metric id, definition version, authorization scope, filters, interval, and timezone.

The dummy Gemfile documents the intended pin (`github: "bowerbird-app/RecordingStudio_cache", tag: "v0.4.0"`) but does not lock the gem. This repository's CI org token cannot clone that private repo (API and Admin clones succeed). Hosts with access should add the gem.

Needed from the Cache gem:

1. A non-recording fetch API for site-wide metrics (no Recording object). Site-wide metrics currently fall back to `Rails.cache` so we do not invent a fake recording key.

## Recording Studio core

No core change is required to register metrics. Recordable-owning gems call `RecordingStudioMetrics.register` from their own initializers.
