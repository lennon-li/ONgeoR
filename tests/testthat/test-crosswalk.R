make_synthetic_layers <- function() {
  phu_poly <- sf::st_polygon(list(rbind(
    c(-80, 44), c(-79, 44), c(-79, 43), c(-80, 43), c(-80, 44)
  )))
  phu <- sf::st_sf(
    PHU_ID = 1,
    PHU_NAME_ENG = "Test Health Unit A",
    geometry = sf::st_sfc(phu_poly, crs = 4326)
  )
  attr(phu, "source_name") <- "MOH Public Health Unit Boundary"
  attr(phu, "source_url") <- "https://example.com/phu"
  attr(phu, "retrieved_at") <- as.POSIXct("2026-07-08 00:00:00", tz = "UTC")

  muni_poly <- sf::st_polygon(list(rbind(
    c(-79.8, 43.8), c(-79.2, 43.8), c(-79.2, 43.2), c(-79.8, 43.2), c(-79.8, 43.8)
  )))
  municipal <- sf::st_sf(
    MUNID = 100,
    MUNICIPAL_NAME = "Test Municipality",
    geometry = sf::st_sfc(muni_poly, crs = 4326)
  )
  attr(municipal, "source_name") <- "Municipal Bnd Upper And Dist"
  attr(municipal, "source_url") <- "https://example.com/municipal"

  list(municipal = municipal, phu = phu)
}

test_that("build_crosswalk produces the documented output schema", {
  layers <- make_synthetic_layers()

  crosswalk <- build_crosswalk(layers$municipal, layers$phu, method = "within")

  expected_cols <- c(
    "from_id", "from_name", "from_source",
    "to_id", "to_name", "to_source",
    "match_method", "match_distance_km",
    "source_url_from", "source_url_to", "retrieved_at"
  )
  expect_equal(colnames(crosswalk), expected_cols)
  expect_equal(nrow(crosswalk), 1)
})

test_that("build_crosswalk populates provenance fields correctly", {
  layers <- make_synthetic_layers()

  crosswalk <- build_crosswalk(layers$municipal, layers$phu, method = "within")

  expect_equal(crosswalk$from_id, "100")
  expect_equal(crosswalk$from_name, "Test Municipality")
  expect_equal(crosswalk$from_source, "Municipal Bnd Upper And Dist")
  expect_equal(crosswalk$to_id, "1")
  expect_equal(crosswalk$to_name, "Test Health Unit A")
  expect_equal(crosswalk$to_source, "MOH Public Health Unit Boundary")
  expect_equal(crosswalk$match_method, "within")
  expect_true(is.na(crosswalk$match_distance_km))
  expect_equal(crosswalk$source_url_from, "https://example.com/municipal")
  expect_equal(crosswalk$source_url_to, "https://example.com/phu")
  expect_equal(crosswalk$retrieved_at, as.POSIXct("2026-07-08 00:00:00", tz = "UTC"))
})

test_that("build_crosswalk defaults to the within predicate", {
  layers <- make_synthetic_layers()

  crosswalk <- build_crosswalk(layers$municipal, layers$phu)

  expect_equal(crosswalk$match_method, "within")
})

make_synthetic_point_layers <- function() {
  polygon <- sf::st_polygon(list(rbind(
    c(-80, 44), c(-79, 44), c(-79, 43), c(-80, 43), c(-80, 44)
  )))
  area <- sf::st_sf(
    MUNID = 100,
    MUNICIPAL_NAME = "Test Municipality",
    geometry = sf::st_sfc(polygon, crs = 4326)
  )
  attr(area, "source_name") <- "Municipal Bnd Upper And Dist"
  attr(area, "source_url") <- "https://example.com/municipal"

  inside_point <- sf::st_point(c(-79.5, 43.5))
  outside_point <- sf::st_point(c(-81.5, 43.5))
  facilities <- sf::st_sf(
    FACILITY_ID = c(10, 20),
    FACILITY_NAME = c("Facility Inside", "Facility Outside"),
    geometry = sf::st_sfc(inside_point, outside_point, crs = 4326)
  )
  attr(facilities, "source_name") <- "Test Facilities"
  attr(facilities, "source_url") <- "https://example.com/facilities"
  attr(facilities, "retrieved_at") <- as.POSIXct("2026-07-08 02:00:00", tz = "UTC")

  list(area = area, facilities = facilities)
}

test_that("build_crosswalk auto-reorders polygon-from/point-to within joins", {
  layers <- make_synthetic_point_layers()

  expect_message(
    crosswalk <- build_crosswalk(layers$area, layers$facilities, method = "within"),
    "auto-corrected"
  )

  expect_equal(nrow(crosswalk), 2)
  inside_row <- crosswalk[crosswalk$to_id == "10", ]
  outside_row <- crosswalk[crosswalk$to_id == "20", ]
  expect_equal(inside_row$from_id, "100")
  expect_equal(inside_row$from_name, "Test Municipality")
  expect_true(is.na(outside_row$from_id))
  expect_equal(
    crosswalk$retrieved_at,
    rep(as.POSIXct("2026-07-08 02:00:00", tz = "UTC"), 2)
  )
})

test_that("build_crosswalk does not reorder when to is already polygonal", {
  layers <- make_synthetic_layers()

  expect_no_message(build_crosswalk(layers$municipal, layers$phu, method = "within"))
})

test_that("build_crosswalk auto-reorder output has the documented column schema", {
  layers <- make_synthetic_point_layers()

  crosswalk <- suppressMessages(
    build_crosswalk(layers$area, layers$facilities, method = "within")
  )

  expected_cols <- c(
    "from_id", "from_name", "from_source",
    "to_id", "to_name", "to_source",
    "match_method", "match_distance_km",
    "source_url_from", "source_url_to", "retrieved_at"
  )
  expect_equal(colnames(crosswalk), expected_cols)
})
