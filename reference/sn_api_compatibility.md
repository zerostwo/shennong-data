# Check ShennongData compatibility with a Shennong API

The compatibility report honors a server capability declaration of
`project_scope_required = TRUE`. In that case, a connection without
`project_id` is incompatible for inspection and query even when public
Resource discovery is available. Servers that omit the capability,
including compatible public/direct ShennongDB endpoints, retain
projectless behavior.

## Usage

``` r
sn_api_compatibility(connection = sn_connection(), probe_discovery = TRUE)
```

## Arguments

- connection:

  A negotiated Shennong OS/gateway or ShennongDB connection.

- probe_discovery:

  Whether to verify the permission-filtered Agent manifest.

## Value

A structured compatibility report, including Project requirements and
actionable incompatibility reasons.
