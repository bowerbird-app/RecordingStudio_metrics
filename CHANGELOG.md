# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.2] - 2026-10-09

### Fixed
- Time series on `date` columns include the current day. The default window ends at the current time, and casting that timestamp to a date was dropping today.
- `date` columns truncate with `date_trunc(interval, column::timestamp)::date`, so a stored day stays on that day in every timezone. Timestamp columns still use timezone-aware `date_trunc`.
- String `start_at` and `end_at` values parse as ISO 8601 dates or datetimes in the request timezone. Unparseable values raise `RecordingStudioMetrics::Errors::InvalidDateRange`.

### Upgrade notes
- Charts of a `date` column now include the day that contains `end_at`, including today when the end is left as the current time. Each row stays on its own date in every timezone. Timestamp-column series are unchanged.
- Pass a time, or an ISO 8601 date or datetime, for `start_at` and `end_at`. Values that are not dates or datetimes raise `InvalidDateRange`.

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_metrics/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/bowerbird-app/RecordingStudio_metrics/compare/v0.2.1...v0.2.2
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_metrics/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_metrics/releases/tag/v0.1.0
