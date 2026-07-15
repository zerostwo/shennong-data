# R API workflow

```r
library(ShennongData)

con <- sn_connect(
  Sys.getenv("SHENNONG_URL", "http://127.0.0.1:18080"),
  token = Sys.getenv("SHENNONG_TOKEN")
)

sn_api_compatibility(con)
sn_resources(con, search = "bulk")

x <- sn_load_data("toil", connection = con)
sn_schema(x)
sn_layers(x)
sn_artifacts(x)
sn_relations(x)

plan <- x |>
  sn_obs() |>
  dplyr::filter(
    disease == "Skin Cutaneous Melanoma",
    sample_type == "Primary Tumor"
  ) |>
  sn_select_features(features = c("YTHDF2", "FTO"), resolve = "strict") |>
  sn_slice_head(100)

sn_show_query(plan)

result <- sn_fetch_data(
  plan,
  features = c("YTHDF2", "FTO"),
  fields = c("disease", "sample_type"),
  layer = "log2_tpm_plus_0.001",
  shape = "long",
  limit = 100
)

sn_provenance(result)
sn_is_partial(result)
```

Use `sn_as()` only after `sn_conversion_plan()` says the target is ready. Use `sn_download_artifact()` or `sn_export()` for large transfers. Do not materialize an unbounded Resource.
