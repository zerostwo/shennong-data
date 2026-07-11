.sn_artifact_record <- function(artifact) {
  schema <- artifact$schema %||% list()
  data.frame(
    id = artifact$id %||% NA_character_,
    resource_id = artifact$resource_id %||% NA_character_,
    role = schema$role %||% NA_character_,
    format = artifact$format %||% NA_character_,
    size = as.numeric(artifact$size %||% NA_real_),
    checksum = artifact$checksum %||% NA_character_,
    storage_backend = artifact$storage_backend %||% NA_character_,
    layout = schema$layout %||% NA_character_,
    measure = schema$measure %||% NA_character_,
    downloadable = !is.null(artifact$id) && nzchar(artifact$id),
    stringsAsFactors = FALSE
  )
}

sn_artifacts <- function(x) {
  if (!S7::S7_inherits(x, ShennongData)) stop("`x` must be a ShennongData handle.", call. = FALSE)
  artifacts <- x@resource$artifacts %||% list()
  out <- if (length(artifacts)) do.call(rbind, lapply(artifacts, .sn_artifact_record)) else data.frame()
  class(out) <- unique(c("shennong_artifacts", class(out))); attr(out, "shennong_resource") <- list(id = x@resource$id, version = x@resource$version); out
}

sn_artifact <- function(x, id = NULL, role = NULL, format = NULL) {
  if (!S7::S7_inherits(x, ShennongData)) stop("`x` must be a ShennongData handle.", call. = FALSE)
  artifacts <- x@resource$artifacts %||% list()
  keep <- vapply(artifacts, function(a) (is.null(id) || identical(a$id, id)) &&
                   (is.null(role) || identical(a$schema$role, role)) &&
                   (is.null(format) || identical(a$format, format)), logical(1))
  if (!any(keep)) stop("No matching Artifact found for Resource `", x@resource$id, "`.", call. = FALSE)
  if (sum(keep) > 1L) stop("Artifact selection is ambiguous; provide `id`, `role`, or `format`.", call. = FALSE)
  artifacts[[which(keep)]]
}

.sn_artifact_path <- function(artifact) {
  uri <- artifact$uri %||% ""
  if (grepl("^file://", uri)) return(sub("^file://", "", uri))
  if (file.exists(uri)) return(uri)
  NULL
}

.sn_verify_file <- function(path, checksum) {
  if (is.null(checksum) || !nzchar(checksum)) return(TRUE)
  parts <- strsplit(checksum, ":", fixed = TRUE)[[1L]]
  algo <- tolower(if (length(parts) > 1L) parts[[1L]] else if (nchar(parts[[1L]]) == 64L) "sha256" else "md5")
  expected <- parts[[length(parts)]]
  if (!requireNamespace("digest", quietly = TRUE)) stop("Package `digest` is required to verify Artifact checksums.", call. = FALSE)
  actual <- digest::digest(file = path, algo = algo, serialize = FALSE)
  identical(tolower(actual), tolower(expected))
}

