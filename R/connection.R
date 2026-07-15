.sn_connection_registry <- new.env(parent = emptyenv())
.sn_token_registry <- new.env(parent = emptyenv())

.sn_connection_key <- function(connection) {
  paste(connection$profile, connection$base_url, sep = "@")
}

.sn_new_connection <- function(url, profile, cache_dir, timeout, retries, throttle, user_agent) {
  structure(
    list(
      base_url = .sn_normalize_url(url),
      profile = profile,
      api_version = NULL,
      server_version = NULL,
      capabilities = NULL,
      cache_dir = path.expand(cache_dir),
      timeout = timeout,
      retries = as.integer(retries),
      throttle = throttle,
      user_agent = user_agent
    ),
    class = "shennong_connection"
  )
}

.sn_check_connection <- function(connection) {
  if (!inherits(connection, "shennong_connection")) {
    stop("`connection` must be created by `sn_connect()`.", call. = FALSE)
  }
  invisible(connection)
}

.sn_resolve_token <- function(connection) {
  key <- .sn_connection_key(connection)
  if (exists(key, envir = .sn_token_registry, inherits = FALSE)) {
    return(get(key, envir = .sn_token_registry, inherits = FALSE))
  }
  sn_session_token()
}

.sn_negotiate <- function(connection) {
  capabilities <- .sn_perform_json(
    sn_request(connection, .sn_endpoint("capabilities"), auth = "none"),
    retries = connection$retries,
    throttle = connection$throttle
  )$data
  version <- tryCatch(
    .sn_perform_json(
      sn_request(connection, .sn_endpoint("version"), auth = "none"),
      retries = connection$retries,
      throttle = connection$throttle
    ),
    shennong_api_error = function(error) {
      if (error$status %in% c(404L, 405L)) NULL else stop(error)
    }
  )
  public_config <- if (is.null(version)) {
    .sn_perform_json(
      sn_request(connection, .sn_endpoint("public_config"), auth = "none"),
      retries = connection$retries,
      throttle = connection$throttle
    )$data
  } else {
    list()
  }
  api_version <- version$api %||% public_config$api_version %||% capabilities$api_version
  if (!is.character(api_version) || length(api_version) != 1L || !nzchar(api_version)) {
    stop("ShennongDB did not provide an API version.", call. = FALSE)
  }
  if (!identical(api_version, "v1")) {
    stop("Unsupported ShennongDB API version: ", api_version, call. = FALSE)
  }
  connection$api_version <- api_version
  connection$server_version <- version$version %||% public_config$service_version %||% NULL
  connection$capabilities <- capabilities
  connection
}

#' Connect to ShennongDB
#'
#' @param url ShennongDB base URL.
#' @param token Session-only bearer token; it is never stored in the returned object.
#' @param profile Authentication profile name.
#' @param cache_dir Metadata cache directory.
#' @param timeout Request timeout in seconds.
#' @param retries Maximum retry attempts.
#' @param throttle Maximum requests per second.
#' @param user_agent Optional user-agent string.
#' @param set_default Whether to register this as the default connection.
#' @export
sn_connect <- function(url = sn_server_url(), token = NULL, profile = "default",
                       cache_dir = tools::R_user_dir("ShennongData", "cache"),
                       timeout = 60, retries = 3L, throttle = 4,
                       user_agent = NULL, set_default = TRUE) {
  if (!is.character(profile) || length(profile) != 1L || !nzchar(profile)) {
    stop("`profile` must be a non-empty character scalar.", call. = FALSE)
  }
  if (!is.null(token) && (!is.character(token) || length(token) != 1L || !nzchar(token))) {
    stop("`token` must be NULL or a single non-empty string.", call. = FALSE)
  }
  if (!is.numeric(timeout) || length(timeout) != 1L || timeout <= 0) {
    stop("`timeout` must be a positive number.", call. = FALSE)
  }
  if (!is.numeric(retries) || length(retries) != 1L || retries < 1) {
    stop("`retries` must be at least 1.", call. = FALSE)
  }
  if (!is.numeric(throttle) || length(throttle) != 1L || throttle <= 0) {
    stop("`throttle` must be a positive number.", call. = FALSE)
  }
  connection <- .sn_new_connection(url, profile, cache_dir, timeout, retries, throttle, user_agent)
  if (!is.null(token)) assign(.sn_connection_key(connection), token, envir = .sn_token_registry)
  connection <- .sn_negotiate(connection)
  if (isTRUE(set_default)) sn_set_connection(connection)
  connection
}

#' Return the default ShennongDB connection
#' @export
sn_connection <- function() {
  if (exists("default", envir = .sn_connection_registry, inherits = FALSE)) {
    return(get("default", envir = .sn_connection_registry, inherits = FALSE))
  }
  sn_connect()
}

#' Set the default ShennongDB connection
#' @export
sn_set_connection <- function(connection) {
  .sn_check_connection(connection)
  assign("default", connection, envir = .sn_connection_registry)
  invisible(connection)
}

#' Remove a session ShennongDB connection
#' @export
sn_disconnect <- function(connection = sn_connection()) {
  .sn_check_connection(connection)
  key <- .sn_connection_key(connection)
  if (exists(key, envir = .sn_token_registry, inherits = FALSE)) rm(list = key, envir = .sn_token_registry)
  if (exists("default", envir = .sn_connection_registry, inherits = FALSE) &&
      identical(.sn_connection_key(sn_connection()), key)) {
    rm(list = "default", envir = .sn_connection_registry)
  }
  invisible(NULL)
}

#' Ping ShennongDB
#' @export
sn_ping <- function(connection = sn_connection()) {
  .sn_check_connection(connection)
  .sn_perform_json(
    sn_request(connection, .sn_endpoint("version"), auth = "none"),
    retries = connection$retries,
    throttle = connection$throttle
  )
}

#' Return negotiated ShennongDB capabilities
#' @export
sn_capabilities <- function(connection = sn_connection(), refresh = FALSE) {
  .sn_check_connection(connection)
  if (isTRUE(refresh) || is.null(connection$capabilities)) connection <- .sn_negotiate(connection)
  connection$capabilities
}

#' Return the negotiated ShennongDB server version
#' @export
sn_server_version <- function(connection = sn_connection()) {
  .sn_check_connection(connection)
  connection$server_version
}
