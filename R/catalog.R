sn_list_datasets <- function(server_url = sn_server_url()) {
  response <- .sn_request_json("GET", .sn_url(server_url, "/v1/catalog/datasets"))
  tibble::as_tibble(response$data)
}

sn_dataset_schema <- function(dataset, version = NULL, server_url = sn_server_url()) {
  path <- paste0("/v1/catalog/datasets/", utils::URLencode(dataset, reserved = TRUE), "/schema")
  if (!is.null(version)) {
    path <- paste0(path, "?version=", utils::URLencode(version, reserved = TRUE))
  }
  response <- .sn_request_json("GET", .sn_url(server_url, path))
  response$data
}
