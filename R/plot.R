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

del <- function(...) invisible(NULL)
