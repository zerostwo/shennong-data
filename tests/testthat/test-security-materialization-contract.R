.contract_fixture <- function(name) {
  jsonlite::fromJSON(
    system.file("extdata", "contract-fixtures", name, package = "ShennongData"),
    simplifyVector = FALSE
  )
}

.contract_project_uuid <- "550e8400-e29b-41d4-a716-446655440000"

.contract_connection <- function(profile = "contract", project_id = NULL) {
  ShennongData:::.sn_new_connection(
    "http://example.test",
    profile,
    tempdir(),
    60,
    3L,
    4,
    NULL,
    project_id = project_id
  )
}

.contract_handle <- function(fixture = "agent-resource-pbmc-toy.json",
                             profile = "contract") {
  resource <- ShennongData:::.sn_normalize_resource(.contract_fixture(fixture))
  ShennongData:::new_shennong_data(
    .contract_connection(profile),
    resource,
    "assay"
  )
}

test_that("local Artifact paths require trusted-local mode and a confined root", {
  root <- tempfile("trusted-artifacts-")
  dir.create(root)
  inside <- file.path(root, "inside.tsv")
  writeLines("safe", inside)
  outside <- tempfile("outside-artifact-")
  writeLines("unsafe", outside)

  expect_null(ShennongData:::.sn_artifact_path(list(uri = inside)))
  expect_null(
    ShennongData:::.sn_artifact_path(list(uri = paste0("file://", inside)))
  )
  expect_error(
    ShennongData:::.sn_artifact_path(
      list(uri = inside),
      trusted_local = TRUE
    ),
    "local_root"
  )
  expect_equal(
    ShennongData:::.sn_artifact_path(
      list(uri = paste0("file://", inside)),
      trusted_local = TRUE,
      local_root = root
    ),
    normalizePath(inside, winslash = "/")
  )
  expect_error(
    ShennongData:::.sn_artifact_path(
      list(uri = "file://remote.example.test/share/inside.tsv"),
      trusted_local = TRUE,
      local_root = root
    ),
    "Remote file URI hosts"
  )
  expect_error(
    ShennongData:::.sn_artifact_path(
      list(uri = "\\\\remote.example.test\\share\\inside.tsv"),
      trusted_local = TRUE,
      local_root = root
    ),
    "Remote file paths"
  )
  expect_error(
    ShennongData:::.sn_artifact_path(
      list(uri = outside),
      trusted_local = TRUE,
      local_root = root
    ),
    "outside"
  )
})

test_that("Artifact requests authenticate only to the connection origin", {
  connection <- .contract_connection(
    "artifact-auth",
    project_id = .contract_project_uuid
  )
  key <- ShennongData:::.sn_connection_key(connection)
  assign(key, "secret-token", envir = ShennongData:::.sn_token_registry)
  on.exit(
    rm(list = key, envir = ShennongData:::.sn_token_registry),
    add = TRUE
  )

  same_origin <- ShennongData:::.sn_artifact_request(
    connection,
    "http://example.test/download/object"
  )
  foreign <- ShennongData:::.sn_artifact_request(
    connection,
    "https://objects.example.test/presigned?signature=abc"
  )

  expect_identical(
    typeof(same_origin$headers$Authorization),
    "weakref"
  )
  expect_null(foreign$headers$Authorization)
  expect_identical(
    same_origin$headers[["X-Shennong-Project-Id"]],
    .contract_project_uuid
  )
  expect_null(foreign$headers[["X-Shennong-Project-Id"]])
  expect_error(
    ShennongData:::.sn_artifact_request(
      connection,
      "http://objects.example.test/presigned?signature=abc"
    ),
    "HTTPS"
  )
  expect_error(
    ShennongData:::.sn_artifact_request(
      connection,
      "https://127.0.0.1/private"
    ),
    "local or literal"
  )
  expect_error(
    ShennongData:::.sn_artifact_request(
      connection,
      "file:///etc/passwd"
    ),
    "HTTP"
  )
})

