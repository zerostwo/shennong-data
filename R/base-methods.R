.sn_view_dim <- function(x) switch(
  x@view,
  observations = c(x@resource$axes$observation$size, length(x@resource$observation_fields)),
  features = c(x@resource$axes$feature$size, length(x@resource$feature_fields)),
  assay = c(x@resource$axes$feature$size, x@resource$axes$observation$size),
  artifacts = c(length(x@resource$artifacts), 0L),
  relations = c(length(x@resource$relations), 0L), NULL
)
S7::method(dim, ShennongData) <- function(x) .sn_view_dim(x)
S7::method(dimnames, ShennongData) <- function(x) {
  feature_ids <- get0("feature_ids", envir = x@cache, inherits = FALSE, ifnotfound = NULL)
  observation_ids <- get0("observation_ids", envir = x@cache, inherits = FALSE, ifnotfound = NULL)
  switch(
    x@view,
    observations = list(observation_ids, names(x@resource$observation_fields)),
    features = list(feature_ids, names(x@resource$feature_fields)),
    assay = list(feature_ids, observation_ids),
    NULL
  )
}
S7::method(print, ShennongData) <- function(x, ...) {
  invisible(list(...))
  resource <- x@resource
  cat("<ShennongData>\nResource: ", resource$id, "\nTitle:    ", resource$title, "\n", sep = "")
  cat("Kind:     ", resource$kind, "   Status: ", resource$status, if (!is.null(resource$version)) paste0("   Version: ", resource$version), "\n", sep = "")
  cat("Model:    ", resource$data_model %||% "unknown", "      Assay: ", paste(resource$assays, collapse = ", "), "\n", sep = "")
  cat("Shape:    ", format(resource$axes$feature$size, big.mark = ","), " features x ", format(resource$axes$observation$size, big.mark = ","), " ", resource$axes$observation$plural, "\n", sep = "")
  current_dim <- dim(x)
  if (!is.null(current_dim)) cat("View:     ", x@view, " (", paste(current_dim, collapse = " x "), ")\n", sep = "")
  if (length(resource$measurements)) cat("Measurements:\n- ", paste(names(resource$measurements), collapse = "\n- "), "\n", sep = "")
  if (length(resource$supported_context)) cat("Context fields:\n- ", paste(resource$supported_context, collapse = ", "), "\n", sep = "")
  ready <- resource$analysis_readiness$ready %||% character()
  if (length(ready)) cat("Ready operations:\n- ", paste(ready, collapse = "\n- "), "\n", sep = "")
  cat("Query plan:\n- no data materialized\nServer: ", x@connection$base_url, "   API: ", x@connection$api_version %||% "v1", "\n", sep = "")
  invisible(x)
}
