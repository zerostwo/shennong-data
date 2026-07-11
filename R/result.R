.sn_context_from_predicate <- function(predicate) {
  if (is.null(predicate)) return(list())
  if (identical(predicate$op, "and")) {
    return(Reduce(function(a, b) {
      overlap <- intersect(names(a), names(b))
      if (length(overlap) && !all(vapply(overlap, function(k) identical(a[[k]], b[[k]]), logical(1)))) {
        stop("Conflicting context filters for field(s): ", paste(overlap, collapse = ", "), call. = FALSE)
      }
      utils::modifyList(a, b)
    }, lapply(predicate$args, .sn_context_from_predicate), init = list()))
  }
  if (predicate$op %in% c("eq", "in")) return(stats::setNames(list(predicate$value), predicate$field))
  list()
}

.sn_context_merge <- function(x, context) {
  plan_context <- .sn_context_from_predicate(x@query$observation_predicate)
  if (is.null(context)) return(plan_context)
  if (!is.list(context) || is.null(names(context))) stop("`context` must be a named list.", call. = FALSE)
  for (field in names(context)) .sn_field_info(x, field)
  overlap <- intersect(names(plan_context), names(context))
  if (length(overlap) && !all(vapply(overlap, function(k) identical(plan_context[[k]], context[[k]]), logical(1)))) {
    stop("`context` conflicts with the lazy filter for field(s): ", paste(overlap, collapse = ", "), call. = FALSE)
  }
  utils::modifyList(plan_context, context)
}

.sn_measurement <- function(x, layer = NULL) {
  measurements <- x@resource$measurements %||% list()
  if (is.null(layer)) {
    defaults <- names(measurements)[vapply(measurements, function(z) isTRUE(z$default), logical(1))]
    if (length(defaults) == 1L) layer <- defaults
    else if (length(measurements) == 1L) layer <- names(measurements)
    else stop("`layer` is required because Resource `", x@resource$id, "` has multiple measurements.", call. = FALSE)
  }
  if (!layer %in% names(measurements)) stop("Unknown layer `", layer, "`. Available layers: ", paste(names(measurements), collapse = ", "), call. = FALSE)
  list(name = layer, spec = measurements[[layer]])
}

.sn_feature_name <- function(feature) {
  if (is.list(feature)) return(feature$original_id %||% feature$resolved_id %||% feature$input %||% feature$stable_id)
  as.character(feature)
}

.sn_resolve_feature_response <- function(response, inputs, resource_id) {
  payload <- response$data %||% response
  rows <- payload$matches %||% payload$data %||% payload$results %||% payload
  if (is.list(rows) && !is.null(rows$matches)) rows <- rows$matches
  if (is.null(rows)) rows <- list()
  if (is.data.frame(rows)) rows <- split(rows, seq_len(nrow(rows)))
  if (!is.list(rows) || !length(rows)) {
    if (all(grepl("^ENS[A-Z]*[0-9]+(?:\\.[0-9]+)?$", inputs))) {
      return(lapply(inputs, function(input) list(input = input, resource = resource_id,
                                                 original_id = input, stable_id = sub("\\..*$", "", input),
                                                 resolved_id = input, symbol = NA_character_)))
    }
    stop("No feature identifiers resolved for Resource `", resource_id, "`.", call. = FALSE)
  }
  resolved <- lapply(seq_along(inputs), function(i) {
    input <- inputs[[i]]
    row <- rows[[i]] %||% rows[[which(vapply(rows, function(z) identical(z$input %||% z$query, input), logical(1)))[1L]]]
    if (is.null(row)) row <- list()
    original <- row$original_id %||% row$id %||% row$ensembl_gene_id %||% row$resolved_id %||% input
    resolved_id <- row$resolved_id %||% row$original_id %||% row$id %||% original
    stable <- row$stable_id %||% sub("\\..*$", "", resolved_id)
    list(input = input, resource = resource_id, original_id = original, resolved_id = resolved_id,
         stable_id = stable, symbol = row$symbol %||% row$gene_symbol %||% NA_character_,
         annotation = row$annotation %||% NULL)
  })
  resolved
}

