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

In production, connect to the user-facing Shennong OS/gateway with a
personal access token (PAT) and the governed Project scope. Do not use a
database admin key:

``` r

library(ShennongData)

con <- sn_connect(
  Sys.getenv("SHENNONG_URL", "https://your-shennong-gateway.example"),
  token = Sys.getenv("SHENNONG_TOKEN"),
  project_id = Sys.getenv(
    "SHENNONG_PROJECT_ID",
    "550e8400-e29b-41d4-a716-446655440000"
  )
)

x <- sn_load_data("toil", connection = con)
x
sn_schema(x)
sn_layers(x)
```

Governed Project scope is UUID-only. `project_id` is normalized to
lowercase canonical `8-4-4-4-12` form; aliases and slugs are rejected
locally before any request. Use `project_id = NULL` only for explicitly
public/direct-DB access.

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

Matrix and container materializations carry the target
`shennong.dev/data-bundle/v1` provenance contract. Current Resources
that do not yet declare the full contract are explicitly labeled
`client_projection`; missing axes and batch `missing_features` remain
visible as partial provenance. Sparse output is available only for
measurements declaring `implicit_zero = TRUE`.

``` r

counts <- sn_fetch_data(
  x,
  features = c("gene-a", "gene-b"),
  layer = "counts",
  shape = "sparse"
)

sn_result_schema(counts)
sn_provenance(counts)$data_bundle
```

See the [data materialization
contract](https://zerostwo.github.io/shennong-data/vignettes/data-materialization-contract.Rmd)
for matrix orientation, zero semantics, Artifact trust boundaries, and
the public Shennong bulk-QC handoff.

## Agent and MCP integration

Check the live API contract and discover visible Resources from R:

``` r

sn_api_compatibility(con)
sn_resources(con, search = "bulk")
```

When a gateway advertises `project_scope_required = TRUE`,
[`sn_api_compatibility()`](https://zerostwo.github.io/shennong-data/reference/sn_api_compatibility.md)
reports a projectless connection as incompatible and instructs you to
reconnect with a canonical Project UUID. This does not change
projectless access to compatible public/direct DB endpoints that omit
the capability or advertise it as false.

The package also includes a read-only stdio MCP server:

``` sh
SHENNONG_URL=http://127.0.0.1:18081 \
  Rscript -e 'ShennongData::sn_mcp_serve()'
```

It exposes bounded tools for compatibility checks, Resource discovery
and inspection, identifier resolution, query planning, and small data
fetches. See
[`docs/agent-integrations.md`](https://zerostwo.github.io/shennong-data/docs/agent-integrations.md)
for client configuration and safety limits.

See the [pkgdown site](https://zerostwo.github.io/shennong-data/) for
the complete function reference.
