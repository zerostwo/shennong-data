# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Typed serializable query plans, strict filter/select pushdown, feature
  resolution, bounded multi-feature fetch, and provenance-aware results.
- Artifact listing/download verification, conversion planning, biological
  object adapters, relation/collection helpers, and server capability flags.
- Align gene resolution with the server GET contract, use Artifact-ID download
  routes, consume cursor pages, and expose Arrow/JSONL streaming hooks.

### Changed

- Expose metadata-first query, artifact, conversion, and collection APIs while
  preserving the existing Resource handle contract.

### Testing

- Add Phase 2–5 contract coverage for fetch, conversion guards, artifacts, and
  collections, cursor pages, capability-gated batch/axis paths, and structured
  API errors.

## [0.1.2] - 2026-07-09

### Added

- Add compatibility entrypoints used by shennong-db clients: `sn_set_api_url`,
  `sn_get_api_url`, `sn_set_api_token`, `sn_get_api_token`.
- Add compatibility helpers `sn_query_spec`, `sn_query`, and `sn_fetch_genes`.
- Add `sn_plot_survival` and legacy bearer-token handling on data handles.

### Changed

- Preserve the legacy query token field (`api_url`, `token`) in `sn_load_data()`
  and emit `Authorization` when requesting `/v1/query`.

## [0.1.1] - 2026-07-09

### Added

- Add `sn_admin_token()` to configure and read the admin token from options
  (with fallback to `SHENNONG_ADMIN_API_KEY`).
- Add optional `admin_token` argument to `sn_register_dataset()`,
  `sn_ingest()`, and `sn_upload_dataset()`.
- Send admin token through `X-Shennong-Admin-Key` for admin operations.

### Changed

- Extend internal HTTP helpers to support layered request headers and include the
  admin header for mutation endpoints.

### Documentation

- Add man page entries for `sn_admin_token()` and `admin_token` parameters.

### Testing

- Add coverage for admin token storage and header generation behavior.

## [0.1.0] - 2026-07-07

### Added

- Initial package scaffold (`ShennongData`) with lazy data loading, querying and
  plotting helpers for Shennong Data Server.

[Unreleased]: https://github.com/zerostwo/shennong-data/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/zerostwo/shennong-data/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/zerostwo/shennong-data/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/zerostwo/shennong-data/releases/tag/v0.1.0