sn_resolve_features <- function(x, features, resources = NULL, strict = TRUE,
                                canonical = "ensembl_gene_stable_id") {
  if (!S7::S7_inherits(x, ShennongData)) stop("`x` must be a ShennongData handle.", call. = FALSE)
  features <- unique(as.character(features))
  if (!length(features) || any(!nzchar(features))) stop("`features` must contain non-empty identifiers.", call. = FALSE)
  invisible(resources)
  resolve_one <- function(input) {
    req <- sn_request(x@connection, .sn_endpoint("genes_resolve"), method = "GET")
    req <- httr2::req_url_query(req, q = input, resources = x@resource$id)
    .sn_perform_json(req, retries = x@connection$retries, throttle = x@connection$throttle)
  }
  responses <- tryCatch(lapply(features, resolve_one), error = function(e) NULL)
  resolved <- if (is.null(responses)) {
    if (all(grepl("^ENS[A-Z]*[0-9]+(?:\\.[0-9]+)?$", features))) {
      lapply(features, function(input) list(input = input, resource = x@resource$id, original_id = input,
                                            resolved_id = input, stable_id = sub("\\..*$", "", input), symbol = NA_character_))
    } else if (isTRUE(strict)) stop("Feature resolution endpoint failed for Resource `", x@resource$id, "`.", call. = FALSE) else lapply(features, function(input) list(input = input, resource = x@resource$id, original_id = input, resolved_id = input, stable_id = sub("\\..*$", "", input), symbol = NA_character_))
  } else {
    lapply(seq_along(features), function(i) {
      .sn_resolve_feature_response(responses[[i]], features[[i]], x@resource$id)[[1L]]
    })
  }
  if (isTRUE(strict)) {
    missing <- vapply(resolved, function(z) is.null(z$resolved_id) || !nzchar(z$resolved_id), logical(1))
    if (any(missing)) stop("One or more feature identifiers could not be resolved.", class = "shennong_identifier_missing")
    stable <- vapply(resolved, `[[`, "", "stable_id")
    if (anyDuplicated(stable)) stop("Feature resolution is ambiguous: multiple inputs map to the same stable identifier.", class = "shennong_identifier_ambiguous")
  }
  resolved
}

.sn_query_row_data <- function(response, feature) {
  outer <- response$data %||% response
  rows <- outer$data %||% outer$results %||% list()
  if (is.null(rows)) rows <- list()
  if (is.data.frame(rows)) return(rows)
  if (!is.list(rows) || !length(rows)) return(data.frame())
  cols <- unique(unlist(lapply(rows, names), use.names = FALSE))
  out <- as.data.frame(stats::setNames(lapply(cols, function(col) vapply(rows, function(row) {
    value <- row[[col]]
    if (is.null(value)) NA else as.character(value)
  }, character(1))), cols), stringsAsFactors = FALSE)
  if (nrow(out)) {
    if ("value" %in% names(out)) out$value <- suppressWarnings(as.numeric(out$value))
    if (!"feature" %in% names(out)) out$feature <- if (length(feature) == 1L) .sn_feature_name(feature) else NA_character_
  }
  out
}

.sn_query_pages <- function(x, body, feature, path = "query", max_pages = 100L) {
  pages <- list(); cursors <- character(); current <- body
  for (page in seq_len(max_pages)) {
    response <- .sn_perform_json(sn_request(x@connection, .sn_endpoint(path), method = "POST", body = current), retries = x@connection$retries, throttle = x@connection$throttle)
    pages[[page]] <- response
    meta <- response$data$meta %||% response$meta %||% list()
    cursor <- meta$next_cursor %||% meta$cursor %||% response$next_cursor %||% NULL
    if (is.null(cursor) || !nzchar(as.character(cursor))) break
    if (cursor %in% cursors) stop("Server returned a repeated query cursor.", call. = FALSE)
    cursors <- c(cursors, as.character(cursor)); current$options <- utils::modifyList(current$options %||% list(), list(cursor = cursor))
    if (page == max_pages) stop("Query exceeded the cursor page limit; narrow the request or use an Artifact.", call. = FALSE)
  }
  data <- do.call(rbind, lapply(pages, .sn_query_row_data, feature = feature))
  attr(data, "shennong_pages") <- length(pages); data
}

.sn_as_result <- function(data, x, plan, provenance, partial = FALSE) {
  if (requireNamespace("tibble", quietly = TRUE)) data <- tibble::as_tibble(data)
  class(data) <- unique(c("shennong_result", class(data)))
  attr(data, "shennong_query") <- plan
  attr(data, "shennong_provenance") <- provenance
  attr(data, "shennong_schema") <- list(shape = plan$shape %||% "long", columns = names(data))
  attr(data, "shennong_partial") <- isTRUE(partial)
  attr(data, "shennong_resource") <- list(id = x@resource$id, version = x@resource$version)
  data
}

