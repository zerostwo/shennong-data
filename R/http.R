sn_server_url <- function(url = NULL) {
  if (!is.null(url)) {
    normalized <- .sn_normalize_url(url)
    options(
      ShennongData.server_url = normalized,
      shennong.data.server_url = normalized,
      shennong.api_url = normalized
    )
  }
  configured <- getOption(
    "ShennongData.server_url",
    getOption("shennong.data.server_url", getOption("shennong.api_url"))
  )
  if (is.character(configured) && length(configured) == 1L && nzchar(configured)) {
    return(.sn_normalize_url(configured))
  }
  env_url <- Sys.getenv("SHENNONG_API_URL", unset = "")
  if (nzchar(env_url)) {
    return(.sn_normalize_url(env_url))
  }
  "http://127.0.0.1:8000"
}

sn_session_token <- function() {
  token <- Sys.getenv("SHENNONG_API_TOKEN", unset = "")
  if (nzchar(token)) token else NULL
}

.sn_endpoints <- list(
  version = "/version",
  public_config = "/api/v1/public-config",
  capabilities = "/api/v1/capabilities",
  resources = "/api/v1/resources",
  agent_manifest = "/.well-known/shennong-agent.json",
  agent_resource = "/api/v1/agent/resources/%s",
  axis = "/api/v1/agent/resources/%s/axes/%s",
  metadata = "/api/v1/agent/resources/%s/metadata",
  artifact_download = "/api/v1/resources/%s/artifacts/%s/download",
  query = "/api/v1/query",
  query_batch = "/api/v1/query/batch",
  query_stream = "/api/v1/query/stream",
  genes_resolve = "/api/v1/genes/resolve"
)

.sn_endpoint <- function(name, ...) {
  path <- .sn_endpoints[[name]]
  if (is.null(path)) stop("Unknown Shennong endpoint: ", name, call. = FALSE)
  if (grepl("%", path, fixed = TRUE)) sprintf(path, ...) else path
}

.sn_normalize_url <- function(url) {
  if (!is.character(url) || length(url) != 1L || !nzchar(url)) {
    stop("`url` must be a non-empty character scalar.", call. = FALSE)
  }
  sub("/+$", "", url)
}

.sn_url <- function(server_url, path) {
  paste0(.sn_normalize_url(server_url), "/", sub("^/+", "", path))
}

.sn_connection_url <- function(connection) {
  url <- connection$base_url %||% connection$server_url %||% connection$url
  .sn_normalize_url(url)
}

.sn_connection_token <- function(connection) {
  if (exists(".sn_resolve_token", mode = "function", inherits = TRUE)) {
    return(.sn_resolve_token(connection))
  }
  connection$token %||% sn_session_token()
}

sn_request <- function(connection, path, method = "GET", body = NULL,
                       auth = c("user", "admin", "none")) {
  auth <- match.arg(auth)
  req <- httr2::request(.sn_url(.sn_connection_url(connection), path))
  req <- httr2::req_method(req, method)
  req <- httr2::req_headers(req, Accept = "application/json")
  if (!is.null(connection$timeout)) req <- httr2::req_timeout(req, connection$timeout)
  if (!is.null(connection$user_agent)) req <- httr2::req_user_agent(req, connection$user_agent)
  if (!is.null(body)) req <- httr2::req_body_json(req, body)

  token <- switch(
    auth,
    user = .sn_connection_token(connection),
    admin = NULL,
    none = NULL
  )
  if (identical(auth, "user") && !is.null(token)) {
    req <- httr2::req_headers(req, Authorization = paste("Bearer", token), .redact = "Authorization")
  }
  if (identical(auth, "admin")) stop("Admin requests are not part of ShennongData.", call. = FALSE)
  req
}

.sn_perform_json <- function(req, retries = 3L, throttle = 4) {
  req <- httr2::req_retry(req, max_tries = as.integer(retries))
  req <- httr2::req_throttle(req, rate = throttle)
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  .sn_parse_json_response(httr2::req_perform(req))
}

.sn_perform_raw <- function(req, retries = 3L, throttle = 4) {
  req <- httr2::req_retry(req, max_tries = as.integer(retries))
  req <- httr2::req_throttle(req, rate = throttle)
  httr2::req_perform(req)
}

.sn_request_json <- function(method, url, body = NULL, headers = NULL) {
  req <- httr2::request(url)
  req <- httr2::req_method(req, method)
  req <- httr2::req_headers(req, Accept = "application/json")
  if (!is.null(headers)) req <- do.call(httr2::req_headers, c(list(req), as.list(headers)))
  if (!is.null(body)) req <- httr2::req_body_json(req, body)
  .sn_perform_json(req)
}

.sn_parse_json_response <- function(response) {
  if (httr2::resp_status(response) >= 400L) {
    body <- tryCatch(httr2::resp_body_json(response, simplifyVector = FALSE), error = function(e) NULL)
    error <- body$error %||% body$message %||% httr2::resp_body_string(response)
    code <- body$code %||% NULL; details <- body$details %||% NULL
    if (is.list(error)) {
      code <- error$code %||% error$type %||% NULL
      details <- error$details %||% NULL
      error <- error$message %||% error$error %||% "request failed"
    } else error <- body$message %||% error
    condition <- structure(list(message = paste0("Shennong API request failed: ", error),
                                call = NULL, status = httr2::resp_status(response), code = code, details = details),
                           class = c("shennong_api_error", "error", "condition"))
    stop(condition)
  }
  httr2::resp_body_json(response, simplifyVector = FALSE)
}

sn_server_features <- function(connection = sn_connection()) {
  caps <- sn_capabilities(connection)
  list(
    batch_features = isTRUE(caps$batch_features) || "expression_batch" %in% (caps$query_operations %||% character()),
    metadata_views = isTRUE(caps$metadata_views),
    axes = isTRUE(caps$axes),
    cursor = isTRUE(caps$cursor),
    arrow = isTRUE(caps$arrow) || "arrow" %in% (caps$artifact_formats %||% character()),
    structured_errors = isTRUE(caps$structured_errors),
    artifact_streaming = isTRUE(caps$artifact_streaming)
  )
}

`%||%` <- function(x, y) if (is.null(x)) y else x
