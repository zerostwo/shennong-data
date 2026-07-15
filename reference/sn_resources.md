# List Resources visible to the current ShennongDB connection

Resource discovery uses the permission-filtered Agent manifest and never
loads Resource payloads.

## Usage

``` r
sn_resources(connection = sn_connection(), search = NULL)
```

## Arguments

- connection:

  A ShennongDB connection.

- search:

  Optional local text filter over identifiers and descriptions.

## Value

A data frame with one visible Resource per row.
