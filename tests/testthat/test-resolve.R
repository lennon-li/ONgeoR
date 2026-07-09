make_synthetic_airports <- function() {
  poly_a <- sf::st_polygon(list(rbind(
    c(-80, 44), c(-79, 44), c(-79, 43), c(-80, 43), c(-80, 44)
  )))
  poly_b <- sf::st_polygon(list(rbind(
    c(-82, 44), c(-81, 44), c(-81, 43), c(-82, 43), c(-82, 44)
  )))
  poly_c <- sf::st_polygon(list(rbind(
    c(-84, 44), c(-83, 44), c(-83, 43), c(-84, 43), c(-84, 44)
  )))

  airports <- sf::st_sf(
    AIRPORT_IDENT = c("CYYZ", "CYTZ", "CYHM"),
    NAME = c("Toronto Pearson International Airport", "Billy Bishop Toronto City Airport", "Hamilton Airport"),
    AIRPORT_TYPE = c("Certified Airport", "Certified Airport", "Registered Aerodrome"),
    MUNICIPALITY = c("Mississauga", "Toronto", "Hamilton"),
    geometry = sf::st_sfc(poly_a, poly_b, poly_c, crs = 4326)
  )
  attr(airports, "source_url") <- "https://example.com/airports"
  attr(airports, "retrieved_at") <- as.POSIXct("2026-07-08 00:00:00", tz = "UTC")
  airports
}

test_that("resolve_airport matches airport ident exactly ignoring case", {
  airports <- make_synthetic_airports()

  result <- resolve_airport("cyyz", airports = airports)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_equal(result$query, "cyyz")
  expect_true(all(c("AIRPORT_IDENT", "NAME", "AIRPORT_TYPE", "MUNICIPALITY") %in% colnames(result)))
  expect_equal(result$AIRPORT_IDENT, "CYYZ")
  expect_equal(result$NAME, "Toronto Pearson International Airport")
  expect_equal(result$source_url, "https://example.com/airports")
  expect_false(is.null(result$retrieved_at))
})

test_that("resolve_airport matches airport names by case-insensitive substring", {
  airports <- make_synthetic_airports()

  result <- resolve_airport("toronto", by = "name", airports = airports)

  expect_equal(nrow(result), 2)
  expect_equal(result$query, c("toronto", "toronto"))
  expect_equal(result$AIRPORT_IDENT, c("CYYZ", "CYTZ"))
  expect_equal(result$source_url, rep("https://example.com/airports", 2))
})

test_that("resolve_airport returns NA airport columns and warns for no match", {
  airports <- make_synthetic_airports()

  expect_warning(
    result <- resolve_airport(c("missing-a", "missing-b"), airports = airports),
    "resolve_airport\\(\\): no match found for: missing-a, missing-b"
  )

  expect_equal(nrow(result), 2)
  expect_equal(result$query, c("missing-a", "missing-b"))
  expect_true(all(is.na(result$AIRPORT_IDENT)))
  expect_true(all(is.na(result$NAME)))
  expect_true(all(is.na(result$AIRPORT_TYPE)))
  expect_equal(result$source_url, rep("https://example.com/airports", 2))
})

test_that("resolve_airport handles multiple query values with matched and unmatched rows", {
  airports <- make_synthetic_airports()

  expect_warning(
    result <- resolve_airport(c("CYYZ", "unknown", "CYTZ"), airports = airports),
    "unknown"
  )

  expect_equal(nrow(result), 3)
  expect_equal(result$query, c("CYYZ", "unknown", "CYTZ"))
  expect_equal(result$AIRPORT_IDENT, c("CYYZ", NA, "CYTZ"))
  expect_equal(result$source_url, rep("https://example.com/airports", 3))
})
