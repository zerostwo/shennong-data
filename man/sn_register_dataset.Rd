\name{sn_register_dataset}
\alias{sn_register_dataset}
\title{Register a Shennong Data Server dataset version}
\usage{
sn_register_dataset(
  dataset,
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
  admin_token = sn_admin_token()
)
}
\arguments{
\item{dataset}{Dataset ID.}
\item{version}{Dataset version.}
\item{type}{Registry dataset type, for example \code{"bulk_expression"}.}
\item{backend}{Backend name, for example \code{"xena"}, \code{"clickhouse"}, or \code{"tenx_h5"}.}
\item{storage_uri}{Server-side storage URI or path.}
\item{metadata}{Named list of dataset metadata.}
\item{citation}{Optional citation.}
\item{status}{Dataset status.}
\item{is_default}{Whether this version should be the default version.}
\item{schema_version}{Dataset schema version.}
\item{server_url}{Shennong Data Server URL.}
\item{admin_token}{Admin API key. Defaults to \code{sn_admin_token()}.}
}
\description{
Registers a dataset version through \code{POST /v1/datasets}. Large data files
should already be available to the server or ingested by the server-side CLI.
}
