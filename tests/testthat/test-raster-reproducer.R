# Regression coverage for the raster reproducer story: before this, a raster
# source/target run's Script download stayed disabled because
# render_reproducer_script() only knew how to rebuild a build_crosswalk()
# run. render_link_reproducer_script() plus the app's raster_link_from_to()
# direction helper close that gap.

test_that("source_geometry_kind maps registry geography_type to link() kinds", {
  expect_equal(source_geometry_kind("synthetic_air_quality"), "raster")
  expect_equal(source_geometry_kind("hive"), "polygon")
  expect_equal(source_geometry_kind("monitoring_stations_bundled"), "point")
  expect_true(is.na(source_geometry_kind("own_upload")))
  expect_true(is.na(source_geometry_kind("not_a_real_source")))
})

test_that("render_link_reproducer_script rebuilds the link() table it documents", {
  out <- withr::local_tempdir()
  script <- render_link_reproducer_script("synthetic_air_quality", "hive", out)

  expect_match(script, "retrieve_synthetic_raster()", fixed = TRUE)
  expect_match(script, "retrieve_hive()", fixed = TRUE)
  expect_match(script, "link(from_layer, to_layer, predicate = predicate)", fixed = TRUE)

  eval(parse(text = script), envir = new.env())

  linked <- utils::read.csv(file.path(out, "linked.csv"))
  expect_gt(nrow(linked), 0)
  expect_true(file.exists(file.path(out, "reproduce.R")))
})

test_that("raster_link_from_to reduces a raster source to points against a polygon target", {
  env <- load_shiny_app_env()
  # base is the polygon target; overlay (raster) is the source being reduced
  # to cell-centroid points, matching the "raster + polygon" branch.
  direction <- env$raster_link_from_to("hive", "synthetic_air_quality")
  expect_equal(direction, list(from = "synthetic_air_quality", to = "hive"))
})

test_that("raster_link_from_to reduces a raster target to cell polygons against a point source", {
  env <- load_shiny_app_env()
  # base is the raster; overlay (point) is the source landing in whichever
  # cell polygon contains it, matching the "raster + point" branch.
  direction <- env$raster_link_from_to("synthetic_air_quality", "monitoring_stations_bundled")
  expect_equal(direction, list(from = "monitoring_stations_bundled", to = "synthetic_air_quality"))
})

test_that("raster_link_from_to is symmetric in which side of the pair is raster", {
  env <- load_shiny_app_env()

  polygon_base <- env$raster_link_from_to("synthetic_air_quality", "hive")
  expect_equal(polygon_base, list(from = "synthetic_air_quality", to = "hive"))

  point_base <- env$raster_link_from_to("monitoring_stations_bundled", "synthetic_air_quality")
  expect_equal(point_base, list(from = "monitoring_stations_bundled", to = "synthetic_air_quality"))
})

test_that("raster_link_from_to returns NULL for an uploaded layer with no registry id", {
  env <- load_shiny_app_env()
  expect_null(env$raster_link_from_to("own_upload", "synthetic_air_quality"))
  expect_null(env$raster_link_from_to("synthetic_air_quality", "postal_upload"))
})