sn_provenance <- function(x) attr(x, "shennong_provenance")
sn_result_schema <- function(x) attr(x, "shennong_schema")
sn_is_partial <- function(x) isTRUE(attr(x, "shennong_partial"))
sn_resource_ref <- function(x) attr(x, "shennong_resource")

print.shennong_result <- function(x, ...) {
  p <- sn_provenance(x) %||% list(resource = list(), layer = NULL)
  cat("<shennong_result>\nResource: ", p$resource$id %||% "unknown", "@", p$resource$version %||% "current", " | layer: ", p$layer %||% "unknown", "\n", sep = "")
  cat("Partial: ", sn_is_partial(x), if (isTRUE(p$nonzero_subset)) " (nonzero subset)" else "", "\n", sep = "")
  NextMethod("print")
}

sn_fetch_data <- function(x, features = NULL, observations = NULL, fields = NULL,
                          context = NULL, assay = NULL, layer = NULL,
                          operation = NULL, shape = c("long", "wide", "matrix", "sparse"),
                          resolve = c("auto", "strict", "never"), source = c("auto", "query", "artifact"),
                          limit = NULL, allow_large = FALSE, cache = NULL,
                          fail_fast = TRUE, ...) {
  if (!S7::S7_inherits(x, ShennongData)) stop("`x` must be a ShennongData handle.", call. = FALSE)
  shape <- match.arg(shape); resolve <- match.arg(resolve); source <- match.arg(source)
  if (is.null(features) && length(x@query$feature_selection)) features <- vapply(x@query$feature_selection, .sn_feature_name, character(1))
  if (is.null(features) || !length(features)) stop("`features` is required for a query fetch; select a bounded feature set first.", call. = FALSE)
  if (!is.null(observations)) stop("The current server contract does not support observation selection.", call. = FALSE)
  if (!is.null(fields)) {
    fields <- unique(as.character(fields)); invisible(lapply(fields, .sn_field_info, x = x))
  } else fields <- x@query$field_selection %||% character()
  measurement <- .sn_measurement(x, layer)
  resolved <- if (resolve == "never") lapply(as.character(features), function(input) list(input = input, original_id = input, resolved_id = input, stable_id = sub("\\..*$", "", input), symbol = NA_character_)) else sn_resolve_features(x, features, strict = resolve == "strict")
  ctx <- .sn_context_merge(x, context)
  n_limit <- limit %||% x@query$limit
  if (!is.null(n_limit) && (length(n_limit) != 1L || is.na(n_limit) || n_limit < 1)) stop("`limit` must be a positive scalar.", call. = FALSE)
  estimated_observations <- if (!is.null(n_limit)) as.numeric(n_limit) else as.numeric(x@resource$axes$observation$size)
  estimated_cells <- length(resolved) * estimated_observations
  if (is.finite(estimated_cells) && estimated_cells > 0) {
    bytes <- estimated_cells * 8 * 2
    threshold <- if (shape %in% c("matrix", "sparse")) getOption("ShennongData.max_matrix_bytes", 256 * 1024^2) else getOption("ShennongData.max_result_bytes", 512 * 1024^2)
    if (!isTRUE(allow_large) && is.finite(bytes) && bytes > threshold) stop("Estimated materialization is ", format(bytes, big.mark = ","), " bytes; narrow features/context or set `allow_large = TRUE`.", call. = FALSE)
  }
  if (identical(source, "artifact")) return(.sn_fetch_from_artifact(x, resolved, fields, measurement$name, shape, allow_large = allow_large, ...))
  if (identical(source, "auto") && !length(ctx) && length(x@resource$artifacts) && length(resolved) > 100L) return(.sn_fetch_from_artifact(x, resolved, fields, measurement$name, shape, allow_large = allow_large, ...))
  if (length(resolved) > 100L && !isTRUE(allow_large)) stop("Refusing more than 100 feature requests without `allow_large = TRUE`; use an Artifact route.", call. = FALSE)
  operation <- operation %||% measurement$spec$operation %||% "expression"
  batch <- isTRUE(x@connection$capabilities$batch_features) || "expression_batch" %in% (x@connection$capabilities$query_operations %||% character())
  requests <- lapply(resolved, function(feature) {
    options <- list(); if (!is.null(n_limit)) options$limit <- as.integer(n_limit)
    list(resource = x@resource$id, operation = operation,
         feature = list(type = "gene", name = feature$resolved_id),
         context = ctx, version = x@resource$version, options = options)
  })
  if (batch) requests <- list(list(resource = x@resource$id, operation = operation,
                                   features = lapply(resolved, function(feature) list(type = "gene", name = feature$resolved_id)),
                                   context = ctx, version = x@resource$version,
                                   options = if (is.null(n_limit)) list() else list(limit = as.integer(n_limit))))
  rows <- vector("list", length(requests)); failures <- list()
  for (i in seq_along(requests)) {
    rows[[i]] <- tryCatch(.sn_query_pages(x, requests[[i]], if (batch) resolved else resolved[[i]], path = if (batch) "query_batch" else "query"), error = function(e) { failures[[length(failures) + 1L]] <<- list(feature = if (batch) resolved else resolved[[i]], error = conditionMessage(e)); NULL })
    if (length(failures) && isTRUE(fail_fast)) stop(failures[[1L]]$error, call. = FALSE)
  }
  data <- do.call(rbind, Filter(Negate(is.null), rows)); if (is.null(data)) data <- data.frame()
  if (nrow(data)) {
    if (!"feature" %in% names(data)) data$feature <- vapply(resolved, .sn_feature_name, character(1))[seq_len(min(nrow(data), length(resolved)))]
    if (length(fields)) for (field in fields) if (!field %in% names(data)) data[[field]] <- ctx[[field]] %||% NA
    names(data)[names(data) == "sample_id"] <- if ("sample_id" %in% names(data)) "observation_id" else names(data)[names(data) == "sample_id"]
  }
  plan <- .sn_empty_query(x); plan$feature_selection <- resolved; plan$field_selection <- fields; plan$observation_predicate <- x@query$observation_predicate; plan$context <- ctx; plan$layer <- measurement$name; plan$operation <- operation; plan$shape <- shape; plan$limit <- n_limit
  if (shape == "wide" && nrow(data)) data <- .sn_long_to_wide(data)
  if (shape %in% c("matrix", "sparse")) data <- .sn_long_to_matrix(data, resolved, sparse = shape == "sparse")
  nonzero_subset <- isTRUE(measurement$spec$sparse) && !isTRUE(measurement$spec$implicit_zero) && identical(source, "query")
  provenance <- list(resource = list(id = x@resource$id, version = x@resource$version), layer = measurement$name, operation = operation, context = ctx, feature_map = resolved, requests = requests, pages = sum(vapply(rows, function(z) attr(z, "shennong_pages") %||% 0L, integer(1))), failures = failures, server = list(url = x@connection$base_url, api = x@connection$api_version %||% "v1"), timestamp = format(Sys.time(), tz = "UTC"), nonzero_subset = nonzero_subset, partial = length(failures) > 0L || nonzero_subset)
  .sn_as_result(data, x, plan, provenance, partial = length(failures) > 0L || nonzero_subset)
}

