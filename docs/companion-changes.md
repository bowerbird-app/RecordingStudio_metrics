# Companion gem changes

RecordingStudioMetrics integrates only through extension points the companion gems already expose. This run does not open PRs on those repositories.

## RecordingStudio_api (v0.6.4)

Done here: `RecordingStudioMetrics::Api.register!(api:)` calls `RecordingStudioApi.register_endpoint` for GET-only `metrics` and `metrics/:resource/:name`. Handlers call `discover` / `execute`.

Needed from the API gem:

1. Dispatch registered endpoints by HTTP verb as well as path. Today `registered_endpoint_request_match` uses `match_path` and ignores the verb, so metrics stays GET-only and cannot share a path with another verb.
2. Optional: a documented hook to attach OpenAPI query parameters for filters/interval/start/end without putting that logic in each handler.
3. Optional: a first-class error mapper for addon error objects (`error.code`) so metrics errors are not left as handler JSON bodies.

## RecordingStudio_admin (v2.0.5)

Done here: `RecordingStudioMetrics::Admin` converts results into scalar values and `{ name:, data: }` series, and can build a standalone `RecordingStudioAdmin::Widget` when Admin is loaded.

Needed from the Admin gem:

1. `RecordingStudioAdmin::Screen.metric_card(identifier, **)` and `metric_chart(identifier, **)` DSL methods that call the metrics execution service. Screen currently has `summary`, `chart`, `widget`, and `query` only.
2. Optional: a filter bridge so a declared metric filter can be attached as a screen filter without copying filter metadata by hand.

## RecordingStudio_cache (v0.4.0)

Done here: when Cache is loaded and the context has a Recording (`id` + `root_recording_id`), fetches use `RecordingStudioCache.fetch` with a vary hash that includes metric id, definition version, authorization scope, filters, interval, and timezone.

Needed from the Cache gem:

1. A non-recording fetch API for site-wide metrics (no Recording object). Site-wide metrics currently fall back to `Rails.cache` so we do not invent a fake recording key.

## Recording Studio core

No core change is required to register metrics. Recordable-owning gems call `RecordingStudioMetrics.register` from their own initializers.