test_that("Artifact redirects are followed without forwarding credentials", {
  connection <- .contract_connection(
    "artifact-redirect",
    project_id = .contract_project_uuid
  )
  key <- ShennongData:::.sn_connection_key(connection)
  assign(key, "secret-token", envir = ShennongData:::.sn_token_registry)
  on.exit(
    rm(list = key, envir = ShennongData:::.sn_token_registry),
    add = TRUE
  )
  requests <- list()
  testthat::local_mocked_bindings(
    .sn_perform_raw = function(req, ...) {
      requests[[length(requests) + 1L]] <<- req
      if (length(requests) == 1L) {
        return(httr2:::new_response(
          "GET",
          req$url,
          302L,
          list(location = "https://objects.example.test/presigned"),
          raw(),
          request = req
        ))
      }
      httr2:::new_response(
        "GET",
        req$url,
        200L,
        list(),
        charToRaw("artifact"),
        request = req
      )
    },
    .package = "ShennongData"
  )

  response <- ShennongData:::.sn_perform_artifact_request(
    connection,
    "/download/object",
    retries = 1L,
    throttle = 100
  )

  expect_equal(httr2::resp_status(response), 200L)
  expect_length(requests, 2L)
  expect_identical(
    typeof(requests[[1L]]$headers$Authorization),
    "weakref"
  )
  expect_null(requests[[2L]]$headers$Authorization)
  expect_null(requests[[2L]]$headers[["X-Shennong-Project-Id"]])
  expect_identical(
    requests[[2L]]$options$followlocation,
    FALSE
  )
})

test_that("foreign redirect chains cannot re-enable same-origin credentials", {
  connection <- .contract_connection(
    "artifact-foreign-chain",
    project_id = .contract_project_uuid
  )
  key <- ShennongData:::.sn_connection_key(connection)
  assign(key, "secret-token", envir = ShennongData:::.sn_token_registry)
  on.exit(
    rm(list = key, envir = ShennongData:::.sn_token_registry),
    add = TRUE
  )
  requests <- list()
  testthat::local_mocked_bindings(
    .sn_perform_raw = function(req, ...) {
      requests[[length(requests) + 1L]] <<- req
      if (length(requests) == 1L) {
        return(httr2:::new_response(
          "GET",
          req$url,
          302L,
          list(location = "http://example.test/download/object"),
          raw(),
          request = req
        ))
      }
      httr2:::new_response(
        "GET",
        req$url,
        200L,
        list(),
        charToRaw("artifact"),
        request = req
      )
    },
    .package = "ShennongData"
  )

  ShennongData:::.sn_perform_artifact_request(
    connection,
    "https://objects.example.test/presigned",
    retries = 1L,
    throttle = 100
  )

  expect_length(requests, 2L)
  expect_true(all(vapply(requests, function(req) {
    is.null(req$headers$Authorization) &&
      is.null(req$headers[["X-Shennong-Project-Id"]])
  }, logical(1))))
})

test_that("project scope is attached to gateway headers and query bodies", {
  connection <- .contract_connection(
    "project-scope",
    project_id = .contract_project_uuid
  )
  request <- sn_request(
    connection,
    "/api/v1/query",
    method = "POST",
    body = list(resource = "pbmc-toy")
  )
  expect_identical(
    request$headers[["X-Shennong-Project-Id"]],
    .contract_project_uuid
  )
  public_request <- sn_request(
    connection,
    "/version",
    auth = "none"
  )
  expect_null(public_request$headers[["X-Shennong-Project-Id"]])

  captured <- NULL
  testthat::local_mocked_bindings(
    .sn_query_pages = function(x, body, ...) {
      captured <<- body
      data.frame(
        observation_id = "c1",
        feature = "g1",
        value = 2
      )
    },
    .package = "ShennongData"
  )
  x <- .contract_handle(profile = "project-query")
  x@connection$project_id <- .contract_project_uuid
  x@connection$capabilities <- list(batch_features = TRUE)
  sn_fetch_data(
    x,
    features = "g1",
    layer = "counts",
    shape = "long",
    resolve = "never"
  )
  expect_identical(captured$project_id, .contract_project_uuid)
})

test_that("sparse long materialization constructs structural zeros directly", {
  skip_if_not_installed("Matrix")
  data <- data.frame(
    observation_id = c("c1", "c2", "c1"),
    feature = c("g1", "g2", "g2"),
    value = c(2, 3, 0)
  )
  resolved <- lapply(c("g1", "g2"), function(id) {
    list(input = id, original_id = id)
  })

  sparse <- ShennongData:::.sn_long_to_matrix(
    data,
    resolved,
    sparse = TRUE,
    implicit_zero = TRUE,
    observation_ids = c("c1", "c2")
  )
  dense <- ShennongData:::.sn_long_to_matrix(
    data,
    resolved,
    sparse = FALSE,
    implicit_zero = FALSE,
    observation_ids = c("c1", "c2")
  )

  expect_s4_class(sparse, "dgCMatrix")
  expect_equal(length(sparse@x), 2L)
  expect_equal(
    as.matrix(sparse),
    matrix(
      c(2, 0, 0, 3),
      nrow = 2,
      dimnames = list(c("g1", "g2"), c("c1", "c2"))
    )
  )
  expect_true(is.na(dense["g1", "c2"]))
  expect_error(
    ShennongData:::.sn_long_to_matrix(
      data,
      resolved,
      sparse = TRUE,
      implicit_zero = FALSE
    ),
    "implicit_zero"
  )
})

