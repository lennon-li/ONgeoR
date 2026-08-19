postal_fixture <- function() {
  path <- testthat::test_path("fixtures", "opcc_m5_sample.csv.gz")
  tibble::as_tibble(utils::read.csv(
    gzfile(path), stringsAsFactors = FALSE, check.names = FALSE
  ))
}

postal_fixture_raw <- function() {
  path <- testthat::test_path("fixtures", "opcc_m5_sample.csv.gz")
  readBin(path, "raw", n = file.info(path)$size)
}

use_postal_temp_cache <- function() {
  cache_dir <- tempfile("ongeor-postal-cache-")
  dir.create(cache_dir, recursive = TRUE)
  testthat::local_mocked_bindings(
    ongeor_cache_dir = function() cache_dir,
    .package = "ONgeoR",
    .env = parent.frame()
  )
  cache_dir
}

seed_postal_cache <- function() {
  fixture <- postal_fixture()
  correspondence <- tibble::tibble(
    postal_code = fixture$postal_code,
    DAUID = as.character(fixture$DAUID),
    allocation_weight = as.numeric(fixture$allocation_weight),
    n_contributing_dbs = as.integer(fixture$n_contributing_dbs),
    census_vintage = as.character(fixture$census_vintages),
    best_link = as.logical(fixture$best_link)
  )
  cache_write(
    opcc_m5_cache_key,
    correspondence,
    postal_cache_meta("2026-08-01 00:00:00 UTC")
  )
}

postal_points_fixture <- function() {
  path <- testthat::test_path("fixtures", "opcc_m1_sample.csv.gz")
  tibble::as_tibble(utils::read.csv(
    gzfile(path), stringsAsFactors = FALSE, check.names = FALSE
  ))
}

postal_points_fixture_raw <- function() {
  path <- testthat::test_path("fixtures", "opcc_m1_sample.csv.gz")
  readBin(path, "raw", n = file.info(path)$size)
}

seed_postal_points_cache <- function() {
  fixture <- postal_points_fixture()
  centroids <- tibble::tibble(
    postal_code = as.character(fixture$postal_code),
    latitude = as.numeric(fixture$latitude),
    longitude = as.numeric(fixture$longitude),
    point_source = as.character(fixture$point_source),
    point_method = as.character(fixture$point_method)
  )
  cache_write(
    opcc_m1_cache_key,
    centroids,
    opcc_m1_cache_meta("2026-08-01 00:00:00 UTC")
  )
}

test_that("resolve_postal returns the best link for a single-DA postal code", {
  cache_dir <- use_postal_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)
  seed_postal_cache()
  fixture <- postal_fixture()
  postal <- fixture$postal_code[fixture$postal_code != "K0A 1A0"][1L]

  result <- resolve_postal(postal)

  expect_s3_class(result, "tbl_df")
  expect_named(result, c(
    "postal_code", "DAUID", "allocation_weight", "n_contributing_dbs",
    "census_vintage", "source_url", "retrieved_at"
  ))
  expect_equal(nrow(result), 1L)
  expect_equal(result$postal_code, postal)
  expect_equal(result$source_url, opcc_m5_url)
})

test_that("resolve_postal returns best or all links for a multi-DA postal code", {
  cache_dir <- use_postal_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)
  seed_postal_cache()
  postal <- "K0A 1A0"

  best <- resolve_postal(postal)
  all <- resolve_postal(postal, all_links = TRUE)

  expect_equal(nrow(best), 1L)
  expect_equal(nrow(all), sum(postal_fixture()$postal_code == postal))
  expected <- postal_fixture()
  expected <- expected[expected$postal_code == postal & expected$best_link, ]
  expect_equal(best$DAUID, as.character(expected$DAUID))
})

test_that("resolve_postal normalizes spacing and case", {
  cache_dir <- use_postal_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)
  seed_postal_cache()

  postal <- postal_fixture()$postal_code[postal_fixture()$postal_code != "K0A 1A0"][1L]
  compact <- gsub(" ", "", postal, fixed = TRUE)
  result <- resolve_postal(c(tolower(compact), postal, compact))

  expect_equal(result$postal_code, rep(postal, 3L))
})

test_that("resolve_postal preserves order and duplicates and warns once", {
  cache_dir <- use_postal_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)
  seed_postal_cache()

  expect_warning(
    result <- resolve_postal(c("K0A 1A0", "ZZZ999", "K0A 1A0")),
    "resolve_postal\\(\\): no match found for: ZZZ 999"
  )

  expect_equal(result$postal_code, c("K0A 1A0", "ZZZ 999", "K0A 1A0"))
  expect_true(all(is.na(result$DAUID[result$postal_code == "ZZZ 999"])))
})

