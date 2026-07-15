# ShennongData

`ShennongData` is a lazy R client for ShennongDB. It discovers resource
metadata first and only downloads data when you explicitly materialize a
query.

## Installation

Install the development version from GitHub:

``` r

install.packages("remotes")
remotes::install_github("zerostwo/shennong-data")
```

## Basic usage

Connect to a ShennongDB server and create a metadata-only resource
handle:

``` r

library(ShennongData)

con <- sn_connect(
  "https://your-shennongdb.example",
  token = Sys.getenv("SHENNONG_TOKEN")
)

x <- sn_load_data("toil", connection = con)
x
sn_schema(x)
sn_layers(x)
```

Choose a view and build a lazy query before collecting data:

``` r

observations <- sn_obs(x)
expression <- sn_assay(x)

sn_show_query(observations)
result <- collect(observations)
```

Use bounded fetches or artifacts for larger data transfers:

``` r

sn_fetch_data(
  x,
  features = c("YTHDF2", "FTO"),
  layer = "log2_tpm_plus_0.001",
  limit = 100
)
sn_artifacts(x)
```

## Agent and MCP integration

Check the live API contract and discover visible Resources from R:

``` r

sn_api_compatibility(con)
sn_resources(con, search = "bulk")
```

The package also includes a read-only stdio MCP server:

``` sh
SHENNONG_URL=http://127.0.0.1:18080 \
  Rscript -e 'ShennongData::sn_mcp_serve()'
```

It exposes bounded tools for compatibility checks, Resource discovery
and inspection, identifier resolution, query planning, and small data
fetches. See
[`docs/agent-integrations.md`](https://zerostwo.github.io/shennong-data/docs/agent-integrations.md)
for client configuration and safety limits.

See the [pkgdown site](https://zerostwo.github.io/shennong-data/) for
the complete function reference.
