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

synthetic_airport_geojson <- paste0(
  '{"type":"FeatureCollection","features":[',
  '{"type":"Feature","properties":{"AIRPORT_IDENT":"ABC","NAME":"Test Airport","AIRPORT_TYPE":"Registered Aerodrome"},',
  '"geometry":{"type":"Polygon","coordinates":[[[-80,44],[-79,44],[-79,43],[-80,43],[-80,44]]]}}',
  "]}"
)

synthetic_waste_site_geojson <- paste0(
  '{"type":"FeatureCollection","features":[',
  '{"type":"Feature","properties":{"SITE_NAME":"Test Waste Site","PRIMARY_CLASSIFICATION":"Landfill","STATUS":"Open"},',
  '"geometry":{"type":"Polygon","coordinates":[[[-82,44],[-81,44],[-81,43],[-82,43],[-82,44]]]}}',
  "]}"
)

synthetic_point_geojson <- function(ids) {
  features <- vapply(ids, function(id) {
    paste0(
      '{"type":"Feature","properties":{"OBJECTID":', id, ',"SERVICE_TYPE":"Test"},',
      '"geometry":{"type":"Point","coordinates":[', -80 - id / 100, ",", 44 + id / 100, "]}}"
    )
  }, character(1))
  paste0(
    '{"type":"FeatureCollection","features":[',
    paste(features, collapse = ","),
    "]}"
  )
}

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

test_that("retrieve_airport returns an sf object with provenance attributes", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  airport <- httr2::with_mocked_responses(
    mock_geojson_response(synthetic_airport_geojson),
    retrieve_airport()
  )

  expect_s3_class(airport, "sf")
  expect_equal(nrow(airport), 1)
  expect_true(all(c("AIRPORT_IDENT", "NAME", "AIRPORT_TYPE") %in% colnames(airport)))
  expect_false(is.null(attr(airport, "source_url")))
  expect_false(is.null(attr(airport, "retrieved_at")))
  expect_equal(attr(airport, "source_name"), "Airport Official")
  expect_match(attr(airport, "source_url"), "LIO_Open05/MapServer/0")
})

test_that("retrieve_waste_management returns an sf object with provenance attributes", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  waste_site <- httr2::with_mocked_responses(
    mock_geojson_response(synthetic_waste_site_geojson),
    retrieve_waste_management()
  )

  expect_s3_class(waste_site, "sf")
  expect_equal(nrow(waste_site), 1)
  expect_true(all(c("SITE_NAME", "PRIMARY_CLASSIFICATION", "STATUS") %in% colnames(waste_site)))
  expect_false(is.null(attr(waste_site, "source_url")))
  expect_false(is.null(attr(waste_site, "retrieved_at")))
  expect_equal(attr(waste_site, "source_name"), "Waste Management Site")
  expect_match(attr(waste_site, "source_url"), "LIO_Open08/MapServer/9")
})

test_that("fetch_lio_sf keeps default single-page behavior", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  calls <- 0
  layer <- httr2::with_mocked_responses(
    function(req) {
      calls <<- calls + 1
      httr2::response(
        status_code = 200,
        body = charToRaw(synthetic_point_geojson(1:2)),
        headers = list("Content-Type" = "application/json")
      )
    },
    fetch_lio_sf(
      service_layer = "LIO_Open09/26",
      source_name = "MOH Service Location",
      simplify = FALSE,
      result_record_count = 2,
      refresh = TRUE
    )
  )

  expect_s3_class(layer, "sf")
  expect_equal(nrow(layer), 2)
  expect_equal(calls, 1)
})

test_that("fetch_lio_sf combines paginated responses", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  pages <- list(1:2, 3:4, 5)
  calls <- 0
  layer <- httr2::with_mocked_responses(
    function(req) {
      calls <<- calls + 1
      httr2::response(
        status_code = 200,
        body = charToRaw(synthetic_point_geojson(pages[[calls]])),
        headers = list("Content-Type" = "application/json")
      )
    },
    fetch_lio_sf(
      service_layer = "LIO_Open09/26",
      source_name = "MOH Service Location",
      simplify = FALSE,
      result_record_count = 2,
      refresh = TRUE,
      paginate = TRUE
    )
  )

  expect_s3_class(layer, "sf")
  expect_equal(nrow(layer), 5)
  expect_equal(layer$OBJECTID, 1:5)
  expect_equal(calls, 3)
  expect_match(attr(layer, "source_url"), "resultRecordCount=2")
  expect_no_match(attr(layer, "source_url"), "resultOffset")
})

test_that("fetch_lio_sf aborts paginated requests after the hard cap", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  calls <- 0
  expect_error(
    httr2::with_mocked_responses(
      function(req) {
        calls <<- calls + 1
        httr2::response(
          status_code = 200,
          body = charToRaw(synthetic_point_geojson(1:2)),
          headers = list("Content-Type" = "application/json")
        )
      },
      fetch_lio_sf(
        service_layer = "LIO_Open09/26",
        source_name = "MOH Service Location",
        simplify = FALSE,
        result_record_count = 2,
        refresh = TRUE,
        paginate = TRUE
      )
    ),
    "pagination exceeded 20 pages"
  )
  expect_equal(calls, 20)
})
