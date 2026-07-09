\name{sn_load_data}
\alias{sn_load_data}
\alias{sn_collect}
\alias{sn_query}
\alias{sn_plot_box}
\alias{sn_list_datasets}
\alias{sn_dataset_schema}
\alias{sn_server_url}
\alias{sn_admin_token}
\title{Lazy Shennong Data Server client}
\description{
Create and materialize lazy queries against Shennong Data Server. The default
workflow stores only API query state in R until \code{sn_collect()} or a plotting
helper needs data.
}
\usage{
sn_load_data(dataset = "toil", version = NULL, assay = "rna",
  data_model = NULL, layer = NULL, measure = "expression",
  server_url = sn_server_url(), lazy = TRUE, limit = 1000L, ...)

sn_collect(x, n = Inf, features = NULL, limit = NULL, max_pages = Inf)

sn_query(dataset, features, filters = list(), version = NULL, assay = "rna",
  data_model = "bulk", layer = "log2_tpm", measure = "expression",
  server_url = sn_server_url(), limit = 1000L)

sn_plot_box(data, gene, x = "group", y = "value", n = Inf,
  limit = 100000L, show_points = TRUE, point_alpha = 0.35, title = NULL)

sn_list_datasets(server_url = sn_server_url())

sn_dataset_schema(dataset, version = NULL, server_url = sn_server_url())

sn_server_url(url = NULL)

sn_admin_token(token = NULL)
}
\arguments{
\item{dataset}{Dataset identifier, for example \code{"toil"}.}
\item{version}{Optional dataset version.}
\item{assay}{Assay name sent to the API.}
\item{data_model}{Semantic data model, such as \code{"bulk"}.}
\item{layer}{Expression layer, such as \code{"log2_tpm"}.}
\item{measure}{Measure name, usually \code{"expression"}.}
\item{server_url}{Base URL for Shennong Data Server.}
\item{lazy}{If \code{TRUE}, return a lazy query object without requesting data.}
\item{limit}{Rows per API page.}
\item{...}{Reserved for future options or dplyr method arguments.}
\item{x}{A lazy Shennong data object.}
\item{n}{Maximum rows to materialize.}
\item{features}{Feature or gene symbols to query.}
\item{max_pages}{Maximum number of API pages to request.}
\item{filters}{Named observation filters for \code{sn_query()}.}
\item{data}{A lazy Shennong data object or a local data frame.}
\item{gene}{Gene symbol to request before plotting.}
\item{y}{Column mapped to the y-axis.}
\item{show_points}{Overlay jittered points on the boxplot.}
\item{point_alpha}{Alpha value for overlaid points.}
\item{title}{Optional plot title.}
\item{url}{Optional URL to store in \code{options("ShennongData.server_url")}.
The legacy \code{options("shennong.data.server_url")} value is still read as a
fallback.}
\item{token}{Optional admin token to store in
\code{options("ShennongData.admin_token")}. If unset, the client reads
\code{Sys.getenv("SHENNONG_ADMIN_API_KEY")}.}
}
\value{
\code{sn_load_data()} returns a lazy Shennong data object by default.
\code{sn_collect()} and \code{sn_query()} return tibbles.
\code{sn_plot_box()} returns a ggplot object.
}
\examples{
\dontrun{
library(dplyr)
toil <- sn_load_data("toil")
toil |>
  filter(cancer == "PAAD") |>
  sn_plot_box(gene = "YTHDF2", x = "group")
}
}