test_that("matrix materialization fetches a declared observation axis", {
  skip_if_not_installed("Matrix")
  query_response <- list(data = list(
    status = "success",
    data = list(
      list(sample_id = "c1", feature = "g1", value = 2),
      list(sample_id = "c2", feature = "g2", value = 3)
    ),
    meta = list(n_rows = 2)
  ))
  testthat::local_mocked_bindings(
    .sn_perform_json = function(req, ...) {
      if (grepl("/axes/observation", req$url, fixed = TRUE)) {
        return(list(data = list(ids = c("c1", "c2", "c3"))))
      }
      query_response
    },
    .package = "ShennongData"
  )
  x <- .contract_handle(profile = "axis-fetch")
  x@connection$capabilities <- list(
    batch_features = TRUE,
    axes = TRUE
  )

  result <- sn_fetch_data(
    x,
    features = c("g1", "g2"),
    layer = "counts",
    shape = "sparse",
    resolve = "never"
  )

  expect_equal(dim(result), c(2L, 3L))
  expect_identical(colnames(result), c("c1", "c2", "c3"))
  expect_false(sn_is_partial(result))
  expect_true(sn_provenance(result)$data_bundle$axis_complete)
})

test_that("sparse query results expose DataBundle completeness provenance", {
  skip_if_not_installed("Matrix")
  response <- list(data = list(
    status = "success",
    data = list(
      list(sample_id = "c1", feature = "g1", value = 2),
      list(sample_id = "c2", feature = "g2", value = 3)
    ),
    meta = list(n_rows = 2)
  ))
  testthat::local_mocked_bindings(
    .sn_perform_json = function(...) response,
    .package = "ShennongData"
  )
  x <- .contract_handle(profile = "sparse-query")
  x@connection$capabilities <- list(batch_features = TRUE)

  incomplete <- sn_fetch_data(
    x,
    features = c("g1", "g2"),
    layer = "counts",
    shape = "sparse",
    resolve = "never"
  )

  expect_s4_class(incomplete, "dgCMatrix")
  expect_true(sn_is_partial(incomplete))
  expect_identical(
    sn_result_schema(incomplete)$contract,
    "shennong.dev/data-bundle/v1"
  )
  expect_identical(
    sn_provenance(incomplete)$data_bundle$status,
    "client_projection"
  )
  expect_false(sn_provenance(incomplete)$data_bundle$complete)
  expect_true(
    "observation_axis_incomplete" %in%
      sn_provenance(incomplete)$data_bundle$incomplete_reasons
  )

  sn_cache_ids(x, axis = "observation", ids = c("c1", "c2"))
  complete <- sn_fetch_data(
    x,
    features = c("g1", "g2"),
    layer = "counts",
    shape = "sparse",
    resolve = "never"
  )
  expect_false(sn_is_partial(complete))
  expect_true(sn_provenance(complete)$data_bundle$complete)
})

test_that("batch missing_features are retained as incomplete provenance", {
  skip_if_not_installed("Matrix")
  response <- list(data = list(
    status = "success",
    data = list(
      list(sample_id = "c1", feature = "g1", value = 2)
    ),
    meta = list(n_rows = 1, missing_features = c("g2"))
  ))
  testthat::local_mocked_bindings(
    .sn_perform_json = function(...) response,
    .package = "ShennongData"
  )
  x <- .contract_handle(profile = "missing-feature")
  x@connection$capabilities <- list(batch_features = TRUE)
  sn_cache_ids(x, axis = "observation", ids = c("c1", "c2"))

  result <- sn_fetch_data(
    x,
    features = c("g1", "g2"),
    layer = "counts",
    shape = "sparse",
    resolve = "never"
  )

  expect_true(sn_is_partial(result))
  expect_identical(
    sn_provenance(result)$data_bundle$missing_features,
    "g2"
  )
  expect_true(
    "missing_features" %in%
      sn_provenance(result)$data_bundle$incomplete_reasons
  )
})

