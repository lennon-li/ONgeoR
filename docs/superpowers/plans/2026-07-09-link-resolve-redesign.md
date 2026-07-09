# link + resolve API Redesign Implementation Plan

> **For agentic workers:** This plan is executed via **Jax dispatch**
> (`ming-calling-jax` skill), one packet per task. Jax writes code + tests and
> runs `devtools::document()`/`devtools::check()`; Jax NEVER commits. After each
> task, Ming reviews the diff, live-verifies against the real LIO API, and
> commits with Lennon's explicit approval. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Replace the drifted, source-specific linking/resolving functions with
four geometry-type/attribute-based verbs: `link()`, `nearest()`, `resolve()`,
and a `link()`-backed `build_crosswalk()`.

**Architecture:** Dispatch on geometry type (spatial) and attribute (resolve),
never on named source. `link()` = topological join (point/polygon/raster seam);
`nearest()` = proximity (absorbs nearest + within-radius); `resolve()` =
attribute lookup; `build_crosswalk()` reimplemented as an opinionated wrapper
over `link()` with its public contract unchanged.

**Tech Stack:** R package; `sf` (S2 geodesic), `tibble`, `rlang`; `testthat`
edition 3; roxygen2 8.0.0.

**Spec:** `docs/superpowers/specs/2026-07-09-link-resolve-redesign-design.md`

---

## File Structure

- `R/link.R` — REPLACE contents: remove `points_to_phu`, `polygon_to_polygon`,
  `nearest_facility`, `facilities_within`, `facility_distance_matrix_km`; add
  `link()`, `nearest()`.
- `R/resolve.R` — REPLACE: remove `resolve_airport`; add `resolve()`.
- `R/crosswalk.R` — reimplement `build_crosswalk()` on `link()` (same
  signature/output).
- `tests/testthat/test-link.R` — rewrite for `link()` + `nearest()`.
- `tests/testthat/test-resolve.R` — rewrite for `resolve()`.
- `tests/testthat/test-crosswalk.R` — UNCHANGED (regression guard).
- `README.md`, `ROADMAP.md` — doc consistency.
- `NAMESPACE`, `man/*` — regenerated via `devtools::document()`.
- Untouched: `R/cli.R`, `R/retrieve.R`, `R/cache.R`, `R/utils.R`,
  `inst/extdata/sources.yaml`, `tests/testthat/test-cli.R`,
  `tests/testthat/test-cache.R`, `tests/testthat/test-retrieve.R`.

Internal helpers already in `R/utils.R` and reused: `guess_id_col()`,
`guess_name_col()`, `provenance_attr()`.

---

## Task 1: `link()` + raster seam

**Files:**
- Modify: `R/link.R` (add `link()`; remove `points_to_phu`, `polygon_to_polygon`)
- Test: `tests/testthat/test-link.R`

- [ ] **Step 1: Write failing tests for `link()`**

Replace the `points_to_phu`/`polygon_to_polygon` tests in
`tests/testthat/test-link.R` with these (keep the existing `make_synthetic_phu()`
helper at the top of the file):

```r
test_that("link joins points to the containing polygon (within)", {
  phu <- make_synthetic_phu()
  points <- data.frame(point_id = 1:2, lon = c(-79.5, -81.5), lat = c(43.5, 43.5))

  result <- link(points, phu)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2)
  expect_equal(result$PHU_NAME_ENG, c("Test Health Unit A", "Test Health Unit B"))
  expect_equal(result$target_url, rep("https://example.com/phu", 2))
  expect_true(all(is.na(result$source_url)))       # user points: no provenance
  expect_false(is.null(result$retrieved_at))
})

test_that("link accepts sf point input directly", {
  phu <- make_synthetic_phu()
  points_sf <- sf::st_as_sf(
    data.frame(point_id = 1, lon = -79.5, lat = 43.5),
    coords = c("lon", "lat"), crs = 4326
  )

  result <- link(points_sf, phu)

  expect_equal(nrow(result), 1)
  expect_equal(result$PHU_NAME_ENG, "Test Health Unit A")
})

test_that("link joins polygons to polygons with the intersects predicate", {
  phu <- make_synthetic_phu()
  muni_poly <- sf::st_polygon(list(rbind(
    c(-79.8, 43.8), c(-79.2, 43.8), c(-79.2, 43.2), c(-79.8, 43.2), c(-79.8, 43.8)
  )))
  municipal <- sf::st_sf(
    MUNID = 100, MUNICIPAL_NAME = "Test Municipality",
    geometry = sf::st_sfc(muni_poly, crs = 4326)
  )
  attr(municipal, "source_url") <- "https://example.com/muni"

  result <- link(municipal, phu, predicate = "intersects")

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_equal(result$PHU_NAME_ENG, "Test Health Unit A")
  expect_equal(result$source_url, "https://example.com/muni")
  expect_equal(result$target_url, "https://example.com/phu")
})

test_that("link aborts on a raster source (seam not yet implemented)", {
  phu <- make_synthetic_phu()
  fake_raster <- structure(list(), class = "SpatRaster")

  expect_error(link(fake_raster, phu), "not yet implemented")
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "link")'`
Expected: FAIL — `could not find function "link"`.

