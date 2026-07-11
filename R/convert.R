.sn_converter_registry <- new.env(parent = emptyenv())

sn_register_converter <- function(target, can_convert, plan, convert, packages = character(), priority = 0L) {
  if (!is.character(target) || length(target) != 1L || !nzchar(target)) stop("`target` must be a non-empty scalar.", call. = FALSE)
  if (!is.function(can_convert) || !is.function(plan) || !is.function(convert)) stop("Converter hooks must be functions.", call. = FALSE)
  assign(target, list(target = target, can_convert = can_convert, plan = plan, convert = convert, packages = packages, priority = priority), envir = .sn_converter_registry)
  invisible(target)
}

.sn_target <- function(target) {
  aliases <- c(se = "SummarizedExperiment", sce = "SingleCellExperiment", dds = "DESeqDataSet", dge = "DGEList", surv = "Surv")
  alias <- unname(aliases[target])
  if (length(alias) == 1L && !is.na(alias)) target <- alias
  if (!is.character(target) || length(target) != 1L || !nzchar(target)) stop("`target` must be a non-empty scalar.", call. = FALSE)
  target
}

.sn_require_measurement <- function(x, layer = NULL, counts = FALSE) {
  measurement <- .sn_measurement(x, layer)
  if (isTRUE(counts)) {
    spec <- measurement$spec
    valid <- identical(tolower(spec$unit %||% ""), "count") &&
      identical(tolower(spec$transformation %||% "identity"), "identity") &&
      (spec$value_type %||% "") %in% c("integer", "integer64", "numeric", "double")
    if (!valid) stop(paste0("available measurement = ", measurement$name, "; required measurement = raw non-negative integer counts"), class = "shennong_conversion_incompatible_measurement")
  }
  measurement
}

sn_conversion_plan <- function(x, target, source = c("auto", "query", "artifact"), assay = NULL,
                               layer = NULL, features = NULL, observations = NULL, fields = NULL,
                               allow_large = FALSE, ...) {
  target <- .sn_target(target); source <- match.arg(source)
  if (inherits(x, "shennong_result")) {
    resource <- sn_resource_ref(x); measurement <- attr(x, "shennong_provenance")$layer
    return(structure(list(target = target, source = source, resource = resource, layer = measurement,
                          ready = TRUE, requirements = list(), query = sn_query_plan(x)), class = "shennong_conversion_plan"))
  }
  if (!S7::S7_inherits(x, ShennongData)) stop("`x` must be a ShennongData handle or shennong_result.", call. = FALSE)
  if (target %in% c("DESeqDataSet", "DGEList", "SingleCellExperiment", "Seurat", "cell_data_set")) {
    if (target %in% c("DESeqDataSet", "DGEList", "SingleCellExperiment", "cell_data_set")) .sn_require_measurement(x, layer, counts = TRUE)
  } else if (!is.null(layer)) .sn_measurement(x, layer)
  if (source == "artifact" && !length(x@resource$artifacts)) stop("No Artifact is available for the requested conversion.", call. = FALSE)
  if (target %in% c("SingleCellExperiment", "Seurat", "cell_data_set", "CellChat") &&
      !identical(x@resource$data_model, "single_cell") && !identical(x@resource$data_model, "spatial")) {
    stop("Target `", target, "` requires a single-cell or spatial Resource schema.", call. = FALSE)
  }
  if (target == "CellChat" && !"cell_type_annotation" %in% (x@resource$analysis_readiness$ready %||% character()) &&
      !"cell_type" %in% names(x@resource$observation_fields)) stop("CellChat conversion requires missing Resource/annotation `cell_type_annotation`.", call. = FALSE)
  invisible(allow_large)
  structure(list(target = target, source = source, resource = list(id = x@resource$id, version = x@resource$version),
                 layer = layer, assay = assay, features = features, observations = observations, fields = fields,
                 ready = TRUE, requirements = list(), query = sn_query_plan(x)), class = "shennong_conversion_plan")
}

print.shennong_conversion_plan <- function(x, ...) { cat("<shennong_conversion_plan>\nTarget: ", x$target, "\nSource: ", x$source, "\nReady: ", x$ready, "\n", sep = ""); invisible(x) }

.sn_materialized_data <- function(x, target, layer = NULL, features = NULL, fields = NULL, source = "auto", allow_large = FALSE, ...) {
  if (inherits(x, "shennong_result")) return(x)
  sn_fetch_data(x, features = features, fields = fields, layer = layer, source = source, shape = "long", allow_large = allow_large, ...)
}

