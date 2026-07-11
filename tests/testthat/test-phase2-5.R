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
  expect_error(dplyr::filter(x, grepl("Tumor", sample_type)), "Unsupported filter operator")
})

test_that("feature resolution follows the GET gene endpoint contract", {
  seen <- list()
  testthat::local_mocked_bindings(
    .sn_perform_json = function(req, retries, throttle) {
      seen <<- c(seen, list(req))
      .phase_fixture("gene-resolve.json")
    }, .package = "ShennongData"
  )
  con <- ShennongData:::.sn_new_connection("http://example.test", "resolver", tempdir(), 60, 3L, 4, NULL)
  x <- ShennongData:::.sn_normalize_resource(.phase_fixture("agent-resource-toil.json"))
  handle <- ShennongData:::new_shennong_data(con, x, "observations")
  resolved <- sn_resolve_features(handle, "YTHDF2", strict = TRUE)
  expect_equal(resolved[[1]]$stable_id, "ENSG00000198492")
  expect_equal(seen[[1]]$method, "GET")
  expect_match(seen[[1]]$url, "/api/v1/genes/resolve\\?q=YTHDF2", fixed = FALSE)
})

test_that("cursor pages are consumed and recorded in provenance", {
  n <- 0L
  resource <- .phase_fixture("agent-resource-toil.json")
  page <- .phase_fixture("query-expression.json")
  page$data$meta$next_cursor <- "next-1"
  testthat::local_mocked_bindings(
    .sn_perform_json = function(req, retries, throttle) {
      if (grepl("/agent/resources/", req$url)) return(resource)
      n <<- n + 1L
      if (n == 2L) page$data$meta$next_cursor <- NULL
      page
    }, .package = "ShennongData"
  )
  con <- ShennongData:::.sn_new_connection("http://example.test", "cursor", tempdir(), 60, 3L, 4, NULL)
  x <- sn_load_data("toil", connection = con)
  out <- sn_fetch_data(x, features = "ENSG00000198492.14", resolve = "never")
  expect_equal(n, 2L)
  expect_equal(sn_provenance(out)$pages, 2L)
})

test_that("server capability negotiation exposes streaming and structured errors", {
  con <- ShennongData:::.sn_new_connection("http://example.test", "caps", tempdir(), 60, 3L, 4, NULL)
  con$capabilities <- .phase_fixture("capabilities.json")$data
  expect_true(sn_server_features(con)$structured_errors)
  expect_true(sn_server_features(con)$artifact_streaming)
  expect_false(sn_server_features(con)$batch_features)
})

test_that("count-based converters reject transformed Toil measurements", {
  testthat::local_mocked_bindings(.sn_perform_json = function(...) .phase_fixture("agent-resource-toil.json"), .package = "ShennongData")
  con <- ShennongData:::.sn_new_connection("http://example.test", "phase3", tempdir(), 60, 3L, 4, NULL)
  x <- sn_load_data("toil", connection = con)
  expect_error(sn_conversion_plan(x, "DESeqDataSet"), "available measurement.*log2_tpm_plus_0.001")
  expect_error(sn_as(x, "DGEList"), "available measurement.*log2_tpm_plus_0.001")
})

test_that("a complete toy count Artifact converts to SingleCellExperiment", {
  fixture <- .phase_fixture("agent-resource-pbmc-toy.json")
  path <- tempfile(fileext = ".tsv")
  utils::write.table(data.frame(feature = c("g1", "g2"), observation_id = c("c1", "c2"), value = c(2L, 0L)), path, sep = "\t", row.names = FALSE, quote = FALSE)
  fixture$resource$artifacts[[1]]$uri <- path
  testthat::local_mocked_bindings(.sn_perform_json = function(...) fixture, .package = "ShennongData")
  con <- ShennongData:::.sn_new_connection("http://example.test", "pbmc-toy", tempdir(), 60, 3L, 4, NULL)
  x <- sn_load_data("pbmc-toy", connection = con)
  sce <- sn_as(x, "SingleCellExperiment", source = "artifact", features = c("g1", "g2"), resolve = "never")
  expect_s4_class(sce, "SingleCellExperiment")
  expect_equal(dim(sce), c(2L, 2L))
  expect_false(is.null(S4Vectors::metadata(sce)$shennong))
})

test_that("third-party converters can register without subclassing ShennongData", {
  sn_register_converter("toy_target", function(x, ...) TRUE,
                        function(x, ...) list(target = "toy_target", ready = TRUE),
                        function(x, ...) list(converted = TRUE))
  expect_true(sn_conversion_plan(structure(data.frame(a = 1), class = "shennong_result"), "toy_target")$ready)
  expect_true(sn_as(structure(data.frame(a = 1), class = "shennong_result"), "toy_target")$converted)
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
  expect_true(sn_artifacts(x)$downloadable[[1]])
  expect_equal(ShennongData:::.sn_endpoint("artifact_download", "toil", "toil-expression"), "/api/v1/resources/toil/artifacts/toil-expression/download")
})
