# Metadata-first ShennongDB Resource handles

Connect to ShennongDB, discover a Resource, and select a metadata or
assay view without materializing data values.

## Usage

``` r
sn_connect(url = sn_server_url(), token = NULL, profile = "default",
  cache_dir = tools::R_user_dir("ShennongData", "cache"), timeout = 60,
  retries = 3L, throttle = 4, user_agent = NULL, set_default = TRUE)
sn_load_data(resource, version = NULL,
  view = c("auto", "observations", "assay", "resource"),
  connection = sn_connection(), refresh = FALSE,
  validate = c("metadata", "capabilities", "none"), ...)
sn_obs(x)
sn_var(x)
sn_assay(x, assay = NULL, layer = NULL)
```

## Arguments

- url:

  ShennongDB base URL.

- token:

  A session-only bearer token.

- profile:

  Authentication profile name.

- cache_dir:

  Metadata cache directory.

- timeout:

  Request timeout in seconds.

- retries:

  Maximum retry attempts.

- throttle:

  Maximum requests per second.

- user_agent:

  Optional user-agent string.

- set_default:

  Whether to use the connection by default.

- resource:

  A Resource ID.

- version:

  Optional Resource version.

- view:

  The Resource view to return.

- connection:

  A negotiated ShennongDB connection.

- refresh:

  Whether to refresh cached metadata.

- validate:

  Metadata validation level.

- ...:

  Additional arguments reserved for compatible methods.

- x:

  A `ShennongData` handle.

- assay:

  An optional declared assay.

- layer:

  An optional declared measurement.

## Value

A `ShennongData` handle or its requested metadata.

## Examples

``` r
if (FALSE) { # \dontrun{
sn_connect("http://127.0.0.1:8000")
toil <- sn_load_data("toil")
dim(toil)
dim(sn_assay(toil))
} # }
```
