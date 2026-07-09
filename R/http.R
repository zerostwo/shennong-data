sn_server_url <- function(url = NULL) {
  if (!is.null(url)) {
    normalized <- .sn_normalize_url(url)
    options(
      ShennongData.server_url = normalized,
      shennong.data.server_url = normalized,
      shennong.api_url = normalized
    )
  }
  env_url <- Sys.getenv("SHENNONG_API_URL", unset = "")
  configured <- getOption(
    "ShennongData.server_url",
    getOption("shennong.data.server_url", getOption("shennong.api_url"))
  )
  if (is.character(configured) && length(configured) == 1L && nzchar(configured)) {
    return(.sn_normalize_url(configured))
  }
  if (nzchar(env_url)) {
    return(.sn_normalize_url(env_url))
  }
  "http://127.0.0.1:18000"
}

sn_set_api_url <- function(url) {
  if (!is.character(url) || length(url) != 1L || !nzchar(url)) {
    stop("`url` must be a non-empty character scalar.", call. = FALSE)
  }
  old <- getOption("shennong.api_url")
  options(
    ShennongData.server_url = .sn_normalize_url(url),
    shennong.data.server_url = .sn_normalize_url(url),
    shennong.api_url = .sn_normalize_url(url)
  )
  invisible(old)
}

sn_get_api_url <- function() {
  sn_server_url()
}

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
  if (is.character(token) && length(token) == 1L && nzchar(token)) {
    return(token)
  }
  env_token <- Sys.getenv("SHENNONG_API_TOKEN", unset = "")
  if (nzchar(env_token)) {
    return(env_token)
  }
  NULL
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

.sn_normalize_url <- function(url) {
  if (!is.character(url) || length(url) != 1L || !nzchar(url)) {
    stop("`url` must be a non-empty character scalar.", call. = FALSE)
  }
  sub("/+$", "", url)
}

.sn_url <- function(server_url, path) {
  paste0(.sn_normalize_url(server_url), "/", sub("^/+", "", path))
}

.sn_request_json <- function(method, url, body = NULL, headers = NULL) {
  handle <- curl::new_handle()
  curl::handle_setopt(handle, customrequest = method)
  .sn_set_headers(handle, c("accept" = "application/json", headers))
  if (!is.null(body)) {
    payload <- jsonlite::toJSON(body, auto_unbox = TRUE, null = "null")
    curl::handle_setopt(handle, postfields = payload)
    .sn_set_headers(handle, "content-type" = "application/json")
  }
  response <- curl::curl_fetch_memory(url, handle = handle)
  .sn_parse_json_response(response)
}

.sn_request_multipart <- function(url, form, headers = NULL) {
  handle <- curl::new_handle()
  .sn_set_headers(handle, c("accept" = "application/json", headers))
  curl::handle_setform(handle, .list = form)
  response <- curl::curl_fetch_memory(url, handle = handle)
  .sn_parse_json_response(response)
}

.sn_set_headers <- function(handle, headers = NULL, ...) {
  headers <- c(headers, ...)
  headers <- headers[!is.na(headers) & nzchar(headers)]
  if (length(headers) == 0L) {
    return(invisible(NULL))
  }
  do.call(curl::handle_setheaders, c(list(handle = handle), as.list(headers)))
}

.sn_parse_json_response <- function(response) {
  text <- rawToChar(response$content)
  if (response$status_code >= 400L) {
    message <- tryCatch({
      parsed <- jsonlite::fromJSON(text, simplifyVector = TRUE)
      parsed$message %||% text
    }, error = function(e) text)
    stop("Shennong API request failed: ", message, call. = FALSE)
  }
  jsonlite::fromJSON(text, simplifyVector = TRUE)
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

.sn_auth_headers <- function(token = NULL) {
  if (!is.character(token) || length(token) != 1L || !nzchar(token)) {
    return(NULL)
  }
  c(Authorization = paste("Bearer", token))
}

.sn_admin_headers <- function(admin_token = sn_admin_token()) {
  if (!is.character(admin_token) || length(admin_token) != 1L || !nzchar(admin_token)) {
    stop("An admin token is required for this operation. Set it with `sn_admin_token()`.", call. = FALSE)
  }
  c("X-Shennong-Admin-Key" = admin_token)
}
