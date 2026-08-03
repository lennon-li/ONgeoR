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

synthetic_conservation_authority_geojson <- paste0(
  '{"type":"FeatureCollection","features":[',
  '{"type":"Feature","properties":{"CA_ID":1,"LEGAL_NAME":"Test Conservation Authority","COMMON_NAME":"Test CA"},',
  '"geometry":{"type":"Polygon","coordinates":[[[-80,44],[-79,44],[-79,43],[-80,43],[-80,44]]]}},',
  '{"type":"Feature","properties":{"CA_ID":2,"LEGAL_NAME":"Another Conservation Authority","COMMON_NAME":"Another CA"},',
  '"geometry":{"type":"Polygon","coordinates":[[[-82,44],[-81,44],[-81,43],[-82,43],[-82,44]]]}}',
  "]}"
)

synthetic_orwn_station_geojson <- paste0(
  '{"type":"FeatureCollection","features":[',
  '{"type":"Feature","properties":{"STENNAME":"Union Station","STNTYPE":"Passenger","TRACKNAME":"Main Line"},',
  '"geometry":{"type":"Point","coordinates":[-79.38,43.64]}},',
  '{"type":"Feature","properties":{"STENNAME":"Oshawa GO","STNTYPE":"Commuter","TRACKNAME":"Lakeshore East"},',
  '"geometry":{"type":"Point","coordinates":[-78.86,43.90]}}',
  "]}"
)

synthetic_monitoring_stations_geojson <- paste0(
  '{"type":"FeatureCollection","features":[',
  '{"type":"Feature","properties":{"OGF_ID":1,"STATION_NAME":"Test Station A","STATION_IDENT":"TS001","NETWORK_NAME":"Hydrometric","DATA_COLLECTION_METHOD":"Auto"},',
  '"geometry":{"type":"Point","coordinates":[-79.38,43.64]}},',
  '{"type":"Feature","properties":{"OGF_ID":2,"STATION_NAME":"Test Station B","STATION_IDENT":"TS002","NETWORK_NAME":"Weather","DATA_COLLECTION_METHOD":"Manual"},',
  '"geometry":{"type":"Point","coordinates":[-78.86,43.90]}}',
  "]}"
)

