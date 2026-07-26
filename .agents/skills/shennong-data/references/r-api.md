# R API workflow

```r
library(ShennongData)

con <- sn_connect(
  Sys.getenv("SHENNONG_URL", "https://your-shennong-gateway.example"),
  token = Sys.getenv("SHENNONG_TOKEN"),
  project_id = Sys.getenv(
    "SHENNONG_PROJECT_ID",
    "550e8400-e29b-41d4-a716-446655440000"
  )
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

Use only a canonical Project UUID for governed access. Set `project_id = NULL`
for explicitly public/direct access; do not substitute a Project alias or slug.

Use `sn_as()` only after `sn_conversion_plan()` says the target is ready. Use `sn_download_artifact()` or `sn_export()` for large transfers. Do not materialize an unbounded Resource.

Matrix and sparse targets are feature-by-observation. Sparse output requires
`implicit_zero = TRUE`; analysis containers reject partial DataBundles by
default. The current TOIL measurement is `log2_tpm_plus_0.001` and is not raw
counts.
