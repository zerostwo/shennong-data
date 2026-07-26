# Connect to ShennongDB

Connect to ShennongDB

## Usage

``` r
sn_connect(
  url = sn_server_url(),
  token = NULL,
  profile = "default",
  project_id = NULL,
  cache_dir = tools::R_user_dir("ShennongData", "cache"),
  timeout = 60,
  retries = 3L,
  throttle = 4,
  user_agent = NULL,
  set_default = TRUE
)
```

## Arguments

- url:

  User-facing Shennong OS/gateway base URL. An explicit public or direct
  ShennongDB URL remains supported.

- token:

  Session-only bearer token; it is never stored in the returned object.

- profile:

  Authentication profile name.

- project_id:

  Optional Shennong project UUID or stable identifier used to scope
  governed gateway requests.

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

  Whether to register this as the default connection.