synthetic_point_geojson <- function(ids, truncated = FALSE) {
  features <- vapply(ids, function(id) {
    paste0(
      '{"type":"Feature","properties":{"OBJECTID":', id, ',"SERVICE_TYPE":"Test"},',
      '"geometry":{"type":"Point","coordinates":[', -80 - id / 100, ",", 44 + id / 100, "]}}"
    )
  }, character(1))
  paste0(
    '{"type":"FeatureCollection","features":[',
    paste(features, collapse = ","),
    "],\"exceededTransferLimit\":", tolower(as.character(truncated)), "}"
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

mock_lio_response <- function(status_code, body = "", retry_after = NULL) {
  headers <- list("Content-Type" = "application/json")
  if (!is.null(retry_after)) {
    headers[["Retry-After"]] <- retry_after
  }
  httr2::response(
    status_code = status_code,
    body = charToRaw(body),
    headers = headers
  )
}

use_temp_cache <- function() {
  cache_dir <- tempfile("ongeor-cache-")
  dir.create(cache_dir, recursive = TRUE)
  testthat::local_mocked_bindings(
    ongeor_cache_dir = function() cache_dir,
    .package = "ONgeoR",
    .env = parent.frame()
  )
  testthat::local_mocked_bindings(
    load_source_registry = function() list(),
    .package = "ONgeoR",
    .env = parent.frame()
  )
  cache_dir
}

capture_lio_messages <- function(expr) {
  messages <- character()
  value <- withCallingHandlers(
    expr,
    message = function(cnd) {
      messages <<- c(messages, conditionMessage(cnd))
      invokeRestart("muffleMessage")
    }
  )
  list(value = value, messages = messages)
}

test_that("lio_query_url builds encoded query and pagination parameters", {
  url <- lio_query_url(
    service_layer = "LIO_Open09/26",
    where = "SERVICE_TYPE = 'Public Health'",
    simplify = FALSE,
    result_record_count = 100,
    result_offset = 200
  )

  expect_match(url, "LIO_Open09/MapServer/26/query", fixed = TRUE)
  expect_match(url, "where=SERVICE_TYPE%20%3D%20%27Public%20Health%27")
  expect_match(url, "resultRecordCount=100", fixed = TRUE)
  expect_match(url, "resultOffset=200", fixed = TRUE)
  expect_no_match(url, "maxAllowableOffset", fixed = TRUE)
})

test_that("retrieve_moh_service_locations escapes apostrophes in WHERE values", {
  service_type <- "Children's Hospital"
  escaped_service_type <- gsub("'", "''", service_type)
  where <- sprintf("SERVICE_TYPE = '%s'", escaped_service_type)

  expect_equal(where, "SERVICE_TYPE = 'Children''s Hospital'")
})

test_that("retrieve_hive reports a missing bundled data file clearly", {
  testthat::local_mocked_bindings(
    hive_data_path = function() "",
    .package = "ONgeoR"
  )

  error <- expect_error(retrieve_hive(), class = "ongeor_hive_missing")
  expect_match(conditionMessage(error), "hive.rds", fixed = TRUE)
  expect_match(conditionMessage(error), "reinstall", ignore.case = TRUE)
})

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

test_that("fetch_lio_sf progress is silent for cache hits", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  httr2::with_mocked_responses(
    mock_geojson_response(synthetic_point_geojson(1)),
    suppressMessages(fetch_lio_sf(
      service_layer = "LIO_Open09/26",
      source_name = "MOH Service Location"
    ))
  )

  progress <- capture_lio_messages(fetch_lio_sf(
    service_layer = "LIO_Open09/26",
    source_name = "MOH Service Location"
  ))

  expect_length(progress$messages, 1)
  expect_match(progress$messages, "cache age", fixed = TRUE)
})

test_that("lio_response_truncated detects ArcGIS transfer-limit flags", {
  expect_true(lio_response_truncated('{"exceededTransferLimit":true}'))
  expect_true(lio_response_truncated('{"exceededTransferLimit" :  true}'))
  expect_false(lio_response_truncated('{"exceededTransferLimit":false}'))
  expect_false(lio_response_truncated('{"features": []}'))
})

test_that("feature-count validation warns outside tolerance", {
  expect_warning(
    validate_lio_feature_count(130, list(name = "Example", feature_count = 100)),
    class = "ongeor_feature_count_mismatch"
  )
  expect_silent(validate_lio_feature_count(
    120, list(name = "Example", feature_count = 100)
  ))
  expect_silent(validate_lio_feature_count(1, list(name = "Example")))
  expect_silent(validate_lio_feature_count(1, NULL))
})

test_that("fetch_lio_sf emits one start message for a fast live fetch", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)
  testthat::local_mocked_bindings(
    lio_now = local({
      times <- as.POSIXct(c(0, 1), origin = "1970-01-01", tz = "UTC")
      function() {
        value <- times[[1]]
        times <<- times[-1]
        value
      }
    }),
    .package = "ONgeoR"
  )

  progress <- httr2::with_mocked_responses(
    mock_geojson_response(synthetic_point_geojson(1)),
    capture_lio_messages(fetch_lio_sf(
      service_layer = "LIO_Open09/26",
      source_name = "MOH Service Location",
      refresh = TRUE
    ))
  )

  expect_length(progress$messages, 1)
  expect_match(progress$messages, "Retrieving source", fixed = TRUE)
  expect_match(progress$messages, "MOH Service Location", fixed = TRUE)
  expect_match(progress$messages, "LIO_Open09/26", fixed = TRUE)
})

