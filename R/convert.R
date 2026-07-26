.sn_converter_registry <- new.env(parent = emptyenv())

sn_register_converter <- function(target, can_convert, plan, convert, packages = character(), priority = 0L) {
  if (!is.character(target) || length(target) != 1L || !nzchar(target)) stop("`target` must be a non-empty scalar.", call. = FALSE)
  if (!is.function(can_convert) || !is.function(plan) || !is.function(convert)) stop("Converter hooks must be functions.", call. = FALSE)
  assign(target, list(target = target, can_convert = can_convert, plan = plan, convert = convert, packages = packages, priority = priority), envir = .sn_converter_registry)
  invisible(target)
}

.sn_target <- function(target) {
  aliases <- c(
    se = "SummarizedExperiment",
    sce = "SingleCellExperiment",
    dds = "DESeqDataSet",
    dge = "DGEList",
    surv = "Surv",
    dgCMatrix = "sparse"
  )
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

#' Plan a DataBundle materialization
#'
#' @param x A [ShennongData] handle or materialized result.
#' @param target Target matrix or analysis container.
#' @param source Query, Artifact, or automatic source selection.
#' @param assay Optional assay name.
#' @param layer Exact declared measurement name.
#' @param features A bounded feature identifier vector.
#' @param observations Reserved for compatible observation selection.
#' @param fields Observation metadata fields.
#' @param allow_large Whether to bypass configured size guards.
#' @param ... Converter-specific controls.
#' @return A conversion plan describing the DataBundle contract,
#'   completeness requirement, and output orientation.
#' @export
sn_conversion_plan <- function(x, target, source = c("auto", "query", "artifact"), assay = NULL,
                               layer = NULL, features = NULL, observations = NULL, fields = NULL,
                               allow_large = FALSE, ...) {
  target <- .sn_target(target); source <- match.arg(source)
  if (exists(target, envir = .sn_converter_registry, inherits = FALSE)) {
    converter <- get(target, envir = .sn_converter_registry, inherits = FALSE)
    if (isTRUE(do.call(converter$can_convert, c(list(x), list(...))))) return(do.call(converter$plan, c(list(x), list(...))))
  }
  if (inherits(x, "ShennongCollection")) {
    if (!identical(target, "MultiAssayExperiment")) stop("Unsupported collection target `", target, "`.", call. = FALSE)
    return(structure(list(target = target, source = source, ready = !is.null(x$sample_map), resources = names(x$resources), requirements = list(sample_map = is.null(x$sample_map))), class = "shennong_conversion_plan"))
  }
  if (.sn_is_result(x)) {
    resource <- sn_resource_ref(x)
    measurement <- (attr(x, "shennong_provenance") %||% list())$layer
    schema <- sn_result_schema(x) %||% list()
    return(structure(list(target = target, source = source, resource = resource, layer = measurement,
                          ready = TRUE, requirements = list(),
                          contract = list(
                            input = schema$contract %||% .sn_data_bundle_contract,
                            status = schema$contract_status %||% "client_projection",
                            completeness = if (isTRUE(schema$complete)) "complete" else "partial",
                            output_orientation = if (target %in% c("matrix", "sparse")) {
                              "feature_by_observation"
                            } else {
                              "target_native"
                            }
                          ),
                          query = sn_query_plan(x)), class = "shennong_conversion_plan"))
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
  bundle <- .sn_data_bundle_base(x@resource, "shennongdb-v1-resource-query")
  structure(list(target = target, source = source, resource = list(id = x@resource$id, version = x@resource$version),
                 layer = layer, assay = assay, features = features, observations = observations, fields = fields,
                 ready = TRUE, requirements = list(),
                 contract = list(
                   input = bundle$contract,
                   status = bundle$status,
                   completeness = "required_for_analysis_containers",
                   output_orientation = if (target %in% c("matrix", "sparse")) {
                     "feature_by_observation"
                   } else {
                     "target_native"
                   }
                 ),
                 query = sn_query_plan(x)), class = "shennong_conversion_plan")
}

#' @exportS3Method
print.shennong_conversion_plan <- function(x, ...) { cat("<shennong_conversion_plan>\nTarget: ", x$target, "\nSource: ", x$source, "\nReady: ", x$ready, "\n", sep = ""); invisible(x) }

.sn_materialized_data <- function(x, target, layer = NULL, features = NULL,
                                  fields = NULL, source = "auto",
                                  allow_large = FALSE, shape = "long", ...) {
  if (.sn_is_result(x)) return(x)
  sn_fetch_data(
    x,
    features = features,
    fields = fields,
    layer = layer,
    source = source,
    shape = shape,
    allow_large = allow_large,
    ...
  )
}

.sn_result_matrix <- function(result, sparse = NULL) {
  if (is.matrix(result) || inherits(result, "Matrix")) {
    if (isTRUE(sparse) && !inherits(result, "Matrix")) {
      bundle <- sn_provenance(result)$data_bundle %||% list()
      if (!isTRUE(bundle$implicit_zero) || anyNA(result)) {
        stop(
          "Sparse conversion requires complete data with `implicit_zero = TRUE`.",
          call. = FALSE
        )
      }
      if (!requireNamespace("Matrix", quietly = TRUE)) {
        stop("Package `Matrix` is required for sparse conversion.", call. = FALSE)
      }
      return(Matrix::drop0(Matrix::Matrix(result, sparse = TRUE)))
    }
    if (identical(sparse, FALSE) && inherits(result, "Matrix")) {
      return(as.matrix(result))
    }
    return(result)
  }
  data <- as.data.frame(result)
  if (!all(c("observation_id", "feature", "value") %in% names(data))) stop("A long result must contain `observation_id`, `feature`, and `value` columns.", call. = FALSE)
  bundle <- sn_provenance(result)$data_bundle %||% list()
  implicit_zero <- isTRUE(bundle$implicit_zero)
  if (is.null(sparse)) {
    sparse <- implicit_zero && (
      isTRUE(bundle$measurement$sparse) ||
        is.null(bundle$measurement$sparse)
    )
  }
  feature_ids <- bundle$feature_ids %||% unique(as.character(data$feature))
  resolved <- lapply(feature_ids, function(id) {
    list(input = id, original_id = id)
  })
  .sn_long_to_matrix(
    data,
    resolved,
    sparse = isTRUE(sparse),
    implicit_zero = implicit_zero,
    observation_ids = bundle$observation_ids %||%
      unique(as.character(data$observation_id))
  )
}

.sn_attach_matrix_contract <- function(mat, result, shape) {
  query <- sn_query_plan(result)
  query$shape <- shape
  provenance <- sn_provenance(result) %||% list()
  provenance$data_bundle <- utils::modifyList(
    provenance$data_bundle %||% list(
      contract = .sn_data_bundle_contract,
      status = "client_projection"
    ),
    list(
      shape = shape,
      orientation = "feature_by_observation"
    )
  )
  if (!inherits(mat, "Matrix")) {
    class(mat) <- unique(c("shennong_matrix", class(mat)))
  }
  attr(mat, "shennong_query") <- query
  attr(mat, "shennong_provenance") <- provenance
  attr(mat, "shennong_schema") <- list(
    contract = provenance$data_bundle$contract %||% .sn_data_bundle_contract,
    contract_status = provenance$data_bundle$status %||% "client_projection",
    shape = shape,
    orientation = "feature_by_observation",
    columns = colnames(mat),
    complete = !sn_is_partial(result)
  )
  attr(mat, "shennong_partial") <- sn_is_partial(result)
  attr(mat, "shennong_resource") <- sn_resource_ref(result)
  mat
}

#' Materialize a matrix or analysis container
#'
#' `matrix` and `sparse` targets use feature-by-observation orientation.
#' SummarizedExperiment and Seurat conversions preserve DataBundle provenance.
#' Analysis containers require a complete DataBundle by default. The
#' `allow_partial` escape hatch is explicit because missing features or axes can
#' otherwise be mistaken for biological zeroes.
#'
#' @inheritParams sn_conversion_plan
#' @param allow_partial Whether an incomplete result may be converted to an
#'   analysis container after provenance review.
#' @return A matrix, `dgCMatrix`, or requested analysis container.
#' @export
sn_as <- function(x, target, source = c("auto", "query", "artifact"), assay = NULL, layer = NULL,
                 features = NULL, observations = NULL, fields = NULL,
                 allow_large = FALSE, allow_partial = FALSE, ...) {
  target <- .sn_target(target); source <- match.arg(source)
  if (inherits(x, "ShennongCollection")) return(sn_as_collection(x, target = target, allow_large = allow_large, ...))
  if (exists(target, envir = .sn_converter_registry, inherits = FALSE)) {
    converter <- get(target, envir = .sn_converter_registry, inherits = FALSE)
    if (isTRUE(do.call(converter$can_convert, c(list(x), list(...))))) return(do.call(converter$convert, c(list(x), list(...))))
  }
  if (target == "Surv") {
    if (!.sn_is_result(x)) stop("Surv conversion requires a materialized result with time/event fields.", call. = FALSE)
    args <- list(...); time <- args$time %||% args$endpoint_time %||% "time"; event <- args$event %||% "event"
    if (!all(c(time, event) %in% names(x))) stop("Survival result requires fields `", time, "` and `", event, "`.", call. = FALSE)
    if (!requireNamespace("survival", quietly = TRUE)) stop("Package `survival` is required.", call. = FALSE)
    return(survival::Surv(x[[time]], x[[event]]))
  }
  if (target == "survival_data") {
    if (!.sn_is_result(x)) stop("`survival_data` conversion requires a materialized result.", call. = FALSE)
    args <- list(...); time <- args$time %||% "time"; event <- args$event %||% "event"
    if (!all(c(time, event) %in% names(x))) stop("Survival result requires fields `", time, "` and `", event, "`.", call. = FALSE)
    if (!requireNamespace("survival", quietly = TRUE)) stop("Package `survival` is required.", call. = FALSE)
    return(list(data = x, surv = survival::Surv(x[[time]], x[[event]]), endpoint = args$endpoint %||% NULL, time = time, event = event, provenance = sn_provenance(x)))
  }
  if (target %in% c("DESeqDataSet", "DGEList")) {
    if (S7::S7_inherits(x, ShennongData)) .sn_require_measurement(x, layer, counts = TRUE)
    else if (!.sn_is_result(x)) stop("Count-based conversion requires a ShennongData handle or shennong_result.", call. = FALSE)
  }
  plan <- if (S7::S7_inherits(x, ShennongData)) sn_conversion_plan(x, target, source, layer = layer, features = features, fields = fields, allow_large = allow_large, ...) else sn_conversion_plan(x, target, source)
  materialization_shape <- if (target %in% c("matrix", "sparse")) target else "long"
  result <- .sn_materialized_data(
    x,
    target,
    layer,
    features,
    fields,
    source,
    allow_large,
    shape = materialization_shape,
    ...
  )
  if (target %in% c("matrix", "sparse")) {
    mat <- .sn_result_matrix(result, sparse = target == "sparse")
    return(.sn_attach_matrix_contract(mat, result, target))
  }
  analysis_targets <- c(
    "SummarizedExperiment",
    "SingleCellExperiment",
    "Seurat",
    "DESeqDataSet",
    "DGEList",
    "EList",
    "CellChat",
    "cell_data_set"
  )
  if (target %in% analysis_targets && sn_is_partial(result) &&
      !isTRUE(allow_partial)) {
    reasons <- sn_provenance(result)$data_bundle$incomplete_reasons %||%
      "unspecified"
    stop(
      "Conversion to `",
      target,
      "` requires a complete DataBundle; result is partial (",
      paste(reasons, collapse = ", "),
      "). Set `allow_partial = TRUE` only after reviewing provenance.",
      call. = FALSE
    )
  }
  if (target %in% c("SummarizedExperiment", "SingleCellExperiment", "Seurat", "DESeqDataSet", "DGEList", "EList")) {
    mat <- .sn_result_matrix(result)
    fields_data <- if (is.matrix(result) || inherits(result, "Matrix")) {
      data.frame(row.names = colnames(mat))
    } else {
      as.data.frame(result)
    }
    available_fields <- intersect(
      setdiff(fields %||% character(), "observation_id"),
      names(fields_data)
    )
    col_data <- if ("observation_id" %in% names(fields_data)) {
      unique(fields_data[, c("observation_id", available_fields), drop = FALSE])
    } else {
      data.frame(observation_id = colnames(mat), stringsAsFactors = FALSE)
    }
    index <- match(colnames(mat), as.character(col_data$observation_id))
    if (anyNA(index)) {
      missing <- colnames(mat)[is.na(index)]
      missing_rows <- col_data[
        rep(NA_integer_, length(missing)),
        ,
        drop = FALSE
      ]
      missing_rows$observation_id <- missing
      col_data <- rbind(
        col_data,
        missing_rows
      )
      index <- match(colnames(mat), as.character(col_data$observation_id))
    }
    col_data <- col_data[index, , drop = FALSE]
    row_data <- data.frame(feature_id = rownames(mat), row.names = rownames(mat), stringsAsFactors = FALSE)
    rownames(col_data) <- colnames(mat)
    if (target == "SummarizedExperiment") {
      if (!requireNamespace("SummarizedExperiment", quietly = TRUE)) stop("Package `SummarizedExperiment` is required.", call. = FALSE)
      assay_name <- sn_provenance(result)$layer %||% plan$layer %||% "assay"
      return(SummarizedExperiment::SummarizedExperiment(assays = stats::setNames(list(mat), assay_name), rowData = row_data, colData = S4Vectors::DataFrame(col_data), metadata = list(shennong = sn_provenance(result))))
    }
    if (target == "SingleCellExperiment") {
      if (!requireNamespace("SingleCellExperiment", quietly = TRUE)) stop("Package `SingleCellExperiment` is required.", call. = FALSE)
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
    object <- CellChat::createCellChat(object = .sn_result_matrix(result), meta = meta, group.by = group)
    object@options$shennong <- sn_provenance(result); return(object)
  }
  if (target == "cell_data_set") {
    if (!requireNamespace("monocle3", quietly = TRUE)) stop("Package `monocle3` is required.", call. = FALSE)
    data <- as.data.frame(result); cell_metadata <- unique(data[c("observation_id", fields)]); rownames(cell_metadata) <- cell_metadata$observation_id
    gene_metadata <- data.frame(gene_short_name = rownames(.sn_result_matrix(result)), row.names = rownames(.sn_result_matrix(result)))
    cds <- monocle3::new_cell_data_set(.sn_result_matrix(result), cell_metadata = cell_metadata, gene_metadata = gene_metadata)
    S4Vectors::metadata(cds)$shennong <- sn_provenance(result); return(cds)
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
  if (format == "arrow" && S7::S7_inherits(x, ShennongData)) return(sn_stream_data(x, path = path, ...))
  if (format %in% c("h5ad", "h5mu")) stop("H5AD/H5MU export requires a matching Artifact or an explicit zellkonverter/anndata runtime; use `sn_runtime_check()` before exporting.", call. = FALSE)
  result <- if (.sn_is_result(x)) x else sn_fetch_data(x, source = source, shape = "long", ...)
  if (format %in% c("csv", "tsv", "txt")) {
    utils::write.table(as.data.frame(result), path, sep = if (format == "csv") "," else "\t", row.names = FALSE, col.names = TRUE, quote = format == "csv")
  } else if (format == "rds") saveRDS(result, path) else stop("Unsupported export format `", format, "`.", call. = FALSE)
  if (isTRUE(verify) && !file.exists(path)) stop("Export did not create `", path, "`.", call. = FALSE)
  invisible(path)
}

sn_runtime_check <- function(id) stop("Runtime manifests are explicit; no runtime is configured for `", id, "`.", call. = FALSE)
sn_runtime_create <- function(id, manager = c("micromamba", "conda")) { manager <- match.arg(manager); stop("Runtime creation is never implicit. Create `", id, "` with ", manager, " explicitly.", call. = FALSE) }
sn_runtime_info <- function(id) list(id = id, available = FALSE)
