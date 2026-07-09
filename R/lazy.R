sn_load_data <- function(dataset = "toil",
                         version = NULL,
                         assay = "rna",
                         data_model = NULL,
                         layer = NULL,
                         measure = "expression",
                         server_url = sn_server_url(),
                         token = sn_get_api_token(),
                         api_url = NULL,
                         lazy = TRUE,
                         limit = 1000L,
                         ...) {
  if (!is.character(dataset) || length(dataset) != 1L || !nzchar(dataset)) {
    stop("`dataset` must be a non-empty character scalar.", call. = FALSE)
  }
  if (!is.null(api_url)) {
    server_url <- api_url
  }
  data_model <- data_model %||% .sn_default_data_model(dataset)
  layer <- layer %||% .sn_default_layer(data_model)
  x <- structure(
    list(
      server_url = .sn_normalize_url(server_url),
      dataset = dataset,
      version = version,
      assay = assay,
      data_model = data_model,
      layer = layer,
      measure = measure,
      filters = list(),
      fields = character(),
      features = character(),
      token = token,
      limit = as.integer(limit)
    ),
    class = c("shennong_remote_tbl", "shennong_lazy")
  )
  if (isTRUE(lazy)) {
    return(x)
  }
  sn_collect(x, ...)
}

check_shennong_remote_tbl <- function(x) {
  if (!inherits(x, "shennong_remote_tbl") && !inherits(x, "shennong_lazy")) {
    stop("`x` must be a Shennong lazy data object.", call. = FALSE)
  }
  invisible(x)
}

.sn_default_data_model <- function(dataset) {
  if (grepl("^pbmc", dataset, ignore.case = TRUE)) {
    return("single_cell")
  }
  if (grepl("survival", dataset, ignore.case = TRUE)) {
    return("clinical")
  }
  "bulk"
}

.sn_default_layer <- function(data_model) {
  switch(
    data_model,
    single_cell = "counts",
    spatial = "counts",
    clinical = NULL,
    "log2_tpm"
  )
}

filter.shennong_remote_tbl <- function(.data, ..., .preserve = FALSE) {
  del(.preserve)
  quos <- rlang::enquos(...)
  if (!length(quos)) {
    return(.data)
  }
  parsed <- lapply(quos, .sn_filter_quo)
  .data$filters <- .sn_merge_filters(c(list(.data$filters), parsed))
  .data
}

select.shennong_remote_tbl <- function(.data, ...) {
  fields <- vapply(rlang::ensyms(...), rlang::as_name, character(1))
  .data$fields <- unique(c(.data$fields, fields))
  .data
}

collect.shennong_remote_tbl <- function(x,
                                        ...,
                                        n = Inf,
                                        features = NULL,
                                        limit = NULL,
                                        max_pages = Inf) {
  del(...)
  sn_collect(x, n = n, features = features, limit = limit, max_pages = max_pages)
}

sn_collect <- function(x,
                       n = Inf,
                       features = NULL,
                       limit = NULL,
                       max_pages = Inf) {
  check_shennong_remote_tbl(x)
  if (is.null(features)) {
    features <- x$features
  }
  features <- as.character(features)
  if (length(features) == 0L && x$data_model %in% c("bulk", "single_cell", "spatial")) {
    stop("Expression queries require `features`, for example `features = \"YTHDF2\"`.", call. = FALSE)
  }
  page_limit <- as.integer(limit %||% x$limit)
  remaining <- if (is.infinite(n)) Inf else as.integer(n)
  cursor <- NULL
  pages <- 0L
  out <- list()
  repeat {
    current_limit <- if (is.infinite(remaining)) page_limit else min(page_limit, remaining)
    spec <- .sn_query_spec(
      x,
      features = features,
      limit = current_limit,
      cursor = cursor
    )
    response <- .sn_request_json(
      "POST",
      .sn_url(x$server_url, "/v1/query"),
      body = spec,
      headers = .sn_auth_headers(x$token)
    )
    out[[length(out) + 1L]] <- tibble::as_tibble(response$data)
    pages <- pages + 1L
    rows <- nrow(out[[length(out)]])
    if (!is.infinite(remaining)) {
      remaining <- remaining - rows
    }
    cursor <- response$meta$next_cursor
    if (is.null(cursor) || rows == 0L || remaining <= 0L || pages >= max_pages) {
      break
    }
  }
  if (length(out) == 0L) {
    return(tibble::tibble())
  }
  dplyr::bind_rows(out)
}

