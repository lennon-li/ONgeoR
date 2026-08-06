test_that("retrieve_hive returns the built-in HIVE Grid dataset", {
  hive <- retrieve_hive()

  expect_s3_class(hive, "sf")
  expect_equal(nrow(hive), 1629L)
  expect_true(all(as.character(sf::st_geometry_type(hive)) == "MULTIPOLYGON"))
  expect_equal(sf::st_crs(hive)$epsg, 4326L)
  expect_true(all(c("GRID_ID", "Level", "HIVE_ID") %in% names(hive)))

  expect_equal(attr(hive, "source_name"), "HIVE Grid (Levels 1-3)")
  expect_equal(attr(hive, "source_url"), "builtin://ongeor/hive")
  expect_false(is.null(attr(hive, "retrieved_at")))
})

test_that("every bundled HIVE cell is valid under planar GEOS", {
  # st_is_valid() on lnglat dispatches to s2, which judged the grid valid
  # while eight Level 1/2 cells were invalid under planar GEOS ("Hole lies
  # outside shell" / "Nested shells") and aborted build_intersection() with
  # TopologyException once the layer was transformed to a planar CRS. The
  # bundled grid must stay valid under planar GEOS, where intersection runs.
  hive <- retrieve_hive()
  geom <- sf::st_transform(sf::st_geometry(hive), 3347)
  prev <- sf::sf_use_s2(FALSE)
  on.exit(sf::sf_use_s2(prev), add = TRUE)
  invalid <- hive$GRID_ID[!sf::st_is_valid(geom)]
  expect_length(invalid, 0)
})

test_that("retrieve_source('hive') delegates to retrieve_hive", {
  via_source <- retrieve_source("hive")
  direct <- retrieve_hive()

  expect_s3_class(via_source, "sf")
  expect_equal(nrow(via_source), nrow(direct))
  expect_equal(names(via_source), names(direct))
  expect_equal(attr(via_source, "source_url"), attr(direct, "source_url"))
})

test_that("list_sources and get_source expose the hive registry entry", {
  sources <- list_sources()
  hive_row <- sources[sources$source_id == "hive", ]

  expect_equal(nrow(hive_row), 1L)
  expect_equal(unname(hive_row$geography_type), "boundary")
  expect_equal(unname(hive_row$feature_count), 1629L)

  meta <- get_source("hive")
  expect_equal(meta$geography_type, "boundary")
  expect_equal(meta$name, "HIVE Grid (Levels 1-3)")
})

test_that("map_layers renders the HIVE dataset without error", {
  hive <- retrieve_hive()

  widget <- map_layers(hive = hive)

  expect_s3_class(widget, "leaflet")
})
