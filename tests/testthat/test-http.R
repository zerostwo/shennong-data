test_that("endpoint paths have one source of truth", {
  expect_equal(ShennongData:::.sn_endpoint("version"), "/version")
  expect_equal(ShennongData:::.sn_endpoint("public_config"), "/api/v1/public-config")
  expect_equal(ShennongData:::.sn_endpoint("capabilities"), "/api/v1/capabilities")
  expect_equal(ShennongData:::.sn_endpoint("agent_resource", "toil"), "/api/v1/agent/resources/toil")
  expect_equal(ShennongData:::.sn_endpoint("query"), "/api/v1/query")
})

test_that("negotiation falls back to public config when the gateway omits version", {
  connection <- ShennongData:::.sn_new_connection(
    "http://example.test", "fallback-test", tempdir(), 60, 3L, 4, NULL
  )
  seen <- character()
  testthat::local_mocked_bindings(
    .sn_perform_json = function(req, retries, throttle) {
      seen <<- c(seen, req$url)
      if (endsWith(req$url, "/api/v1/capabilities")) {
        return(list(data = list(api_version = "v1", resources = c("discover", "inspect"), query_operations = "expression")))
      }
      if (endsWith(req$url, "/version")) {
        stop(structure(
          list(message = "not found", call = NULL, status = 404L),
          class = c("shennong_api_error", "error", "condition")
        ))
      }
      list(data = list(api_version = "v1", service_version = "0.5.2"))
    },
    .package = "ShennongData"
  )

  negotiated <- ShennongData:::.sn_negotiate(connection)

  expect_equal(negotiated$api_version, "v1")
  expect_equal(negotiated$server_version, "0.5.2")
  expect_true(any(endsWith(seen, "/api/v1/public-config")))
})

test_that("httr2 requests use JSON and redact bearer tokens", {
  connection <- ShennongData:::.sn_new_connection(
    "http://example.test", "http-test", tempdir(), 60, 3L, 4, NULL
  )
  key <- ShennongData:::.sn_connection_key(connection)
  assign(
    key, "secret-token",
    envir = ShennongData:::.sn_token_registry
  )
  on.exit(rm(list = key, envir = ShennongData:::.sn_token_registry), add = TRUE)
  req <- sn_request(
    connection,
    ShennongData:::.sn_endpoint("query"),
    method = "POST",
    body = list(resource = "toil"),
    auth = "user"
  )

  expect_s3_class(req, "httr2_request")
  expect_equal(req$url, "http://example.test/api/v1/query")
  expect_equal(req$method, "POST")
  expect_equal(req$headers$Accept, "application/json")
  printed <- paste(capture.output(req), collapse = "\n")
  expect_match(printed, "Authorization: <REDACTED>", fixed = TRUE)
  expect_false(grepl("secret-token", printed, fixed = TRUE))
})
