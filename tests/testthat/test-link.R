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

test_that("points_to_phu joins a data.frame of points to the correct PHU", {
  phu <- make_synthetic_phu()

  points <- data.frame(
    point_id = 1:2,
    lon = c(-79.5, -81.5),
    lat = c(43.5, 43.5)
  )

  result <- points_to_phu(points, phu)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2)
  expect_equal(result$PHU_NAME_ENG, c("Test Health Unit A", "Test Health Unit B"))
  expect_equal(result$source_url, rep("https://example.com/phu", 2))
  expect_false(is.null(result$retrieved_at))
})

test_that("points_to_phu accepts sf point input directly", {
  phu <- make_synthetic_phu()

  points_sf <- sf::st_as_sf(
    data.frame(point_id = 1, lon = -79.5, lat = 43.5),
    coords = c("lon", "lat"),
    crs = 4326
  )

  result <- points_to_phu(points_sf, phu)

  expect_equal(nrow(result), 1)
  expect_equal(result$PHU_NAME_ENG, "Test Health Unit A")
})

test_that("polygon_to_polygon joins municipality polygons to PHU polygons", {
  phu <- make_synthetic_phu()

  muni_poly <- sf::st_polygon(list(rbind(
    c(-79.8, 43.8), c(-79.2, 43.8), c(-79.2, 43.2), c(-79.8, 43.2), c(-79.8, 43.8)
  )))
  municipal <- sf::st_sf(
    MUNID = 100,
    MUNICIPAL_NAME = "Test Municipality",
    geometry = sf::st_sfc(muni_poly, crs = 4326)
  )

  result <- polygon_to_polygon(municipal, phu)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_equal(result$PHU_NAME_ENG, "Test Health Unit A")
  expect_equal(result$source_url_to, "https://example.com/phu")
})
