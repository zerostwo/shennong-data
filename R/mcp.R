.sn_mcp_schema <- function(properties = list(), required = character()) {
  schema <- list(type = "object", properties = properties, additionalProperties = FALSE)
  if (length(required)) schema$required <- as.list(required)
  schema
}

.sn_mcp_string <- function(description) list(type = "string", minLength = 1L, description = description)
.sn_mcp_strings <- function(description, max_items = 20L) {
  list(type = "array", items = list(type = "string", minLength = 1L), minItems = 1L,
       maxItems = max_items, uniqueItems = TRUE, description = description)
}

.sn_mcp_tool <- function(name, title, description, input_schema) {
  list(
    name = name,
    title = title,
    description = description,
    inputSchema = input_schema,
    annotations = list(
      title = title,
      readOnlyHint = TRUE,
      destructiveHint = FALSE,
      idempotentHint = TRUE,
      openWorldHint = TRUE
    )
  )
}

.sn_mcp_tools <- function() {
  url <- .sn_mcp_string("Optional ShennongDB base URL; defaults to SHENNONG_URL, SHENNONG_API_URL, or the package default.")
  resource <- .sn_mcp_string("Exact ShennongDB Resource identifier returned by list_resources.")
  features <- .sn_mcp_strings("Gene symbols or stable/versioned feature identifiers; at most 20.")
  context <- list(type = "object", description = "Exact Resource-declared context labels.", additionalProperties = TRUE)
  limit <- list(type = "integer", minimum = 1L, maximum = 1000L, default = 100L,
                description = "Maximum rows per feature; the MCP server enforces an upper bound of 1000.")
  list(
    .sn_mcp_tool(
      "check_compatibility", "Check API compatibility",
      "Negotiate ShennongDB v1 and report which ShennongData discovery, query, pagination, metadata, and streaming contracts are available.",
      .sn_mcp_schema(list(url = url))
    ),
    .sn_mcp_tool(
      "list_resources", "List readable Resources",
      "List permission-filtered Resource metadata without loading biological data values.",
      .sn_mcp_schema(list(url = url, search = .sn_mcp_string("Optional case-insensitive Resource text filter.")))
    ),
    .sn_mcp_tool(
      "inspect_resource", "Inspect Resource semantics",
      "Inspect one Resource's dimensions, fields, measurements, operations, Artifacts, relations, readiness, and provenance before planning a query.",
      .sn_mcp_schema(list(url = url, resource = resource), "resource")
    ),
    .sn_mcp_tool(
      "resolve_features", "Resolve feature identifiers",
      "Resolve gene symbols or Ensembl identifiers within one Resource and retain original, versioned, and stable identifier provenance.",
      .sn_mcp_schema(list(url = url, resource = resource, features = features), c("resource", "features"))
    ),
    .sn_mcp_tool(
      "plan_query", "Plan a bounded R query",
      "Validate Resource measurement semantics, fields, context, identifiers, and result-size bounds without fetching expression values.",
      .sn_mcp_schema(
        list(
          url = url, resource = resource, features = features,
          fields = .sn_mcp_strings("Observation metadata fields declared by the Resource.", 30L),
          context = context, layer = .sn_mcp_string("Exact measurement/layer name declared by the Resource."),
          operation = .sn_mcp_string("Exact query operation declared by the Resource."), limit = limit
        ),
        c("resource", "features")
      )
    ),
    .sn_mcp_tool(
      "fetch_data", "Fetch bounded data",
      "Execute a permission-filtered ShennongData query for at most 20 features and 1000 rows per feature, returning provenance and truncation metadata.",
      .sn_mcp_schema(
        list(
          url = url, resource = resource, features = features,
          fields = .sn_mcp_strings("Observation metadata fields declared by the Resource.", 30L),
          context = context, layer = .sn_mcp_string("Exact measurement/layer name declared by the Resource."),
          operation = .sn_mcp_string("Exact query operation declared by the Resource."),
          shape = list(type = "string", enum = c("long", "wide"), default = "long"), limit = limit
        ),
        c("resource", "features")
      )
    )
  )
}

.sn_mcp_argument <- function(arguments, name, required = FALSE, default = NULL) {
  value <- arguments[[name]]
  if (is.null(value)) {
    if (isTRUE(required)) stop("Missing required argument `", name, "`.", call. = FALSE)
    return(default)
  }
  value
}

