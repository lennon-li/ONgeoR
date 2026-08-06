test_that("retrieve_synthetic_raster returns a deterministic Ontario PM2.5 grid", {
  r <- retrieve_synthetic_raster()

  expect_s4_class(r, "SpatRaster")
  expect_equal(as.character(terra::crs(r, describe = TRUE)$code), "4326")
  expect_equal(dim(r), c(30L, 42L, 1L))
  expect_equal(terra::nlyr(r), 1L)
  expect_equal(names(r), "pm25")

  ext <- as.vector(terra::ext(r))
  expect_equal(unname(ext[["xmin"]]), -95.2, tolerance = 1e-9)
  expect_equal(unname(ext[["xmax"]]), -74.3, tolerance = 1e-9)
  expect_equal(unname(ext[["ymin"]]), 41.7, tolerance = 1e-9)
  expect_equal(unname(ext[["ymax"]]), 56.9, tolerance = 1e-9)
  expect_equal(unname(terra::res(r)), c(0.5, 0.5), tolerance = 0.02)

  values <- terra::values(r)
  expect_true(all(values >= 3 & values <= 15))

  expect_equal(attr(r, "source_name"), "Synthetic Air Quality Surface (PM2.5)")
  expect_equal(attr(r, "source_url"), "synthetic://ongeor/pm25")
})

test_that("retrieve_synthetic_raster is identical across calls", {
  a <- retrieve_synthetic_raster()
  b <- retrieve_synthetic_raster()

  expect_equal(terra::values(a), terra::values(b))
})

test_that("link reduces a raster source to cell points joined to polygons", {
  r <- retrieve_synthetic_raster()
  poly <- sf::st_sf(
    zone = "South",
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(
        c(-80, 43), c(-79, 43), c(-79, 44), c(-80, 44), c(-80, 43)
      ))),
      crs = 4326
    )
  )

  result <- link(r, poly, predicate = "within")

  expect_s3_class(result, "tbl_df")
  expect_true(all(c("pm25", "zone", "source_url", "target_url", "retrieved_at")
    %in% names(result)))
  matched <- result[!is.na(result$zone), ]
  expect_gt(nrow(matched), 0)
  expect_true(all(matched$pm25 >= 3 & matched$pm25 <= 15))
  expect_equal(unique(result$source_url), "synthetic://ongeor/pm25")
})

test_that("link samples a raster target at the containing cell", {
  r <- retrieve_synthetic_raster()
  points <- data.frame(
    point_id = 1:2,
    lon = c(-79.4, -75.7),
    lat = c(43.7, 45.4)
  )

  result <- link(points, r, predicate = "within")
  ground_truth <- terra::extract(r, cbind(points$lon, points$lat))$pm25

  expect_equal(result$point_id, 1:2)
  expect_equal(result$pm25, ground_truth, tolerance = 1e-9)
  expect_equal(unique(result$target_url), "synthetic://ongeor/pm25")
  expect_false(is.null(result$retrieved_at))
})

test_that("link returns NA for a point outside the raster extent", {
  r <- retrieve_synthetic_raster()
  points <- data.frame(point_id = 1, lon = -120, lat = 60)

  result <- link(points, r, predicate = "within")

  expect_equal(nrow(result), 1)
  expect_true(is.na(result$pm25))
})

test_that("map_layers renders the synthetic raster without error", {
  m <- map_layers(retrieve_synthetic_raster())

  expect_s3_class(m, "leaflet")
  expect_s3_class(m, "htmlwidget")
})

test_that("the registry advertises the synthetic raster source", {
  sources <- list_sources()

  expect_s3_class(sources, "tbl_df")
  expect_true("synthetic_air_quality" %in% sources$source_id)
  row <- sources[sources$source_id == "synthetic_air_quality", ]
  expect_equal(unname(row$geography_type), "raster")

  meta <- get_source("synthetic_air_quality")
  expect_equal(meta$geography_type, "raster")
  expect_equal(meta$name, "Synthetic Air Quality Surface (PM2.5)")
})

test_that("link() gives the same result whichever slot the raster sits in", {
  skip_if_not_installed("terra")
  raster <- retrieve_synthetic_raster()
  ext <- as.vector(terra::ext(raster))
  crs <- terra::crs(raster)
  square <- sf::st_polygon(list(rbind(
    c(ext[1], ext[3]), c(ext[2], ext[3]),
    c(ext[2], ext[4]), c(ext[1], ext[4]), c(ext[1], ext[3])
  )))
  polygon <- sf::st_sf(PID = "P1", geometry = sf::st_sfc(square, crs = crs))
  points <- sf::st_sf(
    TID = c("a", "b"),
    geometry = sf::st_sfc(
      sf::st_point(c(ext[1] + diff(ext[1:2]) * 0.3,
                     ext[3] + diff(ext[3:4]) * 0.3)),
      sf::st_point(c(ext[1] + diff(ext[1:2]) * 0.6,
                     ext[3] + diff(ext[3:4]) * 0.6)),
      crs = crs
    )
  )

  # Reducing by slot position rather than by the other layer's geometry made
  # link(polygon, raster) and link(raster, point) match nothing and return it
  # silently, with every joined column NA at full height.
  point_first <- link(points, raster)
  raster_first <- link(raster, points)
  expect_equal(nrow(point_first), nrow(points))
  expect_equal(nrow(raster_first), nrow(points))
  expect_true(all(!is.na(point_first$pm25)))
  expect_true(all(!is.na(raster_first$pm25)))

  cells_first <- link(raster, polygon)
  polygon_first <- link(polygon, raster)
  expect_equal(nrow(cells_first), nrow(polygon_first))
  expect_gt(sum(!is.na(cells_first$PID)), 0)
  expect_equal(sum(!is.na(polygon_first$PID)), sum(!is.na(cells_first$PID)))
})