.sn_result_matrix <- function(result) {
  if (is.matrix(result) || inherits(result, "Matrix")) return(result)
  data <- as.data.frame(result)
  if (!all(c("observation_id", "feature", "value") %in% names(data))) stop("A long result must contain `observation_id`, `feature`, and `value` columns.", call. = FALSE)
  .sn_long_to_matrix(data, lapply(unique(data$feature), function(z) list(input = z, original_id = z)), sparse = FALSE)
}

sn_as <- function(x, target, source = c("auto", "query", "artifact"), assay = NULL, layer = NULL,
                 features = NULL, observations = NULL, fields = NULL, allow_large = FALSE, ...) {
  target <- .sn_target(target); source <- match.arg(source)
  if (target == "Surv") {
    if (!inherits(x, "shennong_result")) stop("Surv conversion requires a materialized result with time/event fields.", call. = FALSE)
    args <- list(...); time <- args$time %||% args$endpoint_time %||% "time"; event <- args$event %||% "event"
    if (!all(c(time, event) %in% names(x))) stop("Survival result requires fields `", time, "` and `", event, "`.", call. = FALSE)
    if (!requireNamespace("survival", quietly = TRUE)) stop("Package `survival` is required.", call. = FALSE)
    return(survival::Surv(x[[time]], x[[event]]))
  }
  if (target %in% c("DESeqDataSet", "DGEList")) {
    if (S7::S7_inherits(x, ShennongData)) .sn_require_measurement(x, layer, counts = TRUE)
    else if (!inherits(x, "shennong_result")) stop("Count-based conversion requires a ShennongData handle or shennong_result.", call. = FALSE)
  }
  plan <- if (S7::S7_inherits(x, ShennongData)) sn_conversion_plan(x, target, source, layer = layer, features = features, fields = fields, allow_large = allow_large, ...) else sn_conversion_plan(x, target, source)
  result <- .sn_materialized_data(x, target, layer, features, fields, source, allow_large, ...)
  if (target %in% c("SummarizedExperiment", "SingleCellExperiment", "Seurat", "DESeqDataSet", "DGEList", "EList")) {
    mat <- .sn_result_matrix(result)
    fields_data <- as.data.frame(result)
    col_data <- if ("observation_id" %in% names(fields_data)) unique(fields_data[, c("observation_id", setdiff(fields, "observation_id")), drop = FALSE]) else data.frame(row.names = colnames(mat))
    row_data <- data.frame(feature_id = rownames(mat), row.names = rownames(mat), stringsAsFactors = FALSE)
    if ("observation_id" %in% names(col_data)) rownames(col_data) <- make.unique(as.character(col_data$observation_id))
    if (target == "SummarizedExperiment") {
      if (!requireNamespace("SummarizedExperiment", quietly = TRUE)) stop("Package `SummarizedExperiment` is required.", call. = FALSE)
      assay_name <- sn_provenance(result)$layer %||% plan$layer %||% "assay"
      return(SummarizedExperiment::SummarizedExperiment(assays = stats::setNames(list(mat), assay_name), rowData = row_data, colData = S4Vectors::DataFrame(col_data), metadata = list(shennong = sn_provenance(result))))
    }
    if (target == "SingleCellExperiment") {
      if (!requireNamespace("SingleCellExperiment", quietly = TRUE)) stop("Package `SingleCellExperiment` is required.", call. = FALSE)
      if (S7::S7_inherits(x, ShennongData) && identical(source, "query") && isTRUE(.sn_measurement(x, layer)$spec$sparse) && is.null(get0("observation_ids", envir = x@cache, inherits = FALSE, ifnotfound = NULL))) stop("A sparse query is a nonzero subset; a complete cell axis or Artifact is required for SingleCellExperiment conversion.", call. = FALSE)
      sce <- SingleCellExperiment::SingleCellExperiment(assays = list(counts = mat), rowData = S4Vectors::DataFrame(row_data), colData = S4Vectors::DataFrame(col_data)); S4Vectors::metadata(sce)$shennong <- sn_provenance(result); return(sce)
    }
    if (target == "DESeqDataSet") {
      if (!requireNamespace("DESeq2", quietly = TRUE)) stop("Package `DESeq2` is required.", call. = FALSE)
      design <- list(...)$design %||% stop("DESeqDataSet conversion requires a `design` formula.", call. = FALSE)
      if (!inherits(design, "formula")) stop("`design` must be a formula.", call. = FALSE)
      if (any(!is.finite(mat)) || any(mat < 0) || any(abs(mat - round(mat)) > .Machine$double.eps^0.5)) stop("Count assay contains non-integer or negative values.", call. = FALSE)
      return(DESeq2::DESeqDataSetFromMatrix(countData = round(mat), colData = S4Vectors::DataFrame(col_data), design = design))
    }
    if (target == "DGEList") {
      if (!requireNamespace("edgeR", quietly = TRUE)) stop("Package `edgeR` is required.", call. = FALSE)
      return(edgeR::DGEList(counts = mat))
    }
    if (target == "EList") return(list(E = mat, genes = row_data, targets = col_data))
    if (target == "Seurat") {
      if (!requireNamespace("SeuratObject", quietly = TRUE)) stop("Package `SeuratObject` is required.", call. = FALSE)
      if (S7::S7_inherits(x, ShennongData) && !identical(x@resource$data_model, "single_cell") && !identical(x@resource$data_model, "spatial")) stop("Seurat conversion requires a single-cell or spatial Resource.", call. = FALSE)
      obj <- SeuratObject::CreateSeuratObject(counts = mat, meta.data = if (nrow(col_data)) as.data.frame(col_data) else NULL)
      obj@misc$shennong <- sn_provenance(result); return(obj)
    }
  }
  if (target == "CellChat") {
    if (!requireNamespace("CellChat", quietly = TRUE)) stop("Package `CellChat` is required.", call. = FALSE)
    data <- as.data.frame(result); group <- list(...)$group.by %||% "cell_type"
    if (!group %in% names(data)) stop("CellChat conversion requires missing Resource/annotation `cell_type_annotation` (or an explicit `group.by` field).", call. = FALSE)
    meta <- unique(data[c("observation_id", group)]); rownames(meta) <- meta$observation_id
    return(CellChat::createCellChat(object = .sn_result_matrix(result), meta = meta, group.by = group))
  }
  if (target == "cell_data_set") {
    if (!requireNamespace("monocle3", quietly = TRUE)) stop("Package `monocle3` is required.", call. = FALSE)
    data <- as.data.frame(result); cell_metadata <- unique(data[c("observation_id", fields)]); rownames(cell_metadata) <- cell_metadata$observation_id
    gene_metadata <- data.frame(gene_short_name = rownames(.sn_result_matrix(result)), row.names = rownames(.sn_result_matrix(result)))
    return(monocle3::new_cell_data_set(.sn_result_matrix(result), cell_metadata = cell_metadata, gene_metadata = gene_metadata))
  }
  stop("Unsupported conversion target `", target, "`.", call. = FALSE)
}

