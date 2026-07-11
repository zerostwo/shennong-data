# Typed, serialisable query plans.  Keep this file dependency-light: the
# server contract is small enough that base R is sufficient for compilation.

.sn_empty_query <- function(x) {
  utils::modifyList(list(
    schema_version = "1.0",
    resource_id = x@resource$id,
    resource_version = x@resource$version,
    view = x@view,
    operation = NULL,
    assay = NULL,
    layer = NULL,
    observation_predicate = NULL,
    field_selection = character(),
    feature_selection = list(),
    renames = list(),
    shape = "long",
    limit = NULL,
    local_steps = list(),
    options = list()
  ), x@query)
}

.sn_query_copy <- function(x) {
  new_shennong_data(.sn_connection_from_handle(x), x@resource, x@view,
                    .sn_empty_query(x), x@cache)
}

.sn_field_info <- function(x, field) {
  info <- x@resource$observation_fields[[field]]
  if (is.null(info)) stop("Unknown observation field `", field, "` for Resource `",
                         x@resource$id, "`.", call. = FALSE)
  info
}

.sn_literal <- function(value) {
  if (length(value) != 1L) stop("A filter literal must be scalar.", call. = FALSE)
  list(value = unname(value), type = typeof(value))
}

.sn_parse_predicate <- function(expr, x, envir = parent.frame()) {
  if (is.call(expr) && identical(expr[[1L]], as.name("&"))) {
    return(list(op = "and", args = lapply(as.list(expr)[-1L], .sn_parse_predicate, x = x, envir = envir)))
  }
  if (is.call(expr) && identical(expr[[1L]], as.name("|"))) {
    args <- as.list(expr)[-1L]
    parsed <- lapply(args, .sn_parse_predicate, x = x, envir = envir)
    if (length(parsed) == 2L && identical(parsed[[1L]]$field, parsed[[2L]]$field) &&
        all(vapply(parsed, function(z) identical(z$op, "eq"), logical(1)))) {
      return(list(op = "in", field = parsed[[1L]]$field,
                  value = c(parsed[[1L]]$value, parsed[[2L]]$value), type = "character"))
    }
    stop("Only `field == value | field == value` can be pushed down; use `%in%` for other OR expressions.", call. = FALSE)
  }
  if (!is.call(expr) || length(expr) < 2L) stop("Unsupported filter expression.", call. = FALSE)
  op <- as.character(expr[[1L]])
  if (op %in% c("==", "%in%")) {
    field <- as.character(expr[[2L]])
    .sn_field_info(x, field)
    value <- eval(expr[[3L]], envir = envir)
    if (op == "==") {
      literal <- .sn_literal(value)
      return(list(op = "eq", field = field, value = literal$value, type = literal$type))
    }
    if (length(value) < 1L) stop("`%in%` requires at least one value.", call. = FALSE)
    return(list(op = "in", field = field, value = unname(value), type = typeof(value[[1L]])))
  }
  if (op %in% c("is.na", "!is.na")) {
    field <- as.character(expr[[2L]])
    .sn_field_info(x, field)
    return(list(op = if (op == "is.na") "is_null" else "not_null", field = field))
  }
  stop("Unsupported filter operator `", op, "`. Supported operators: `==`, `%in%`, `&`, and capability-gated `is.na()`.", call. = FALSE)
}

sn_filter <- function(.data, ...) {
  if (!S7::S7_inherits(.data, ShennongData)) stop("`.data` must be a ShennongData handle.", call. = FALSE)
  if (!identical(.data@view, "observations")) stop("`filter()` requires the observations view; use `sn_obs(x)` first.", call. = FALSE)
  exprs <- as.list(substitute(list(...)))[-1L]
  if (!length(exprs)) return(.data)
  predicates <- lapply(exprs, .sn_parse_predicate, x = .data, envir = parent.frame())
  predicate <- if (length(predicates) == 1L) predicates[[1L]] else list(op = "and", args = predicates)
  out <- .sn_query_copy(.data)
  old <- out@query$observation_predicate
  out@query$observation_predicate <- if (is.null(old)) predicate else list(op = "and", args = list(old, predicate))
  out
}

filter.ShennongData <- function(.data, ..., .preserve = FALSE) {
  invisible(.preserve)
  sn_filter(.data, ...)
}

sn_select <- function(x, ...) {
  if (!S7::S7_inherits(x, ShennongData)) stop("`x` must be a ShennongData handle.", call. = FALSE)
  fields <- as.list(substitute(list(...)))[-1L]
  fields <- vapply(fields, function(z) as.character(z), character(1))
  if (!length(fields)) fields <- names(x@resource$observation_fields)
  invisible(lapply(fields, .sn_field_info, x = x))
  out <- .sn_query_copy(x)
  out@query$field_selection <- unique(fields)
  out
}

select.ShennongData <- function(.data, ...) sn_select(.data, ...)

