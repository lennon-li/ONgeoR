test_that("census query URLs use the StatCan endpoint and Ontario filter", {
  url <- lio_query_url(
    service_layer = "2021/Cartographic_boundary_files/MapServer/4",
    endpoint = "https://geo.statcan.gc.ca/geo_wa/rest/services/2021/Cartographic_boundary_files/MapServer/4",
    where = "PRUID='35'"
  )

  expect_match(url, "geo.statcan.gc.ca", fixed = TRUE)
  expect_match(url, "PRUID%3D%2735%27", fixed = TRUE)
  expect_match(url, "outSR=4326", fixed = TRUE)
})

test_that("retrieve_census returns Ontario census divisions in EPSG:4326", {
  skip_on_cran()
  skip_if_offline("geo.statcan.gc.ca")

  census_divisions <- retrieve_census("census_cd_2021", refresh = TRUE)

  expect_equal(nrow(census_divisions), 49L)
  expect_equal(sf::st_crs(census_divisions)$epsg, 4326L)
})

test_that("retrieve_census composes an Ontario bbox filter", {
  skip_on_cran()
  skip_if_offline("geo.statcan.gc.ca")

  expect_no_warning(
    toronto <- retrieve_census(
      "census_cd_2021",
      bbox = c(xmin = -80, ymin = 43, xmax = -79, ymax = 44),
      refresh = TRUE
    ),
    class = "ongeor_feature_count_mismatch"
  )
  expect_lt(nrow(toronto), 49L)
})

test_that("census dissemination blocks are not registered", {
  expect_false("census_db_2021" %in% list_sources()$source_id)
})
