# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Add the `shennong.dev/data-bundle/v1` client materialization contract for
  long, wide, dense, sparse, SummarizedExperiment, and Seurat outputs, with
  explicit completeness, axis, missing-feature, and zero-semantics provenance.
- Add optional governed Project scope through `sn_connect(project_id = ...)`,
  same-origin `X-Shennong-Project-Id`, query-body bridging, and MCP
  `SHENNONG_PROJECT_ID` configuration.
- Export the documented `sn_resolve_features()`, `sn_slice_head()`, and
  `sn_write_query()` helpers.
- Add an R-native read-only MCP stdio server with six bounded Agent tools for
  compatibility checks, Resource discovery/inspection, identifier resolution,
  query planning, and small provenance-aware fetches.
- Add a repository-local `shennong-data` Agent Skill, MCP installation guide,
  Resource discovery API, and programmatic API compatibility report.
- Typed serializable query plans, strict filter/select pushdown, feature
  resolution, bounded multi-feature fetch, and provenance-aware results.
- Artifact listing/download verification, conversion planning, biological
  object adapters, relation/collection helpers, and server capability flags.
- Align gene resolution with the server GET contract, use Artifact-ID download
  routes, consume cursor pages, and expose Arrow/JSONL streaming hooks.

### Changed

- Fetch declared observation axes before matrix/sparse materialization, build
  sparse matrices directly, remove explicit zero entries, and reject sparse
  output when missing coordinates are not declared structural zeroes.
- Restrict Artifact credentials to the connection origin, strip bearer and
  Project headers from foreign presigned redirects, require foreign HTTPS, and
  make local file access an explicit root-confined trusted mode.
- Require complete DataBundles for analysis-container conversion by default;
  retain `allow_partial = TRUE` as an explicit provenance-reviewed escape
  hatch.
- Document production use through the Shennong OS/gateway with a user PAT,
  never a DB admin key, and correct the TOIL layer to
  `log2_tpm_plus_0.001`.
- Fall back from a gateway-level `/version` `404`/`405` to
  `/api/v1/public-config` while retaining strict ShennongDB API-v1 negotiation.
- Refresh the contract matrix and frozen server version against the
  ShennongDB `1.0.0` contract exposed through the Shennong OS/gateway, without
  making a live-deployment claim.
- Expose metadata-first query, artifact, conversion, and collection APIs while
  preserving the existing Resource handle contract.

### Testing

- Add security and materialization contract tests for SSRF/local-path guards,
  credential-stripping redirects, Project scope, axis retrieval,
  `missing_features`, sparse structural zeroes, DataBundle provenance, and
  public Shennong bulk-QC consumption.
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
