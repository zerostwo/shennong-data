#' A metadata-first ShennongDB Resource handle
#'
#' `ShennongData` stores only connection configuration, normalized Resource
#' metadata, a lazy query plan and a non-semantic cache. It never stores data
#' values or bearer tokens.
#' @export
ShennongData <- S7::new_class(
  "ShennongData",
  package = "ShennongData",
  properties = list(
    connection = S7::class_list,
    resource = S7::class_list,
    view = S7::class_character,
    query = S7::class_list,
    cache = S7::class_any
  ),
  validator = function(self) {
    errors <- character()
    if (length(self@view) != 1L || !self@view %in% c(
      "resource", "observations", "features", "assay", "artifacts", "relations"
    )) {
      errors <- c(errors, "`@view` is invalid")
    }
    if (!is.character(self@resource$id) || length(self@resource$id) != 1L || !nzchar(self@resource$id)) {
      errors <- c(errors, "`@resource$id` is required")
    }
    if (is.null(self@query$schema_version)) {
      errors <- c(errors, "`@query$schema_version` is required")
    }
    if (length(errors)) errors
  }
)

new_shennong_data <- function(connection, resource, view = "resource", query = NULL, cache = NULL) {
  .sn_check_connection(connection)
  if (is.null(query)) {
    query <- list(
      schema_version = "1.0",
      resource_id = resource$id,
      resource_version = resource$version %||% NULL,
      view = view
    )
  }
  if (is.null(cache)) cache <- new.env(parent = emptyenv())
  ShennongData(
    connection = unclass(connection),
    resource = resource,
    view = view,
    query = query,
    cache = cache
  )
}
