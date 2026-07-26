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

.sn_artifact_path <- function(artifact, trusted_local = FALSE,
                              local_root = getOption("ShennongData.trusted_local_root", NULL)) {
  uri <- artifact$local_path %||% artifact$uri %||% ""
  if (!is.character(uri) || length(uri) != 1L || !nzchar(uri)) return(NULL)
  if (grepl("^https?://", uri, ignore.case = TRUE)) return(NULL)
  if (grepl("^[A-Za-z][A-Za-z0-9+.-]*://", uri) &&
      !grepl("^file://", uri, ignore.case = TRUE)) {
    return(NULL)
  }
  if (!isTRUE(trusted_local)) return(NULL)
  if (is.null(local_root) || !is.character(local_root) ||
      length(local_root) != 1L || !nzchar(local_root)) {
    stop(
      "Trusted-local Artifact access requires a configured `local_root`.",
      call. = FALSE
    )
  }

  root <- normalizePath(path.expand(local_root), mustWork = TRUE)
  source <- if (grepl("^file://", uri, ignore.case = TRUE)) {
    decoded <- utils::URLdecode(sub("^file://", "", uri, ignore.case = TRUE))
    if (!startsWith(decoded, "/")) {
      stop("Remote file URI hosts are not supported in trusted-local mode.", call. = FALSE)
    }
    decoded
  } else if (startsWith(path.expand(uri), "/")) {
    path.expand(uri)
  } else {
    file.path(root, uri)
  }
  source <- normalizePath(source, mustWork = TRUE)
  root_prefix <- paste0(root, .Platform$file.sep)
  if (!identical(source, root) && !startsWith(source, root_prefix)) {
    stop("Artifact local path resolves outside the configured `local_root`.", call. = FALSE)
  }
  if (dir.exists(source)) {
    stop("Artifact local path must identify a file, not a directory.", call. = FALSE)
  }
  source
}

.sn_url_origin <- function(url) {
  parsed <- tryCatch(httr2::url_parse(url), error = function(error) NULL)
  if (is.null(parsed) || is.null(parsed$scheme) || is.null(parsed$hostname)) {
    stop("Artifact URL must be an absolute HTTP(S) URL.", call. = FALSE)
  }
  scheme <- tolower(parsed$scheme)
  if (!scheme %in% c("http", "https")) {
    stop("Artifact URL must use HTTP or HTTPS.", call. = FALSE)
  }
  port <- parsed$port %||% if (identical(scheme, "https")) "443" else "80"
  paste(scheme, tolower(parsed$hostname), port, sep = "|")
}

.sn_validate_foreign_artifact_url <- function(url) {
  parsed <- tryCatch(httr2::url_parse(url), error = function(error) NULL)
  if (is.null(parsed) || !identical(tolower(parsed$scheme %||% ""), "https")) {
    stop("Foreign Artifact URLs must use HTTPS.", call. = FALSE)
  }
  if (!is.null(parsed$username) || !is.null(parsed$password)) {
    stop("Foreign Artifact URLs must not contain user information.", call. = FALSE)
  }
  hostname <- tolower(parsed$hostname %||% "")
  literal_ipv4 <- grepl("^[0-9]+(?:\\.[0-9]+){3}$", hostname)
  literal_ipv6 <- grepl(":", hostname, fixed = TRUE)
  local_name <- hostname %in% c("", "localhost", "localhost.localdomain") ||
    grepl("\\.(?:localhost|local|internal|lan|home)$", hostname)
  if (literal_ipv4 || literal_ipv6 || local_name) {
    stop(
      "Foreign Artifact URL uses a local or literal-IP destination.",
      call. = FALSE
    )
  }
  allowed <- getOption("ShennongData.allowed_artifact_hosts", NULL)
  if (!is.null(allowed)) {
    allowed <- unique(tolower(as.character(allowed)))
    if (!hostname %in% allowed) {
      stop(
        "Foreign Artifact host is not in `ShennongData.allowed_artifact_hosts`.",
        call. = FALSE
      )
    }
  }
  invisible(url)
}

