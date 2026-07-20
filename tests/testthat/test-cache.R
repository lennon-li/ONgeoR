make_cache_layer <- function(source_name = "MOH Public Health Unit Boundary") {
  poly <- sf::st_polygon(list(rbind(
    c(-80, 44), c(-79, 44), c(-79, 43), c(-80, 43), c(-80, 44)
  )))
  layer <- sf::st_sf(
    PHU_ID = 1,
    PHU_NAME_ENG = "Test Health Unit A",
    geometry = sf::st_sfc(poly, crs = 4326)
  )
  attr(layer, "source_url") <- "https://example.com/phu"
  attr(layer, "source_name") <- source_name
  attr(layer, "retrieved_at") <- as.POSIXct("2026-07-08 00:00:00", tz = "UTC")
  layer
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

test_that("cache_key is deterministic for identical inputs", {
  key_one <- cache_key(
    source_name = "MOH Public Health Unit Boundary",
    service_layer = "LIO_Open09/44",
    where = "1=1",
    simplify = FALSE,
    result_record_count = 2000
  )
  key_two <- cache_key(
    source_name = "MOH Public Health Unit Boundary",
    service_layer = "LIO_Open09/44",
    where = "1=1",
    simplify = FALSE,
    result_record_count = 2000
  )

  expect_identical(key_one, key_two)
  expect_match(key_one, "^moh-public-health-unit-boundary__[[:alnum:]]{8}$")
})

test_that("cache_key changes when effective query inputs change", {
  base_key <- cache_key(
    source_name = "MOH Public Health Unit Boundary",
    service_layer = "LIO_Open09/44",
    where = "1=1",
    simplify = FALSE,
    result_record_count = 2000
  )

  expect_false(identical(base_key, cache_key(
    source_name = "MOH Public Health Unit Boundary",
    service_layer = "LIO_Open09/44",
    where = "PHU_ID = 1",
    simplify = FALSE,
    result_record_count = 2000
  )))
  expect_false(identical(base_key, cache_key(
    source_name = "MOH Public Health Unit Boundary",
    service_layer = "LIO_Open09/44",
    where = "1=1",
    simplify = TRUE,
    result_record_count = 2000
  )))
  expect_false(identical(base_key, cache_key(
    source_name = "MOH Public Health Unit Boundary",
    service_layer = "LIO_Open09/44",
    where = "1=1",
    simplify = FALSE,
    result_record_count = 1000
  )))
  expect_false(identical(base_key, cache_key(
    source_name = "MOH Public Health Unit Boundary",
    service_layer = "LIO_Open09/44",
    where = "1=1",
    simplify = FALSE,
    result_record_count = 2000,
    paginate = TRUE
  )))
})

test_that("cache_write and cache_read round-trip an sf object", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  layer <- make_cache_layer()
  key <- "phu__abc12345"
  meta <- list(
    source_name = "MOH Public Health Unit Boundary",
    source_url = "https://example.com/phu",
    where = "1=1",
    simplify = FALSE,
    retrieved_at = "2026-07-08 00:00:00 UTC"
  )

  cache_write(key, layer, meta)
  result <- cache_read(key)

  expect_s3_class(result, "sf")
  expect_equal(sf::st_drop_geometry(result), sf::st_drop_geometry(layer))
  expect_true(sf::st_equals(result, layer, sparse = FALSE)[1, 1])
  expect_equal(attr(result, "source_url"), "https://example.com/phu")
  expect_equal(attr(result, "source_name"), "MOH Public Health Unit Boundary")
  expect_equal(
    attr(result, "retrieved_at"),
    as.POSIXct("2026-07-08 00:00:00", tz = "UTC")
  )
})

test_that("cache_read returns NULL for a missing key", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  expect_null(cache_read("never-written"))
})

test_that("clear_cache removes all cached files when source_id is NULL", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  layer <- make_cache_layer()
  meta <- list(
    source_name = "MOH Public Health Unit Boundary",
    source_url = "https://example.com/phu",
    where = "1=1",
    simplify = FALSE,
    retrieved_at = "2026-07-08 00:00:00 UTC"
  )
  cache_write("phu__abc12345", layer, meta)
  cache_write("phu__def67890", layer, meta)

  expect_message(removed <- clear_cache(), "Removed 2 cached entries")
  expect_equal(removed, 4)
  expect_equal(list.files(cache_dir), character())
})

