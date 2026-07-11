
<!-- README.md is generated from README.Rmd. Please edit that file. -->

# ShennongData

<!-- badges: start -->

[![R-CMD-check](https://github.com/zerostwo/shennong-data/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/zerostwo/shennong-data/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/zerostwo/shennong-data/branch/main/graph/badge.svg)](https://app.codecov.io/gh/zerostwo/shennong-data)
<!-- badges: end -->

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
sn_fetch_data(x)
sn_artifacts(x)
```

See the [pkgdown site](https://zerostwo.github.io/shennong-data/) for
the complete function reference.