test_that("resolve_postal validates input and checksum", {
  expect_error(resolve_postal(1), "`x` must be a character vector")
  expect_error(
    opcc_m5_verify_checksum(charToRaw("not the artifact")),
    class = "ongeor_retrieval_error"
  )
})

test_that("resolve_postal parses a verified download once and caches it", {
  cache_dir <- use_postal_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)
  calls <- 0L
  testthat::local_mocked_bindings(
    opcc_m5_download_gzip = function() {
      calls <<- calls + 1L
      postal_fixture_raw()
    },
    opcc_m5_verify_checksum = function(raw) invisible(raw),
    .package = "ONgeoR"
  )

  resolve_postal("K0A 1A0")
  resolve_postal("K0A 1A0")

  expect_equal(calls, 1L)
  expect_equal(list_cache()$source_name, "OPCC M5 DA correspondence")
})

test_that("postal correspondence cache is listed and cleared", {
  cache_dir <- use_postal_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)
  seed_postal_cache()

  listed <- list_cache()
  expect_equal(listed$source_name, "OPCC M5 DA correspondence")
  expect_message(removed <- clear_cache(), "Removed 1 cached entry")
  expect_equal(removed, 2L)
  expect_equal(nrow(list_cache()), 0L)
})

test_that("render_postal_reproducer_script returns a runnable template", {
  script <- render_postal_reproducer_script(
    "records.csv", "postal", tempdir()
  )

  expect_type(script, "character")
  expect_length(script, 1L)
  expect_match(script, "input_file <- \"records.csv\"", fixed = TRUE)
  expect_match(script, "resolve_postal", fixed = TRUE)
  expect_match(script, "merge", fixed = TRUE)
  expect_true(all(charToRaw(script) < as.raw(128)))
})

test_that("normalize_postal_code produces the correspondence's own format", {
  expect_equal(
    normalize_postal_code(c("m5v3a8", "M5V 3A8", " m5v 3a8 ", "M5V3A8")),
    rep("M5V 3A8", 4L)
  )
})

test_that("the reproducer joins on a normalized key, not the raw column", {
  script <- render_postal_reproducer_script("records.csv", "postal", tempdir())

  expect_match(script, "normalize_postal_code(records[[postal_col]])", fixed = TRUE)
  expect_match(script, "by.x = \".postal_key\"", fixed = TRUE)
  expect_false(grepl("by.x = postal_col", script, fixed = TRUE))
})

test_that("render_postal_reproducer_script carries all_links through", {
  expect_match(
    render_postal_reproducer_script("records.csv", "postal", tempdir()),
    "all_links = TRUE", fixed = TRUE
  )
  expect_match(
    render_postal_reproducer_script(
      "records.csv", "postal", tempdir(), all_links = FALSE
    ),
    "all_links = FALSE", fixed = TRUE
  )
  expect_error(
    render_postal_reproducer_script(
      "records.csv", "postal", tempdir(), all_links = NA
    ),
    "single non-missing logical"
  )
})

test_that("resolve_postal_points returns nar_centroid coordinates", {
  cache_dir <- use_postal_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)
  seed_postal_points_cache()
  fixture <- postal_points_fixture()
  nar <- fixture[fixture$point_source == "nar_centroid", ][1L, ]

  result <- resolve_postal_points(nar$postal_code)

  expect_s3_class(result, "tbl_df")
  expect_named(result, c(
    "postal_code", "latitude", "longitude", "point_source", "point_method",
    "source_url", "retrieved_at"
  ))
  expect_equal(nrow(result), 1L)
  expect_equal(result$postal_code, nar$postal_code)
  expect_equal(result$latitude, nar$latitude)
  expect_equal(result$longitude, nar$longitude)
  expect_equal(result$point_source, "nar_centroid")
  expect_equal(result$source_url, opcc_m1_url)
})

test_that("resolve_postal_points reports geonames provenance", {
  cache_dir <- use_postal_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)
  seed_postal_points_cache()
  fixture <- postal_points_fixture()
  gn <- fixture[fixture$point_source == "geonames", ][1L, ]

  result <- resolve_postal_points(gn$postal_code)

  expect_equal(nrow(result), 1L)
  expect_equal(result$point_source, "geonames")
  expect_equal(result$latitude, gn$latitude)
  expect_equal(result$longitude, gn$longitude)
})

