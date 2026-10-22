# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.0] - 2026-10-22

### Added
- Per-metric `bucket_timezone:` for time-series rollups. Default is the request/context timezone.
- Per-metric `fill_gaps:` (`true` for count and sum). Set `false` to omit empty buckets instead of filling `0`.
- Per-metric `removal_column:` for population-at-end counts. Default `deleted_at` (pass `trashed_at` for Trashable).
- Definition keys are allowlisted. Unknown options raise `ArgumentError` at registration.

### Changed
- Invalid context timezones and non-time window values raise `RecordingStudioMetrics::Errors::InvalidDateRange`.
- Missing YAML config is still ignored; invalid config raises.
- Install generator no longer injects Tailwind `@source` paths.
- Engine home controller, root route, and unused pages migration are gone.
- Committed `coverage/` output is removed and gitignored.

### Upgrade notes
- See `UPGRADING.md`. Existing registrations keep current behaviour. New options are opt-in.

## [0.5.0] - 2026-10-19

### Changed
- `Admin.chart_series` points are `{ x:, y: }` hashes. ApexCharts 3.45.1 (via Flatpack) treats `[date, value]` pairs as `x=0`, so the chart is empty.

### Upgrade notes
- Callers that read pair points (`point[0]`, `point[1]`) should read `x` and `y`.

### Added
- Catalog entries include `group_by`, `date_range`, `timezone`, and `freshness`.
- Registration options `group_by:` (default `[]`) and `freshness:` (from cache settings).
- `discover(resource:)` and API `filters[resource]`. Unknown catalog filters are rejected.
- Execute `group_by` (Ruby and API). Values must be in the metric's catalog list or `InvalidGroupBy` (422). Allowed on count, sum, average, and created-during-period time series. Registering it on breakdown, custom, or population-at-end series raises `ArgumentError`.
- Results keep the ungrouped total and add `groups` plus `other`.
- Groups smaller than `min_group_size` (default 5) merge into unlabeled `other`.

## [0.4.0] - 2026-10-16

### Added
- Optional `labels:` callable. It receives kept group values and the grouped column, and returns a Hash of raw value to display string. Breakdown `data` and `group_by` `groups` rows include `label` when that string is present. Blank labels are omitted. `other` has no `label`. The callable is not in catalog metadata or `#version`.
- `labels:` is allowed on breakdowns, and on count, sum, average, or created-during-period time series that declare `group_by:`. Other metrics raise `ArgumentError`.

### Upgrade notes
- No host change is required. Pass `labels:` when a group key needs a display name. Callers that only read `key` keep working.

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_metrics/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/bowerbird-app/RecordingStudio_metrics/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/bowerbird-app/RecordingStudio_metrics/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_metrics/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_metrics/compare/v0.2.2...v0.3.0
[0.2.2]: https://github.com/bowerbird-app/RecordingStudio_metrics/compare/v0.2.1...v0.2.2
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_metrics/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_metrics/releases/tag/v0.1.0
