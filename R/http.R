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

sn_set_api_url <- function(url) {
  if (!is.character(url) || length(url) != 1L || !nzchar(url)) {
    stop("`url` must be a non-empty character scalar.", call. = FALSE)
  }
  old <- getOption("shennong.api_url")
  sn_server_url(url)
  invisible(old)
}

sn_get_api_url <- function() sn_server_url()

sn_set_api_token <- function(token = NULL) {
  if (!is.null(token) && (!is.character(token) || length(token) != 1L || !nzchar(token))) {
    stop("`token` must be NULL or a single non-empty string.", call. = FALSE)
  }
  old <- getOption("shennong.api_token")
  options(shennong.api_token = token)
  invisible(old)
}

sn_get_api_token <- function() {
  token <- getOption("shennong.api_token")
  if (is.character(token) && length(token) == 1L && nzchar(token)) return(token)
  token <- Sys.getenv("SHENNONG_API_TOKEN", unset = "")
  if (nzchar(token)) token else NULL
}

sn_admin_token <- function(token = NULL) {
  if (!is.null(token)) {
    if (!is.character(token) || length(token) != 1L || !nzchar(token)) {
      stop("`token` must be a non-empty character scalar.", call. = FALSE)
    }
    options(ShennongData.admin_token = token)
  }
  getOption("ShennongData.admin_token", Sys.getenv("SHENNONG_ADMIN_API_KEY", unset = ""))
}

.sn_endpoints <- list(
  version = "/version",
  capabilities = "/api/v1/capabilities",
  resources = "/api/v1/resources",
  agent_manifest = "/.well-known/shennong-agent.json",
  agent_resource = "/api/v1/agent/resources/%s",
  query = "/api/v1/query",
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

.sn_connection_token <- function(connection) connection$token %||% sn_get_api_token()

sn_request <- function(connection, path, method = "GET", body = NULL,
                       auth = c("user", "admin", "none")) {
  auth <- match.arg(auth)
  req <- httr2::request(.sn_url(.sn_connection_url(connection), path))
  req <- httr2::req_method(req, method)
  req <- httr2::req_headers(req, Accept = "application/json")
  if (!is.null(body)) req <- httr2::req_body_json(req, body)

  token <- switch(
    auth,
    user = .sn_connection_token(connection),
    admin = sn_admin_token(),
    none = NULL
  )
  if (identical(auth, "user") && !is.null(token)) {
    req <- httr2::req_headers(req, Authorization = paste("Bearer", token), .redact = "Authorization")
  }
  if (identical(auth, "admin")) {
    if (!is.character(token) || length(token) != 1L || !nzchar(token)) {
      stop("An admin token is required for this operation.", call. = FALSE)
    }
    req <- httr2::req_headers(req, `X-Shennong-Admin-Key` = token, .redact = "X-Shennong-Admin-Key")
  }
  req
}

.sn_perform_json <- function(req, retries = 3L, throttle = 4) {
  req <- httr2::req_retry(req, max_tries = as.integer(retries))
  req <- httr2::req_throttle(req, rate = throttle, capacity = throttle, fill_time_s = 1)
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  .sn_parse_json_response(httr2::req_perform(req))
}

.sn_request_json <- function(method, url, body = NULL, headers = NULL) {
  req <- httr2::request(url)
  req <- httr2::req_method(req, method)
  req <- httr2::req_headers(req, Accept = "application/json")
  if (!is.null(headers)) req <- do.call(httr2::req_headers, c(list(req), as.list(headers)))
  if (!is.null(body)) req <- httr2::req_body_json(req, body)
  .sn_perform_json(req)
}

.sn_request_multipart <- function(url, form, headers = NULL) {
  req <- httr2::request(url)
  req <- httr2::req_headers(req, Accept = "application/json")
  if (!is.null(headers)) req <- do.call(httr2::req_headers, c(list(req), as.list(headers)))
  req <- do.call(httr2::req_body_multipart, c(list(req), form))
  .sn_perform_json(req)
}

.sn_parse_json_response <- function(response) {
  if (httr2::resp_status(response) >= 400L) {
    body <- tryCatch(httr2::resp_body_json(response, simplifyVector = FALSE), error = function(e) NULL)
    message <- body$error %||% body$message %||% httr2::resp_body_string(response)
    stop("Shennong API request failed: ", message, call. = FALSE)
  }
  httr2::resp_body_json(response, simplifyVector = FALSE)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

.sn_auth_headers <- function(token = NULL) {
  if (!is.character(token) || length(token) != 1L || !nzchar(token)) return(NULL)
  c(Authorization = paste("Bearer", token))
}

.sn_admin_headers <- function(admin_token = sn_admin_token()) {
  if (!is.character(admin_token) || length(admin_token) != 1L || !nzchar(admin_token)) {
    stop("An admin token is required for this operation. Set it with `sn_admin_token()`.", call. = FALSE)
  }
  c("X-Shennong-Admin-Key" = admin_token)
}
