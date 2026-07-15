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

  expect_length(progress$messages, 0)
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
      mock_lio_response(200, synthetic_point_geojson(pages[[calls]]))
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
    class = "ongeor_retrieval_error"
  )
  expect_equal(calls, 20)
  expect_match(conditionMessage(error), "20-page", fixed = TRUE)
  expect_match(conditionMessage(error), "MOH Service Location", fixed = TRUE)
  expect_match(conditionMessage(error), "LIO_Open09/26", fixed = TRUE)
})
