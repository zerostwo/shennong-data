.sn_agent_scalar <- function(value, default = NA_character_) {
  if (is.null(value) || !length(value)) return(default)
  paste(as.character(unlist(value, use.names = FALSE)), collapse = ",")
}

.sn_agent_records <- function(rows) {
  if (is.data.frame(rows)) return(rows)
  if (!is.list(rows) || !length(rows)) return(data.frame())
  data.frame(
    id = vapply(rows, function(row) .sn_agent_scalar(row$id), character(1)),
    kind = vapply(rows, function(row) .sn_agent_scalar(row$kind), character(1)),
    title = vapply(rows, function(row) .sn_agent_scalar(row$title), character(1)),
    summary = vapply(rows, function(row) .sn_agent_scalar(row$summary), character(1)),
    organism = vapply(rows, function(row) .sn_agent_scalar(row$organism), character(1)),
    data_model = vapply(rows, function(row) .sn_agent_scalar(row$data_model), character(1)),
    assays = vapply(rows, function(row) .sn_agent_scalar(row$assays), character(1)),
    status = vapply(rows, function(row) .sn_agent_scalar(row$status), character(1)),
    details_url = vapply(rows, function(row) .sn_agent_scalar(row$details_url), character(1)),
    stringsAsFactors = FALSE
  )
}

#' List Resources visible to the current ShennongDB connection
#'
#' Resource discovery uses the permission-filtered Agent manifest and never
#' loads Resource payloads.
#'
#' @param connection A ShennongDB connection.
#' @param search Optional local text filter over identifiers and descriptions.
#' @return A data frame with one visible Resource per row.
#' @export
sn_resources <- function(connection = sn_connection(), search = NULL) {
  .sn_check_connection(connection)
  if (!is.null(search) && (!is.character(search) || length(search) != 1L || !nzchar(search))) {
    stop("`search` must be NULL or a non-empty character scalar.", call. = FALSE)
  }
  manifest <- .sn_perform_json(
    sn_request(connection, .sn_endpoint("agent_manifest")),
    retries = connection$retries,
    throttle = connection$throttle
  )
  records <- .sn_agent_records(manifest$resources %||% list())
  if (!is.null(search) && nrow(records)) {
    needle <- tolower(search)
    haystack <- apply(records[c("id", "kind", "title", "summary", "organism", "data_model", "assays")], 1L, paste, collapse = " ")
    records <- records[grepl(needle, tolower(haystack), fixed = TRUE), , drop = FALSE]
  }
  rownames(records) <- NULL
  attr(records, "shennong_manifest_schema") <- manifest$schema_version %||% NA_character_
  records
}

#' Check ShennongData compatibility with a Shennong API
#'
#' The compatibility report honors a server capability declaration of
#' `project_scope_required = TRUE`. In that case, a connection without
#' `project_id` is incompatible for inspection and query even when public
#' Resource discovery is available. Servers that omit the capability, including
#' compatible public/direct ShennongDB endpoints, retain projectless behavior.
#'
#' @param connection A negotiated Shennong OS/gateway or ShennongDB connection.
#' @param probe_discovery Whether to verify the permission-filtered Agent manifest.
#' @return A structured compatibility report, including Project requirements
#'   and actionable incompatibility reasons.
#' @export
sn_api_compatibility <- function(connection = sn_connection(), probe_discovery = TRUE) {
  .sn_check_connection(connection)
  capabilities <- sn_capabilities(connection)
  features <- sn_server_features(connection)
  project_required <- isTRUE(capabilities$project_scope_required)
  project_supplied <- !is.null(connection$project_id)
  discovery <- if (isTRUE(probe_discovery)) {
    tryCatch(sn_resources(connection), error = identity)
  } else {
    NULL
  }
  discovery_ok <- !inherits(discovery, "error")
  checks <- c(
    api_v1 = identical(connection$api_version, "v1"),
    resource_discovery = discovery_ok,
    resource_inspection = "inspect" %in% (capabilities$resources %||% character()),
    expression_query = "expression" %in% (capabilities$query_operations %||% character()),
    project_scope = !project_required || project_supplied,
    batch_query = isTRUE(features$batch_features),
    metadata_views = isTRUE(features$metadata_views),
    axes = isTRUE(features$axes),
    cursor_pagination = isTRUE(features$cursor),
    structured_errors = isTRUE(features$structured_errors),
    jsonl_streaming = isTRUE(features$artifact_streaming)
  )
  core_checks <- c(
    "api_v1",
    "resource_discovery",
    "resource_inspection",
    "expression_query",
    "project_scope"
  )
  incompatibility_reasons <- character()
  if (!isTRUE(checks[["api_v1"]])) {
    incompatibility_reasons <- c(
      incompatibility_reasons,
      "The server did not negotiate Shennong API v1."
    )
  }
  if (!isTRUE(checks[["resource_discovery"]])) {
    incompatibility_reasons <- c(
      incompatibility_reasons,
      paste0(
        "Permission-filtered Resource discovery failed",
        if (inherits(discovery, "error")) {
          paste0(": ", conditionMessage(discovery))
        } else {
          "."
        }
      )
    )
  }
  if (!isTRUE(checks[["resource_inspection"]])) {
    incompatibility_reasons <- c(
      incompatibility_reasons,
      "The server did not advertise Resource inspection support."
    )
  }
  if (!isTRUE(checks[["expression_query"]])) {
    incompatibility_reasons <- c(
      incompatibility_reasons,
      "The server did not advertise the `expression` query operation."
    )
  }
  if (!isTRUE(checks[["project_scope"]])) {
    incompatibility_reasons <- c(
      incompatibility_reasons,
      paste0(
        "This server requires a Shennong Project for Resource inspection and ",
        "queries. Reconnect with `sn_connect(..., project_id = ",
        "\"<canonical-project-uuid>\")`; public discovery alone is not full ",
        "API compatibility."
      )
    )
  }
  structure(
    list(
      compatible = all(checks[core_checks]),
      client = list(package = "ShennongData", version = as.character(utils::packageVersion("ShennongData"))),
      server = list(url = connection$base_url, api_version = connection$api_version, version = connection$server_version),
      checks = as.list(checks),
      project_requirement = list(
        required = project_required,
        supplied = project_supplied,
        satisfied = isTRUE(checks[["project_scope"]]),
        public_discovery = isTRUE(capabilities$public_discovery)
      ),
      optional = list(arrow_streaming = isTRUE(features$arrow)),
      discovery_error = if (inherits(discovery, "error")) conditionMessage(discovery) else NULL,
      incompatibility_reasons = incompatibility_reasons
    ),
    class = "shennong_api_compatibility"
  )
}
