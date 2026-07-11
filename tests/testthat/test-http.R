test_that("endpoint paths have one source of truth", {
  expect_equal(ShennongData:::.sn_endpoint("version"), "/version")
  expect_equal(ShennongData:::.sn_endpoint("capabilities"), "/api/v1/capabilities")
  expect_equal(ShennongData:::.sn_endpoint("agent_resource", "toil"), "/api/v1/agent/resources/toil")
  expect_equal(ShennongData:::.sn_endpoint("query"), "/api/v1/query")
})

test_that("httr2 requests use JSON and redact bearer tokens", {
  req <- sn_request(
    list(base_url = "http://example.test", token = "secret-token"),
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
