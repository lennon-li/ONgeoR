make_synthetic_phu <- function() {
  poly_a <- sf::st_polygon(list(rbind(
    c(-80, 44), c(-79, 44), c(-79, 43), c(-80, 43), c(-80, 44)
  )))
  poly_b <- sf::st_polygon(list(rbind(
    c(-82, 44), c(-81, 44), c(-81, 43), c(-82, 43), c(-82, 44)
  )))

  phu <- sf::st_sf(
    PHU_ID = c(1, 2),
    PHU_NAME_ENG = c("Test Health Unit A", "Test Health Unit B"),
    geometry = sf::st_sfc(poly_a, poly_b, crs = 4326)
  )
  attr(phu, "source_url") <- "https://example.com/phu"
  attr(phu, "retrieved_at") <- as.POSIXct("2026-07-08 00:00:00", tz = "UTC")
  phu
}

make_synthetic_facilities <- function() {
  facilities <- sf::st_as_sf(
    data.frame(
      facility_id = c(10, 20, 30),
      facility_name = c("Facility A", "Facility B", "Facility C"),
      service_type = c("Hospital", "Clinic", "Hospital"),
      lon = c(-79.000, -79.010, -80.000),
      lat = c(43.000, 43.000, 44.000)
    ),
    coords = c("lon", "lat"),
    crs = 4326
  )
  attr(facilities, "source_url") <- "https://example.com/facilities"
  attr(facilities, "retrieved_at") <- as.POSIXct(
    "2026-07-08 01:00:00",
    tz = "UTC"
  )
  facilities
}

test_that("link joins points to the containing polygon (within)", {
  phu <- make_synthetic_phu()
  points <- data.frame(point_id = 1:2, lon = c(-79.5, -81.5), lat = c(43.5, 43.5))

  result <- link(points, phu)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2)
  expect_equal(result$PHU_NAME_ENG, c("Test Health Unit A", "Test Health Unit B"))
  expect_equal(result$target_url, rep("https://example.com/phu", 2))
  expect_true(all(is.na(result$source_url)))
  expect_false(is.null(result$retrieved_at))
})

test_that("link accepts sf point input directly", {
  phu <- make_synthetic_phu()
  points_sf <- sf::st_as_sf(
    data.frame(point_id = 1, lon = -79.5, lat = 43.5),
    coords = c("lon", "lat"), crs = 4326
  )

  result <- link(points_sf, phu)

  expect_equal(nrow(result), 1)
  expect_equal(result$PHU_NAME_ENG, "Test Health Unit A")
})

test_that("link joins polygons to polygons with the intersects predicate", {
  phu <- make_synthetic_phu()
  muni_poly <- sf::st_polygon(list(rbind(
    c(-79.8, 43.8), c(-79.2, 43.8), c(-79.2, 43.2), c(-79.8, 43.2), c(-79.8, 43.8)
  )))
  municipal <- sf::st_sf(
    MUNID = 100, MUNICIPAL_NAME = "Test Municipality",
    geometry = sf::st_sfc(muni_poly, crs = 4326)
  )
  attr(municipal, "source_url") <- "https://example.com/muni"

  result <- link(municipal, phu, predicate = "intersects")

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_equal(result$PHU_NAME_ENG, "Test Health Unit A")
  expect_equal(result$source_url, "https://example.com/muni")
  expect_equal(result$target_url, "https://example.com/phu")
})

test_that("link aborts on a raster source (seam not yet implemented)", {
  phu <- make_synthetic_phu()
  fake_raster <- structure(list(), class = "SpatRaster")

  expect_error(link(fake_raster, phu), "not yet implemented")
})

test_that("nearest_facility returns the closest facility per point", {
  facilities <- make_synthetic_facilities()
  points <- data.frame(
    point_id = 1:2,
    lon = c(-79.000, -80.000),
    lat = c(43.000, 44.000)
  )

  result <- nearest_facility(points, facilities)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2)
  expect_equal(result$point_id, 1:2)
  expect_equal(result$rank, c(1, 1))
  expect_equal(result$facility_name, c("Facility A", "Facility C"))
  expect_equal(result$distance_km, c(0, 0), tolerance = 0.001)
  expect_equal(result$source_url, rep("https://example.com/facilities", 2))
  expect_false(is.null(result$retrieved_at))
})

test_that("nearest_facility returns k matches in ascending distance order", {
  facilities <- make_synthetic_facilities()
  points <- data.frame(point_id = 1, lon = -79.000, lat = 43.000)

  result <- nearest_facility(points, facilities, k = 2)

  expect_equal(nrow(result), 2)
  expect_equal(result$rank, c(1, 2))
  expect_equal(result$facility_name, c("Facility A", "Facility B"))
  expect_true(result$distance_km[1] <= result$distance_km[2])
})

test_that("nearest_facility caps k at the available facility count", {
  facilities <- make_synthetic_facilities()
  points <- data.frame(point_id = 1, lon = -79.000, lat = 43.000)

  result <- nearest_facility(points, facilities, k = 5)

  expect_equal(nrow(result), 3)
  expect_equal(result$rank, 1:3)
  expect_equal(
    result$facility_name,
    c("Facility A", "Facility B", "Facility C")
  )
})

test_that("facilities_within returns nearby facilities and omits no-match points", {
  facilities <- make_synthetic_facilities()
  points <- data.frame(
    point_id = 1:2,
    lon = c(-79.000, -82.000),
    lat = c(43.000, 45.000)
  )

  result <- expect_no_warning(
    facilities_within(points, facilities, radius_km = 2)
  )

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2)
  expect_equal(result$point_id, c(1, 1))
  expect_equal(result$facility_name, c("Facility A", "Facility B"))
  expect_true(result$distance_km[1] <= result$distance_km[2])
  expect_false("rank" %in% names(result))
  expect_equal(result$source_url, rep("https://example.com/facilities", 2))
  expect_false(is.null(result$retrieved_at))
})
