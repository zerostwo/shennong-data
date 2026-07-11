.resource_fixture <- function(name) {
  jsonlite::fromJSON(
    system.file("extdata", "contract-fixtures", name, package = "ShennongData"),
    simplifyVector = FALSE
  )
}

test_that("sn_load_data discovers only metadata and normalizes the Resource", {
  seen <- character()
  testthat::local_mocked_bindings(
    .sn_perform_json = function(req, retries, throttle) {
      seen <<- c(seen, req$url)
      .resource_fixture("agent-resource-toil.json")
    },
    .package = "ShennongData"
  )
  connection <- ShennongData:::.sn_new_connection(
    "http://example.test", "resource-test", tempdir(), 60, 3L, 4, NULL
  )
  x <- sn_load_data("toil", connection = connection)

  expect_true(S7::S7_inherits(x, ShennongData))
  expect_equal(seen, "http://example.test/api/v1/agent/resources/toil")
  expect_equal(x@resource$axes$feature$size, 60498L)
  expect_equal(x@resource$axes$observation$size, 19131L)
  expect_equal(x@resource$measurements$log2_tpm_plus_0.001$source_measure, "log2_tpm_plus_0.001")
  expect_false("token" %in% names(x@connection))
})

test_that("views and base methods are metadata-only", {
  testthat::local_mocked_bindings(
    .sn_perform_json = function(req, retries, throttle) .resource_fixture("agent-resource-toil.json"),
    .package = "ShennongData"
  )
  connection <- ShennongData:::.sn_new_connection(
    "http://example.test", "view-test", tempdir(), 60, 3L, 4, NULL
  )
  x <- sn_load_data("toil", connection = connection)

  expect_equal(dim(x), c(19131L, 6L))
  expect_equal(colnames(x), c("sample_id", "disease", "primary_site", "sample_type", "study", "detailed_category"))
  expect_equal(dim(sn_var(x)), c(60498L, 1L))
  expect_equal(dim(sn_assay(x)), c(60498L, 19131L))
  expect_null(rownames(x))
  expect_null(colnames(sn_assay(x)))
  expect_snapshot_output(x)
})