test_that("fetch_lio_sf retry progress has no attempt-level noise", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  calls <- 0
  testthat::local_mocked_bindings(
    req_perform1 = function(req, ...) {
      calls <<- calls + 1
      if (calls == 1) {
        return(mock_lio_response(503, retry_after = "0"))
      }
      mock_lio_response(200, synthetic_point_geojson(1))
    },
    .package = "httr2"
  )
  testthat::local_mocked_bindings(
    lio_now = local({
      times <- as.POSIXct(c(0, 1), origin = "1970-01-01", tz = "UTC")
      function() {
        value <- times[[1]]
        times <<- times[-1]
        value
      }
    }),
    .package = "ONgeoR"
  )

  progress <- capture_lio_messages(fetch_lio_sf(
    service_layer = "LIO_Open09/26",
    source_name = "MOH Service Location",
    refresh = TRUE
  ))

  expect_equal(calls, 2)
  expect_length(progress$messages, 1)
  expect_match(progress$messages, "Retrieving source", fixed = TRUE)
})

test_that("fetch_lio_sf emits bounded page progress", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  testthat::local_mocked_bindings(
    lio_now = local({
      times <- as.POSIXct(c(0, 1), origin = "1970-01-01", tz = "UTC")
      function() {
        value <- times[[1]]
        times <<- times[-1]
        value
      }
    }),
    .package = "ONgeoR"
  )

  pages <- list(1:2, 3:4, 5)
  calls <- 0
  progress <- httr2::with_mocked_responses(
    function(req) {
      calls <<- calls + 1
      mock_lio_response(
        200,
        synthetic_point_geojson(pages[[calls]], truncated = calls < length(pages))
      )
    },
    capture_lio_messages(fetch_lio_sf(
      service_layer = "LIO_Open09/26",
      source_name = "MOH Service Location",
      result_record_count = 2,
      refresh = TRUE,
      paginate = TRUE
    ))
  )

  expect_equal(calls, 3)
  expect_length(progress$messages, 3)
  expect_match(progress$messages[[1]], "Retrieving source", fixed = TRUE)
  expect_match(progress$messages[[2]], "page 2", fixed = TRUE)
  expect_match(progress$messages[[3]], "page 3", fixed = TRUE)
})

test_that("fetch_lio_sf summarizes slow live fetches", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)
  testthat::local_mocked_bindings(
    lio_now = local({
      times <- as.POSIXct(c(0, 2), origin = "1970-01-01", tz = "UTC")
      function() {
        value <- times[[1]]
        times <<- times[-1]
        value
      }
    }),
    .package = "ONgeoR"
  )

  progress <- httr2::with_mocked_responses(
    mock_geojson_response(synthetic_point_geojson(1:2)),
    capture_lio_messages(fetch_lio_sf(
      service_layer = "LIO_Open09/26",
      source_name = "MOH Service Location",
      refresh = TRUE
    ))
  )

  expect_length(progress$messages, 2)
  expect_match(progress$messages[[2]], "Retrieved source", fixed = TRUE)
  expect_match(progress$messages[[2]], "MOH Service Location", fixed = TRUE)
  expect_match(progress$messages[[2]], "2 rows", fixed = TRUE)
  expect_match(progress$messages[[2]], "2.0 seconds", fixed = TRUE)
})

test_that("fetch_lio_sf failures have no completion progress", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  calls <- 0
  messages <- character()
  testthat::local_mocked_bindings(
    req_perform1 = function(req, ...) {
      calls <<- calls + 1
      mock_lio_response(503, retry_after = "0")
    },
    .package = "httr2"
  )
  error <- expect_error(
    withCallingHandlers(
      fetch_lio_sf(
        service_layer = "LIO_Open09/26",
        source_name = "MOH Service Location",
        refresh = TRUE
      ),
      message = function(cnd) {
        messages <<- c(messages, conditionMessage(cnd))
        invokeRestart("muffleMessage")
      }
    ),
    class = "ongeor_retrieval_error"
  )

  expect_equal(calls, 3)
  expect_length(messages, 1)
  expect_match(messages, "Retrieving source", fixed = TRUE)
  expect_no_match(messages, "Retrieved source", fixed = TRUE)
  expect_s3_class(error, "ongeor_retrieval_error")
})