test_that("Resource-declared DataBundle metadata is distinguished from projections", {
  fixture <- .contract_fixture("agent-resource-pbmc-toy.json")
  fixture$resource$metadata$data_bundle <- list(
    schema_version = "shennong.dev/data-bundle/v1",
    producer = "shennong-db"
  )
  declared <- ShennongData:::.sn_normalize_resource(fixture)
  projected <- .contract_handle(profile = "projection")@resource

  expect_identical(
    ShennongData:::.sn_data_bundle_base(
      declared,
      "shennongdb-v1-resource-query"
    )$status,
    "resource_declared"
  )
  expect_identical(
    ShennongData:::.sn_data_bundle_base(
      projected,
      "shennongdb-v1-resource-query"
    )$status,
    "client_projection"
  )
})

test_that("SummarizedExperiment and Seurat preserve materialization provenance", {
  skip_if_not_installed("Matrix")
  skip_if_not_installed("SummarizedExperiment")
  skip_if_not_installed("S4Vectors")
  data <- data.frame(
    observation_id = c("c1", "c2"),
    feature = c("g1", "g2"),
    value = c(2, 3)
  )
  resolved <- lapply(c("g1", "g2"), function(id) {
    list(input = id, original_id = id)
  })
  x <- .contract_handle(profile = "conversion-contract")
  plan <- ShennongData:::.sn_empty_query(x)
  plan$shape <- "long"
  provenance <- list(
    resource = list(id = "pbmc-toy", version = "toy-1"),
    layer = "counts",
    data_bundle = list(
      contract = "shennong.dev/data-bundle/v1",
      status = "client_projection",
      complete = TRUE,
      orientation = "feature_by_observation",
      implicit_zero = TRUE,
      observation_ids = c("c1", "c2"),
      incomplete_reasons = character()
    )
  )
  result <- ShennongData:::.sn_as_result(
    data,
    x,
    plan,
    provenance,
    partial = FALSE
  )

  se <- sn_as(result, "SummarizedExperiment")
  expect_identical(
    S4Vectors::metadata(se)$shennong$data_bundle$contract,
    "shennong.dev/data-bundle/v1"
  )
  expect_s4_class(SummarizedExperiment::assay(se), "dgCMatrix")

  partial <- result
  attr(partial, "shennong_partial") <- TRUE
  attr(partial, "shennong_provenance")$data_bundle$complete <- FALSE
  attr(partial, "shennong_provenance")$data_bundle$incomplete_reasons <-
    "observation_axis_incomplete"
  expect_error(
    sn_as(partial, "SummarizedExperiment"),
    "requires a complete DataBundle"
  )

  if (requireNamespace("SeuratObject", quietly = TRUE)) {
    seurat <- sn_as(result, "Seurat")
    expect_identical(
      seurat@misc$shennong$data_bundle$contract,
      "shennong.dev/data-bundle/v1"
    )
  }
})

test_that("documented query helpers are exported", {
  exports <- getNamespaceExports("ShennongData")
  expect_true(
    all(c(
      "sn_resolve_features",
      "sn_slice_head",
      "sn_write_query"
    ) %in% exports)
  )
})

test_that("Shennong accepts the ShennongData bulk SummarizedExperiment contract", {
  skip_if_not_installed("Shennong")
  skip_if_not_installed("SummarizedExperiment")
  skip_if_not_installed("S4Vectors")

  set.seed(42)
  matrix <- matrix(
    stats::rnorm(30L * 8L, mean = 5, sd = 1),
    nrow = 30,
    dimnames = list(
      paste0("ENSG", sprintf("%011d", seq_len(30)), ".1"),
      paste0("sample-", seq_len(8))
    )
  )
  se <- SummarizedExperiment::SummarizedExperiment(
    assays = list(log2_tpm_plus_0.001 = matrix),
    colData = S4Vectors::DataFrame(
      sample_id = colnames(matrix),
      row.names = colnames(matrix)
    ),
    metadata = list(shennong = list(
      layer = "log2_tpm_plus_0.001",
      data_bundle = list(
        contract = "shennong.dev/data-bundle/v1",
        status = "client_projection",
        complete = TRUE
      )
    ))
  )

  normalized <- getFromNamespace(".sn_bulk_input", "Shennong")(se)
  expect_equal(normalized$matrix, matrix)
  expect_identical(normalized$assay, "log2_tpm_plus_0.001")
  expect_false(normalized$is_counts)

  result <- Shennong::sn_run_bulk(se, workflow = "qc")
  expect_true(Shennong::sn_validate_result(
    result,
    error = FALSE
  )$valid)
})