- [ ] **Step 3: Implement `link()` and remove the two old functions**

In `R/link.R`, delete `points_to_phu()` and `polygon_to_polygon()` entirely, and
add:

```r
#' Link geometries to a target layer by spatial relationship
#'
#' Joins a source layer to a target layer using a spatial predicate. Covers
#' point-in-polygon and polygon-to-polygon joins. Raster sources are planned
#' (reduced to centroids per the package's raster linking model) but not yet
#' implemented.
#'
#' @param source An `sf` object (points or polygons), or a `data.frame` with
#'   `lon` and `lat` columns (assumed CRS 4326 / WGS 84). A `SpatRaster`
#'   routes to the raster-reduction path (not yet implemented).
#' @param target An `sf` object, typically polygons.
#' @param predicate Character. Spatial join predicate: `"within"` (default),
#'   `"intersects"`, or `"contains"`. Note: simplified boundary data (e.g.
#'   municipal boundaries retrieved with `simplify = TRUE`) often needs
#'   `"intersects"`, because `"within"` misses matches against generalized
#'   borders. For very complex geometry, simplify first
#'   (retrieve with `simplify = TRUE`, or `sf::st_simplify()`) then link.
#'
#' @return A [tibble::tibble()] with the source's non-geometry columns, the
#'   matched target columns, and `source_url` / `target_url` / `retrieved_at`
#'   provenance columns. Column-name collisions between source and target
#'   follow `sf::st_join()`'s default `.x`/`.y` suffixing.
#'
#' @examples
#' if (interactive()) {
#'   points <- data.frame(lon = -79.3832, lat = 43.6532)
#'   result <- link(points, retrieve_phu())
#' }
#'
#' @export
link <- function(source, target,
                 predicate = c("within", "intersects", "contains")) {
  predicate <- match.arg(predicate)

  if (inherits(source, "SpatRaster") || inherits(target, "SpatRaster")) {
    rlang::abort(
      "raster linking not yet implemented; see the package raster linking model"
    )
  }

  if (inherits(source, "data.frame") && !inherits(source, "sf")) {
    source <- sf::st_as_sf(source, coords = c("lon", "lat"), crs = 4326)
  }

  predicate_fn <- switch(predicate,
    within = sf::st_within,
    intersects = sf::st_intersects,
    contains = sf::st_contains
  )

  joined <- sf::st_join(source, target, join = predicate_fn)
  result <- tibble::as_tibble(sf::st_drop_geometry(joined))

  result$source_url <- provenance_attr(source, "source_url")
  result$target_url <- provenance_attr(target, "source_url")
  result$retrieved_at <- provenance_attr(target, "retrieved_at")

  result
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `Rscript -e 'devtools::document(); devtools::test(filter = "link")'`
Expected: PASS. The `nearest_facility`/`facilities_within` functions and their
tests remain untouched in this task and stay green; they are replaced in Task 2.

- [ ] **Step 5: Ming review + live-verify + commit**

STOP. Return to Ming. Ming verifies against real data:
`link(data.frame(point_id=1, lon=-79.3832, lat=43.6532), retrieve_phu())` returns
the Toronto PHU with `target_url` populated. Ming commits with Lennon's approval.

---

## Task 2: `nearest()`

**Files:**
- Modify: `R/link.R` (add `nearest()`; remove `nearest_facility`,
  `facilities_within`, `facility_distance_matrix_km`)
- Test: `tests/testthat/test-link.R`

- [ ] **Step 1: Write failing tests for `nearest()`**

Replace the `nearest_facility`/`facilities_within` tests in
`tests/testthat/test-link.R` with these (add the helper below to the top of the
file, next to `make_synthetic_phu()`):

```r
make_synthetic_facilities <- function() {
  facilities <- sf::st_as_sf(
    data.frame(
      facility_id = c(10, 20, 30),
      facility_name = c("Facility A", "Facility B", "Facility C"),
      lon = c(-79.000, -79.010, -80.000),
      lat = c(43.000, 43.000, 44.000)
    ),
    coords = c("lon", "lat"), crs = 4326
  )
  attr(facilities, "source_url") <- "https://example.com/facilities"
  attr(facilities, "retrieved_at") <- as.POSIXct("2026-07-08 01:00:00", tz = "UTC")
  facilities
}