sn_download_artifact <- function(x, artifact, path, verify = TRUE, overwrite = FALSE,
                                 resume = TRUE, allow_large = FALSE, ...) {
  if (!S7::S7_inherits(x, ShennongData)) stop("`x` must be a ShennongData handle.", call. = FALSE)
  if (is.character(artifact)) artifact <- sn_artifact(x, id = artifact)
  size <- as.numeric(artifact$size %||% NA_real_)
  max_size <- getOption("ShennongData.max_artifact_bytes", 1024^3)
  if (!isTRUE(allow_large) && is.finite(size) && size > max_size) stop("Artifact is ", format(size, big.mark = ","), " bytes; set `allow_large = TRUE` or choose a smaller Artifact.", call. = FALSE)
  if (file.exists(path) && !isTRUE(overwrite)) stop("Destination already exists: ", path, call. = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  source <- .sn_artifact_path(artifact)
  if (!is.null(source)) {
    if (!file.copy(source, path, overwrite = TRUE)) stop("Could not copy Artifact from `", source, "`.", call. = FALSE)
  } else {
    uri <- artifact$download_url %||% artifact$url %||% artifact$uri
    if (is.null(uri) || !nzchar(uri)) {
      if (is.null(artifact$id) || !nzchar(artifact$id)) stop("Artifact has no downloadable URI or ID.", call. = FALSE)
      uri <- .sn_endpoint("artifact_download", utils::URLencode(x@resource$id, reserved = TRUE), utils::URLencode(artifact$id, reserved = TRUE))
    }
    req <- httr2::request(if (grepl("^https?://", uri)) uri else .sn_url(x@connection$base_url, uri))
    req <- httr2::req_headers(req, Accept = "application/octet-stream")
    token <- .sn_connection_token(x@connection); if (!is.null(token)) req <- httr2::req_headers(req, Authorization = paste("Bearer", token), .redact = "Authorization")
    tmp <- paste0(path, ".part")
    offset <- if (isTRUE(resume) && file.exists(tmp)) as.numeric(file.info(tmp)$size) else 0
    if (offset > 0) req <- httr2::req_headers(req, Range = paste0("bytes=", offset, "-"))
    response <- httr2::req_perform(req)
    status <- httr2::resp_status(response)
    body <- httr2::resp_body_raw(response)
    if (status == 206L && offset > 0) {
      con <- file(tmp, open = "ab"); writeBin(body, con); close(con)
    } else if (status == 200L) writeBin(body, tmp)
    else stop("Artifact download returned unexpected HTTP status ", status, ".", call. = FALSE)
    if (!file.rename(tmp, path)) stop("Could not finalize Artifact download.", call. = FALSE)
  }
  if (isTRUE(verify) && !.sn_verify_file(path, artifact$checksum)) { unlink(path); stop("Artifact checksum verification failed.", call. = FALSE) }
  sidecar <- paste0(path, ".shennong.json")
  if (requireNamespace("jsonlite", quietly = TRUE)) jsonlite::write_json(list(resource = list(id = x@resource$id, version = x@resource$version), artifact = .sn_artifact_record(artifact), downloaded_at = format(Sys.time(), tz = "UTC")), sidecar, auto_unbox = TRUE, pretty = TRUE)
  invisible(path)
}

.sn_fetch_from_artifact <- function(x, resolved, fields, layer, shape, allow_large = FALSE, ...) {
  artifact <- sn_artifact(x, role = "expression")
  path <- .sn_artifact_path(artifact)
  if (is.null(path)) {
    cache_dir <- file.path(x@connection$cache_dir, "artifacts", x@resource$id)
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    suffix <- artifact$format %||% "bin"
    path <- file.path(cache_dir, paste0(artifact$id, ".", suffix))
    if (!file.exists(path)) sn_download_artifact(x, artifact, path, verify = TRUE, overwrite = FALSE, allow_large = allow_large)
  }
  format <- tolower(artifact$format %||% tools::file_ext(path))
  if (!format %in% c("rds", "rda", "rdata", "csv", "tsv", "txt")) stop("Artifact format `", format, "` is not supported by the built-in reader.", call. = FALSE)
  raw <- if (format == "rds") readRDS(path) else if (format %in% c("rda", "rdata")) { e <- new.env(); load(path, envir = e); as.list(e) } else utils::read.delim(path, check.names = FALSE, stringsAsFactors = FALSE)
  if (is.data.frame(raw)) data <- raw else if (is.list(raw) && !is.null(raw$data)) data <- raw$data else stop("Artifact does not contain a tabular expression payload.", call. = FALSE)
  if (!"feature" %in% names(data) && "feature_id" %in% names(data)) names(data)[names(data) == "feature_id"] <- "feature"
  if (!"value" %in% names(data)) stop("Artifact expression payload must contain a `value` column.", call. = FALSE)
  data <- data[data$feature %in% vapply(resolved, .sn_feature_name, character(1)), , drop = FALSE]
  plan <- .sn_empty_query(x); plan$feature_selection <- resolved; plan$field_selection <- fields; plan$layer <- layer; plan$shape <- shape
  if (shape == "wide") data <- .sn_long_to_wide(data)
  if (shape %in% c("matrix", "sparse")) data <- .sn_long_to_matrix(data, resolved, shape == "sparse")
  provenance <- list(resource = list(id = x@resource$id, version = x@resource$version), layer = layer, source = "artifact", artifact = .sn_artifact_record(artifact), feature_map = resolved, partial = FALSE)
  .sn_as_result(data, x, plan, provenance)
}
