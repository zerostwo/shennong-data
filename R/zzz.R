.onLoad <- function(libname, pkgname) {
  S7::methods_register()
  if (requireNamespace("dplyr", quietly = TRUE)) {
    ns <- asNamespace("dplyr")
    registerS3method("filter", "ShennongData::ShennongData", function(.data, ..., .preserve = FALSE) { invisible(.preserve); sn_filter(.data, ...) }, envir = ns)
    registerS3method("select", "ShennongData::ShennongData", function(.data, ...) sn_select(.data, ...), envir = ns)
    registerS3method("rename", "ShennongData::ShennongData", function(.data, ...) sn_rename(.data, ...), envir = ns)
    registerS3method("slice_head", "ShennongData::ShennongData", function(.data, ..., n = 6L) sn_slice_head(.data, n), envir = ns)
  }
  registerS3method("collect", "ShennongData::ShennongData", collect.ShennongData, envir = asNamespace(pkgname))
  registerS3method("print", "shennong_result", print.shennong_result, envir = asNamespace("base"))
}
