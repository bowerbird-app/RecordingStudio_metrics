# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-10-16

### Added
- Discovery catalog entries include `group_by`, `date_range` (`supported`, `max_period_seconds`, `max_buckets`), `timezone` (configured default), and `freshness`, alongside existing `unit` and `supported_intervals`.
- Optional registration options `group_by:` and `freshness:`. Defaults: `group_by` is `[]`; freshness derives from caching (`{ cached: true, max_age_seconds: }` or `{ cached: false }`). Existing registrations need no changes.
- `RecordingStudioMetrics.discover(resource:)` and API catalog filter `filters[resource]`, using the same `filters` object as metric execution. Unknown catalog filters are rejected.
- `group_by` execute option (Ruby `execute(group_by:)`, API `group_by` query param, documented in OpenAPI). Values must be in the metric's catalog `group_by` list; others raise `RecordingStudioMetrics::Errors::InvalidGroupBy` (422 on the API). Supported on count, sum, average, and created-during-period time series, together with `from`/`to`/`interval` and filters. Registering `group_by:` on breakdown, custom, or population-at-end time series raises `ArgumentError`.
- Grouped results keep the ungrouped `value`/`data` total and add `group_by`, `groups` (`[{ key:, value: }]` or `[{ key:, data: }]`), and `other`.
- Minimum group size: groups with fewer rows than `config.min_group_size` (default 5, per-metric `min_group_size:`) are merged into an unlabeled `other` bucket (`{ groups:, value: }` or `{ groups:, data: }`), so kept groups plus `other` add up to the total. The effective threshold appears in the catalog as `min_group_size`.
- Optional `labels:` callable on a metric. Execute calls it once with the kept group values and the grouped column. The callable returns a Hash of raw value to string. Breakdown `data` rows and `group_by` `groups` rows include `label` beside `key` when that string is present. A missing or blank label is left off the row. `other` has no `label`. Metrics without `labels:` return the same hashes as before. The callable is omitted from catalog metadata and `#version`.

### Upgrade notes
- No host change is required. Pass `labels:` when a kept group key needs a display name, and read `label` on that row. The callable returns the strings. Metrics does not query other tables. Consumers that only read `key` keep working.

## [0.3.0] - 2026-10-13

### Added
- Metric query params accept `from` as an alias for `start` and `to` as an alias for `end` (API execute endpoint and OpenAPI catalog).
- When both forms are provided with different values, raises `RecordingStudioMetrics::Errors::InvalidDateRange`. Matching values are accepted. Existing `start`/`end` and legacy `start_at`/`end_at` behaviour is unchanged.

## [0.2.2] - 2026-10-09

### Fixed
- Time series on `date` columns include the calendar day of a non-midnight `end_at`, so the default window includes today. The range starts on `start_at`'s calendar day and does not include other days from a week, month, or year bucket.
- `date` columns truncate with `date_trunc(interval, column::timestamp)::date`, so a stored day stays on that day in every timezone. Timestamp columns still use timezone-aware `date_trunc`.
- String `start_at` and `end_at` values are parsed in the request timezone. Unparseable values raise `RecordingStudioMetrics::Errors::InvalidDateRange`.

### Upgrade notes
- Charts of a `date` column now include the day that contains `end_at`, including today when the end is left as the current time, and leave out days before `start_at` or after `end_at`. Each row stays on its own date in every timezone. Timestamp-column series are unchanged.
- Pass a time, or a string parsed in the request timezone, for `start_at` and `end_at`. Values that do not parse raise `InvalidDateRange`.

## [0.2.0] - 2026-10-09

### Added
- Optional `api_authorize:` callable on `RecordingStudioMetrics.register` so an owning gem can apply its own API access check.
- When that callable is truthy for a `blast_radius: :site` resource, API execute and discovery use site scope. Falsy denies with 403 and hides the metric. Resources without the callable are unchanged.

### Upgrade notes
- No host change is required. Site metrics remain denied over the API unless the owning gem passes `api_authorize:`.

## [0.1.0] - 2026-10-08

### Added
- `RecordingStudioMetrics` registry, DSL, execution, discovery, and result contract.
- Standard metric types: count, sum, average, breakdown, time series, and custom calculators.
- Fail-closed authorization context with recording, root/workspace, and site scopes.
- Optional Recording Studio API GET endpoint registration and Admin result adapters.
- Optional cache keys that include authorization scope.
- Dummy host examples for members, projects, and child-image metrics.

### Fixed
- Context workspace/root/recording isolation is always applied; metric `scope:` lambdas run on top of it.
- API discovery, missing recording ids, and Admin site flags fail closed.
- API handlers raise RS_API error classes (404/403/422) instead of returning errors as HTTP 200.
- Breakdown supports sum and average; historical timeseries computes population at end of period.
- PostgreSQL `date_trunc` is isolated behind an adapter; standard metrics wrap database errors.

[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_metrics/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_metrics/compare/v0.2.2...v0.3.0
[0.2.2]: https://github.com/bowerbird-app/RecordingStudio_metrics/compare/v0.2.1...v0.2.2
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_metrics/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_metrics/releases/tag/v0.1.0
