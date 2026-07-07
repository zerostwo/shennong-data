sn_server_url <- function(url = NULL) {
  if (!is.null(url)) {
    normalized <- .sn_normalize_url(url)
    options(
      ShennongData.server_url = normalized,
      shennong.data.server_url = normalized
    )
  }
  .sn_normalize_url(
    getOption(
      "ShennongData.server_url",
      getOption("shennong.data.server_url", "http://127.0.0.1:18000")
    )
  )
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

.sn_request_json <- function(method, url, body = NULL) {
  handle <- curl::new_handle()
  curl::handle_setopt(handle, customrequest = method)
  curl::handle_setheaders(handle, "accept" = "application/json")
  if (!is.null(body)) {
    payload <- jsonlite::toJSON(body, auto_unbox = TRUE, null = "null")
    curl::handle_setopt(handle, postfields = payload)
    curl::handle_setheaders(handle, "content-type" = "application/json")
  }
  response <- curl::curl_fetch_memory(url, handle = handle)
  .sn_parse_json_response(response)
}

.sn_request_multipart <- function(url, form) {
  handle <- curl::new_handle()
  curl::handle_setheaders(handle, "accept" = "application/json")
  curl::handle_setform(handle, .list = form)
  response <- curl::curl_fetch_memory(url, handle = handle)
  .sn_parse_json_response(response)
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
