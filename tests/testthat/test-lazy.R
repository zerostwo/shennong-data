test_that("sn_load_data is lazy", {
  x <- sn_load_data("toil", server_url = "http://example.test")
  expect_s3_class(x, "shennong_remote_tbl")
  expect_equal(x$dataset, "toil")
  expect_equal(x$server_url, "http://example.test")
})

test_that("filter accumulates observation filters", {
  x <- dplyr::filter(sn_load_data("toil"), cancer == "PAAD" & group == "Primary Tumor")
  expect_equal(x$filters$cancer, "PAAD")
  expect_equal(x$filters$group, "Primary Tumor")
})

test_that("query spec uses features only when materializing", {
  x <- dplyr::filter(sn_load_data("toil"), cancer == "PAAD")
  spec <- ShennongData:::.sn_query_spec(x, features = "YTHDF2", limit = 10)
  expect_equal(spec$select$features, list("YTHDF2"))
  expect_equal(spec$select$observations$cancer, "PAAD")
})

test_that("dataset registration payload matches server schema", {
  payload <- ShennongData:::.sn_dataset_payload(
    dataset = "toil",
    version = "v1",
    type = "bulk_expression",
    backend = "xena",
    storage_uri = "/data/shennong/toil.tsv",
    metadata = list(title = "Toil"),
    is_default = TRUE
  )
  expect_equal(payload$dataset_id, "toil")
  expect_equal(payload$type, "bulk_expression")
  expect_equal(payload$backend, "xena")
  expect_true(payload$is_default)
  expect_equal(payload$metadata$title, "Toil")
})
