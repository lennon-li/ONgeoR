make_synthetic_layers <- function() {
  phu_poly <- sf::st_polygon(list(rbind(
    c(-80, 44), c(-79, 44), c(-79, 43), c(-80, 43), c(-80, 44)
  )))
  phu <- sf::st_sf(
    PHU_ID = 1,
    PHU_NAME_ENG = "Test Health Unit A",
    geometry = sf::st_sfc(phu_poly, crs = 4326)
  )
  attr(phu, "source_name") <- "MOH Public Health Unit Boundary"
  attr(phu, "source_url") <- "https://example.com/phu"
  attr(phu, "retrieved_at") <- as.POSIXct("2026-07-08 00:00:00", tz = "UTC")

  muni_poly <- sf::st_polygon(list(rbind(
    c(-79.8, 43.8), c(-79.2, 43.8), c(-79.2, 43.2), c(-79.8, 43.2), c(-79.8, 43.8)
  )))
  municipal <- sf::st_sf(
    MUNID = 100,
    MUNICIPAL_NAME = "Test Municipality",
    geometry = sf::st_sfc(muni_poly, crs = 4326)
  )
  attr(municipal, "source_name") <- "Municipal Bnd Upper And Dist"
  attr(municipal, "source_url") <- "https://example.com/municipal"

  list(municipal = municipal, phu = phu)
}

test_that("build_crosswalk produces the documented output schema", {
  layers <- make_synthetic_layers()

  crosswalk <- build_crosswalk(layers$municipal, layers$phu, method = "within")

  expected_cols <- c(
    "from_id", "from_name", "from_source",
    "to_id", "to_name", "to_source",
    "match_method", "match_distance_km", "coverage",
    "from_id_col", "to_id_col",
    "source_url_from", "source_url_to", "retrieved_at"
  )
  expect_equal(colnames(crosswalk), expected_cols)
  expect_equal(nrow(crosswalk), 1)
  expect_true(all(is.na(crosswalk$coverage)))
})

test_that("build_crosswalk populates provenance fields correctly", {
  layers <- make_synthetic_layers()

  crosswalk <- build_crosswalk(layers$municipal, layers$phu, method = "within")

  expect_equal(crosswalk$from_id, "100")
  expect_equal(crosswalk$from_name, "Test Municipality")
  expect_equal(crosswalk$from_source, "Municipal Bnd Upper And Dist")
  expect_equal(crosswalk$to_id, "1")
  expect_equal(crosswalk$to_name, "Test Health Unit A")
  expect_equal(crosswalk$to_source, "MOH Public Health Unit Boundary")
  expect_equal(crosswalk$match_method, "within")
  expect_equal(crosswalk$from_id_col, "MUNID")
  expect_equal(crosswalk$to_id_col, "PHU_ID")
  expect_true(is.na(crosswalk$match_distance_km))
  expect_equal(crosswalk$source_url_from, "https://example.com/municipal")
  expect_equal(crosswalk$source_url_to, "https://example.com/phu")
  expect_equal(crosswalk$retrieved_at, as.POSIXct("2026-07-08 00:00:00", tz = "UTC"))
})

test_that("build_crosswalk defaults to the within predicate", {
  layers <- make_synthetic_layers()

  crosswalk <- build_crosswalk(layers$municipal, layers$phu)

  expect_equal(crosswalk$match_method, "within")
})

make_synthetic_point_layers <- function() {
  polygon <- sf::st_polygon(list(rbind(
    c(-80, 44), c(-79, 44), c(-79, 43), c(-80, 43), c(-80, 44)
  )))
  area <- sf::st_sf(
    MUNID = 100,
    MUNICIPAL_NAME = "Test Municipality",
    geometry = sf::st_sfc(polygon, crs = 4326)
  )
  attr(area, "source_name") <- "Municipal Bnd Upper And Dist"
  attr(area, "source_url") <- "https://example.com/municipal"

  inside_point <- sf::st_point(c(-79.5, 43.5))
  outside_point <- sf::st_point(c(-81.5, 43.5))
  facilities <- sf::st_sf(
    FACILITY_ID = c(10, 20),
    FACILITY_NAME = c("Facility Inside", "Facility Outside"),
    geometry = sf::st_sfc(inside_point, outside_point, crs = 4326)
  )
  attr(facilities, "source_name") <- "Test Facilities"
  attr(facilities, "source_url") <- "https://example.com/facilities"
  attr(facilities, "retrieved_at") <- as.POSIXct("2026-07-08 02:00:00", tz = "UTC")

  list(area = area, facilities = facilities)
}

