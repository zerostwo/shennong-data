sn_relations <- function(x, direction = c("both", "out", "in"), type = NULL) {
  if (!S7::S7_inherits(x, ShennongData)) stop("`x` must be a ShennongData handle.", call. = FALSE)
  direction <- match.arg(direction)
  relations <- x@resource$relations %||% list()
  if (length(relations)) {
    out <- do.call(rbind, lapply(relations, function(r) data.frame(
      source = r$source %||% r$source_id %||% x@resource$id,
      target = r$target %||% r$target_id %||% NA_character_,
      type = r$type %||% NA_character_,
      evidence = I(list(r$evidence %||% list())),
      provenance = I(list(r$provenance %||% list())),
      stringsAsFactors = FALSE)))
  } else out <- data.frame(source = character(), target = character(), type = character(), evidence = I(list()), provenance = I(list()))
  if (direction == "out") out <- out[out$source == x@resource$id, , drop = FALSE]
  if (direction == "in") out <- out[out$target == x@resource$id, , drop = FALSE]
  if (!is.null(type)) out <- out[out$type %in% type, , drop = FALSE]
  class(out) <- unique(c("shennong_relations", class(out))); out
}

sn_related <- function(x, type = NULL, kind = NULL, load = FALSE) {
  rel <- sn_relations(x, type = type)
  ids <- unique(c(rel$source, rel$target)); ids <- setdiff(ids, x@resource$id)
  if (isTRUE(load)) {
    return(stats::setNames(lapply(ids, function(id) sn_load_data(id, connection = .sn_connection_from_handle(x))), ids))
  }
  out <- data.frame(resource_id = ids, stringsAsFactors = FALSE)
  if (!is.null(kind)) out$kind <- kind
  out
}

ShennongCollection <- structure(list(), class = "ShennongCollection")

sn_collection <- function(..., resources = NULL) {
  values <- c(list(...), resources %||% list())
  if (!length(values) || is.null(names(values)) || any(!nzchar(names(values)))) stop("Collection resources must be named ShennongData handles.", call. = FALSE)
  if (!all(vapply(values, function(x) S7::S7_inherits(x, ShennongData), logical(1)))) stop("All collection entries must be ShennongData handles.", call. = FALSE)
  structure(list(resources = values, feature_map = NULL, sample_map = NULL, provenance = list()), class = "ShennongCollection")
}

print.ShennongCollection <- function(x, ...) { cat("<ShennongCollection>\nResources: ", paste(names(x$resources), collapse = ", "), "\n", sep = ""); invisible(x) }

sn_collection_resources <- function(x) {
  if (!inherits(x, "ShennongCollection")) stop("`x` must be a ShennongCollection.", call. = FALSE)
  x$resources
}

sn_link_features <- function(collection, by = "ensembl_gene_stable_id", strict = TRUE) {
  if (!inherits(collection, "ShennongCollection")) stop("`collection` must be a ShennongCollection.", call. = FALSE)
  resources <- collection$resources
  refs <- lapply(resources, function(x) {
    fields <- x@resource$feature_fields
    ids <- names(fields)[vapply(fields, function(z) identical(z$role, "identifier"), logical(1))]
      data.frame(resource = x@resource$id, field = if (length(ids)) ids[[1L]] else NA_character_, stable_id = NA_character_, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, refs)
  if (isTRUE(strict) && anyNA(out$field)) stop("Feature linking requires a declared feature identifier field in every Resource.", call. = FALSE)
  collection$feature_map <- list(by = by, records = out); collection
}

sn_as_collection <- function(x, target = "MultiAssayExperiment", allow_large = FALSE, ...) {
  if (!inherits(x, "ShennongCollection")) stop("`x` must be a ShennongCollection.", call. = FALSE)
  if (!identical(target, "MultiAssayExperiment")) stop("Unsupported collection target `", target, "`.", call. = FALSE)
  if (!requireNamespace("MultiAssayExperiment", quietly = TRUE)) stop("Package `MultiAssayExperiment` is required.", call. = FALSE)
  invisible(allow_large)
  if (is.null(x$sample_map)) stop("MultiAssayExperiment conversion requires an explicit sample map; use `sn_set_sample_map()` first.", call. = FALSE)
  stop("MultiAssayExperiment conversion needs materialized assays and is not implemented for an unbounded collection.", call. = FALSE)
}

sn_set_sample_map <- function(collection, sample_map) {
  if (!inherits(collection, "ShennongCollection")) stop("`collection` must be a ShennongCollection.", call. = FALSE)
  if (!is.data.frame(sample_map) || !all(c("assay", "primary", "colname") %in% names(sample_map))) stop("`sample_map` must contain `assay`, `primary`, and `colname` columns.", call. = FALSE)
  collection$sample_map <- sample_map; collection
}