sn_select_features <- function(x, ..., features = NULL, resolve = c("auto", "strict", "never")) {
  if (!S7::S7_inherits(x, ShennongData)) stop("`x` must be a ShennongData handle.", call. = FALSE)
  resolve <- match.arg(resolve)
  dots <- as.list(substitute(list(...)))[-1L]
  values <- unlist(lapply(dots, function(z) {
    value <- tryCatch(eval(z, parent.frame()), error = function(e) as.character(z))
    as.character(value)
  }), use.names = FALSE)
  if (!is.null(features)) values <- c(values, as.character(features))
  values <- unique(values[nzchar(values)])
  if (!length(values)) stop("`features` must contain at least one identifier.", call. = FALSE)
  out <- .sn_query_copy(x)
  out@query$feature_selection <- lapply(values, function(input) list(input = input))
  if (resolve == "strict") out@query$feature_selection <- sn_resolve_features(out, values, strict = TRUE)
  out
}

sn_use_layer <- function(x, layer) {
  sn_assay(x, layer = layer)
}

sn_rename <- function(.data, ...) {
  dots <- as.list(substitute(list(...)))[-1L]
  if (!length(dots)) return(.data)
  aliases <- stats::setNames(lapply(dots, function(z) as.character(z)), names(dots))
  for (source in unname(unlist(aliases))) .sn_field_info(.data, source)
  out <- .sn_query_copy(.data)
  out@query$renames <- utils::modifyList(out@query$renames %||% list(), aliases)
  out
}

rename.ShennongData <- function(.data, ...) sn_rename(.data, ...)

sn_slice_head <- function(x, n = 6L, ...) {
  if (!S7::S7_inherits(x, ShennongData)) stop("`x` must be a ShennongData handle.", call. = FALSE)
  if (length(n) != 1L || is.na(n) || n < 0) stop("`n` must be a non-negative scalar.", call. = FALSE)
  out <- .sn_query_copy(x)
  out@query$limit <- as.integer(n)
  out
}

slice_head.ShennongData <- function(.data, ..., n = 6L) sn_slice_head(.data, n)

head.ShennongData <- function(x, n = 6L, ...) sn_slice_head(x, n)

sn_query_plan <- function(x) {
  if (S7::S7_inherits(x, ShennongData)) return(.sn_empty_query(x))
  if (inherits(x, "shennong_result")) return(attr(x, "shennong_query"))
  stop("`x` is not a ShennongData handle or shennong_result.", call. = FALSE)
}

.sn_jsonable <- function(x) {
  if (is.environment(x)) return(NULL)
  if (is.list(x)) return(lapply(x, .sn_jsonable))
  x
}

sn_show_query <- function(x) {
  plan <- sn_query_plan(x)
  cat("Resource: ", plan$resource_id, "\n", sep = "")
  cat("View: ", plan$view, "\n", sep = "")
  if (length(plan$feature_selection)) cat("Features: ", paste(vapply(plan$feature_selection, `[[`, "", "input"), collapse = ", "), "\n", sep = "")
  if (length(plan$field_selection)) cat("Fields: ", paste(plan$field_selection, collapse = ", "), "\n", sep = "")
  if (!is.null(plan$observation_predicate)) cat("Filters: pushdown predicate\n")
  invisible(plan)
}

sn_explain <- function(x) {
  plan <- sn_query_plan(x)
  source <- if (S7::S7_inherits(x, ShennongData) && length(x@resource$artifacts)) "query or artifact" else "query"
  result <- list(resource = plan$resource_id, source = source,
                 pushdown = c("feature", "context", "fields", "limit"),
                 local_steps = plan$local_steps %||% list(), plan = plan)
  class(result) <- "shennong_explanation"
  result
}

format.shennong_explanation <- function(x, ...) paste0("<shennong_explanation> ", x$resource, " via ", x$source)
print.shennong_explanation <- function(x, ...) { cat(format(x), "\n"); invisible(x) }

sn_query_fingerprint <- function(x) {
  plan <- .sn_jsonable(sn_query_plan(x))
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    json <- jsonlite::toJSON(plan, auto_unbox = TRUE, null = "null", digits = NA, pretty = FALSE)
  } else json <- paste(utils::capture.output(dput(plan)), collapse = "")
  if (requireNamespace("digest", quietly = TRUE)) digest::digest(json, algo = "sha256") else paste0("sha256:", nchar(json), ":", sum(charToRaw(json)))
}

sn_write_query <- function(x, path, format = c("json", "yaml")) {
  format <- match.arg(format)
  if (format == "yaml") stop("YAML query writing requires an explicit YAML dependency; use `format = \"json\"`.", call. = FALSE)
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Package `jsonlite` is required to write query plans.", call. = FALSE)
  jsonlite::write_json(.sn_jsonable(sn_query_plan(x)), path, auto_unbox = TRUE, null = "null", pretty = TRUE)
  invisible(path)
}

sn_read_query <- function(path, connection = sn_connection()) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Package `jsonlite` is required to read query plans.", call. = FALSE)
  plan <- jsonlite::read_json(path, simplifyVector = FALSE)
  x <- sn_load_data(plan$resource_id, version = plan$resource_version, view = plan$view, connection = connection)
  x@query <- utils::modifyList(.sn_empty_query(x), plan)
  x
}