.sn_mcp_scalar_argument <- function(arguments, name, required = FALSE, default = NULL) {
  value <- .sn_mcp_argument(arguments, name, required, default)
  if (is.null(value)) return(NULL)
  if (!is.character(value) || length(value) != 1L || !nzchar(value)) {
    stop("`", name, "` must be a non-empty string.", call. = FALSE)
  }
  value
}

.sn_mcp_vector_argument <- function(arguments, name, required = FALSE, max_items = 20L) {
  value <- .sn_mcp_argument(arguments, name, required, character())
  value <- unique(as.character(unlist(value, use.names = FALSE)))
  if ((isTRUE(required) && !length(value)) || any(!nzchar(value))) {
    stop("`", name, "` must contain non-empty strings.", call. = FALSE)
  }
  if (length(value) > max_items) stop("`", name, "` accepts at most ", max_items, " values.", call. = FALSE)
  value
}

.sn_mcp_limit <- function(arguments) {
  configured <- suppressWarnings(as.integer(Sys.getenv("SHENNONG_DATA_MCP_MAX_ROWS", unset = "1000")))
  if (is.na(configured) || configured < 1L) configured <- 1000L
  maximum <- min(configured, 1000L)
  value <- .sn_mcp_argument(arguments, "limit", default = min(100L, maximum))
  if (!is.numeric(value) || length(value) != 1L || is.na(value) || value < 1L || value > maximum) {
    stop("`limit` must be between 1 and ", maximum, ".", call. = FALSE)
  }
  as.integer(value)
}

.sn_mcp_connection <- function(arguments) {
  url <- .sn_mcp_scalar_argument(arguments, "url", default = NULL)
  if (is.null(url)) {
    url <- Sys.getenv("SHENNONG_URL", unset = "")
    if (!nzchar(url)) url <- sn_server_url()
  }
  token <- Sys.getenv("SHENNONG_TOKEN", unset = "")
  if (!nzchar(token)) token <- Sys.getenv("SHENNONG_API_TOKEN", unset = "")
  sn_connect(url, token = if (nzchar(token)) token else NULL, profile = "mcp", set_default = FALSE)
}

.sn_mcp_resource_summary <- function(x) {
  schema <- sn_schema(x)
  list(
    id = schema$id,
    kind = schema$kind,
    title = schema$title,
    summary = schema$summary,
    status = schema$status,
    version = schema$version,
    organism = schema$organism,
    data_model = schema$data_model,
    assays = schema$assays,
    axes = schema$axes,
    observation_fields = schema$observation_fields,
    feature_fields = schema$feature_fields,
    measurements = schema$measurements,
    operations = schema$operations,
    supported_context = schema$supported_context,
    analysis_readiness = schema$analysis_readiness,
    artifacts = sn_artifacts(x),
    relations = sn_relations(x),
    provenance = schema$provenance
  )
}

.sn_mcp_records <- function(data) {
  if (!is.data.frame(data) || !nrow(data)) return(list())
  lapply(seq_len(nrow(data)), function(index) {
    stats::setNames(lapply(names(data), function(column) data[[column]][[index]]), names(data))
  })
}

.sn_mcp_query_inputs <- function(arguments) {
  resource <- .sn_mcp_scalar_argument(arguments, "resource", required = TRUE)
  features <- .sn_mcp_vector_argument(arguments, "features", required = TRUE, max_items = 20L)
  fields <- .sn_mcp_vector_argument(arguments, "fields", max_items = 30L)
  context <- .sn_mcp_argument(arguments, "context", default = NULL)
  if (!is.null(context) && (!is.list(context) || (length(context) && is.null(names(context))))) {
    stop("`context` must be a JSON object.", call. = FALSE)
  }
  connection <- .sn_mcp_connection(arguments)
  x <- sn_load_data(resource, connection = connection)
  invisible(lapply(fields, .sn_field_info, x = x))
  resolved <- sn_resolve_features(x, features, strict = TRUE)
  layer <- .sn_mcp_scalar_argument(arguments, "layer", default = NULL)
  measurement <- .sn_measurement(x, layer)
  operation <- .sn_mcp_scalar_argument(arguments, "operation", default = NULL) %||%
    measurement$spec$operation %||% "expression"
  if (!operation %in% x@resource$operations) {
    stop("Operation `", operation, "` is not declared by Resource `", resource, "`.", call. = FALSE)
  }
  context <- .sn_context_merge(x, context)
  if (!length(context)) context <- NULL
  limit <- .sn_mcp_limit(arguments)
  list(
    connection = connection,
    handle = x,
    resolved = resolved,
    fields = fields,
    context = context,
    measurement = measurement,
    operation = operation,
    limit = limit
  )
}