.sn_artifact_request <- function(connection, url, allow_auth = TRUE,
                                 range = NULL) {
  connection_url <- .sn_connection_url(connection)
  has_scheme <- grepl("^[A-Za-z][A-Za-z0-9+.-]*:", url)
  if (has_scheme && !grepl("^https?://", url, ignore.case = TRUE)) {
    stop("Artifact URL must use HTTP or HTTPS.", call. = FALSE)
  }
  absolute <- if (has_scheme) {
    url
  } else {
    .sn_url(connection_url, url)
  }
  same_origin <- identical(
    .sn_url_origin(absolute),
    .sn_url_origin(connection_url)
  )
  if (!same_origin) .sn_validate_foreign_artifact_url(absolute)

  req <- httr2::request(absolute)
  req <- httr2::req_headers(req, Accept = "application/octet-stream")
  req <- httr2::req_options(req, followlocation = FALSE)
  if (!is.null(range)) {
    req <- httr2::req_headers(req, Range = range)
  }
  if (same_origin && isTRUE(allow_auth)) {
    token <- .sn_connection_token(connection)
    if (!is.null(token)) {
      req <- httr2::req_headers(
        req,
        Authorization = paste("Bearer", token),
        .redact = "Authorization"
      )
    }
    if (!is.null(connection$project_id)) {
      req <- httr2::req_headers(
        req,
        `X-Shennong-Project-Id` = connection$project_id
      )
    }
  }
  req
}

.sn_perform_artifact_request <- function(connection, url, retries, throttle,
                                         range = NULL, max_redirects = 3L) {
  if (length(max_redirects) != 1L || is.na(max_redirects) ||
      max_redirects < 0L) {
    stop("`max_redirects` must be a non-negative scalar.", call. = FALSE)
  }
  current <- if (grepl("^https?://", url, ignore.case = TRUE)) {
    url
  } else {
    .sn_url(.sn_connection_url(connection), url)
  }
  allow_auth <- identical(
    .sn_url_origin(current),
    .sn_url_origin(.sn_connection_url(connection))
  )
  for (redirect in 0:as.integer(max_redirects)) {
    req <- .sn_artifact_request(
      connection,
      current,
      allow_auth = allow_auth,
      range = range
    )
    response <- .sn_perform_raw(
      req,
      retries = retries,
      throttle = throttle
    )
    status <- httr2::resp_status(response)
    if (!status %in% c(301L, 302L, 303L, 307L, 308L)) {
      return(response)
    }
    if (redirect >= max_redirects) {
      stop("Artifact download exceeded the redirect limit.", call. = FALSE)
    }
    location <- httr2::resp_header(response, "location")
    if (is.null(location) || !nzchar(location)) {
      stop("Artifact redirect did not provide a Location header.", call. = FALSE)
    }
    current <- httr2::url_modify_relative(req$url, location)
    next_same_origin <- identical(
      .sn_url_origin(current),
      .sn_url_origin(.sn_connection_url(connection))
    )
    allow_auth <- isTRUE(allow_auth) && next_same_origin
  }
  stop("Artifact download exceeded the redirect limit.", call. = FALSE)
}

