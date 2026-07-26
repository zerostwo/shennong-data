# Materialize a bounded ShennongDB query

Results carry `shennong.dev/data-bundle/v1` provenance. Until a Resource
explicitly declares that contract, the result is labeled
`client_projection`. Matrix-like results are feature-by-observation.
Sparse materialization is permitted only when the measurement declares
`implicit_zero = TRUE`; declared observation axes are fetched when the
server supports them, and missing axes or features are reported as
partial provenance.

## Usage

``` r
sn_fetch_data(
  x,
  features = NULL,
  observations = NULL,
  fields = NULL,
  context = NULL,
  assay = NULL,
  layer = NULL,
  operation = NULL,
  shape = c("long", "wide", "matrix", "sparse"),
  resolve = c("auto", "strict", "never"),
  source = c("auto", "query", "artifact"),
  limit = NULL,
  allow_large = FALSE,
  cache = NULL,
  fail_fast = TRUE,
  ...
)
```

## Arguments

- x:

  A
  [ShennongData](https://zerostwo.github.io/shennong-data/reference/ShennongData.md)
  handle.

- features:

  A bounded feature identifier vector.

- observations:

  Reserved; observation selection is not supported by the current server
  query contract.

- fields:

  Observation metadata fields to retain.

- context:

  Named exact context filters.

- assay:

  Optional assay name.

- layer:

  Exact declared measurement name, for example `log2_tpm_plus_0.001` for
  the current TOIL Resource.

- operation:

  Optional declared server operation.

- shape:

  Output shape: long, wide, dense matrix, or sparse `dgCMatrix`.

- resolve:

  Feature-resolution policy.

- source:

  Query, Artifact, or automatic source selection.

- limit:

  Optional per-feature query bound.

- allow_large:

  Whether to bypass configured size guards.

- cache:

  Reserved for compatible cache implementations.

- fail_fast:

  Whether the first feature request failure stops the query.

- ...:

  Additional Artifact materialization controls, including
  `trusted_local` and `local_root`.

## Value

A provenance-aware materialized result.
