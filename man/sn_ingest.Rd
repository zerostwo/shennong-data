\name{sn_ingest}
\alias{sn_ingest}
\title{Create a Shennong Data Server ingestion request}
\usage{
sn_ingest(
  dataset,
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
  admin_token = sn_admin_token()
)
}
\arguments{
\item{dataset}{Dataset ID.}
\item{version}{Dataset version.}
\item{data_model}{Semantic data model.}
\item{backend}{Backend name.}
\item{source}{Named list of server-side source paths.}
\item{options}{Named list of ingestion options.}
\item{metadata}{Named list of dataset metadata.}
\item{dataset_type}{Optional registry dataset type override.}
\item{storage_uri}{Optional registered storage URI.}
\item{citation}{Optional citation.}
\item{status}{Dataset status.}
\item{is_default}{Whether this version should be the default version.}
\item{schema_version}{Dataset schema version.}
\item{register}{Whether to register the dataset version immediately.}
\item{server_url}{Shennong Data Server URL.}
\item{admin_token}{Admin API key. Defaults to \code{sn_admin_token()}.}
}
\description{
Creates a \code{POST /v1/ingest} request. The current server deployment supports
registration-style ingestion for server-side paths and leaves heavy backend
loading to the CLI or durable worker.
}
