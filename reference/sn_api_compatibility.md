# Check ShennongData compatibility with a ShennongDB instance

Check ShennongData compatibility with a ShennongDB instance

## Usage

``` r
sn_api_compatibility(connection = sn_connection(), probe_discovery = TRUE)
```

## Arguments

- connection:

  A negotiated ShennongDB connection.

- probe_discovery:

  Whether to verify the permission-filtered Agent manifest.

## Value

A structured compatibility report.
