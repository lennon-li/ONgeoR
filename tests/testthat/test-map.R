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

test_that("map_layers renders a raster layer as a leaflet widget", {
  m <- map_layers(`Air quality` = retrieve_synthetic_raster())
  expect_s3_class(m, "leaflet")
  expect_s3_class(m, "htmlwidget")

  methods <- vapply(m$x$calls, `[[`, character(1), "method")
  expect_true("addRasterImage" %in% methods)
  expect_true("addLegend" %in% methods)
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

test_that("map_nearest maps exact matches and connector lines", {
  source <- sf::st_as_sf(
    data.frame(NAME = c("Same", "Same"), lon = c(-79.0, -80.0), lat = c(43, 44)),
    coords = c("lon", "lat"), crs = 4326
  )
  target <- sf::st_as_sf(
    data.frame(NAME = c("Same", "Same"), lon = c(-79.01, -80.01), lat = c(43, 44)),
    coords = c("lon", "lat"), crs = 4326
  )

  map <- map_nearest(source, target)
  methods <- vapply(map$x$calls, `[[`, character(1), "method")
  marker_calls <- map$x$calls[methods == "addCircleMarkers"]
  line_call <- map$x$calls[[which(methods == "addPolylines")]]
  control_calls <- map$x$calls[methods == "addLayersControl"]
  control_call <- control_calls[[length(control_calls)]]

  expect_s3_class(map, "leaflet")
  expect_s3_class(map, "htmlwidget")
  expect_length(marker_calls, 2)
  expect_length(marker_calls[[2]]$args[[1]], 2)
  expect_length(line_call$args[[1]], 2)
  second_connector <- line_call$args[[1]][[2]][[1]][[1]]
  expect_equal(second_connector$lng, c(-80, -80.01))
  expect_equal(second_connector$lat, c(44, 44))
  expect_equal(
    control_call$args[[2]],
    c("Source", "Matched targets", "Connections")
  )
})

test_that("map_nearest accepts lon-lat data frames and k matches", {
  source <- data.frame(id = "origin", lon = -79, lat = 43)
  target <- sf::st_as_sf(
    data.frame(NAME = c("A", "B", "C"), lon = c(-79.01, -79.02, -80), lat = 43),
    coords = c("lon", "lat"), crs = 4326
  )

  map <- map_nearest(source, target, k = 2)
  methods <- vapply(map$x$calls, `[[`, character(1), "method")
  marker_calls <- map$x$calls[methods == "addCircleMarkers"]
  line_call <- map$x$calls[[which(methods == "addPolylines")]]

  expect_length(marker_calls[[2]]$args[[1]], 2)
  expect_length(line_call$args[[1]], 2)
})

test_that("map_nearest maps sources when no target is in range", {
  source <- sf::st_as_sf(
    data.frame(NAME = "Origin", lon = -79, lat = 43),
    coords = c("lon", "lat"), crs = 4326
  )
  target <- sf::st_as_sf(
    data.frame(NAME = "Far", lon = -80, lat = 44),
    coords = c("lon", "lat"), crs = 4326
  )

  map <- map_nearest(source, target, max_dist_km = 1)
  methods <- vapply(map$x$calls, `[[`, character(1), "method")

  expect_s3_class(map, "leaflet")
  expect_equal(sum(methods == "addCircleMarkers"), 1)
  expect_false(any(methods == "addPolylines"))
})

test_that("map_nearest validates its public inputs", {
  point <- sf::st_as_sf(
    data.frame(NAME = "A", lon = -79, lat = 43),
    coords = c("lon", "lat"), crs = 4326
  )
  polygon <- make_map_polys()

  expect_error(map_nearest(data.frame(x = 1), point), "lon.*lat")
  expect_error(map_nearest(point, data.frame(x = 1)), "target.*sf")
  expect_error(map_nearest(polygon, point), "source.*point")
  expect_error(map_nearest(point, point, k = 0), "k.*positive")
  expect_error(map_nearest(point, point, max_dist_km = -1), "max_dist_km")
})
