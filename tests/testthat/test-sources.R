test_that("the PHU registry advertises current and pre-2025 boundaries", {
  sources <- list_sources()
  pre2025_row <- sources[sources$source_id == "phu_boundaries_pre2025", ]
  current_row <- sources[sources$source_id == "phu_boundaries", ]

  expect_equal(nrow(pre2025_row), 1L)
  expect_equal(unname(pre2025_row$geography_type), "boundary")
  expect_equal(unname(current_row$feature_count), 29L)
})

test_that("registry_cache_get skips the loader while the file's mtime is unchanged", {
  path <- withr::local_tempfile(lines = "v1")
  cache_env <- new.env(parent = emptyenv())
  n_calls <- 0
  loader <- function() {
    n_calls <<- n_calls + 1
    "loaded"
  }

  first <- registry_cache_get(path, loader, cache_env)
  second <- registry_cache_get(path, loader, cache_env)

  expect_equal(n_calls, 1)
  expect_identical(first, "loaded")
  expect_identical(second, "loaded")
})

test_that("registry_cache_get re-runs the loader after the file's mtime changes", {
  path <- withr::local_tempfile(lines = "v1")
  cache_env <- new.env(parent = emptyenv())
  n_calls <- 0
  loader <- function() {
    n_calls <<- n_calls + 1
    paste0("loaded-", n_calls)
  }

  first <- registry_cache_get(path, loader, cache_env)

  # Force a distinct mtime: some filesystems have 1-second resolution, so
  # advancing the clock forward is more reliable than relying on wall-clock
  # elapsed time between the two writes.
  writeLines("v2", path)
  Sys.setFileTime(path, Sys.time() + 5)

  second <- registry_cache_get(path, loader, cache_env)

  expect_equal(n_calls, 2)
  expect_identical(first, "loaded-1")
  expect_identical(second, "loaded-2")
})

test_that("load_source_registry returns the real registry unmemoized across a fresh cache", {
  registry <- load_source_registry()

  expect_true("monitoring_stations_bundled" %in% names(registry))
  expect_false("monitoring_stations_simple" %in% names(registry))
})
