\name{sn_upload_dataset}
\alias{sn_upload_dataset}
\title{Upload a local file to Shennong Data Server}
\usage{
sn_upload_dataset(
  file,
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
  server_url = sn_server_url()
)
}
\arguments{
\item{file}{Existing local file path to upload.}
\item{dataset}{Dataset ID.}
\item{version}{Dataset version.}
\item{data_model}{Semantic data model.}
\item{backend}{Backend name.}
\item{role}{Source role for the uploaded file, such as \code{"expression"},
\code{"matrix"}, \code{"h5"}, or \code{"metadata"}.}
\item{metadata}{Named list of dataset metadata.}
\item{options}{Named list of ingestion options.}
\item{dataset_type}{Optional registry dataset type override.}
\item{citation}{Optional citation.}
\item{status}{Dataset status.}
\item{is_default}{Whether this version should be the default version.}
\item{schema_version}{Dataset schema version.}
\item{register}{Whether to register the dataset version after upload.}
\item{server_url}{Shennong Data Server URL.}
}
\description{
Uploads a file using \code{POST /v1/ingest/upload}. The server stores the file
under its configured data root and, by default, registers the uploaded path as
a dataset version.
}
