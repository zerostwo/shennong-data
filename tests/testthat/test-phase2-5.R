.phase_fixture <- function(name) jsonlite::fromJSON(system.file("extdata", "contract-fixtures", name, package = "ShennongData"), simplifyVector = FALSE)

test_that("typed plans fetch bounded multi-feature results with provenance", {
  calls <- list()
  testthat::local_mocked_bindings(
    .sn_perform_json = function(req, retries, throttle) {
      calls <<- c(calls, list(req))
      if (grepl("/agent/resources/", req$url)) return(.phase_fixture("agent-resource-toil.json"))
      .phase_fixture("query-expression.json")
    }, .package = "ShennongData"
  )
  con <- ShennongData:::.sn_new_connection("http://example.test", "phase2", tempdir(), 60, 3L, 4, NULL)
  x <- sn_load_data("toil", connection = con)
  y <- dplyr::filter(x, disease == "Skin Cutaneous Melanoma") |>
    dplyr::select(sample_id, disease)
  expect_equal(y@query$field_selection, c("sample_id", "disease"))
  out <- sn_fetch_data(y, features = "ENSG00000198492.14", fields = "disease", resolve = "never")
  expect_s3_class(out, "shennong_result")
  expect_false(sn_is_partial(out))
  expect_equal(length(sn_provenance(out)$requests), 1L)
  expect_equal(length(calls), 2L)
  expect_equal(sn_query_fingerprint(y), sn_query_fingerprint(y))
})

test_that("count-based converters reject transformed Toil measurements", {
  testthat::local_mocked_bindings(.sn_perform_json = function(...) .phase_fixture("agent-resource-toil.json"), .package = "ShennongData")
  con <- ShennongData:::.sn_new_connection("http://example.test", "phase3", tempdir(), 60, 3L, 4, NULL)
  x <- sn_load_data("toil", connection = con)
  expect_error(sn_conversion_plan(x, "DESeqDataSet"), "available measurement.*log2_tpm_plus_0.001")
  expect_error(sn_as(x, "DGEList"), "available measurement.*log2_tpm_plus_0.001")
})

test_that("artifact metadata and collections stay local", {
  testthat::local_mocked_bindings(.sn_perform_json = function(...) .phase_fixture("agent-resource-toil.json"), .package = "ShennongData")
  con <- ShennongData:::.sn_new_connection("http://example.test", "phase45", tempdir(), 60, 3L, 4, NULL)
  x <- sn_load_data("toil", connection = con)
  expect_equal(nrow(sn_artifacts(x)), 1L)
  expect_equal(nrow(sn_relations(x)), 0L)
  collection <- sn_collection(toil = x)
  expect_named(sn_collection_resources(collection), "toil")
  expect_s3_class(sn_link_features(collection), "ShennongCollection")
})
