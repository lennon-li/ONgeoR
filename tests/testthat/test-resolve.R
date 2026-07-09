make_synthetic_airports <- function() {
  poly <- function(x) sf::st_polygon(list(rbind(
    c(x, 44), c(x + 1, 44), c(x + 1, 43), c(x, 43), c(x, 44)
  )))
  # OGF_ID first, mirroring real LIO layers: the domain identifier is
  # AIRPORT_IDENT, not the generic OGF_ID. This shape guards against
  # guess_id_col() picking OGF_ID instead of AIRPORT_IDENT.
  airports <- sf::st_sf(
    OGF_ID = c(1001, 1002, 1003),
    AIRPORT_IDENT = c("CYYZ", "CYTZ", "CYHM"),
    NAME = c("Toronto Pearson", "Billy Bishop Toronto City", "Hamilton"),
    POSTAL_CODE = c("L5P", "M5V", "L0R"),
    geometry = sf::st_sfc(poly(-80), poly(-82), poly(-84), crs = 4326)
  )
  attr(airports, "source_url") <- "https://example.com/airports"
  attr(airports, "retrieved_at") <- as.POSIXct("2026-07-08 00:00:00", tz = "UTC")
  airports
}

test_that("resolve auto-detects the *_IDENT column over the generic OGF_ID", {
  airports <- make_synthetic_airports()

  result <- resolve(airports, "CYYZ")

  expect_equal(nrow(result), 1)
  expect_equal(result$AIRPORT_IDENT, "CYYZ")
})

test_that("resolve matches the ident column exactly, ignoring case, by default", {
  airports <- make_synthetic_airports()

  result <- resolve(airports, "cyyz")

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_equal(result$query, "cyyz")
  expect_equal(result$AIRPORT_IDENT, "CYYZ")
  expect_equal(result$source_url, "https://example.com/airports")
  expect_false(is.null(result$retrieved_at))
})

test_that("resolve matches the name column by case-insensitive substring", {
  airports <- make_synthetic_airports()

  result <- resolve(airports, "toronto", by = "name")

  expect_equal(nrow(result), 2)
  expect_equal(result$AIRPORT_IDENT, c("CYYZ", "CYTZ"))
})

test_that("resolve targets an arbitrary column via column=/match=", {
  airports <- make_synthetic_airports()

  exact <- resolve(airports, "M5V", column = "POSTAL_CODE")
  expect_equal(exact$AIRPORT_IDENT, "CYTZ")

  sub <- resolve(airports, "L", column = "POSTAL_CODE", match = "substring")
  expect_equal(sort(sub$AIRPORT_IDENT), c("CYHM", "CYYZ"))
})

test_that("resolve returns NA data columns and one combined warning for no match", {
  airports <- make_synthetic_airports()

  expect_warning(
    result <- resolve(airports, c("missing-a", "missing-b")),
    "resolve\\(\\): no match found for: missing-a, missing-b"
  )
  expect_equal(nrow(result), 2)
  expect_equal(result$query, c("missing-a", "missing-b"))
  expect_true(all(is.na(result$AIRPORT_IDENT)))
})

test_that("resolve handles mixed matched and unmatched queries", {
  airports <- make_synthetic_airports()

  expect_warning(
    result <- resolve(airports, c("CYYZ", "unknown", "CYTZ")),
    "unknown"
  )
  expect_equal(nrow(result), 3)
  expect_equal(result$AIRPORT_IDENT, c("CYYZ", NA, "CYTZ"))
})
