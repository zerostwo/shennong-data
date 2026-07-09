sn_plot_box <- function(data,
                        gene,
                        x = "group",
                        y = "value",
                        n = Inf,
                        limit = 100000L,
                        show_points = TRUE,
                        point_alpha = 0.35,
                        title = NULL) {
  gene <- rlang::as_string(rlang::ensym(gene))
  plot_data <- if (inherits(data, "shennong_remote_tbl")) {
    sn_collect(data, features = gene, n = n, limit = limit)
  } else {
    tibble::as_tibble(data)
  }
  p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = .data[[x]], y = .data[[y]])) +
    ggplot2::geom_boxplot(outlier.shape = NA)
  if (isTRUE(show_points)) {
    p <- p + ggplot2::geom_jitter(width = 0.15, alpha = point_alpha, size = 0.8)
  }
  p + ggplot2::labs(x = x, y = y, title = title %||% gene) + ggplot2::theme_classic()
}

sn_plot_survival <- function(
  .data,
  time = "month",
  survival = "survival",
  group = "group",
  limit = 10000,
  ...
) {
  df <- sn_collect(.data, fields = c(time, survival, group), limit = limit, ...)
  require_columns(df, c(time, survival, group))
  ggplot2::ggplot(df, ggplot2::aes(x = .data[[time]], y = .data[[survival]], color = .data[[group]])) +
    ggplot2::geom_step() +
    ggplot2::labs(x = time, y = survival) +
    ggplot2::theme_minimal(base_size = 12)
}

require_columns <- function(data, columns) {
  missing <- setdiff(columns, names(data))
  if (length(missing)) {
    stop("Missing required column(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(data)
}

del <- function(...) invisible(NULL)
