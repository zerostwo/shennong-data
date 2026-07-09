# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Placeholder for upcoming changes.

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

[Unreleased]: https://github.com/zerostwo/shennong-data/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/zerostwo/shennong-data/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/zerostwo/shennong-data/releases/tag/v0.1.0