.sn_artifact_download_url <- function(x, artifact) {
  candidate <- artifact$download_url %||% artifact$url %||% NULL
  if (is.null(candidate) && grepl("^https?://", artifact$uri %||% "", ignore.case = TRUE)) {
    candidate <- artifact$uri
  }
  if (!is.null(candidate) && is.character(candidate) &&
      length(candidate) == 1L && nzchar(candidate)) {
    return(candidate)
  }
  if (is.null(artifact$id) || !nzchar(artifact$id)) {
    stop("Artifact has no downloadable URL or ID.", call. = FALSE)
  }
  .sn_endpoint(
    "artifact_download",
    utils::URLencode(x@resource$id, reserved = TRUE),
    utils::URLencode(artifact$id, reserved = TRUE)
  )
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

#' Download a ShennongDB Artifact safely
#'
#' Same-origin Artifact endpoints use the connection's session bearer token.
#' A foreign presigned URL is requested without that token, must use HTTPS, and
#' is followed through a small number of credential-stripping redirects. Local
#' paths are disabled by default; trusted-local mode requires explicit opt-in
#' and confinement beneath `local_root`.
#'
#' @param x A [ShennongData] handle.
#' @param artifact An Artifact record or Artifact ID.
#' @param path Destination file.
#' @param verify Whether to verify a declared checksum.
#' @param overwrite Whether to replace an existing destination.
#' @param resume Whether to resume a partial HTTP download.
#' @param allow_large Whether to bypass the configured Artifact-size guard.
#' @param trusted_local Whether a local Artifact path may be read.
#' @param local_root Trusted root directory. Local paths and resolved symlinks
#'   must remain below this directory.
#' @param ... Reserved for compatible methods.
#' @return `path`, invisibly.
#' @export
sn_download_artifact <- function(x, artifact, path, verify = TRUE, overwrite = FALSE,
                                 resume = TRUE, allow_large = FALSE,
                                 trusted_local = FALSE,
                                 local_root = getOption("ShennongData.trusted_local_root", NULL),
                                 ...) {
  if (!S7::S7_inherits(x, ShennongData)) stop("`x` must be a ShennongData handle.", call. = FALSE)
  if (is.character(artifact)) artifact <- sn_artifact(x, id = artifact)
  size <- as.numeric(artifact$size %||% NA_real_)
  max_size <- getOption("ShennongData.max_artifact_bytes", 1024^3)
  if (!isTRUE(allow_large) && is.finite(size) && size > max_size) stop("Artifact is ", format(size, big.mark = ","), " bytes; set `allow_large = TRUE` or choose a smaller Artifact.", call. = FALSE)
  if (file.exists(path) && !isTRUE(overwrite)) stop("Destination already exists: ", path, call. = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  source <- .sn_artifact_path(
    artifact,
    trusted_local = trusted_local,
    local_root = local_root
  )
  if (!is.null(source)) {
    if (!file.copy(source, path, overwrite = TRUE)) stop("Could not copy Artifact from `", source, "`.", call. = FALSE)
  } else {
    uri <- .sn_artifact_download_url(x, artifact)
    tmp <- paste0(path, ".part")
    offset <- if (isTRUE(resume) && file.exists(tmp)) as.numeric(file.info(tmp)$size) else 0
    range <- if (offset > 0) paste0("bytes=", offset, "-") else NULL
    response <- .sn_perform_artifact_request(
      x@connection,
      uri,
      retries = x@connection$retries,
      throttle = x@connection$throttle,
      range = range
    )
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
  if (requireNamespace("jsonlite", quietly = TRUE)) jsonlite::write_json(list(resource = list(id = x@resource$id, version = x@resource$version), project_id = x@connection$project_id, artifact = .sn_artifact_record(artifact), downloaded_at = format(Sys.time(), tz = "UTC")), sidecar, auto_unbox = TRUE, pretty = TRUE)
  invisible(path)
}

.sn_fetch_from_artifact <- function(x, resolved, fields, layer, shape,
                                    allow_large = FALSE,
                                    trusted_local = FALSE,
                                    local_root = getOption("ShennongData.trusted_local_root", NULL),
                                    ...) {
  artifact <- sn_artifact(x, role = "expression")
  path <- .sn_artifact_path(
    artifact,
    trusted_local = trusted_local,
    local_root = local_root
  )
  if (is.null(path)) {
    cache_dir <- file.path(x@connection$cache_dir, "artifacts", x@resource$id)
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    suffix <- artifact$format %||% "bin"
    path <- file.path(cache_dir, paste0(artifact$id, ".", suffix))
    if (!file.exists(path)) {
      sn_download_artifact(
        x,
        artifact,
        path,
        verify = TRUE,
        overwrite = FALSE,
        allow_large = allow_large,
        trusted_local = trusted_local,
        local_root = local_root
      )
    }
  }
  format <- tolower(artifact$format %||% tools::file_ext(path))
  if (!format %in% c("rds", "rda", "rdata", "csv", "tsv", "txt")) stop("Artifact format `", format, "` is not supported by the built-in reader.", call. = FALSE)
  raw <- if (format == "rds") readRDS(path) else if (format %in% c("rda", "rdata")) { e <- new.env(); load(path, envir = e); as.list(e) } else utils::read.delim(path, check.names = FALSE, stringsAsFactors = FALSE)
  payload_observation_ids <- if (is.list(raw) && !is.data.frame(raw)) {
    raw$observation_ids %||% NULL
  } else {
    NULL
  }
  if (is.data.frame(raw)) data <- raw else if (is.list(raw) && !is.null(raw$data)) data <- raw$data else stop("Artifact does not contain a tabular expression payload.", call. = FALSE)
  schema <- artifact$schema %||% list()
  feature_field <- schema$feature_field %||% "feature"
  observation_field <- schema$observation_field %||% "observation_id"
  measure_field <- schema$measure %||% "value"
  if (!"feature" %in% names(data) && feature_field %in% names(data)) {
    names(data)[names(data) == feature_field] <- "feature"
  }
  if (!"feature" %in% names(data) && "feature_id" %in% names(data)) {
    names(data)[names(data) == "feature_id"] <- "feature"
  }
  if (!"observation_id" %in% names(data) && observation_field %in% names(data)) {
    names(data)[names(data) == observation_field] <- "observation_id"
  }
  if (!"value" %in% names(data) && measure_field %in% names(data)) {
    names(data)[names(data) == measure_field] <- "value"
  }
  if (!all(c("feature", "observation_id", "value") %in% names(data))) {
    stop(
      "Artifact expression payload must contain feature, observation, and value columns declared by its schema.",
      call. = FALSE
    )
  }
  requested_features <- vapply(resolved, .sn_feature_name, character(1))
  present_features <- unique(as.character(data$feature))
  missing_features <- setdiff(requested_features, present_features)
  observation_ids <- payload_observation_ids %||%
    schema$observation_ids %||%
    unique(as.character(data$observation_id))
  observation_ids <- unname(as.character(unlist(observation_ids, use.names = FALSE)))
  axis_complete <- isTRUE(schema$complete_axes) ||
    isTRUE(schema$observation_axis_complete) ||
    !is.null(payload_observation_ids)
  implicit_zero <- isTRUE(schema$implicit_zero)
  sparse_measurement <- isTRUE(schema$sparse)
  incomplete_reasons <- character()
  if (length(missing_features)) {
    incomplete_reasons <- c(incomplete_reasons, "missing_features")
  }
  if ((shape %in% c("matrix", "sparse") || sparse_measurement) &&
      !axis_complete) {
    incomplete_reasons <- c(
      incomplete_reasons,
      "observation_axis_incomplete"
    )
  }
  if (shape == "sparse" && !implicit_zero) {
    stop(
      "Sparse materialization requires an Artifact schema with `implicit_zero = TRUE`.",
      call. = FALSE
    )
  }
  data <- data[data$feature %in% requested_features, , drop = FALSE]
  plan <- .sn_empty_query(x); plan$feature_selection <- resolved; plan$field_selection <- fields; plan$layer <- layer; plan$shape <- shape
  if (shape == "wide") data <- .sn_long_to_wide(data)
  if (shape %in% c("matrix", "sparse")) {
    data <- .sn_long_to_matrix(
      data,
      resolved,
      sparse = shape == "sparse",
      implicit_zero = implicit_zero,
      observation_ids = observation_ids
    )
    if (shape == "matrix" && anyNA(data)) {
      incomplete_reasons <- c(incomplete_reasons, "missing_coordinates")
    }
  }
  incomplete_reasons <- unique(incomplete_reasons)
  partial <- length(incomplete_reasons) > 0L
  data_bundle <- utils::modifyList(
    .sn_data_bundle_base(x@resource, "shennongdb-v1-resource-artifact"),
    list(
      complete = !partial,
      axis_complete = axis_complete,
      orientation = if (shape %in% c("matrix", "sparse")) {
        "feature_by_observation"
      } else {
        shape
      },
      shape = shape,
      layer = layer,
      measurement = schema,
      implicit_zero = implicit_zero,
      feature_ids = requested_features,
      observation_ids = observation_ids,
      missing_features = missing_features,
      incomplete_reasons = incomplete_reasons
    )
  )
  provenance <- list(
    resource = list(id = x@resource$id, version = x@resource$version),
    project_id = x@connection$project_id,
    layer = layer,
    source = "artifact",
    artifact = .sn_artifact_record(artifact),
    feature_map = resolved,
    partial = partial,
    data_bundle = data_bundle
  )
  .sn_as_result(data, x, plan, provenance, partial = partial)
}