test_that("build_crosswalk auto-reorders polygon-from/point-to within joins", {
  layers <- make_synthetic_point_layers()

  expect_message(
    crosswalk <- build_crosswalk(layers$area, layers$facilities, method = "within"),
    "auto-corrected"
  )

  expect_equal(nrow(crosswalk), 2)
  inside_row <- crosswalk[crosswalk$to_id == "10", ]
  outside_row <- crosswalk[crosswalk$to_id == "20", ]
  expect_equal(inside_row$from_id, "100")
  expect_equal(inside_row$from_name, "Test Municipality")
  expect_true(is.na(outside_row$from_id))
  expect_equal(
    crosswalk$retrieved_at,
    rep(as.POSIXct("2026-07-08 02:00:00", tz = "UTC"), 2)
  )
})

test_that("build_crosswalk does not reorder when to is already polygonal", {
  layers <- make_synthetic_layers()

  expect_no_message(build_crosswalk(layers$municipal, layers$phu, method = "within"))
})

test_that("build_crosswalk auto-reorder output has the documented column schema", {
  layers <- make_synthetic_point_layers()

  crosswalk <- suppressMessages(
    build_crosswalk(layers$area, layers$facilities, method = "within")
  )

  expected_cols <- c(
    "from_id", "from_name", "from_source",
    "to_id", "to_name", "to_source",
    "match_method", "match_distance_km", "coverage",
    "from_id_col", "to_id_col",
    "source_url_from", "source_url_to", "retrieved_at"
  )
  expect_equal(colnames(crosswalk), expected_cols)
})

test_that("auto-reorder: matched facility has non-NA from_id and non-NA to_id (direction-sensitivity regression)", {
  # Regression guard: without the direction fix, build_crosswalk(polygon, points)
  # called link(polygon, points, predicate = "within"), which ran
  # st_within(polygon, point) -- geometrically degenerate (a polygon is never
  # "within" a point). Every matched column (including to_id) came back NA.
  # The direction guard fixes this by calling link(to, from, ...) instead.
  # After the fix, link(points, polygon) runs st_join(points, polygon, st_within),
  # which adds the polygon boundary columns to each point row. Both from_id
  # (boundary ID, from the reversed join target) and to_id (facility ID, from
  # the reversed join source) must be non-NA for the inside facility.
  layers <- make_synthetic_point_layers()

  crosswalk <- suppressMessages(
    build_crosswalk(layers$area, layers$facilities, method = "within")
  )

  # which() drops NA comparisons, so a degenerate all-NA to_id column yields
  # zero matches (a clear failure) instead of an all-NA phantom row.
  inside_idx <- which(crosswalk$to_id == "10")
  expect_length(inside_idx, 1)
  inside_row <- crosswalk[inside_idx, ]

  # The direction guard must produce a valid, non-degenerate result.
  expect_false(
    is.na(inside_row$from_id),
    label = "from_id must not be NA for the facility inside the boundary"
  )
  expect_false(
    is.na(inside_row$to_id),
    label = "to_id must not be NA for the matched facility"
  )
  # Confirm the actual matched boundary ID is correct.
  expect_equal(inside_row$from_id, "100")
  # Confirm the facility ID round-trips correctly through the reversed join.
  expect_equal(inside_row$to_id, "10")
})

# --- helpers for polygon-to-polygon method tests ---------------------------

make_two_base_layer <- function() {
  square <- function(x0, x1, y0, y1) {
    sf::st_polygon(list(rbind(
      c(x0, y1), c(x1, y1), c(x1, y0), c(x0, y0), c(x0, y1)
    )))
  }
  base <- sf::st_sf(
    BASE_ID = c(1, 2),
    BASE_NAME = c("Base A", "Base B"),
    geometry = sf::st_sfc(
      square(-80, -79, 43, 44),
      square(-79, -78, 43, 44),
      crs = 4326
    )
  )
  attr(base, "source_name") <- "Synthetic Base Layer"
  attr(base, "source_url") <- "https://example.com/base"
  attr(base, "retrieved_at") <- as.POSIXct("2026-07-08 03:00:00", tz = "UTC")
  base
}

square_sf <- function(x0, x1, y0, y1, id, name) {
  poly <- sf::st_polygon(list(rbind(
    c(x0, y1), c(x1, y1), c(x1, y0), c(x0, y0), c(x0, y1)
  )))
  from <- sf::st_sf(
    FROM_ID = id,
    FROM_NAME = name,
    geometry = sf::st_sfc(poly, crs = 4326)
  )
  attr(from, "source_name") <- "Synthetic From Layer"
  attr(from, "source_url") <- "https://example.com/from"
  from
}

