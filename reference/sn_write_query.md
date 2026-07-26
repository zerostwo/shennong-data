# Write a serializable ShennongData query plan

Write a serializable ShennongData query plan

## Usage

``` r
sn_write_query(x, path, format = c("json", "yaml"))
```

## Arguments

- x:

  A
  [ShennongData](https://zerostwo.github.io/shennong-data/reference/ShennongData.md)
  handle or materialized result.

- path:

  Destination JSON path.

- format:

  Query-plan format. JSON is currently supported.

## Value

`path`, invisibly.
