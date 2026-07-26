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

  connection <- sn_connect(
    "http://example.test/",
    token = "secret-token",
    project_id = "project-123",
    set_default = FALSE
  )

  expect_s3_class(connection, "shennong_connection")
  expect_equal(connection$base_url, "http://example.test")
  expect_equal(connection$api_version, "v1")
  expect_equal(connection$server_version, "1.0.0")
  expect_identical(connection$project_id, "project-123")
  expect_true("expression" %in% unlist(sn_capabilities(connection)$query_operations))
  expect_false("token" %in% names(connection))
  expect_false(grepl("secret-token", paste(capture.output(str(connection)), collapse = "\n"), fixed = TRUE))
})

test_that("project identifiers are optional and validated before negotiation", {
  expect_error(
    sn_connect(
      "http://example.test",
      project_id = "project id with spaces",
      set_default = FALSE
    ),
    "project_id"
  )
  connection <- ShennongData:::.sn_new_connection(
    "http://example.test",
    "no-project",
    tempdir(),
    60,
    3L,
    4,
    NULL
  )
  expect_null(connection$project_id)
})

test_that("the default local entry point is the Shennong OS gateway", {
  option_names <- c(
    "ShennongData.server_url",
    "shennong.data.server_url",
    "shennong.api_url"
  )
  old_options <- options()[option_names]
  on.exit(options(old_options), add = TRUE)
  options(
    ShennongData.server_url = NULL,
    shennong.data.server_url = NULL,
    shennong.api_url = NULL
  )
  old_env <- Sys.getenv("SHENNONG_API_URL", unset = NA_character_)
  on.exit(
    if (is.na(old_env)) {
      Sys.unsetenv("SHENNONG_API_URL")
    } else {
      Sys.setenv(SHENNONG_API_URL = old_env)
    },
    add = TRUE
  )
  Sys.unsetenv("SHENNONG_API_URL")

  expect_identical(sn_server_url(), "http://127.0.0.1:18081")
})

test_that("sn_connect rejects an unsupported API version", {
  testthat::local_mocked_bindings(
    .sn_perform_json = function(req, retries, throttle) list(api = "v2", version = "2.0.0"),
    .package = "ShennongData"
  )

  expect_error(sn_connect("http://example.test", set_default = FALSE), "Unsupported ShennongDB API version")
})
