# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_metrics/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_metrics/releases/tag/v0.1.0
