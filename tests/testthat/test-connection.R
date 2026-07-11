.connection_fixture <- function(name) {
  jsonlite::fromJSON(
    system.file("extdata", "contract-fixtures", name, package = "ShennongData"),
    simplifyVector = FALSE
  )
}

test_that("sn_connect negotiates and keeps tokens out of its specification", {
  testthat::local_mocked_bindings(
    .sn_perform_json = function(req, retries, throttle) {
      if (endsWith(req$url, "/version")) return(.connection_fixture("version.json"))
      .connection_fixture("capabilities.json")
    },
    .package = "ShennongData"
  )

  connection <- sn_connect("http://example.test/", token = "secret-token", set_default = FALSE)

  expect_s3_class(connection, "shennong_connection")
  expect_equal(connection$base_url, "http://example.test")
  expect_equal(connection$api_version, "v1")
  expect_equal(connection$server_version, "0.1.0")
  expect_true("expression" %in% unlist(sn_capabilities(connection)$query_operations))
  expect_false("token" %in% names(connection))
  expect_false(grepl("secret-token", paste(capture.output(str(connection)), collapse = "\n"), fixed = TRUE))
})

test_that("sn_connect rejects an unsupported API version", {
  testthat::local_mocked_bindings(
    .sn_perform_json = function(req, retries, throttle) list(api = "v2", version = "2.0.0"),
    .package = "ShennongData"
  )

  expect_error(sn_connect("http://example.test", set_default = FALSE), "Unsupported ShennongDB API version")
})