test_that("point_on_surface assigns small polygons to the containing base", {
  base <- make_two_base_layer()
  small_a <- sf::st_polygon(list(rbind(
    c(-79.6, 43.6), c(-79.4, 43.6), c(-79.4, 43.4), c(-79.6, 43.4), c(-79.6, 43.6)
  )))
  small_b <- sf::st_polygon(list(rbind(
    c(-78.6, 43.6), c(-78.4, 43.6), c(-78.4, 43.4), c(-78.6, 43.4), c(-78.6, 43.6)
  )))
  from <- sf::st_sf(
    FROM_ID = c(1, 2),
    FROM_NAME = c("Small A", "Small B"),
    geometry = sf::st_sfc(small_a, small_b, crs = 4326)
  )
  attr(from, "source_name") <- "Synthetic From Layer"
  attr(from, "source_url") <- "https://example.com/from"

  crosswalk <- build_crosswalk(from, base, method = "point_on_surface")

  expect_equal(nrow(crosswalk), 2)
  expect_equal(crosswalk$match_method, rep("point_on_surface", 2))
  expect_true(all(is.na(crosswalk$coverage)))
  row_a <- crosswalk[crosswalk$from_id == "1", ]
  row_b <- crosswalk[crosswalk$from_id == "2", ]
  expect_equal(row_a$to_id, "1")
  expect_equal(row_a$from_name, "Small A")
  expect_equal(row_b$to_id, "2")
})

test_that("point_on_surface uses interior point, not centroid, for concave from", {
  base <- make_two_base_layer()
  # C-shaped polygon straddling the A/B boundary: its centroid lands in base A,
  # but its guaranteed-interior point_on_surface point lands in base B.
  concave <- sf::st_polygon(list(rbind(
    c(-79.90, 43.05), c(-79.30, 43.05), c(-79.30, 43.35), c(-78.10, 43.35),
    c(-78.10, 43.05), c(-78.05, 43.05), c(-78.05, 43.95), c(-78.10, 43.95),
    c(-78.10, 43.65), c(-79.30, 43.65), c(-79.30, 43.95), c(-79.90, 43.95),
    c(-79.90, 43.05)
  )))
  from <- sf::st_sf(
    FROM_ID = 7,
    FROM_NAME = "Concave",
    geometry = sf::st_sfc(concave, crs = 4326)
  )
  attr(from, "source_name") <- "Synthetic From Layer"
  attr(from, "source_url") <- "https://example.com/from"

  # Document the centroid trap: the area centroid falls in base A (wrong).
  centroid <- suppressWarnings(sf::st_centroid(sf::st_geometry(from)))
  expect_true(lengths(sf::st_within(centroid, sf::st_geometry(base)[1])) > 0)

  crosswalk <- build_crosswalk(from, base, method = "point_on_surface")

  # point_on_surface point falls in base B, so the assignment must be base B.
  expect_equal(crosswalk$to_id, "2")
  expect_equal(crosswalk$match_method, "point_on_surface")
})

test_that("point_on_surface aborts when the to layer is point-type", {
  base <- make_two_base_layer()
  from <- square_sf(-79.6, -79.4, 43.4, 43.6, 1, "Small A")
  points <- sf::st_sf(
    P_ID = 5,
    P_NAME = "A point",
    geometry = sf::st_sfc(sf::st_point(c(-79.5, 43.5)), crs = 4326)
  )

  expect_error(
    build_crosswalk(from, points, method = "point_on_surface"),
    "polygon"
  )
})