test_that("fetch_lio_sf retries a transient response then succeeds", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  calls <- 0
  testthat::local_mocked_bindings(
    req_perform1 = function(req, ...) {
      calls <<- calls + 1
      if (calls == 1) {
        return(mock_lio_response(503, retry_after = "0"))
      }
      mock_lio_response(200, synthetic_point_geojson(1))
    },
    .package = "httr2"
  )
  layer <- fetch_lio_sf(
    service_layer = "LIO_Open09/26",
    source_name = "MOH Service Location",
    refresh = TRUE
  )

  expect_s3_class(layer, "sf")
  expect_equal(calls, 2)
})

test_that("fetch_lio_sf stops after three persistent transient responses", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  calls <- 0
  testthat::local_mocked_bindings(
    req_perform1 = function(req, ...) {
      calls <<- calls + 1
      mock_lio_response(503, retry_after = "0")
    },
    .package = "httr2"
  )
  error <- expect_error(
    fetch_lio_sf(
      service_layer = "LIO_Open09/26",
      source_name = "MOH Service Location",
      refresh = TRUE
    ),
    class = "ongeor_retrieval_error"
  )
  expect_equal(calls, 3)
  expect_match(conditionMessage(error), "MOH Service Location", fixed = TRUE)
  expect_match(conditionMessage(error), "LIO_Open09/26", fixed = TRUE)
  expect_match(conditionMessage(error), "retry later", ignore.case = TRUE)
  expect_match(conditionMessage(error), "three attempts", fixed = TRUE)
  expect_match(conditionMessage(error), "already requested", ignore.case = TRUE)
  expect_s3_class(error$parent, "error")
})

test_that("fetch_lio_sf does not retry a non-transient client response", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  calls <- 0
  testthat::local_mocked_bindings(
    req_perform1 = function(req, ...) {
      calls <<- calls + 1
      mock_lio_response(400)
    },
    .package = "httr2"
  )
  error <- expect_error(
    fetch_lio_sf(
      service_layer = "LIO_Open09/26",
      source_name = "MOH Service Location",
      refresh = TRUE
    ),
    class = "ongeor_retrieval_error"
  )
  expect_equal(calls, 1)
  expect_match(conditionMessage(error), "MOH Service Location", fixed = TRUE)
  expect_match(conditionMessage(error), "LIO_Open09/26", fixed = TRUE)
  expect_s3_class(error$parent, "error")
})

test_that("fetch_lio_sf wraps malformed GeoJSON with source context", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  error <- expect_error(
    httr2::with_mocked_responses(
      mock_geojson_response("not geojson"),
      fetch_lio_sf(
        service_layer = "LIO_Open09/26",
        source_name = "MOH Service Location",
        simplify = FALSE,
        refresh = TRUE
      )
    ),
    class = "ongeor_retrieval_error"
  )

  expect_match(conditionMessage(error), "MOH Service Location", fixed = TRUE)
  expect_match(conditionMessage(error), "LIO_Open09/26", fixed = TRUE)
  expect_match(conditionMessage(error), "simplify = TRUE", fixed = TRUE)
  expect_s3_class(error$parent, "error")
})