.sn_mcp_call_tool <- function(name, arguments = list()) {
  if (!is.list(arguments)) stop("Tool arguments must be a JSON object.", call. = FALSE)
  if (identical(name, "check_compatibility")) {
    connection <- .sn_mcp_connection(arguments)
    return(unclass(sn_api_compatibility(connection)))
  }
  if (identical(name, "list_resources")) {
    connection <- .sn_mcp_connection(arguments)
    resources <- sn_resources(connection, search = .sn_mcp_scalar_argument(arguments, "search", default = NULL))
    return(list(count = nrow(resources), resources = resources))
  }
  if (identical(name, "inspect_resource")) {
    resource <- .sn_mcp_scalar_argument(arguments, "resource", required = TRUE)
    connection <- .sn_mcp_connection(arguments)
    return(.sn_mcp_resource_summary(sn_load_data(resource, connection = connection)))
  }
  if (identical(name, "resolve_features")) {
    resource <- .sn_mcp_scalar_argument(arguments, "resource", required = TRUE)
    features <- .sn_mcp_vector_argument(arguments, "features", required = TRUE, max_items = 20L)
    connection <- .sn_mcp_connection(arguments)
    x <- sn_load_data(resource, connection = connection)
    return(list(resource = resource, mappings = sn_resolve_features(x, features, strict = TRUE)))
  }
  if (identical(name, "plan_query")) {
    values <- .sn_mcp_query_inputs(arguments)
    request <- list(
      resource = values$handle@resource$id,
      operation = values$operation,
      features = lapply(values$resolved, function(feature) list(type = "gene", name = feature$resolved_id)),
      context = values$context,
      version = values$handle@resource$version,
      options = list(limit = values$limit)
    )
    return(list(
      executable = TRUE,
      resource = .sn_mcp_resource_summary(values$handle)[c("id", "version", "axes", "measurements", "operations", "supported_context")],
      measurement = list(name = values$measurement$name, semantics = values$measurement$spec),
      feature_map = values$resolved,
      fields = values$fields,
      estimated = list(max_rows = length(values$resolved) * values$limit,
                       approximate_value_bytes = length(values$resolved) * values$limit * 16),
      request = request
    ))
  }
  if (identical(name, "fetch_data")) {
    values <- .sn_mcp_query_inputs(arguments)
    shape <- .sn_mcp_scalar_argument(arguments, "shape", default = "long")
    if (!shape %in% c("long", "wide")) stop("`shape` must be `long` or `wide`.", call. = FALSE)
    result <- sn_fetch_data(
      values$handle,
      features = vapply(values$resolved, function(feature) feature$resolved_id, character(1)),
      fields = values$fields,
      context = values$context,
      layer = values$measurement$name,
      operation = values$operation,
      shape = shape,
      resolve = "never",
      limit = values$limit,
      allow_large = FALSE
    )
    provenance <- sn_provenance(result)
    provenance$feature_map <- values$resolved
    return(list(
      rows = .sn_mcp_records(as.data.frame(result)),
      n_rows = nrow(result),
      columns = names(result),
      partial = sn_is_partial(result),
      feature_map = values$resolved,
      provenance = provenance
    ))
  }
  stop(structure(list(message = paste0("Unknown tool: ", name), call = NULL),
                 class = c("shennong_mcp_unknown_tool", "error", "condition")))
}

.sn_mcp_json <- function(value) {
  jsonlite::toJSON(value, auto_unbox = TRUE, null = "null", na = "null", dataframe = "rows", digits = NA)
}