test_that("nearest returns the closest target per source (k = 1)", {
  facilities <- make_synthetic_facilities()
  points <- data.frame(point_id = 1:2, lon = c(-79.000, -80.000), lat = c(43.000, 44.000))

  result <- nearest(points, facilities)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2)
  expect_equal(result$point_id, 1:2)
  expect_equal(result$rank, c(1, 1))
  expect_equal(result$facility_name, c("Facility A", "Facility C"))
  expect_equal(result$distance_km, c(0, 0), tolerance = 0.001)
  expect_equal(result$target_url, rep("https://example.com/facilities", 2))
  expect_false(is.null(result$retrieved_at))
})

test_that("nearest returns k matches in ascending distance order", {
  facilities <- make_synthetic_facilities()
  points <- data.frame(point_id = 1, lon = -79.000, lat = 43.000)

  result <- nearest(points, facilities, k = 2)

  expect_equal(nrow(result), 2)
  expect_equal(result$rank, c(1, 2))
  expect_equal(result$facility_name, c("Facility A", "Facility B"))
  expect_true(result$distance_km[1] <= result$distance_km[2])
})

test_that("nearest caps k at the available target count", {
  facilities <- make_synthetic_facilities()
  points <- data.frame(point_id = 1, lon = -79.000, lat = 43.000)

  result <- nearest(points, facilities, k = 5)

  expect_equal(nrow(result), 3)
  expect_equal(result$rank, 1:3)
})

test_that("nearest with max_dist_km acts as a radius search and omits empty sources", {
  facilities <- make_synthetic_facilities()
  points <- data.frame(point_id = 1:2, lon = c(-79.000, -82.000), lat = c(43.000, 45.000))

  result <- nearest(points, facilities, k = Inf, max_dist_km = 2)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2)          # point 1 matches A + B; point 2 matches none
  expect_equal(result$point_id, c(1, 1))
  expect_equal(result$facility_name, c("Facility A", "Facility B"))
  expect_true(result$distance_km[1] <= result$distance_km[2])
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "link")'`
Expected: FAIL — `could not find function "nearest"`.

- [ ] **Step 3: Implement `nearest()` and remove the old proximity functions**

In `R/link.R`, delete `nearest_facility()`, `facilities_within()`, and the
internal `facility_distance_matrix_km()`, and add:

