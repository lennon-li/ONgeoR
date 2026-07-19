test_that("build_nearest_layers returns matched layers and connectors", {
  points <- fixture_points()
  source <- points[1:2, , drop = FALSE]
  target <- points[4:6, , drop = FALSE]

  result <- build_nearest_layers(source, target, k = 2)

  expect_named(
    result,
    c("source", "matched_target", "connectors", "table")
  )
  expect_identical(result$source, source)
  expect_s3_class(result$matched_target, "sf")
  expect_s3_class(result$connectors, "sf")
  expect_s3_class(result$table, "tbl_df")
  expect_equal(nrow(result$matched_target), 2)
  expect_equal(nrow(result$connectors), 4)
  expect_equal(nrow(result$table), 4)
  expect_type(result$source$point_id, "integer")
  expect_type(result$matched_target$point_id, "integer")
  expect_type(result$connectors$distance_km, "double")
  expect_type(result$table$rank, "integer")
  expect_type(result$table$distance_km, "double")
  expect_true(all(sf::st_geometry_type(result$source) == "POINT"))
  expect_true(all(sf::st_geometry_type(result$matched_target) == "POINT"))
  expect_true(all(sf::st_geometry_type(result$connectors) == "LINESTRING"))
})

test_that("build_nearest_layers represents empty matches without connectors", {
  points <- fixture_points()
  source <- points[1, , drop = FALSE]
  target <- points[10, , drop = FALSE]

  result <- build_nearest_layers(
    source,
    target,
    k = 1,
    max_dist_km = 0
  )

  expect_named(
    result,
    c("source", "matched_target", "connectors", "table")
  )
  expect_identical(result$source, source)
  expect_s3_class(result$matched_target, "sf")
  expect_equal(nrow(result$matched_target), 0)
  expect_null(result$connectors)
  expect_s3_class(result$table, "tbl_df")
  expect_equal(nrow(result$table), 0)
  expect_type(result$source$point_id, "integer")
  expect_type(result$matched_target$point_id, "integer")
  expect_type(result$table$rank, "integer")
  expect_type(result$table$distance_km, "double")
  expect_true(all(sf::st_geometry_type(result$source) == "POINT"))
  expect_s3_class(sf::st_geometry(result$matched_target), "sfc_POINT")
})
