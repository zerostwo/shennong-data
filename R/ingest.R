sn_register_dataset <- function(dataset,
                                version,
                                type,
                                backend,
                                storage_uri = NULL,
                                metadata = list(),
                                citation = NULL,
                                status = "active",
                                is_default = FALSE,
                                schema_version = "1.0",
                                server_url = sn_server_url(),
                                admin_token = sn_admin_token()) {
  payload <- .sn_dataset_payload(
    dataset = dataset,
    version = version,
    type = type,
    backend = backend,
    storage_uri = storage_uri,
    metadata = metadata,
    citation = citation,
    status = status,
    is_default = is_default,
    schema_version = schema_version
  )
  .sn_request_json(
    "POST",
    .sn_url(server_url, "/v1/datasets"),
    body = payload,
    headers = .sn_admin_headers(admin_token)
  )
}

sn_ingest <- function(dataset,
                      version,
                      data_model = c("bulk", "single_cell", "spatial", "clinical", "qtl"),
                      backend,
                      source = list(),
                      options = list(),
                      metadata = list(),
                      dataset_type = NULL,
                      storage_uri = NULL,
                      citation = NULL,
                      status = "active",
                      is_default = FALSE,
                      schema_version = "1.0",
                      register = TRUE,
                      server_url = sn_server_url(),
                      admin_token = sn_admin_token()) {
  data_model <- match.arg(data_model)
  body <- list(
    dataset = .sn_scalar_chr(dataset, "dataset"),
    version = .sn_scalar_chr(version, "version"),
    data_model = data_model,
    backend = .sn_scalar_chr(backend, "backend"),
    source = .sn_named_json_object(source, "source"),
    options = .sn_named_json_object(options, "options"),
    metadata = .sn_named_json_object(metadata, "metadata"),
    dataset_type = dataset_type,
    storage_uri = storage_uri,
    citation = citation,
    status = status,
    is_default = isTRUE(is_default),
    schema_version = schema_version,
    register = isTRUE(register)
  )
  .sn_request_json(
    "POST",
    .sn_url(server_url, "/v1/ingest"),
    body = body,
    headers = .sn_admin_headers(admin_token)
  )
}

sn_upload_dataset <- function(file,
                              dataset,
                              version,
                              data_model = c("bulk", "single_cell", "spatial", "clinical", "qtl"),
                              backend,
                              role = "file",
                              metadata = list(),
                              options = list(),
                              dataset_type = NULL,
                              citation = NULL,
                              status = "active",
                              is_default = FALSE,
                              schema_version = "1.0",
                              register = TRUE,
                              server_url = sn_server_url(),
                              admin_token = sn_admin_token()) {
  data_model <- match.arg(data_model)
  if (!is.character(file) || length(file) != 1L || !file.exists(file)) {
    stop("`file` must be an existing local file path.", call. = FALSE)
  }
  form <- .sn_compact_list(list(
    file = curl::form_file(file),
    dataset = .sn_scalar_chr(dataset, "dataset"),
    version = .sn_scalar_chr(version, "version"),
    data_model = data_model,
    backend = .sn_scalar_chr(backend, "backend"),
    role = .sn_scalar_chr(role, "role"),
    metadata_json = .sn_json_object_string(.sn_named_json_object(metadata, "metadata")),
    options_json = .sn_json_object_string(.sn_named_json_object(options, "options")),
    dataset_type = dataset_type,
    citation = citation,
    status = status,
    is_default = .sn_form_bool(is_default),
    schema_version = schema_version,
    register = .sn_form_bool(register)
  ))
  .sn_request_multipart(
    .sn_url(server_url, "/v1/ingest/upload"),
    form = form,
    headers = .sn_admin_headers(admin_token)
  )
}

.sn_dataset_payload <- function(dataset,
                                version,
                                type,
                                backend,
                                storage_uri = NULL,
                                metadata = list(),
                                citation = NULL,
                                status = "active",
                                is_default = FALSE,
                                schema_version = "1.0") {
  list(
    dataset_id = .sn_scalar_chr(dataset, "dataset"),
    type = .sn_scalar_chr(type, "type"),
    backend = .sn_scalar_chr(backend, "backend"),
    version = .sn_scalar_chr(version, "version"),
    citation = citation,
    storage_uri = storage_uri,
    status = status,
    is_default = isTRUE(is_default),
    schema_version = schema_version,
    metadata = .sn_named_json_object(metadata, "metadata")
  )
}

.sn_named_json_object <- function(x, name) {
  if (!is.list(x)) {
    stop("`", name, "` must be a named list.", call. = FALSE)
  }
  if (length(x) == 0L) {
    return(structure(list(), names = character()))
  }
  if (is.null(names(x)) || any(!nzchar(names(x)))) {
    stop("`", name, "` must be a named list.", call. = FALSE)
  }
  x
}

.sn_scalar_chr <- function(x, name) {
  if (!is.character(x) || length(x) != 1L || !nzchar(x)) {
    stop("`", name, "` must be a non-empty character scalar.", call. = FALSE)
  }
  x
}

.sn_json_object_string <- function(x) {
  as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null"))
}

.sn_form_bool <- function(x) {
  if (isTRUE(x)) "true" else "false"
}

.sn_compact_list <- function(x) {
  x[!vapply(x, is.null, logical(1))]
}
