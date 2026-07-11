.sn_field_record <- function(fields, role) {
  if (is.null(fields)) return(list())
  if (is.character(fields)) return(stats::setNames(lapply(fields, function(x) list(type = "unknown", role = role)), fields))
  if (!is.list(fields) || is.null(names(fields))) return(list())
  lapply(fields, function(field) utils::modifyList(list(type = "unknown", role = role), field))
}

.sn_chr <- function(x) unname(as.character(unlist(x, use.names = FALSE)))

.sn_dimensions <- function(metadata) {
  dimensions <- metadata$dimensions %||% list()
  feature_size <- dimensions$features %||% dimensions$feature %||% NA_integer_
  observation_names <- setdiff(names(dimensions), c("features", "feature"))
  observation_size <- if (length(observation_names)) dimensions[[observation_names[[1]]]] else NA_integer_
  list(
    feature = list(size = as.integer(feature_size), plural = "features"),
    observation = list(size = as.integer(observation_size), plural = observation_names[[1]] %||% "observations")
  )
}

.sn_measurements <- function(resource) {
  artifacts <- resource$artifacts %||% list()
  measures <- unique(vapply(artifacts, function(x) x$schema$measure %||% NA_character_, character(1)))
  measures <- measures[!is.na(measures)]
  stats::setNames(lapply(measures, function(name) list(
    name = name, assay = resource$metadata$assays[[1]] %||% NULL,
    value_type = "unknown", unit = NULL, transformation = NULL, sparse = NULL,
    implicit_zero = NULL, source_measure = name,
    operation = resource$spec$operations[[1]] %||% NULL, artifact_role = "expression",
    default = length(measures) == 1L
  )), measures)
}

.sn_normalize_resource <- function(detail) {
  resource <- detail$resource %||% detail$data %||% detail
  if (!is.list(resource) || !is.character(resource$id) || length(resource$id) != 1L || !nzchar(resource$id)) {
    stop("Malformed ShennongDB Resource response: missing `resource$id`.", call. = FALSE)
  }
  metadata <- resource$metadata %||% list()
  artifacts <- resource$artifacts %||% list()
  expression <- Filter(function(x) identical(x$schema$role, "expression"), artifacts)
  feature_names <- unique(vapply(expression, function(x) x$schema$feature_field %||% NA_character_, character(1)))
  observation_id <- unique(vapply(expression, function(x) x$schema$observation_field %||% NA_character_, character(1)))
  observation_id <- observation_id[!is.na(observation_id)]
  supported_context <- .sn_chr(metadata$supported_context)
  observation_fields <- .sn_field_record(metadata$observation_fields, "context")
  if (!length(observation_fields)) {
    observation_fields <- .sn_field_record(unique(c(observation_id, supported_context)), "context")
    if (length(observation_id) == 1L) observation_fields[[observation_id]]$role <- "identifier"
  }
  list(
    schema_version = "1.0", id = resource$id, kind = resource$kind %||% "Resource",
    title = metadata$title %||% resource$id, summary = metadata$summary %||% NULL,
    status = resource$status %||% "unknown", version = resource$spec$version %||% NULL,
    revision = resource$revision %||% NULL, etag = resource$etag %||% NULL,
    organism = metadata$organism %||% list(), data_model = metadata$data_model %||% NULL,
    assays = .sn_chr(metadata$assays), axes = .sn_dimensions(metadata),
    observation_fields = observation_fields,
    feature_fields = .sn_field_record(feature_names[!is.na(feature_names)], "identifier"),
    measurements = .sn_measurements(resource), operations = .sn_chr(resource$spec$operations),
    supported_context = supported_context,
    analysis_readiness = metadata$analysis_capabilities %||% list(), artifacts = artifacts,
    relations = resource$relations %||% list(), provenance = resource$provenance %||% list(),
    permissions = resource$permissions %||% list(), raw = detail
  )
}

.sn_connection_from_handle <- function(x) structure(x@connection, class = "shennong_connection")

.sn_view <- function(x, view, query = x@query) {
  if (!S7::S7_inherits(x, ShennongData)) stop("`x` must be a ShennongData handle.", call. = FALSE)
  query$view <- view
  new_shennong_data(.sn_connection_from_handle(x), x@resource, view, query)
}

.sn_auto_view <- function(resource) {
  if (identical(resource$kind, "Dataset") && length(resource$observation_fields)) return("observations")
  if (!is.na(resource$axes$feature$size) && !is.na(resource$axes$observation$size)) return("assay")
  "resource"
}

sn_load_data <- function(resource, version = NULL,
                         view = c("auto", "observations", "assay", "resource"),
                         connection = sn_connection(), refresh = FALSE,
                         validate = c("metadata", "capabilities", "none"), ...) {
  invisible(refresh)
  .sn_check_connection(connection)
  if (!is.character(resource) || length(resource) != 1L || !nzchar(resource)) stop("`resource` must be a non-empty character scalar.", call. = FALSE)
  view <- match.arg(view)
  validate <- match.arg(validate)
  detail <- .sn_perform_json(
    sn_request(connection, .sn_endpoint("agent_resource", utils::URLencode(resource, reserved = TRUE))),
    retries = connection$retries, throttle = connection$throttle
  )
  normalized <- .sn_normalize_resource(detail)
  if (!is.null(version) && !identical(version, normalized$version)) stop("Resource `", resource, "` does not provide version `", version, "`.", call. = FALSE)
  if (identical(validate, "metadata") && !identical(normalized$status, "available")) stop("Resource `", resource, "` is not available.", call. = FALSE)
  if (identical(validate, "capabilities")) sn_capabilities(connection)
  if (identical(view, "auto")) view <- .sn_auto_view(normalized)
  query <- list(schema_version = "1.0", resource_id = normalized$id, resource_version = normalized$version,
                view = view, operation = NULL, assay = NULL, layer = NULL,
                observation_predicate = NULL, field_selection = character(), feature_selection = character())
  new_shennong_data(connection, normalized, view, query)
}

sn_obs <- function(x) .sn_view(x, "observations")
sn_var <- function(x) .sn_view(x, "features")
sn_assay <- function(x, assay = NULL, layer = NULL) {
  if (!is.null(assay) && !assay %in% x@resource$assays) stop("Unknown assay `", assay, "` for Resource `", x@resource$id, "`.", call. = FALSE)
  if (is.null(assay)) assay <- x@resource$assays[[1]] %||% NULL
  if (is.null(layer) && length(x@resource$measurements) == 1L) layer <- names(x@resource$measurements)[[1]]
  if (!is.null(layer) && !layer %in% names(x@resource$measurements)) stop("Unknown layer `", layer, "`. Available layers: ", paste(names(x@resource$measurements), collapse = ", "), call. = FALSE)
  query <- x@query
  query$assay <- assay
  query$layer <- layer
  .sn_view(x, "assay", query)
}
sn_resource <- function(x) .sn_view(x, "resource")
sn_schema <- function(x) {
  if (!S7::S7_inherits(x, ShennongData)) stop("`x` must be a ShennongData handle.", call. = FALSE)
  x@resource
}
