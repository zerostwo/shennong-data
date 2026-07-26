# Data materialization maintainer contract

Audit date: 2026-07-26

ShennongData is the read-only, user-facing data client in the Shennong
ecosystem. Production callers should connect to the Shennong OS/gateway with a
PAT and, for governed work, `sn_connect(project_id = ...)`. The client must
never accept or emit a DB admin key.

When capabilities declare `project_scope_required = true`, public catalog
discovery is not sufficient for materialization. `sn_api_compatibility()` must
reject a projectless connection before inspection/query and direct the caller
to reconnect with a canonical Project UUID. Servers that omit the field retain
their existing projectless public/direct DB behavior.

## Cross-package boundary

- ShennongDB target input contract:
  `shennong.dev/data-bundle/v1`.
- Shennong analysis result contract:
  `shennong.dev/analysis-result-bundle/v1`.
- A legacy DB Resource without `metadata.data_bundle.schema_version` is a
  `client_projection`, not an official complete DataBundle.
- ShennongData matrices are always feature-by-observation.
- The current TOIL measurement name is exactly
  `log2_tpm_plus_0.001`; it is transformed expression, not counts.

The integration test in
`tests/testthat/test-security-materialization-contract.R` passes a
ShennongData-compatible SummarizedExperiment to the public
`Shennong::sn_run_bulk(..., workflow = "qc")` entry point and validates the
result with `Shennong::sn_validate_result()`.

## Completeness invariants

1. Matrix/sparse query paths request the observation axis when the server
   advertises it and no context filter changes the axis.
2. An absent/failed axis, batch `missing_features`, a failed request, or an
   unsafe query limit is represented in `incomplete_reasons` and makes the
   result partial.
3. Sparse materialization requires `implicit_zero = TRUE`, uses direct
   `Matrix::sparseMatrix()` construction, and calls `Matrix::drop0()`.
4. Dense missing coordinates are `NA` unless the measurement explicitly
   declares structural zero semantics.
5. SummarizedExperiment, SingleCellExperiment, Seurat, and other analysis
   containers reject partial inputs unless the caller explicitly supplies
   `allow_partial = TRUE`.

## Artifact trust boundary

- Same-origin Artifact endpoints may carry the user bearer token and Project
  header.
- A foreign presigned URL must be HTTPS and receives neither
  `Authorization` nor `X-Shennong-Project-Id`.
- Redirects are followed manually with automatic redirect forwarding disabled.
  Once a chain leaves the connection origin, credentials stay disabled for all
  remaining hops.
- Literal/local destinations are rejected; an optional exact host allowlist is
  available through `ShennongData.allowed_artifact_hosts`.
- Local paths are disabled unless `trusted_local = TRUE` and `local_root` is
  configured. Normalization and symlink resolution must remain under the root.

## Project scope bridge

With `project_id` configured, authenticated same-origin calls carry
`X-Shennong-Project-Id`. Query, batch, and stream bodies also contain
`project_id` for the OS gateway to authorize and remove before DB forwarding.
The configured value must be a canonical Project UUID; aliases and slugs are
rejected locally. With no Project configured, no header or body field is added.
