make_map_points <- function(source_name = NULL) {
  pts <- sf::st_as_sf(
    data.frame(NAME = c("A", "B"), lon = c(-79, -80), lat = c(43, 44)),
    coords = c("lon", "lat"), crs = 4326
  )
  if (!is.null(source_name)) attr(pts, "source_name") <- source_name
  pts
}

make_map_polys <- function() {
  poly <- sf::st_polygon(list(rbind(
    c(-80, 44), c(-79, 44), c(-79, 43), c(-80, 43), c(-80, 44)
  )))
  sf::st_sf(PHU_NAME_ENG = "Unit A", geometry = sf::st_sfc(poly, crs = 4326))
}

test_that("map_layers returns a leaflet htmlwidget for polygons", {
  m <- map_layers(make_map_polys())
  expect_s3_class(m, "leaflet")
  expect_s3_class(m, "htmlwidget")
})

test_that("map_layers renders points and polygons together", {
  m <- map_layers(make_map_polys(), make_map_points())
  expect_s3_class(m, "leaflet")
  expect_s3_class(m, "htmlwidget")
})

test_that("layer_group_labels prefers arg name, then source_name, then position", {
  named <- layer_group_labels(list(units = make_map_polys(), pts = make_map_points()))
  expect_equal(named, c("units", "pts"))

  from_prov <- layer_group_labels(list(
    make_map_polys(),
    make_map_points(source_name = "MOH Service Location")
  ))
  expect_equal(from_prov, c("Layer 1", "MOH Service Location"))
})

test_that("map_layers aborts on a raster layer (seam not implemented)", {
  fake_raster <- structure(list(), class = "SpatRaster")
  expect_error(map_layers(fake_raster), "not yet implemented")
})

test_that("map_layers aborts on an unsupported geometry type", {
  line <- sf::st_sf(
    NAME = "L",
    geometry = sf::st_sfc(sf::st_linestring(rbind(c(-79, 43), c(-80, 44))), crs = 4326)
  )
  expect_error(map_layers(line), "unsupported geometry")
})

test_that("map_layers requires at least one layer", {
  expect_error(map_layers(), "at least one")
})
