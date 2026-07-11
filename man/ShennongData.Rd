\name{ShennongData}
\alias{ShennongData}
\alias{sn_connect}
\alias{sn_connection}
\alias{sn_set_connection}
\alias{sn_disconnect}
\alias{sn_ping}
\alias{sn_capabilities}
\alias{sn_server_version}
\alias{sn_server_url}
\alias{sn_load_data}
\alias{sn_obs}
\alias{sn_var}
\alias{sn_assay}
\alias{sn_resource}
\alias{sn_schema}
\alias{collect}
\alias{ShennongCollection}
\alias{sn_artifact}
\alias{sn_artifacts}
\alias{sn_as}
\alias{sn_cache_ids}
\alias{sn_collect_metadata}
\alias{sn_collection}
\alias{sn_collection_resources}
\alias{sn_conversion_plan}
\alias{sn_convert}
\alias{sn_download_artifact}
\alias{sn_explain}
\alias{sn_export}
\alias{sn_feature_ids}
\alias{sn_fetch_data}
\alias{sn_is_partial}
\alias{sn_layers}
\alias{sn_link_features}
\alias{sn_observation_ids}
\alias{sn_provenance}
\alias{sn_query_fingerprint}
\alias{sn_query_plan}
\alias{sn_read_query}
\alias{sn_register_converter}
\alias{sn_related}
\alias{sn_relations}
\alias{sn_resource_ref}
\alias{sn_result_schema}
\alias{sn_runtime_check}
\alias{sn_runtime_create}
\alias{sn_runtime_info}
\alias{sn_select_features}
\alias{sn_server_features}
\alias{sn_set_sample_map}
\alias{sn_show_query}
\alias{sn_stream_data}
\alias{sn_use_layer}
\title{Metadata-first ShennongDB Resource handles}
\description{Connect to ShennongDB, discover a Resource, and select a metadata or assay view without materializing data values.}
\usage{
sn_connect(url = sn_server_url(), token = NULL, profile = "default",
  cache_dir = tools::R_user_dir("ShennongData", "cache"), timeout = 60,
  retries = 3L, throttle = 4, user_agent = NULL, set_default = TRUE)
sn_load_data(resource, version = NULL,
  view = c("auto", "observations", "assay", "resource"),
  connection = sn_connection(), refresh = FALSE,
  validate = c("metadata", "capabilities", "none"), ...)
sn_obs(x)
sn_var(x)
sn_assay(x, assay = NULL, layer = NULL)
}
\arguments{
  \item{url}{ShennongDB base URL.}
  \item{token}{A session-only bearer token.}
  \item{profile}{Authentication profile name.}
  \item{cache_dir}{Metadata cache directory.}
  \item{timeout}{Request timeout in seconds.}
  \item{retries}{Maximum retry attempts.}
  \item{throttle}{Maximum requests per second.}
  \item{user_agent}{Optional user-agent string.}
  \item{set_default}{Whether to use the connection by default.}
  \item{resource}{A Resource ID.}
  \item{version}{Optional Resource version.}
  \item{view}{The Resource view to return.}
  \item{connection}{A negotiated ShennongDB connection.}
  \item{refresh}{Whether to refresh cached metadata.}
  \item{validate}{Metadata validation level.}
  \item{...}{Additional arguments reserved for compatible methods.}
  \item{x}{A \code{ShennongData} handle.}
  \item{assay}{An optional declared assay.}
  \item{layer}{An optional declared measurement.}
}
\value{A \code{ShennongData} handle or its requested metadata.}
\examples{
\dontrun{
sn_connect("http://127.0.0.1:8000")
toil <- sn_load_data("toil")
dim(toil)
dim(sn_assay(toil))
}
}
