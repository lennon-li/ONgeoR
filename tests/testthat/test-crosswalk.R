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
