test_that("endpoint paths have one source of truth", {
  expect_equal(ShennongData:::.sn_endpoint("version"), "/version")
  expect_equal(ShennongData:::.sn_endpoint("capabilities"), "/api/v1/capabilities")
  expect_equal(ShennongData:::.sn_endpoint("agent_resource", "toil"), "/api/v1/agent/resources/toil")
  expect_equal(ShennongData:::.sn_endpoint("query"), "/api/v1/query")
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