```r
#' Find the nearest targets to each source geometry
#'
#' For each source geometry, returns the `k` nearest targets in ascending
#' distance, optionally capped at `max_dist_km`. Use `k = Inf` with
#' `max_dist_km` for a pure radius search.
#'
#' @param source An `sf` object of points, or a `data.frame` with `lon`/`lat`
#'   columns (assumed CRS 4326 / WGS 84).
#' @param target An `sf` object of candidate geometries.
#' @param k Integer. Number of nearest targets to return per source. Defaults
#'   to `1`. If a source has fewer than `k` targets available, all are returned.
#' @param max_dist_km Numeric or `NULL`. If set, drop targets farther than this
#'   distance (km). Defaults to `NULL` (no cap). A source with no target in
#'   range contributes zero rows.
#'
#' @return A [tibble::tibble()] with the source columns, `rank` (1 = nearest),
#'   the matched target columns, `distance_km`, and `source_url` / `target_url`
#'   / `retrieved_at` provenance columns. Uses a full source-by-target distance
#'   matrix (not spatial-indexed); adequate at current scale.
#'
#' @examples
#' if (interactive()) {
#'   points <- data.frame(lon = -79.3832, lat = 43.6532)
#'   result <- nearest(points, retrieve_moh_service_locations(), k = 3)
#' }
#'
#' @export
nearest <- function(source, target, k = 1, max_dist_km = NULL) {
  if (inherits(source, "data.frame") && !inherits(source, "sf")) {
    source <- sf::st_as_sf(source, coords = c("lon", "lat"), crs = 4326)
  }

  source_data <- tibble::as_tibble(sf::st_drop_geometry(source))
  if (ncol(source_data) == 0) {
    source_data <- tibble::tibble(point_id = seq_len(nrow(source)))
  }
  target_data <- tibble::as_tibble(sf::st_drop_geometry(target))

  distances_km <- matrix(
    as.numeric(sf::st_distance(source, target)) / 1000,
    nrow = nrow(source), ncol = nrow(target)
  )

  rows <- vector("list", nrow(source))
  for (i in seq_len(nrow(source))) {
    ordered <- order(distances_km[i, ])
    idx <- ordered[seq_len(min(k, length(ordered)))]
    if (!is.null(max_dist_km)) {
      idx <- idx[distances_km[i, idx] <= max_dist_km]
    }
    if (length(idx) == 0) next

    rows[[i]] <- cbind(
      source_data[rep(i, length(idx)), , drop = FALSE],
      rank = seq_along(idx),
      target_data[idx, , drop = FALSE],
      distance_km = distances_km[i, idx]
    )
  }

  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) {
    result <- cbind(
      source_data[0, , drop = FALSE], rank = integer(),
      target_data[0, , drop = FALSE], distance_km = numeric()
    )
  } else {
    result <- do.call(rbind, rows)
  }

  result <- tibble::as_tibble(result)
  result$source_url <- provenance_attr(source, "source_url")
  result$target_url <- provenance_attr(target, "source_url")
  result$retrieved_at <- provenance_attr(target, "retrieved_at")

  result
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `Rscript -e 'devtools::document(); devtools::test(filter = "link")'`
Expected: PASS (all `link` + `nearest` tests green).

- [ ] **Step 5: Ming review + live-verify + commit**

STOP. Ming verifies against real data at a downtown Toronto point:
`nearest(data.frame(point_id=1, lon=-79.3832, lat=43.6532), retrieve_moh_service_locations(), k=3)`
returns 3 ranked facilities; `nearest(..., k=Inf, max_dist_km=1)` returns a
larger ascending-ordered set; `max_dist_km=0.01` returns zero rows. Ming commits
with Lennon's approval.

---

## Task 3: `build_crosswalk()` reimplemented on `link()`

**Files:**
- Modify: `R/crosswalk.R`
- Test: `tests/testthat/test-crosswalk.R` (UNCHANGED — regression guard)

- [ ] **Step 1: Confirm the existing regression tests currently pass**

Run: `Rscript -e 'devtools::test(filter = "crosswalk")'`
Expected: PASS (baseline before the change).

- [ ] **Step 2: Reimplement `build_crosswalk()` on `link()`**

Replace the body of `build_crosswalk()` in `R/crosswalk.R` (keep its roxygen and
signature exactly as-is) with:

```r
build_crosswalk <- function(from, to, method = c("within", "intersects")) {
  method <- match.arg(method)

  linked <- link(from, to, predicate = method)

  from_id_col <- guess_id_col(from)
  from_name_col <- guess_name_col(from)
  to_id_col <- guess_id_col(to)
  to_name_col <- guess_name_col(to)

  tibble::tibble(
    from_id = as.character(linked[[from_id_col]]),
    from_name = as.character(linked[[from_name_col]]),
    from_source = provenance_attr(from, "source_name"),
    to_id = as.character(linked[[to_id_col]]),
    to_name = as.character(linked[[to_name_col]]),
    to_source = provenance_attr(to, "source_name"),
    match_method = method,
    match_distance_km = NA_real_,
    source_url_from = provenance_attr(from, "source_url"),
    source_url_to = provenance_attr(to, "source_url"),
    retrieved_at = provenance_attr(to, "retrieved_at")
  )
}
```

- [ ] **Step 3: Run the regression tests to verify the contract held**

Run: `Rscript -e 'devtools::test(filter = "crosswalk")'`
Expected: PASS — identical output schema and values as before, proving
`build_crosswalk()`'s public contract survived the reimplementation.

- [ ] **Step 4: Ming review + live-verify + commit**

STOP. Ming verifies against real data:
`build_crosswalk(retrieve_municipal("upper"), retrieve_phu(), method = "intersects")`
returns the canonical schema with populated `from_source`/`to_source`. Ming
commits with Lennon's approval.

---

## Task 4: `resolve()`

**Files:**
- Modify: `R/resolve.R` (remove `resolve_airport`; add `resolve()`)
- Test: `tests/testthat/test-resolve.R` (rewrite)

- [ ] **Step 1: Write failing tests for `resolve()`**

Replace the entire contents of `tests/testthat/test-resolve.R` with:

```r
make_synthetic_airports <- function() {
  poly <- function(x) sf::st_polygon(list(rbind(
    c(x, 44), c(x + 1, 44), c(x + 1, 43), c(x, 43), c(x, 44)
  )))
  airports <- sf::st_sf(
    AIRPORT_IDENT = c("CYYZ", "CYTZ", "CYHM"),
    NAME = c("Toronto Pearson", "Billy Bishop Toronto City", "Hamilton"),
    POSTAL_CODE = c("L5P", "M5V", "L0R"),
    geometry = sf::st_sfc(poly(-80), poly(-82), poly(-84), crs = 4326)
  )
  attr(airports, "source_url") <- "https://example.com/airports"
  attr(airports, "retrieved_at") <- as.POSIXct("2026-07-08 00:00:00", tz = "UTC")
  airports
}

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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "resolve")'`
Expected: FAIL — `could not find function "resolve"`.