test_that("resolve_postal_points returns NA coordinates for none codes", {
  cache_dir <- use_postal_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)
  seed_postal_points_cache()
  fixture <- postal_points_fixture()
  none <- fixture[fixture$point_source == "none", ][1L, ]

  result <- resolve_postal_points(none$postal_code)

  expect_equal(nrow(result), 1L)
  expect_equal(result$postal_code, none$postal_code)
  expect_equal(result$point_source, "none")
  expect_true(is.na(result$latitude))
  expect_true(is.na(result$longitude))
})

test_that("resolve_postal_points warns once on unmatched codes", {
  cache_dir <- use_postal_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)
  seed_postal_points_cache()

  expect_warning(
    result <- resolve_postal_points("ZZZ999"),
    "resolve_postal_points\\(\\): no match found for: ZZZ 999"
  )

  expect_equal(nrow(result), 1L)
  expect_equal(result$postal_code, "ZZZ 999")
  expect_true(is.na(result$latitude))
  expect_true(is.na(result$longitude))
})

test_that("resolve_postal_points preserves order, length, and duplicates", {
  cache_dir <- use_postal_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)
  seed_postal_points_cache()
  fixture <- postal_points_fixture()
  nar <- fixture[fixture$point_source == "nar_centroid", ][1L, ]
  compact <- tolower(gsub(" ", "", nar$postal_code, fixed = TRUE))

  expect_warning(
    result <- resolve_postal_points(c(nar$postal_code, "ZZZ999", compact)),
    "no match found"
  )

  expect_length(result$postal_code, 3L)
  expect_equal(
    result$postal_code,
    c(nar$postal_code, "ZZZ 999", nar$postal_code)
  )
})

test_that("resolve_postal_points as_sf returns POINT sf in EPSG:4326", {
  cache_dir <- use_postal_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)
  seed_postal_points_cache()
  fixture <- postal_points_fixture()
  nar <- fixture[fixture$point_source == "nar_centroid", ][1L, ]
  none <- fixture[fixture$point_source == "none", ][1L, ]

  expect_warning(
    result <- resolve_postal_points(
      c(nar$postal_code, none$postal_code), as_sf = TRUE
    ),
    "dropped 1 row without coordinates"
  )

  expect_s3_class(result, "sf")
  expect_true(sf::st_crs(result) == sf::st_crs(4326))
  expect_true(all(sf::st_geometry_type(result) == "POINT"))
  expect_equal(nrow(result), 1L)
  expect_named(result, c(
    "postal_code", "point_source", "point_method", "source_url",
    "retrieved_at", "geometry"
  ))
  coords <- sf::st_coordinates(result)[1L, ]
  expect_equal(unname(coords[["X"]]), nar$longitude)
  expect_equal(unname(coords[["Y"]]), nar$latitude)
})

test_that("resolve_postal_points validates input and checksum", {
  expect_error(resolve_postal_points(1), "`x` must be a character vector")
  expect_error(
    resolve_postal_points("M5V 3A8", as_sf = NA),
    "single non-missing logical"
  )
  expect_error(
    opcc_m1_verify_checksum(charToRaw("not the artifact")),
    class = "ongeor_retrieval_error"
  )
})

test_that("resolve_postal_points parses a verified download and caches it", {
  cache_dir <- use_postal_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)
  calls <- 0L
  testthat::local_mocked_bindings(
    opcc_m1_download_gzip = function() {
      calls <<- calls + 1L
      postal_points_fixture_raw()
    },
    opcc_m1_verify_checksum = function(raw) invisible(raw),
    .package = "ONgeoR"
  )
  fixture <- postal_points_fixture()
  none <- fixture[fixture$point_source == "none", ][1L, ]

  result <- resolve_postal_points(none$postal_code)

  expect_equal(calls, 1L)
  expect_equal(result$point_source, "none")
  expect_true(is.na(result$latitude))
  expect_true(is.na(result$longitude))

  resolve_postal_points(none$postal_code)
  expect_equal(calls, 1L)
  expect_true("OPCC M1 postal centroids" %in% list_cache()$source_name)
})

postal_points_layer_stub <- function() {
  list(
    data = tibble::tibble(
      postal_code = c("M5V 3A8", "M5V 3A9", "K1A 0B1", "P0T 1A0"),
      latitude = c(43.6426, 43.6440, 45.4215, NA_real_),
      longitude = c(-79.3871, -79.3900, -75.6972, NA_real_),
      point_source = c("nar_centroid", "geonames", "nar_centroid", "none"),
      point_method = c(
        "nar_reppoint", "geonames_direct_wgs84", "nar_reppoint", "none"
      )
    ),
    meta = opcc_m1_cache_meta("2026-08-01 00:00:00 UTC")
  )
}