sn_stream_data <- function(x, features = NULL, fields = NULL, context = NULL,
                           layer = NULL, operation = NULL,
                           format = c("arrow", "jsonl"), path = NULL,
                           allow_large = FALSE, ...) {
  if (!S7::S7_inherits(x, ShennongData)) stop("`x` must be a ShennongData handle.", call. = FALSE)
  format <- match.arg(format)
  capabilities <- sn_server_features(.sn_connection_from_handle(x))
  if (format == "arrow" && !isTRUE(capabilities$arrow)) stop("The server did not advertise Arrow streaming.", call. = FALSE)
  if (is.null(features) && length(x@query$feature_selection)) features <- vapply(x@query$feature_selection, .sn_feature_name, character(1))
  if (is.null(features) || !length(features)) stop("`features` is required for streaming.", call. = FALSE)
  measurement <- .sn_measurement(x, layer)
  resolved <- sn_resolve_features(x, features, strict = FALSE)
  body <- list(resource = x@resource$id, operation = operation %||% measurement$spec$operation %||% "expression",
               features = lapply(resolved, function(z) list(type = "gene", name = z$resolved_id)),
               context = .sn_context_merge(x, context), version = x@resource$version,
               options = list(format = format, fields = fields %||% character()))
  req <- sn_request(x@connection, .sn_endpoint("query_stream"), method = "POST", body = body)
  req <- httr2::req_headers(req, Accept = if (format == "arrow") "application/vnd.apache.arrow.stream" else "application/x-ndjson")
  response <- .sn_perform_raw(req, retries = x@connection$retries, throttle = x@connection$throttle)
  bytes <- httr2::resp_body_raw(response)
  if (is.null(path)) return(bytes)
  if (file.exists(path) && !isTRUE(allow_large)) stop("Destination already exists: ", path, call. = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE); writeBin(bytes, path); invisible(path)
}