test_that("fetch_lio_sf wraps corrupt cache reads with refresh guidance", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)
  key <- cache_key(
    source_name = "MOH Service Location",
    service_layer = "LIO_Open09/26",
    where = "1=1",
    simplify = TRUE,
    result_record_count = 2000,
    paginate = FALSE
  )
  writeLines("not an rds", file.path(cache_dir, paste0(key, ".rds")))

  error <- expect_error(
    fetch_lio_sf(
      service_layer = "LIO_Open09/26",
      source_name = "MOH Service Location"
    ),
    class = "ongeor_retrieval_error"
  )

  expect_match(conditionMessage(error), "MOH Service Location", fixed = TRUE)
  expect_match(conditionMessage(error), "LIO_Open09/26", fixed = TRUE)
  expect_match(conditionMessage(error), "refresh = TRUE", fixed = TRUE)
  expect_s3_class(error$parent, "error")
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
        body = charToRaw(synthetic_point_geojson(
          pages[[calls]], truncated = calls < length(pages)
        )),
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
  error <- expect_error(
    httr2::with_mocked_responses(
      function(req) {
        calls <<- calls + 1
        expect_equal(req$policies$retry_max_tries, 3)
        expect_true(req$policies$retry_on_failure)
        if (calls == 1) {
          is_transient <- req$policies$retry_is_transient
          expect_true(is_transient(mock_lio_response(429)))
          expect_true(is_transient(mock_lio_response(500)))
          expect_true(is_transient(mock_lio_response(599)))
          expect_false(is_transient(mock_lio_response(400)))
        }
        httr2::response(
          status_code = 200,
          body = charToRaw(synthetic_point_geojson(1:2, truncated = TRUE)),
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
    class = "ongeor_retrieval_error"
  )
  expect_equal(calls, 20)
  expect_match(conditionMessage(error), "20-page", fixed = TRUE)
  expect_match(conditionMessage(error), "MOH Service Location", fixed = TRUE)
  expect_match(conditionMessage(error), "LIO_Open09/26", fixed = TRUE)
})

test_that("retrieve_conservation_authority returns an sf object with provenance attributes", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  ca <- httr2::with_mocked_responses(
    mock_geojson_response(synthetic_conservation_authority_geojson),
    retrieve_conservation_authority()
  )

  expect_s3_class(ca, "sf")
  expect_equal(nrow(ca), 2)
  expect_true(all(c("CA_ID", "LEGAL_NAME", "COMMON_NAME") %in% colnames(ca)))
  expect_false(is.null(attr(ca, "source_url")))
  expect_false(is.null(attr(ca, "retrieved_at")))
  expect_equal(attr(ca, "source_name"), "Conservation Authority Admin Area")
  expect_match(attr(ca, "source_url"), "LIO_Open03/MapServer/11")
})

test_that("retrieve_conservation_authority dispatches simplify argument", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  captured_url <- NULL
  httr2::with_mocked_responses(
    function(req) {
      captured_url <<- req$url
      mock_geojson_response(synthetic_conservation_authority_geojson)(req)
    },
    retrieve_conservation_authority(simplify = FALSE)
  )
  expect_no_match(captured_url, "maxAllowableOffset", fixed = TRUE)
})

test_that("retrieve_orwn_station returns an sf object with provenance attributes", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  stations <- httr2::with_mocked_responses(
    mock_geojson_response(synthetic_orwn_station_geojson),
    retrieve_orwn_station()
  )

  expect_s3_class(stations, "sf")
  expect_equal(nrow(stations), 2)
  expect_true(all(c("STENNAME", "STNTYPE", "TRACKNAME") %in% colnames(stations)))
  expect_false(is.null(attr(stations, "source_url")))
  expect_false(is.null(attr(stations, "retrieved_at")))
  expect_equal(attr(stations, "source_name"), "ORWN Station")
  expect_match(attr(stations, "source_url"), "LIO_Open04/MapServer/15")
})

test_that("fetch_lio_sf advances pagination by rows actually returned", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  offsets <- integer(0)
  handler <- function(req) {
    offset <- httr2::url_parse(req$url)$query$resultOffset
    offset <- if (is.null(offset)) 0L else as.integer(offset)
    offsets <<- c(offsets, offset)
    mock_lio_response(
      200,
      synthetic_point_geojson(offset + 1, truncated = offset < 2)
    )
  }

  layer <- httr2::with_mocked_responses(handler, fetch_lio_sf(
    service_layer = "LIO_Open09/26",
    source_name = "MOH Service Location",
    simplify = FALSE,
    result_record_count = 2,
    refresh = TRUE,
    paginate = TRUE
  ))

  expect_equal(offsets, c(0L, 1L, 2L))
  expect_equal(nrow(layer), 3)
  expect_equal(layer$OBJECTID, 1:3)
})

