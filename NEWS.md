# ShennongData 0.2.0.9000

- Materialized results now target `shennong.dev/data-bundle/v1` with explicit
  client-projection, completeness, axis, missing-feature, orientation, and
  structural-zero provenance.
- `sn_connect(project_id = ...)` supports governed Shennong OS/gateway access
  with a user PAT. Project scope is added only to authenticated same-origin
  requests and query bodies; foreign Artifact redirects receive neither
  bearer nor Project headers.
- Non-`NULL` `project_id` values must now be canonical UUIDs and are normalized
  to lowercase before use. Former free-form Project aliases are rejected
  locally so the client matches the OS authorization header contract.
- Sparse output now requires `implicit_zero = TRUE`, retrieves declared
  observation axes when available, uses direct sparse construction, and drops
  explicit zero entries.
- Local Artifact paths require explicit trusted-local mode and confinement
  below a configured root.
- SummarizedExperiment and Seurat conversions preserve DataBundle provenance
  and reject partial inputs by default.
- `sn_resolve_features()`, `sn_slice_head()`, and `sn_write_query()` are now
  exported as documented.