.sn_long_to_wide <- function(data) {
  feature <- if ("feature" %in% names(data)) data$feature else data$feature_id
  obs <- if ("observation_id" %in% names(data)) data$observation_id else data[[1L]]
  value <- data$value
  keys <- unique(obs); feats <- unique(feature)
  out <- data.frame(observation_id = keys, stringsAsFactors = FALSE)
  for (f in feats) { vals <- value[match(paste(keys, f), paste(obs, feature))]; out[[make.unique(f)]] <- vals }
  metadata <- setdiff(names(data), c("value", "feature", "feature_id", "observation_id"))
  for (field in metadata) out[[field]] <- data[[field]][match(keys, obs)]
  out
}

.sn_long_to_matrix <- function(data, resolved, sparse = FALSE) {
  if (!nrow(data)) return(matrix(numeric(), nrow = 0L, ncol = 0L))
  obs <- unique(data$observation_id %||% data[[1L]]); feats <- vapply(resolved, .sn_feature_name, character(1))
  mat <- matrix(NA_real_, nrow = length(feats), ncol = length(obs), dimnames = list(feats, obs))
  for (i in seq_len(nrow(data))) mat[match(data$feature[[i]], feats), match(data$observation_id[[i]], obs)] <- data$value[[i]]
  if (sparse && requireNamespace("Matrix", quietly = TRUE)) Matrix::Matrix(mat, sparse = TRUE) else mat
}

sn_collect_metadata <- function(x, fields = NULL, limit = NULL, cursor = NULL) {
  if (!S7::S7_inherits(x, ShennongData)) stop("`x` must be a ShennongData handle.", call. = FALSE)
  if (!identical(x@view, "observations")) stop("Metadata collection requires the observations view.", call. = FALSE)
  fields <- fields %||% x@query$field_selection %||% character()
  req <- sn_request(x@connection, .sn_endpoint("metadata", utils::URLencode(x@resource$id, reserved = TRUE)), method = "GET")
  req <- httr2::req_url_query(req, fields = if (length(fields)) paste(fields, collapse = ",") else NULL,
                              limit = limit %||% x@query$limit, cursor = cursor)
  response <- .sn_perform_json(req, retries = x@connection$retries, throttle = x@connection$throttle)
  payload <- response$data %||% response
  rows <- payload$data %||% list()
  if (is.data.frame(rows)) data <- rows else if (length(rows)) {
    columns <- unique(unlist(lapply(rows, names), use.names = FALSE))
    data <- as.data.frame(stats::setNames(lapply(columns, function(column) vapply(rows, function(row) row[[column]] %||% NA_character_, character(1))), columns), stringsAsFactors = FALSE)
  } else data <- data.frame()
  plan <- .sn_empty_query(x); plan$field_selection <- fields; plan$shape <- "metadata"; plan$limit <- limit %||% x@query$limit
  meta <- payload$meta %||% list()
  provenance <- list(resource = list(id = x@resource$id, version = x@resource$version), source = "metadata_view", fields = fields, meta = meta, server = list(url = x@connection$base_url, api = x@connection$api_version %||% "v1"), partial = !is.null(meta$next_cursor))
  .sn_as_result(data, x, plan, provenance, partial = !is.null(meta$next_cursor))
}

collect.ShennongData <- function(x, ..., shape = "long", allow_large = FALSE) {
  if (identical(x@view, "observations") && isTRUE(x@connection$capabilities$metadata_views) && is.null(list(...)$features)) return(sn_collect_metadata(x, ...))
  sn_fetch_data(x, shape = shape, allow_large = allow_large, ...)
}
collect.shennong_result <- function(x, ...) x
collect <- function(x, ...) UseMethod("collect")

vec_restore.shennong_result <- function(x, to, ...) .sn_as_result(x, structure(list(`@resource` = list(id = "unknown")), class = "list"), attr(to, "shennong_query"), attr(to, "shennong_provenance"), sn_is_partial(to))
dplyr_reconstruct.shennong_result <- function(data, template) {
  attributes(data)[c("shennong_query", "shennong_provenance", "shennong_schema", "shennong_partial", "shennong_resource")] <- attributes(template)[c("shennong_query", "shennong_provenance", "shennong_schema", "shennong_partial", "shennong_resource")]
  class(data) <- class(template); data
}