test_that("largest_overlap assigns to the base with the greatest overlap area", {
  base <- make_two_base_layer()
  # p1: 70% in base A, 30% in base B -> assigned A, coverage ~0.7
  p1 <- sf::st_polygon(list(rbind(
    c(-79.35, 43.6), c(-78.85, 43.6), c(-78.85, 43.4), c(-79.35, 43.4), c(-79.35, 43.6)
  )))
  # p2: fully inside base B -> coverage ~1
  p2 <- sf::st_polygon(list(rbind(
    c(-78.7, 43.6), c(-78.3, 43.6), c(-78.3, 43.4), c(-78.7, 43.4), c(-78.7, 43.6)
  )))
  # p3: overlaps nothing -> NA to_id, NA coverage
  p3 <- sf::st_polygon(list(rbind(
    c(-70, 43.6), c(-69, 43.6), c(-69, 43.4), c(-70, 43.4), c(-70, 43.6)
  )))
  from <- sf::st_sf(
    FROM_ID = c(1, 2, 3),
    FROM_NAME = c("Straddle", "Inside B", "Nowhere"),
    geometry = sf::st_sfc(p1, p2, p3, crs = 4326)
  )
  attr(from, "source_name") <- "Synthetic From Layer"
  attr(from, "source_url") <- "https://example.com/from"

  crosswalk <- build_crosswalk(from, base, method = "largest_overlap")

  expect_equal(nrow(crosswalk), 3)
  expect_equal(crosswalk$match_method, rep("largest_overlap", 3))

  r1 <- crosswalk[crosswalk$from_id == "1", ]
  r2 <- crosswalk[crosswalk$from_id == "2", ]
  r3 <- crosswalk[crosswalk$from_id == "3", ]

  expect_equal(r1$to_id, "1")
  expect_equal(r1$coverage, 0.7, tolerance = 0.05)
  expect_equal(r2$to_id, "2")
  expect_equal(r2$coverage, 1, tolerance = 0.05)
  expect_true(is.na(r3$to_id))
  expect_true(is.na(r3$coverage))
})

test_that("largest_overlap aborts when either layer is point-type", {
  base <- make_two_base_layer()
  from_poly <- square_sf(-79.6, -79.4, 43.4, 43.6, 1, "Small A")
  points <- sf::st_sf(
    P_ID = 5,
    P_NAME = "A point",
    geometry = sf::st_sfc(sf::st_point(c(-79.5, 43.5)), crs = 4326)
  )

  expect_error(
    build_crosswalk(from_poly, points, method = "largest_overlap"),
    "polygon"
  )
  expect_error(
    build_crosswalk(points, base, method = "largest_overlap"),
    "polygon"
  )
})

test_that("weighted keeps every positive-area pair", {
  layers <- fixture_overlap_layers()
  weighted <- build_crosswalk(layers$from, layers$to, method = "weighted")
  largest <- build_crosswalk(layers$from, layers$to, method = "largest_overlap")

  expect_equal(nrow(weighted), 3)
  expect_equal(weighted$match_method, rep("weighted", 3))
  expect_equal(weighted$coverage, c(1, 0.25, 0.75), tolerance = 1e-6)
  expect_equal(weighted$from_id_col, rep("from_id", 3))
  expect_equal(weighted$to_id_col, rep("to_id", 3))
  expect_true(all(tapply(weighted$coverage, weighted$from_id, sum) <= 1 + 1e-6))
  expect_equal(weighted$to_id[c(1, 3)], largest$to_id)
})

test_that("weighted preserves an unmatched from row", {
  layers <- fixture_overlap_layers()
  unmatched_from <- sf::st_sf(
    from_id = "F3", from_name = "From 3",
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(5, 0), c(6, 0), c(6, 1), c(5, 1), c(5, 0)
    ))), crs = 3347)
  )
  layers$from <- rbind(layers$from, fixture_provenance(unmatched_from))

  result <- build_crosswalk(layers$from, layers$to, method = "weighted")
  row <- result[result$from_id == "F3", ]
  expect_equal(nrow(row), 1)
  expect_true(is.na(row$to_id))
  expect_true(is.na(row$to_name))
  expect_true(is.na(row$coverage))
})

test_that("weighted aborts when either layer is point-type", {
  layers <- fixture_overlap_layers()
  points <- sf::st_as_sf(data.frame(x = 0.5, y = 0.5), coords = c("x", "y"), crs = 4326)

  expect_error(
    build_crosswalk(layers$from, points, method = "weighted"),
    class = "ongeor_crosswalk_weighted_needs_polygons"
  )
  expect_error(
    build_crosswalk(points, layers$to, method = "weighted"),
    class = "ongeor_crosswalk_weighted_needs_polygons"
  )
})

test_that("registry key fields drive crosswalk identifiers and names", {
  phu <- sf::st_sf(
    OGF_ID = "decoy", PHU_ID = "PHU-1", PHU_NAME_ENG = "Registry PHU",
    PHU_NAME_FR = "USI registre",
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(0, 0), c(1, 0), c(1, 1), c(0, 1), c(0, 0)
    ))), crs = 4326)
  )
  attr(phu, "source_name") <- "MOH Public Health Unit Boundary"
  target <- make_synthetic_layers()$municipal
  result <- build_crosswalk(phu, target, method = "intersects")
  expect_equal(result$from_id, "PHU-1")
  expect_equal(result$from_name, "Registry PHU")
  expect_equal(result$from_id_col, "PHU_ID")
  expect_equal(result$to_id_col, "MUNID")
})