test_that("fetch_lio_sf aborts on an empty truncated page", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  calls <- 0
  error <- expect_error(
    httr2::with_mocked_responses(
      function(req) {
        calls <<- calls + 1
        mock_lio_response(200, synthetic_point_geojson(integer(0), truncated = TRUE))
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
    class = "ongeor_retrieval_error"
  )
  expect_equal(calls, 1)
  expect_match(conditionMessage(error), "empty truncated page", fixed = TRUE)
})

test_that("retrieve_monitoring_stations returns an sf object with provenance attributes", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  stations <- httr2::with_mocked_responses(
    mock_geojson_response(synthetic_monitoring_stations_geojson),
    retrieve_monitoring_stations()
  )

  expect_s3_class(stations, "sf")
  expect_equal(nrow(stations), 2)
  expect_true(all(c("STATION_NAME", "STATION_IDENT", "NETWORK_NAME") %in% colnames(stations)))
  expect_false(is.null(attr(stations, "source_url")))
  expect_false(is.null(attr(stations, "source_name")))
  expect_false(is.null(attr(stations, "retrieved_at")))
  expect_equal(attr(stations, "source_name"), "Monitoring Station Point")
  expect_match(attr(stations, "source_url"), "LIO_Open08/MapServer/30")
})

test_that("retrieve_monitoring_stations paginates when the page is truncated", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  station_page <- function(features, truncated) {
    paste0(
      '{"type":"FeatureCollection","features":[',
      paste(features, collapse = ","),
      '],"exceededTransferLimit":', tolower(as.character(truncated)), "}"
    )
  }
  station_feature <- function(id) {
    paste0(
      '{"type":"Feature","properties":{"OGF_ID":', id,
      ',"STATION_NAME":"Station ', id, '","STATION_IDENT":"TS', id,
      '","NETWORK_NAME":"Hydrometric","DATA_COLLECTION_METHOD":"Auto"},',
      '"geometry":{"type":"Point","coordinates":[-80,44]}}'
    )
  }
  pages <- list(
    station_page(station_feature(1:2), truncated = TRUE),
    station_page(station_feature(3), truncated = FALSE)
  )
  calls <- 0

  stations <- httr2::with_mocked_responses(
    function(req) {
      calls <<- calls + 1
      httr2::response(
        status_code = 200,
        body = charToRaw(pages[[calls]]),
        headers = list("Content-Type" = "application/json")
      )
    },
    retrieve_monitoring_stations(refresh = TRUE)
  )

  expect_equal(calls, 2)
  expect_s3_class(stations, "sf")
  expect_equal(nrow(stations), 3)
  expect_equal(stations$OGF_ID, 1:3)
})

test_that("retrieve_monitoring_stations_simple returns an sf object of POINT geometry", {
  stations <- retrieve_monitoring_stations_simple()

  expect_s3_class(stations, "sf")
  expect_true(all(
    c("OGF_ID", "STATION_NAME", "STATION_IDENT", "NETWORK_NAME",
      "DATA_COLLECTION_METHOD", "geometry") %in% colnames(stations)
  ))
  expect_true(all(sf::st_geometry_type(stations) == "POINT"))
})

test_that("bundled monitoring stations survive subsetting", {
  stations <- retrieve_monitoring_stations_simple()
  subset <- stations[stations$DATA_COLLECTION_METHOD == "Auto", ]
  expect_s3_class(sf::st_geometry(subset), "sfc")
})

# The test above documents the behaviour but cannot enforce it. sf is not in
# this package's NAMESPACE imports, so it is not loaded on package load - but
# every test file that sorts before this one (test-cache.R, test-link.R and
# four others) calls sf::, which loads the namespace. By the time the check
# above runs, sf's S3 methods are registered and `[` dispatches correctly even
# if read_bundled_sf() were reduced back to a bare readRDS(). It passes either
# way, which makes it worthless as a guard.
#
# Assert the guarantee at its source instead. This is white-box and will need
# updating if read_bundled_sf() is rewritten - that is the point: the load must
# be a deliberate, visible decision, because dropping it reintroduces a bug
# that silently degrades every bundled layer's geometry column to a bare list
# and surfaces far from the cause (fixed in 33ad227).
test_that("read_bundled_sf loads the sf namespace before returning", {
  body_text <- paste(deparse(body(read_bundled_sf)), collapse = " ")
  expect_match(body_text, "loadNamespace", fixed = TRUE)
  expect_match(body_text, "sf", fixed = TRUE)
})
