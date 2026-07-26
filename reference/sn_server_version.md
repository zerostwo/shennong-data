# Return the negotiated ShennongDB server version

Return the negotiated ShennongDB server version

## Usage

``` r
sn_server_version(connection = sn_connection())
```

## Arguments

- connection:

  A ShennongDB connection.

## Value

The server version string, or `NULL` when unavailable.