.sn_mcp_tool_result <- function(value, is_error = FALSE) {
  if (isTRUE(is_error)) {
    return(list(content = list(list(type = "text", text = as.character(value))), isError = TRUE))
  }
  list(
    content = list(list(type = "text", text = as.character(.sn_mcp_json(value)))),
    structuredContent = value,
    isError = FALSE
  )
}

.sn_mcp_protocol_error <- function(id, code, message) {
  list(jsonrpc = "2.0", id = id, error = list(code = as.integer(code), message = message))
}

.sn_mcp_protocol_version <- function(requested) {
  supported <- c("2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05")
  if (is.character(requested) && length(requested) == 1L && requested %in% supported) requested else supported[[1L]]
}

.sn_mcp_handle <- function(request) {
  has_id <- "id" %in% names(request)
  id <- request$id %||% NULL
  method <- request$method %||% ""
  params <- request$params %||% list()
  if (!is.list(params)) {
    if (!has_id) return(NULL)
    return(.sn_mcp_protocol_error(id, -32602L, "Invalid params: expected an object"))
  }
  if (identical(method, "initialize")) {
    if (!has_id) return(NULL)
    return(list(
      jsonrpc = "2.0",
      id = id,
      result = list(
        protocolVersion = .sn_mcp_protocol_version(params$protocolVersion %||% NULL),
        capabilities = list(tools = list(listChanged = FALSE)),
        serverInfo = list(name = "shennong-data-mcp", version = as.character(utils::packageVersion("ShennongData")),
                          description = "Read-only ShennongData R client tools for ShennongDB"),
        instructions = "Discover and inspect a Resource before querying. Preserve measurement and identifier provenance. Keep fetches bounded."
      )
    ))
  }
  if (startsWith(method, "notifications/")) return(NULL)
  if (!has_id) return(NULL)
  if (identical(method, "ping")) return(list(jsonrpc = "2.0", id = id, result = list()))
  if (identical(method, "tools/list")) {
    return(list(jsonrpc = "2.0", id = id, result = list(tools = .sn_mcp_tools())))
  }
  if (identical(method, "tools/call")) {
    name <- params$name %||% ""
    if (!name %in% vapply(.sn_mcp_tools(), `[[`, "", "name")) {
      return(.sn_mcp_protocol_error(id, -32602L, paste0("Unknown tool: ", name)))
    }
    result <- tryCatch(
      .sn_mcp_tool_result(.sn_mcp_call_tool(name, params$arguments %||% list())),
      error = function(error) .sn_mcp_tool_result(conditionMessage(error), is_error = TRUE)
    )
    return(list(jsonrpc = "2.0", id = id, result = result))
  }
  .sn_mcp_protocol_error(id, -32601L, paste0("Method not found: ", method))
}

#' Run the ShennongData MCP stdio server
#'
#' The server reads newline-delimited JSON-RPC from standard input and writes
#' only MCP messages to standard output. Configure the upstream instance with
#' `SHENNONG_URL` and an optional `SHENNONG_TOKEN`.
#'
#' @param input Optional input connection. `NULL` opens the process standard input.
#' @param output Output connection, normally standard output.
#' @return `NULL`, invisibly, when the input stream closes.
#' @export
sn_mcp_serve <- function(input = NULL, output = stdout()) {
  close_input <- is.null(input)
  if (close_input) input <- file("stdin", open = "r", encoding = "UTF-8")
  if (close_input) on.exit(close(input), add = TRUE)
  repeat {
    line <- readLines(input, n = 1L, warn = FALSE)
    if (!length(line)) break
    request <- tryCatch(jsonlite::fromJSON(line, simplifyVector = FALSE), error = identity)
    response <- if (inherits(request, "error")) {
      .sn_mcp_protocol_error(NULL, -32700L, "Parse error")
    } else if (!is.list(request) || !identical(request$jsonrpc, "2.0") ||
               !is.character(request$method) || length(request$method) != 1L) {
      id <- if (is.list(request)) request$id %||% NULL else NULL
      .sn_mcp_protocol_error(id, -32600L, "Invalid Request")
    } else {
      .sn_mcp_handle(request)
    }
    if (!is.null(response)) {
      writeLines(as.character(.sn_mcp_json(response)), con = output, sep = "\n")
      flush(output)
    }
  }
  invisible(NULL)
}
