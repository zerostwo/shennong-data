# Plan a DataBundle materialization

Plan a DataBundle materialization

## Usage

``` r
sn_conversion_plan(
  x,
  target,
  source = c("auto", "query", "artifact"),
  assay = NULL,
  layer = NULL,
  features = NULL,
  observations = NULL,
  fields = NULL,
  allow_large = FALSE,
  ...
)
```

## Arguments

- x:

  A
  [ShennongData](https://zerostwo.github.io/shennong-data/reference/ShennongData.md)
  handle or materialized result.

- target:

  Target matrix or analysis container.

- source:

  Query, Artifact, or automatic source selection.

- assay:

  Optional assay name.

- layer:

  Exact declared measurement name.

- features:

  A bounded feature identifier vector.

- observations:

  Reserved for compatible observation selection.

- fields:

  Observation metadata fields.

- allow_large:

  Whether to bypass configured size guards.

- ...:

  Converter-specific controls.

## Value

A conversion plan describing the DataBundle contract, completeness
requirement, and output orientation.
