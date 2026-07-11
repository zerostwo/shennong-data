test_that("ShennongData validates the stable Resource handle state", {
  connection <- ShennongData:::.sn_new_connection(
    "http://example.test", "class-test", tempdir(), 60, 3L, 4, NULL
  )
  resource <- list(id = "toil", version = "2018-05-08")
  x <- ShennongData:::new_shennong_data(connection, resource)

  expect_true(S7::S7_inherits(x, ShennongData))
  expect_equal(x@resource$id, "toil")
  expect_equal(x@query$schema_version, "1.0")
  expect_false("token" %in% names(x@connection))
  expect_error(
    ShennongData:::new_shennong_data(connection, resource, view = "matrix"),
    "@view.*invalid"
  )
})

test_that("ShennongData rejects missing Resource IDs", {
  connection <- ShennongData:::.sn_new_connection(
    "http://example.test", "class-test", tempdir(), 60, 3L, 4, NULL
  )
  expect_error(
    ShennongData:::new_shennong_data(connection, list(id = "")),
    "@resource\\$id.*required"
  )
})