sn_query <- function(dataset,
                     features,
                     filters = list(),
                     version = NULL,
                     assay = "rna",
                     data_model = "bulk",
                     layer = "log2_tpm",
                     measure = "expression",
                     server_url = sn_server_url(),
                     token = sn_get_api_token(),
                     limit = 1000L) {
  x <- sn_load_data(
    dataset = dataset,
    version = version,
    assay = assay,
    data_model = data_model,
    layer = layer,
    measure = measure,
    server_url = server_url,
    token = token
  )
  x$filters <- filters
  sn_collect(x, features = features, limit = limit)
}

sn_query_spec <- function(
  x,
  features = NULL,
  fields = NULL,
  limit = NULL,
  cursor = NULL,
  format = "json",
  shape = "tidy",
  aggregation = NULL,
  include_metadata = TRUE,
  include_feature_metadata = FALSE,
  measure = NULL,
  layer = NULL
) {
  check_shennong_remote_tbl(x)
  .sn_query_spec(
    x = x,
    features = features %||% x$features,
    fields = fields,
    limit = limit %||% x$limit %||% 1000L,
    cursor = cursor,
    format = format,
    shape = shape,
    aggregation = aggregation,
    include_metadata = include_metadata,
    include_feature_metadata = include_feature_metadata,
    measure = measure %||% x$measure,
    layer = layer %||% x$layer
  )
}

sn_fetch_genes <- function(x, genes, ...) {
  if (!is.character(genes) || !length(genes) || any(!nzchar(genes))) {
    stop("`genes` must be a non-empty character vector.", call. = FALSE)
  }
  sn_collect(x, features = genes, ...)
}

print.shennong_remote_tbl <- function(x, ...) {
  del(...)
  cat("# Shennong lazy data\n")
  cat("dataset: ", x$dataset, "\n", sep = "")
  cat("server:  ", x$server_url, "\n", sep = "")
  cat("assay:   ", x$assay, "\n", sep = "")
  cat("model:   ", x$data_model, "\n", sep = "")
  if (length(x$filters) > 0L) {
    cat("filters: ", paste(names(x$filters), collapse = ", "), "\n", sep = "")
  }
  invisible(x)
}

.sn_query_spec <- function(
  x,
  features,
  limit,
  cursor = NULL,
  fields = NULL,
  format = "json",
  shape = "tidy",
  aggregation = NULL,
  include_metadata = TRUE,
  include_feature_metadata = FALSE,
  measure = NULL,
  layer = NULL
) {
  list(
    dataset = x$dataset,
    version = x$version,
    assay = x$assay,
    data_model = x$data_model,
    select = list(
      features = as.list(as.character(features)),
      observations = .sn_json_object(x$filters),
      fields = as.list(as.character(fields %||% x$fields))
    ),
    layer = layer %||% x$layer,
    measure = measure %||% x$measure,
    `return` = list(format = format, shape = shape),
    options = list(
      limit = as.integer(limit),
      cursor = cursor,
      include_metadata = include_metadata,
      include_feature_metadata = include_feature_metadata,
      aggregation = aggregation
    )
  )
}

.sn_json_object <- function(x) {
  if (length(x) == 0L) {
    return(structure(list(), names = character()))
  }
  x
}

.sn_filter_quo <- function(quo) {
  .sn_filter_expr(rlang::get_expr(quo), rlang::get_env(quo))
}

.sn_filter_expr <- function(expr, env) {
  if (!rlang::is_call(expr)) {
    stop("Only simple filter expressions are supported for Shennong lazy data.", call. = FALSE)
  }
  op <- rlang::call_name(expr)
  if (identical(op, "&")) {
    return(.sn_merge_filters(list(
      .sn_filter_expr(expr[[2]], env),
      .sn_filter_expr(expr[[3]], env)
    )))
  }
  if (!op %in% c("==", "%in%")) {
    stop("Unsupported lazy filter operator: ", op, call. = FALSE)
  }
  field <- rlang::as_name(expr[[2]])
  value <- rlang::eval_tidy(expr[[3]], env = env)
  if (identical(op, "==") && length(value) != 1L) {
    stop("`==` filters must compare to one value. Use `%in%` for multiple values.", call. = FALSE)
  }
  stats::setNames(list(as.character(value)), field)
}

.sn_merge_filters <- function(filters) {
  merged <- list()
  for (item in filters) {
    for (name in names(item)) {
      merged[[name]] <- item[[name]]
    }
  }
  merged
}
