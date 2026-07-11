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
\title{Metadata-first ShennongDB Resource handles}
\description{Connect to ShennongDB, discover a Resource, and select a metadata or assay view without materializing data values.}
\usage{
sn_connect(url = sn_server_url(), token = NULL, profile = "default", set_default = TRUE)
sn_load_data(resource, connection = sn_connection())
sn_obs(x)
sn_var(x)
sn_assay(x, assay = NULL, layer = NULL)
}
\arguments{
  \item{url}{ShennongDB base URL.}
  \item{token}{A session-only bearer token.}
  \item{profile}{Authentication profile name.}
  \item{set_default}{Whether to use the connection by default.}
  \item{resource}{A Resource ID.}
  \item{connection}{A negotiated ShennongDB connection.}
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
