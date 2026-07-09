synthetic_phu_geojson <- paste0(
  '{"type":"FeatureCollection","features":[',
  '{"type":"Feature","properties":{"PHU_ID":1,"PHU_NAME_ENG":"Test Health Unit A"},',
  '"geometry":{"type":"Polygon","coordinates":[[[-80,44],[-79,44],[-79,43],[-80,43],[-80,44]]]}},',
  '{"type":"Feature","properties":{"PHU_ID":2,"PHU_NAME_ENG":"Test Health Unit B"},',
  '"geometry":{"type":"Polygon","coordinates":[[[-82,44],[-81,44],[-81,43],[-82,43],[-82,44]]]}}',
  "]}"
)

synthetic_health_region_geojson <- paste0(
  '{"type":"FeatureCollection","features":[',
  '{"type":"Feature","properties":{"OH_REGION_ID":1,"ENGLISH_NAME":"Test Region A"},',
  '"geometry":{"type":"Polygon","coordinates":[[[-80,44],[-79,44],[-79,43],[-80,43],[-80,44]]]}}',
  "]}"
)

mock_geojson_response <- function(body) {
  function(req) {
    httr2::response(
      status_code = 200,
      body = charToRaw(body),
      headers = list("Content-Type" = "application/json")
    )
  }
}

use_temp_cache <- function() {
  cache_dir <- tempfile("ongeor-cache-")
  dir.create(cache_dir, recursive = TRUE)
  testthat::local_mocked_bindings(
    ongeor_cache_dir = function() cache_dir,
    .package = "ONgeoR",
    .env = parent.frame()
  )
  cache_dir
}

test_that("retrieve_phu returns an sf object with provenance attributes", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  phu <- httr2::with_mocked_responses(
    mock_geojson_response(synthetic_phu_geojson),
    retrieve_phu()
  )

  expect_s3_class(phu, "sf")
  expect_equal(nrow(phu), 2)
  expect_true(all(c("PHU_ID", "PHU_NAME_ENG") %in% colnames(phu)))
  expect_false(is.null(attr(phu, "source_url")))
  expect_false(is.null(attr(phu, "retrieved_at")))
  expect_equal(attr(phu, "source_name"), "MOH Public Health Unit Boundary")
})

test_that("retrieve_health_region returns an sf object with provenance attributes", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  health_region <- httr2::with_mocked_responses(
    mock_geojson_response(synthetic_health_region_geojson),
    retrieve_health_region()
  )

  expect_s3_class(health_region, "sf")
  expect_equal(nrow(health_region), 1)
  expect_true(all(c("OH_REGION_ID", "ENGLISH_NAME") %in% colnames(health_region)))
  expect_false(is.null(attr(health_region, "source_url")))
  expect_false(is.null(attr(health_region, "retrieved_at")))
})

test_that("retrieve_municipal dispatches to the correct tier layer", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  municipal <- httr2::with_mocked_responses(
    mock_geojson_response(synthetic_phu_geojson),
    retrieve_municipal("upper")
  )

  expect_s3_class(municipal, "sf")
  expect_equal(attr(municipal, "source_name"), "Municipal Bnd Upper And Dist")
  expect_match(attr(municipal, "source_url"), "LIO_Open03/MapServer/13")
})
