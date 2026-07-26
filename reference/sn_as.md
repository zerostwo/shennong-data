# Materialize a matrix or analysis container

`matrix` and `sparse` targets use feature-by-observation orientation.
SummarizedExperiment and Seurat conversions preserve DataBundle
provenance. Analysis containers require a complete DataBundle by
default. The `allow_partial` escape hatch is explicit because missing
features or axes can otherwise be mistaken for biological zeroes.

## Usage

``` r
sn_as(
  x,
  target,
  source = c("auto", "query", "artifact"),
  assay = NULL,
  layer = NULL,
  features = NULL,
  observations = NULL,
  fields = NULL,
  allow_large = FALSE,
  allow_partial = FALSE,
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

- allow_partial:

  Whether an incomplete result may be converted to an analysis container
  after provenance review.

- ...:

  Converter-specific controls.

## Value

A matrix, `dgCMatrix`, or requested analysis container.