sn_convert <- function(x, to, ...) {
  warning("`sn_convert()` is deprecated; use `sn_as()` or `sn_export()`.", call. = FALSE)
  if (tolower(to) %in% c("h5ad", "h5mu", "csv", "tsv")) sn_export(x, format = to, ...) else sn_as(x, target = to, ...)
}

sn_export <- function(x, format, path, source = c("auto", "query", "artifact"), overwrite = FALSE,
                      verify = TRUE, runtime = c("auto", "r", "micromamba", "conda"), ...) {
  source <- match.arg(source); runtime <- match.arg(runtime); format <- tolower(format)
  if (file.exists(path) && !isTRUE(overwrite)) stop("Destination already exists: ", path, call. = FALSE)
  if (format == "h5ad" && S7::S7_inherits(x, ShennongData)) {
    artifact <- tryCatch(sn_artifact(x, format = "h5ad"), error = function(e) NULL)
    if (!is.null(artifact)) return(sn_download_artifact(x, artifact, path, verify = verify, overwrite = overwrite, ...))
  }
  if (format %in% c("h5ad", "h5mu")) stop("H5AD/H5MU export requires a matching Artifact or an explicit zellkonverter/anndata runtime; use `sn_runtime_check()` before exporting.", call. = FALSE)
  result <- if (inherits(x, "shennong_result")) x else sn_fetch_data(x, source = source, shape = "long", ...)
  if (format %in% c("csv", "tsv", "txt")) {
    utils::write.table(as.data.frame(result), path, sep = if (format == "csv") "," else "\t", row.names = FALSE, col.names = TRUE, quote = format == "csv")
  } else if (format == "rds") saveRDS(result, path) else stop("Unsupported export format `", format, "`.", call. = FALSE)
  if (isTRUE(verify) && !file.exists(path)) stop("Export did not create `", path, "`.", call. = FALSE)
  invisible(path)
}

sn_runtime_check <- function(id) stop("Runtime manifests are explicit; no runtime is configured for `", id, "`.", call. = FALSE)
sn_runtime_create <- function(id, manager = c("micromamba", "conda")) { manager <- match.arg(manager); stop("Runtime creation is never implicit. Create `", id, "` with ", manager, " explicitly.", call. = FALSE) }
sn_runtime_info <- function(id) list(id = id, available = FALSE)
