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
