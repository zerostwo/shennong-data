fixture <- function(name) {
  jsonlite::fromJSON(
    system.file("extdata", "contract-fixtures", name, package = "ShennongData"),
    simplifyVector = FALSE
  )
}

test_that("fixed ShennongDB v1 fixtures preserve response envelopes", {
  version <- fixture("version.json")
  capabilities <- fixture("capabilities.json")
  resource <- fixture("agent-resource-toil.json")
  query <- fixture("query-expression.json")

  expect_equal(version$api, "v1")
  expect_equal(capabilities$data$api_version, "v1")
  expect_true("expression" %in% unlist(capabilities$data$query_operations))
  expect_equal(resource$schema_version, "1.1")
  expect_equal(resource$resource$id, "toil")
  expect_equal(resource$query$url, "/api/v1/query")
  expect_equal(resource$resource$metadata$dimensions$features, 60498)
  expect_equal(resource$resource$metadata$dimensions$samples, 19131)
  expect_equal(query$data$status, "success")
  expect_equal(query$data$meta$version, "2018-05-08")
})