mock_postal_points_layer <- function(env = parent.frame()) {
  testthat::local_mocked_bindings(
    opcc_m1_centroids = postal_points_layer_stub,
    .package = "ONgeoR",
    .env = env
  )
}

test_that("retrieve_postal_points returns a POINT layer in EPSG:4326", {
  mock_postal_points_layer()

  result <- retrieve_postal_points()

  expect_s3_class(result, "sf")
  expect_true(sf::st_crs(result) == sf::st_crs(4326))
  expect_true(all(sf::st_geometry_type(result) == "POINT"))
  expect_named(
    result,
    c("postal_code", "point_source", "point_method", "geometry")
  )
})

test_that("retrieve_postal_points drops codes without coordinates silently", {
  mock_postal_points_layer()

  expect_no_warning(result <- retrieve_postal_points())

  expect_equal(nrow(result), 3L)
  expect_false("P0T 1A0" %in% result$postal_code)
  expect_false("none" %in% result$point_source)
})

test_that("retrieve_postal_points filters to a bbox", {
  mock_postal_points_layer()

  toronto <- retrieve_postal_points(
    bbox = c(xmin = -79.5, ymin = 43.6, xmax = -79.3, ymax = 43.7)
  )

  expect_equal(nrow(toronto), 2L)
  expect_equal(toronto$postal_code, c("M5V 3A8", "M5V 3A9"))
  expect_false("K1A 0B1" %in% toronto$postal_code)

  empty <- retrieve_postal_points(
    bbox = c(xmin = -60, ymin = 40, xmax = -59, ymax = 41)
  )

  expect_s3_class(empty, "sf")
  expect_equal(nrow(empty), 0L)
  expect_true(sf::st_crs(empty) == sf::st_crs(4326))
})

test_that("retrieve_postal_points rejects a bbox the way retrieve_census does", {
  mock_postal_points_layer()
  message <- paste0(
    "`bbox` must be an sf bbox or numeric xmin, ymin, xmax, ymax in ",
    "EPSG:4326."
  )

  expect_error(
    retrieve_postal_points(bbox = c(-79.5, 43.6, -79.3)),
    message,
    fixed = TRUE
  )
  expect_error(
    retrieve_postal_points(bbox = c(-79.3, 43.6, -79.5, 43.7)),
    message,
    fixed = TRUE
  )
  expect_error(
    retrieve_census("census_cd_2021", bbox = c(-79.5, 43.6, -79.3)),
    message,
    fixed = TRUE
  )
  expect_error(
    retrieve_postal_points(refresh = NA),
    "single non-missing logical"
  )
})

test_that("retrieve_postal_points attaches provenance attributes", {
  mock_postal_points_layer()

  result <- retrieve_postal_points()

  expect_equal(
    attr(result, "source_name"),
    "Ontario postal code points (OPCC M1 centroids)"
  )
  expect_equal(attr(result, "source_url"), opcc_m1_url)
  expect_equal(attr(result, "retrieved_at"), "2026-08-01 00:00:00 UTC")
})

test_that("retrieve_postal_points refresh discards the cached release", {
  cache_dir <- use_postal_temp_cache()
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)
  seed_postal_points_cache()
  cached <- file.path(cache_dir, paste0(opcc_m1_cache_key, ".rds"))
  expect_true(file.exists(cached))
  mock_postal_points_layer()

  retrieve_postal_points(refresh = TRUE)

  expect_false(file.exists(cached))
})

test_that("retrieve_source dispatches postal_points to the new layer", {
  mock_postal_points_layer()

  result <- retrieve_source("postal_points")

  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 3L)
  expect_equal(
    source_retrieve_call("postal_points"),
    "retrieve_postal_points()"
  )
})

test_that("the registry advertises postal_points as a facility layer", {
  entry <- get_source("postal_points")

  expect_equal(entry$geography_type, "facility")
  expect_equal(entry$key_fields, "postal_code")
  expect_equal(entry$source_url, opcc_m1_url)
  expect_equal(entry$feature_count, 299782L)

  sources <- list_sources()
  row <- sources[sources$source_id == "postal_points", ]
  expect_equal(nrow(row), 1L)
  expect_equal(unname(row$geography_type), "facility")
})