- [ ] **Step 3: Implement `resolve()` and remove `resolve_airport()`**

Replace the entire contents of `R/resolve.R` with:

```r
#' Resolve records from a layer by an identifier or name
#'
#' Attribute lookup (not a spatial operation): given one or more query values,
#' return the matching record(s) from a layer. By default matches an id column
#' exactly or a name column by substring; either can be overridden.
#'
#' @param layer An `sf` object or `data.frame` with attribute columns.
#' @param query A character vector of one or more values to look up.
#' @param by Character. `"ident"` (default) uses the layer's id column with
#'   exact matching; `"name"` uses the name column with substring matching.
#'   The columns are auto-detected. Ignored when `column` is supplied.
#' @param column Character or `NULL`. Overrides the column to match against.
#' @param match Character or `NULL`. `"exact"` or `"substring"`. If `NULL`
#'   (default), derived from `by` (`ident` -> exact, `name` -> substring).
#'
#' @return A [tibble::tibble()] with a `query` column, the layer's non-geometry
#'   columns for matches, and `source_url` / `retrieved_at` provenance. A query
#'   with no match yields one row with `NA` data columns; a single combined
#'   warning lists all unmatched query values.
#'
#' @examples
#' if (interactive()) {
#'   airports <- retrieve_airport()
#'   resolve(airports, "CYYZ")
#'   resolve(airports, "toronto", by = "name")
#' }
#'
#' @export
resolve <- function(layer, query,
                    by = c("ident", "name"), column = NULL, match = NULL) {
  by <- match.arg(by)

  if (!is.character(query)) {
    rlang::abort("`query` must be a character vector.")
  }

  layer_data <- if (inherits(layer, "sf")) {
    tibble::as_tibble(sf::st_drop_geometry(layer))
  } else {
    tibble::as_tibble(layer)
  }

  if (is.null(column)) {
    column <- if (by == "ident") guess_id_col(layer) else guess_name_col(layer)
  }
  if (is.null(match)) {
    match <- if (by == "name") "substring" else "exact"
  }
  match <- rlang::arg_match(match, c("exact", "substring"))

  if (!column %in% colnames(layer_data)) {
    rlang::abort(sprintf("column `%s` not found in `layer`.", column))
  }

  values <- as.character(layer_data[[column]])
  unmatched <- character()

  results <- lapply(query, function(q) {
    if (is.na(q)) {
      matches <- integer()
    } else if (match == "exact") {
      matches <- which(!is.na(values) & tolower(values) == tolower(q))
    } else {
      matches <- which(grepl(q, values, ignore.case = TRUE))
    }

    if (length(matches) == 0) {
      unmatched <<- c(unmatched, q)
      matched <- layer_data[NA_integer_, , drop = FALSE]
    } else {
      matched <- layer_data[matches, , drop = FALSE]
    }
    tibble::add_column(matched, query = rep(q, nrow(matched)), .before = 1)
  })

  if (length(results) == 0) {
    result <- tibble::add_column(
      layer_data[0, , drop = FALSE], query = character(), .before = 1
    )
  } else {
    result <- do.call(rbind, results)
  }

  result$source_url <- provenance_attr(layer, "source_url")
  result$retrieved_at <- provenance_attr(layer, "retrieved_at")

  if (length(unmatched) > 0) {
    rlang::warn(
      paste0("resolve(): no match found for: ", paste(unmatched, collapse = ", "))
    )
  }

  result
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `Rscript -e 'devtools::document(); devtools::test(filter = "resolve")'`
Expected: PASS.

- [ ] **Step 5: Ming review + live-verify + commit**

STOP. Ming verifies against real data: `resolve(retrieve_airport(), "CYYZ")`
returns Toronto Pearson; `resolve(retrieve_airport(), "toronto", by = "name")`
returns the multi-airport set; a bogus code warns and returns an NA row. Ming
commits with Lennon's approval.

---

## Task 5: Documentation consistency (in-repo)

**Files:**
- Modify: `README.md`, `ROADMAP.md`
- Regenerate: `NAMESPACE`, `man/*`

- [ ] **Step 1: Update `README.md` Quick Start**

In `README.md`, change the linking line in the Quick Start block from:

```r
result <- points_to_phu(points, phu)
```
to:
```r
result <- link(points, phu)
```

In the "What ONgeoR Does (v0.1)" list, change the spatial-linking bullet to name
the verbs, e.g.: "Performs spatial linking by geometry type (`link()` for
point/polygon containment, `nearest()` for proximity) and attribute lookup
(`resolve()`)".

- [ ] **Step 2: Update `ROADMAP.md`**

In `ROADMAP.md`:
- Phase 2 "Functions" block: change `points_to_phu(points_sf, phu_sf)` to
  `link(source, target, predicate)` and `build_crosswalk(from_sf, to_sf)` stays.
- Phase 2 Deliverables: change "`R/link.R` -- `points_to_phu()` function" to
  "`R/link.R` -- `link()` and `nearest()` functions".
- Anywhere `facility_to_phu`, `facility_to_region`, `point_to_health_region`, or
  a separate nearest-facility function is named as future work, replace with a
  single note: "facility/region/point linkage is expressed as `link()`;
  proximity as `nearest()` -- no per-source functions."

- [ ] **Step 3: Regenerate docs and namespace**

Run: `Rscript -e 'devtools::document()'`
Expected: writes `man/link.Rd`, `man/nearest.Rd`, `man/resolve.Rd`; removes
`man/points_to_phu.Rd`, `man/polygon_to_polygon.Rd`, `man/nearest_facility.Rd`,
`man/facilities_within.Rd`, `man/resolve_airport.Rd`; updates `NAMESPACE`
exports accordingly.

- [ ] **Step 4: Confirm ASCII-clean (repo pre-commit hook requirement)**

Run: `Rscript -e 'invisible(lapply(list.files(c("R","man"), full.names=TRUE), function(f) { if (any(utf8ToInt(paste(readLines(f, warn=FALSE), collapse="")) > 127)) stop("non-ASCII in ", f) }))'`
Expected: no error (all R/ and man/ files ASCII).

- [ ] **Step 5: Ming review + commit**

STOP. Ming reviews the doc diffs and regenerated man/NAMESPACE, confirms no
dangling references to the removed functions
(`grep -rn "points_to_phu\|polygon_to_polygon\|nearest_facility\|facilities_within\|resolve_airport" R/ man/ README.md ROADMAP.md`
returns nothing). Ming commits with Lennon's approval.

---

## Task 6: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full package check**

Run: `Rscript -e 'devtools::check()'`
Expected: `0 errors | 0 warnings | 0 notes`.

- [ ] **Step 2: Confirm the CLI still works (unchanged, build_crosswalk contract)**

Run: `Rscript -e 'devtools::test(filter = "cli")'`
Expected: PASS (proves `cli.R`'s `build_crosswalk` usage is unaffected).

- [ ] **Step 3: Ming end-to-end live-verify**

Ming runs a real end-to-end flow: retrieve PHU + a facility layer, `link()`
points to PHU, `nearest()` to facilities, `resolve()` an airport, and
`build_crosswalk()` municipal->PHU -- all against the live LIO API -- and
confirms sane output. Final commit (if any cleanup) with Lennon's approval.

---

## Memory reconciliation (Ming, obsidian repo -- not part of Jax packets)

After the in-repo work lands, Ming reconciles the obsidian memory docs per the
spec's "Documentation consistency" section:
- `projects/ongeor/FULL_PLAN.md`: reconcile function lists to the four verbs;
  mark `point_to_phu`/`point_to_health_region`/`facility_to_phu`/
  `facility_to_region`/`polygon_to_polygon`/`resolve_airport` as collapsed into
  `link()`/`nearest()`/`resolve()`.
- `projects/ongeor/TODO.md`: remove `facility_to_phu()`/`facility_to_region()`;
  update the resolver line; record this redesign.
- `projects/ongeor/CURRENT_STATE.md`: document the four-verb API + clean break.
- `projects/ongeor/DECISIONS.md`: update the raster note to reference `link()`;
  record the redesign decision; close the polygon->polygon complex-ops question
  (simplify-first); AND fix the stale claim that `terra` is an installed
  dependency -- it is not in `DESCRIPTION` (Imports: htmlwidgets, httr2,
  leaflet, rlang, sf, tibble, yaml). When raster is actually built, `terra`
  must be added to `DESCRIPTION` first.

---

## Self-Review

**Spec coverage:**
- `link()` (point/polygon + raster seam) -> Task 1. Covered.
- `nearest()` (k + max_dist_km absorbing within-radius) -> Task 2. Covered.
- `resolve()` (by/column/match) -> Task 4. Covered.
- `build_crosswalk()` on `link()`, contract preserved -> Task 3 + regression
  guard. Covered.
- Raster seam stub -> Task 1 Step 3 + test Step 1. Covered.
- Clean break (delete old fns) -> Tasks 1, 2, 4 delete; Task 5 Step 5 greps for
  stragglers. Covered.
- Provenance standardization (source_url/target_url/retrieved_at) -> Task 1/2
  impl + assertions. Covered.
- Doc consistency in-repo (README/ROADMAP) -> Task 5. Memory docs -> Memory
  reconciliation section. Covered.
- predicate default "within" + caveat -> Task 1 roxygen. Covered.
- simplify-first for complex ops -> Task 1 roxygen note. Covered.
- Non-goal: retrieve_* untouched, cli.R untouched -> asserted in File Structure
  + Task 6 Step 2. Covered.

**Placeholder scan:** No TBD/TODO/"handle edge cases"; every code step shows
full code; every run step shows the command + expected result. Clean.

**Type consistency:** `link(source, target, predicate)`, `nearest(source,
target, k, max_dist_km)`, `resolve(layer, query, by, column, match)`,
`build_crosswalk(from, to, method)` used identically across tasks, tests, docs,
and memory sections. Provenance columns named `source_url`/`target_url`/
`retrieved_at` consistently in `link`/`nearest`; `build_crosswalk` maps to
`source_url_from`/`source_url_to` (its unchanged schema). Consistent.
