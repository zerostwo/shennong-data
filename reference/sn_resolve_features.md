# Resolve feature identifiers for a ShennongDB Resource

Resolve feature identifiers for a ShennongDB Resource

## Usage

``` r
sn_resolve_features(
  x,
  features,
  resources = NULL,
  strict = TRUE,
  canonical = "ensembl_gene_stable_id"
)
```

## Arguments

- x:

  A
  [ShennongData](https://zerostwo.github.io/shennong-data/reference/ShennongData.md)
  handle.

- features:

  Feature identifiers or symbols to resolve.

- resources:

  Reserved for multi-Resource compatibility. Resolution is scoped to
  `x`.

- strict:

  Whether unresolved or ambiguous identifiers are errors.

- canonical:

  Canonical identifier namespace requested by the client.

## Value

A list preserving input, original, resolved, stable, and symbol
identifiers.
