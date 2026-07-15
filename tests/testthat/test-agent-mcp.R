.agent_manifest_fixture <- function() {
  list(
    schema_version = "1.2",
    resources = list(
      list(
        id = "toil", kind = "Dataset", title = "Toil expression",
        summary = "TCGA TARGET GTEx", organism = "human", data_model = "bulk",
        assays = list("rna"), status = "available",
        details_url = "/api/v1/agent/resources/toil"
      ),
      list(
        id = "pbmc-3k", kind = "Dataset", title = "PBMC 3K",
        summary = "single-cell counts", organism = "human", data_model = "single_cell",
        assays = list("rna"), status = "available",
        details_url = "/api/v1/agent/resources/pbmc-3k"
      )
    )
  )
}

test_that("Agent Resource discovery is permission-filtered and searchable", {
  connection <- ShennongData:::.sn_new_connection(
    "http://example.test", "agent-test", tempdir(), 60, 3L, 4, NULL
  )
  testthat::local_mocked_bindings(
    .sn_perform_json = function(req, retries, throttle) .agent_manifest_fixture(),
    .package = "ShennongData"
  )

  resources <- sn_resources(connection, search = "single-cell")

  expect_equal(resources$id, "pbmc-3k")
  expect_equal(attr(resources, "shennong_manifest_schema"), "1.2")
})

test_that("MCP advertises six bounded read-only tools", {
  tools <- ShennongData:::.sn_mcp_tools()
  names <- vapply(tools, `[[`, "", "name")

  expect_equal(
    names,
    c("check_compatibility", "list_resources", "inspect_resource",
      "resolve_features", "plan_query", "fetch_data")
  )
  expect_true(all(vapply(tools, function(tool) isTRUE(tool$annotations$readOnlyHint), logical(1))))
  fetch <- tools[[match("fetch_data", names)]]
  inspect <- tools[[match("inspect_resource", names)]]
  expect_equal(fetch$inputSchema$properties$limit$maximum, 1000L)
  expect_equal(fetch$inputSchema$properties$features$maxItems, 20L)
  expect_equal(inspect$inputSchema$required, list("resource"))
})

test_that("MCP initialize and tool listing follow JSON-RPC", {
  initialized <- ShennongData:::.sn_mcp_handle(list(
    jsonrpc = "2.0", id = 1L, method = "initialize",
    params = list(protocolVersion = "2025-11-25", capabilities = list(), clientInfo = list(name = "test", version = "1"))
  ))
  listed <- ShennongData:::.sn_mcp_handle(list(jsonrpc = "2.0", id = 2L, method = "tools/list", params = list()))

  expect_equal(initialized$result$protocolVersion, "2025-11-25")
  expect_false(initialized$result$capabilities$tools$listChanged)
  expect_equal(length(listed$result$tools), 6L)
})

test_that("MCP stdio loop emits newline-delimited JSON-RPC", {
  request <- ShennongData:::.sn_mcp_json(list(
    jsonrpc = "2.0", id = 9L, method = "tools/list", params = list()
  ))
  input <- textConnection(as.character(request), open = "r")
  output <- textConnection("captured", open = "w", local = TRUE)
  on.exit(close(input), add = TRUE)
  ShennongData::sn_mcp_serve(input, output)
  close(output)

  response <- jsonlite::fromJSON(captured, simplifyVector = FALSE)
  expect_equal(response$id, 9L)
  expect_equal(length(response$result$tools), 6L)
  inspect <- response$result$tools[[3L]]
  expect_equal(inspect$inputSchema$required, list("resource"))
})

test_that("MCP reports protocol and actionable tool errors separately", {
  unknown <- ShennongData:::.sn_mcp_handle(list(
    jsonrpc = "2.0", id = 3L, method = "tools/call",
    params = list(name = "delete_everything", arguments = list())
  ))
  invalid <- ShennongData:::.sn_mcp_handle(list(
    jsonrpc = "2.0", id = 4L, method = "tools/call",
    params = list(name = "inspect_resource", arguments = list())
  ))

  expect_equal(unknown$error$code, -32602L)
  expect_true(invalid$result$isError)
  expect_match(invalid$result$content[[1]]$text, "resource")

  malformed <- ShennongData:::.sn_mcp_handle(list(
    jsonrpc = "2.0", id = 5L, method = "tools/call", params = "not-an-object"
  ))
  expect_equal(malformed$error$code, -32602L)
})

test_that("MCP query bounds cannot be widened by callers", {
  old <- Sys.getenv("SHENNONG_DATA_MCP_MAX_ROWS", unset = NA_character_)
  on.exit(if (is.na(old)) Sys.unsetenv("SHENNONG_DATA_MCP_MAX_ROWS") else Sys.setenv(SHENNONG_DATA_MCP_MAX_ROWS = old), add = TRUE)
  Sys.setenv(SHENNONG_DATA_MCP_MAX_ROWS = "250")
  expect_equal(ShennongData:::.sn_mcp_limit(list(limit = 250L)), 250L)
  expect_error(ShennongData:::.sn_mcp_limit(list(limit = 251L)), "between 1 and 250")
  expect_error(
    ShennongData:::.sn_mcp_vector_argument(list(features = as.character(seq_len(21))), "features", TRUE, 20L),
    "at most 20"
  )
})