test_that("clear_cache returns zero for an empty cache", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  expect_message(removed <- clear_cache(), "Removed 0 cached entries")
  expect_equal(removed, 0)
})

test_that("clear_cache removes only entries matching a source id", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  phu <- make_cache_layer("MOH Public Health Unit Boundary")
  health_region <- make_cache_layer("Ontario Health Region")
  cache_write("phu__abc12345", phu, list(
    source_name = "MOH Public Health Unit Boundary",
    source_url = "https://example.com/phu",
    where = "1=1",
    simplify = FALSE,
    retrieved_at = "2026-07-08 00:00:00 UTC"
  ))
  cache_write("health__abc12345", health_region, list(
    source_name = "Ontario Health Region",
    source_url = "https://example.com/health",
    where = "1=1",
    simplify = TRUE,
    retrieved_at = "2026-07-08 00:00:01 UTC"
  ))

  expect_message(
    removed <- clear_cache("phu_boundaries"),
    "Removed 1 cached entry"
  )

  expect_equal(removed, 2)
  expect_false(file.exists(file.path(cache_dir, "phu__abc12345.rds")))
  expect_false(file.exists(file.path(cache_dir, "phu__abc12345.yaml")))
  expect_true(file.exists(file.path(cache_dir, "health__abc12345.rds")))
  expect_true(file.exists(file.path(cache_dir, "health__abc12345.yaml")))
})

test_that("list_cache reports cached entries and handles an empty cache", {
  cache_dir <- use_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  empty <- list_cache()
  expect_s3_class(empty, "tbl_df")
  expect_named(empty, c("source_name", "retrieved_at", "age_days", "file_size_kb"))
  expect_equal(nrow(empty), 0)

  layer <- make_cache_layer()
  cache_write("phu__abc12345", layer, list(
    source_name = "MOH Public Health Unit Boundary",
    source_url = "https://example.com/phu",
    where = "1=1",
    simplify = FALSE,
    retrieved_at = "2026-07-08 00:00:00 UTC"
  ))
  cache_write("health__abc12345", layer, list(
    source_name = "Ontario Health Region",
    source_url = "https://example.com/health",
    where = "1=1",
    simplify = TRUE,
    retrieved_at = "2026-07-08 00:00:01 UTC"
  ))

  listed <- list_cache()

  expect_s3_class(listed, "tbl_df")
  expect_named(listed, c("source_name", "retrieved_at", "age_days", "file_size_kb"))
  expect_equal(nrow(listed), 2)
  expect_setequal(
    listed$source_name,
    c("MOH Public Health Unit Boundary", "Ontario Health Region")
  )
  expect_true(all(listed$file_size_kb > 0))
})

test_that("cache ages parse retrieved_at and unknown values as NA", {
  now <- as.POSIXct("2026-07-18 00:00:00", tz = "UTC")
  expect_lt(cache_age_days(
    list(retrieved_at = "2026-07-17 12:00:00 UTC"), now
  ), 1)
  expect_true(is.na(cache_age_days(list(), now)))
  expect_true(is.na(cache_age_days(list(retrieved_at = "not a date"), now)))
})

test_that("cache staleness decision handles age and unknown metadata", {
  expect_false(cache_is_stale(2, NULL))
  expect_false(cache_is_stale(2, 3))
  expect_true(cache_is_stale(4, 3))
  expect_true(cache_is_stale(NA_real_, 3))
})

test_that("cache timestamps round-trip timezone-safely", {
  withr::local_timezone("America/Toronto")

  meta <- list(retrieved_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"))
  expect_lt(abs(cache_age_days(meta)), 0.001)

  expect_equal(
    cache_age_days(
      list(retrieved_at = format(as.POSIXct("2026-07-08 00:00:00", tz = "UTC"), "%Y-%m-%d %H:%M:%S %Z", tz = "UTC")),
      now = as.POSIXct("2026-07-09 00:00:00", tz = "UTC")
    ),
    1
  )
})
