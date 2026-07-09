# map_layers() Implementation Plan

> **For agentic workers:** Executed via **Jax dispatch** (`ming-calling-jax`),
> one packet per task. Jax writes code + tests and runs
> `devtools::document()`/`devtools::check()`; Jax NEVER commits. After each task,
> Ming reviews the diff, live-verifies, and commits with Lennon's approval.
> Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add a generic `map_layers()` mapping primitive that dispatches on
geometry type, and refactor `map_crosswalk()` to delegate to it.

**Architecture:** `map_layers()` (new, `R/map.R`) is the mapping analog of
`link()`: it draws any sf layers on a leaflet map, dispatching per layer on
geometry type. `map_crosswalk()` becomes a thin wrapper over it. Group labeling
is factored into a pure helper so it can be tested without leaflet
introspection.

**Tech Stack:** R package; `leaflet`, `sf`, `rlang`; `testthat` edition 3;
roxygen2 8.0.0.

**Spec:** `docs/superpowers/specs/2026-07-09-map-layers-design.md`

---

## File Structure

- `R/map.R` — NEW: exported `map_layers()`; internal `layer_group_labels()`
  (pure, testable), `add_sf_layer()`, and `extract_polygon_collection()` (moved
  verbatim from `R/cli.R`).
- `R/cli.R` — remove `extract_polygon_collection()` (moved); Task 2 reimplements
  `map_crosswalk()` as a wrapper.
- `tests/testthat/test-map.R` — NEW.
- `tests/testthat/test-cli.R` — UNCHANGED (regression guard for `map_crosswalk`).
- `README.md`, `ROADMAP.md` — doc consistency.
- `NAMESPACE`, `man/*` — regenerated.

Reused existing helpers (same namespace): `guess_name_col()`,
`provenance_attr()` (`R/utils.R`).

---

## Task 1: `map_layers()` + helpers in `R/map.R`

**Files:**
- Create: `R/map.R`
- Modify: `R/cli.R` (remove `extract_polygon_collection()`)
- Test: `tests/testthat/test-map.R`

- [ ] **Step 1: Write failing tests**

Create `tests/testthat/test-map.R` with:

```r
make_map_points <- function(source_name = NULL) {
  pts <- sf::st_as_sf(
    data.frame(NAME = c("A", "B"), lon = c(-79, -80), lat = c(43, 44)),
    coords = c("lon", "lat"), crs = 4326
  )
  if (!is.null(source_name)) attr(pts, "source_name") <- source_name
  pts
}

make_map_polys <- function() {
  poly <- sf::st_polygon(list(rbind(
    c(-80, 44), c(-79, 44), c(-79, 43), c(-80, 43), c(-80, 44)
  )))
  sf::st_sf(PHU_NAME_ENG = "Unit A", geometry = sf::st_sfc(poly, crs = 4326))
}

test_that("map_layers returns a leaflet htmlwidget for polygons", {
  m <- map_layers(make_map_polys())
  expect_s3_class(m, "leaflet")
  expect_s3_class(m, "htmlwidget")
})

test_that("map_layers renders points and polygons together", {
  m <- map_layers(make_map_polys(), make_map_points())
  expect_s3_class(m, "leaflet")
  expect_s3_class(m, "htmlwidget")
})

test_that("layer_group_labels prefers arg name, then source_name, then position", {
  named <- layer_group_labels(list(units = make_map_polys(), pts = make_map_points()))
  expect_equal(named, c("units", "pts"))

  from_prov <- layer_group_labels(list(
    make_map_polys(),
    make_map_points(source_name = "MOH Service Location")
  ))
  expect_equal(from_prov, c("Layer 1", "MOH Service Location"))
})

test_that("map_layers aborts on a raster layer (seam not implemented)", {
  fake_raster <- structure(list(), class = "SpatRaster")
  expect_error(map_layers(fake_raster), "not yet implemented")
})

test_that("map_layers aborts on an unsupported geometry type", {
  line <- sf::st_sf(
    NAME = "L",
    geometry = sf::st_sfc(sf::st_linestring(rbind(c(-79, 43), c(-80, 44))), crs = 4326)
  )
  expect_error(map_layers(line), "unsupported geometry")
})

test_that("map_layers requires at least one layer", {
  expect_error(map_layers(), "at least one")
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "map")'`
Expected: FAIL — `could not find function "map_layers"`.

- [ ] **Step 3: Create `R/map.R`**

Create `R/map.R` with the following (ASCII only — the pre-commit hook rejects
non-ASCII in R files):

```r
#' Map one or more layers on an interactive leaflet map
#'
#' Draws each `sf` layer on a single leaflet map, dispatching on geometry type:
#' polygons are drawn as filled outlines, points as circle markers. Layers get
#' a toggle in a layers-control. Raster layers are planned but not yet
#' implemented.
#'
#' @param ... One or more `sf` objects (points or polygons). Arguments may be
#'   named; a name sets that layer's group label. A `SpatRaster` argument
#'   aborts (raster mapping is not yet implemented).
#' @param colors Optional character vector of colors, one per layer (recycled if
#'   shorter). If `NULL` (default), distinct colors are assigned from a built-in
#'   qualitative palette.
#'
#' @return A `leaflet` htmlwidget.
#'
#' @examples
#' if (interactive()) {
#'   map_layers(retrieve_phu(), retrieve_moh_service_locations(service_type = "Hospital"))
#' }
#'
#' @export
map_layers <- function(..., colors = NULL) {
  layers <- list(...)
  if (length(layers) == 0) {
    rlang::abort("map_layers() requires at least one sf layer.")
  }

  for (layer in layers) {
    if (inherits(layer, "SpatRaster")) {
      rlang::abort(
        "raster mapping not yet implemented; see the package raster linking model"
      )
    }
  }

  groups <- layer_group_labels(layers)

  palette <- c(
    "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
    "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf"
  )
  layer_colors <- if (is.null(colors)) {
    palette[((seq_along(layers) - 1) %% length(palette)) + 1]
  } else {
    rep(colors, length.out = length(layers))
  }

  map <- leaflet::addTiles(leaflet::leaflet())
  for (i in seq_along(layers)) {
    map <- add_sf_layer(map, layers[[i]], groups[i], layer_colors[i])
  }

  leaflet::addLayersControl(
    map,
    overlayGroups = groups,
    options = leaflet::layersControlOptions(collapsed = FALSE)
  )
}

#' Derive group labels for map layers
#'
#' Priority: the argument name, then the layer's `source_name` provenance
#' attribute, then a positional `"Layer N"`.
#'
#' @param layers A list of `sf` layers, optionally named.
#' @return Character vector of group labels, one per layer.
#' @keywords internal
#' @noRd
layer_group_labels <- function(layers) {
  arg_names <- names(layers)
  vapply(seq_along(layers), function(i) {
    if (!is.null(arg_names) && nzchar(arg_names[i])) {
      return(arg_names[i])
    }
    src <- provenance_attr(layers[[i]], "source_name")
    if (!is.null(src) && !is.na(src) && nzchar(as.character(src))) {
      return(as.character(src))
    }
    paste("Layer", i)
  }, character(1))
}

#' Add a single sf layer to a leaflet map by geometry type
#'
#' @param map A leaflet map.
#' @param layer An `sf` object of points or polygons.
#' @param group Character group label for the layers-control.
#' @param color Character color for the layer.
#' @return The updated leaflet map.
#' @keywords internal
#' @noRd
add_sf_layer <- function(map, layer, group, color) {
  name_col <- guess_name_col(layer)
  geometry_types <- unique(as.character(sf::st_geometry_type(layer)))
  polygon_types <- c("POLYGON", "MULTIPOLYGON", "GEOMETRYCOLLECTION")

  if (all(geometry_types %in% c("POINT", "MULTIPOINT"))) {
    popups <- as.character(layer[[name_col]])
    leaflet::addCircleMarkers(
      map,
      data = layer,
      group = group,
      popup = popups,
      radius = 4,
      stroke = FALSE,
      fillColor = color,
      fillOpacity = 0.8
    )
  } else if (all(geometry_types %in% polygon_types)) {
    polygon_layer <- if ("GEOMETRYCOLLECTION" %in% geometry_types) {
      extract_polygon_collection(layer)
    } else {
      layer
    }
    polygon_layer <- polygon_layer[!sf::st_is_empty(polygon_layer), ]
    popups <- as.character(polygon_layer[[name_col]])
    leaflet::addPolygons(
      map,
      data = polygon_layer,
      group = group,
      popup = popups,
      weight = 1,
      color = color,
      fillColor = color,
      fillOpacity = 0.2
    )
  } else {
    rlang::abort(sprintf(
      "Layer '%s' has unsupported geometry type(s): %s.",
      group,
      paste(geometry_types, collapse = ", ")
    ))
  }
}

#' Reduce GEOMETRYCOLLECTION geometries to their polygon parts
#'
#' @param layer An `sf` object that may contain `GEOMETRYCOLLECTION` geometries.
#' @return The `sf` object with each `GEOMETRYCOLLECTION` replaced by its
#'   combined polygon parts (empty polygon if it has none).
#' @keywords internal
#' @noRd
extract_polygon_collection <- function(layer) {
  geometries <- sf::st_geometry(layer)
  polygon_geometries <- lapply(geometries, function(geometry) {
    geometry_type <- as.character(sf::st_geometry_type(geometry))
    if (geometry_type != "GEOMETRYCOLLECTION") {
      return(geometry)
    }

    extracted <- suppressWarnings(
      sf::st_collection_extract(
        sf::st_sfc(geometry, crs = sf::st_crs(layer)),
        "POLYGON"
      )
    )
    if (length(extracted) == 0) {
      return(sf::st_polygon())
    }
    sf::st_combine(extracted)[[1]]
  })

  sf::st_geometry(layer) <- sf::st_sfc(polygon_geometries, crs = sf::st_crs(layer))
  layer
}
```

- [ ] **Step 4: Remove the duplicate `extract_polygon_collection()` from `R/cli.R`**

Delete the `extract_polygon_collection()` function definition (the block at
`R/cli.R` lines 159-181) from `R/cli.R`. Do NOT change `map_crosswalk()` in this
task — its inline loop still calls `extract_polygon_collection()`, which now
lives in `R/map.R` (same package namespace, so the call still resolves).

- [ ] **Step 5: Regenerate docs and run tests**

Run: `Rscript -e 'devtools::document(); devtools::test(filter = "map")'`
Expected: all `map` tests PASS. `devtools::document()` writes `man/map_layers.Rd`
and adds `map_layers` to `NAMESPACE`.

Then run: `Rscript -e 'devtools::test(filter = "cli")'`
Expected: PASS — `map_crosswalk()` still works (calls the moved
`extract_polygon_collection()`).

- [ ] **Step 6: Full check**

Run: `Rscript -e 'devtools::check()'`
Expected: 0 errors / 0 warnings / 0 notes.

- [ ] **Step 7: Ming review + live-verify + commit**

STOP. Ming verifies against real data: `map_layers(retrieve_phu())` and
`map_layers(retrieve_phu(), retrieve_moh_service_locations(service_type = "Hospital"))`
each return a `leaflet`/`htmlwidget` and build without error. Ming commits with
Lennon's approval.

---

## Task 2: Refactor `map_crosswalk()` to a wrapper

**Files:**
- Modify: `R/cli.R`
- Test: `tests/testthat/test-cli.R` (UNCHANGED — regression guard)

- [ ] **Step 1: Confirm the regression test currently passes (baseline)**

Run: `Rscript -e 'devtools::test(filter = "cli")'`
Expected: PASS.

- [ ] **Step 2: Reimplement `map_crosswalk()` as a wrapper**

In `R/cli.R`, replace the entire `map_crosswalk()` function (its body currently
loops over layers and draws each) with this. Keep its roxygen block unchanged:

```r
map_crosswalk <- function(layers, from_ids, to_ids) {
  ids <- unique(c(from_ids, to_ids))
  do.call(map_layers, layers[ids])
}
```

Because `layers[ids]` is a named list keyed by source id, `map_layers()`
receives named arguments and the layers-control groups become the source ids —
matching the previous behavior.

- [ ] **Step 3: Run the regression test**

Run: `Rscript -e 'devtools::test(filter = "cli")'`
Expected: PASS — `map_crosswalk()` still returns a `leaflet`/`htmlwidget`.

- [ ] **Step 4: Full check**

Run: `Rscript -e 'devtools::check()'`
Expected: 0 errors / 0 warnings / 0 notes.

- [ ] **Step 5: Ming review + live-verify + commit**

STOP. Ming verifies against real data via the CLI path: a run that crosses a
polygon source and a point source produces a `map.html` that opens with both
layers and a working toggle. Ming commits with Lennon's approval.

---

## Task 3: Documentation consistency (in-repo)

**Files:**
- Modify: `README.md`, `ROADMAP.md`
- Regenerate: `NAMESPACE`, `man/*` (no-op if already current)

- [ ] **Step 1: Update `README.md`**

In the "What ONgeoR Does" list, add mapping to the linking/resolving bullet or a
new bullet, e.g.: "Draws interactive leaflet maps of any layers by geometry type
with `map_layers()`." Optionally add a Quick Start line:

```r
# Map health-unit boundaries and hospitals together
map_layers(phu, retrieve_moh_service_locations(service_type = "Hospital"))
```

- [ ] **Step 2: Update `ROADMAP.md`**

In `ROADMAP.md`, replace any `map_boundaries()` / `map_facilities()` references
with `map_layers()`, and note `map_nearest()` is deferred. Add a line: "Mapping
dispatches on geometry type via `map_layers()`; `map_crosswalk()` is a thin
wrapper over it."

- [ ] **Step 3: Regenerate and grep for stragglers**

Run: `Rscript -e 'devtools::document()'`
Run: `grep -rn "map_boundaries\|map_facilities" R/ man/ README.md ROADMAP.md`
Expected: no matches.

- [ ] **Step 4: Ming review + commit**

STOP. Ming reviews the doc diffs. Ming commits with Lennon's approval.

---

## Task 4: Full verification + live render

**Files:** none (verification only)

- [ ] **Step 1: Full check**

Run: `Rscript -e 'devtools::check()'`
Expected: 0 errors / 0 warnings / 0 notes.

- [ ] **Step 2: CLI regression**

Run: `Rscript -e 'devtools::test(filter = "cli")'`
Expected: PASS.

- [ ] **Step 3: Render a real map to self-contained HTML and send to Lennon**

Ming runs, against the live LIO API:

```r
devtools::load_all()
m <- map_layers(
  retrieve_phu(),
  retrieve_moh_service_locations(service_type = "Hospital")
)
htmlwidgets::saveWidget(m, "map-layers-demo.html", selfcontained = TRUE)
```

Ming confirms the HTML is non-empty, then sends `map-layers-demo.html` to Lennon
(SendUserFile) to visually confirm: PHU polygons + hospital points both render,
the layer toggle works, and labels are correct. This is the render-and-look
validation Lennon asked for — not just a class check.

---

## Memory reconciliation (Ming, obsidian repo — not part of Jax packets)

- `projects/ongeor/CURRENT_STATE.md`: record `map_layers()` and the
  `map_crosswalk` refactor.
- `projects/ongeor/TODO.md`: remove `map_boundaries`/`map_facilities` from the
  map candidates; add `map_nearest()` (points + connector lines + nearest
  facilities, on `map_layers()`) as a deferred item.
- `projects/ongeor/FULL_PLAN.md`: mark the per-purpose Mapping function list
  superseded (as the linking/resolvers lists already are).

---

## Self-Review

**Spec coverage:**
- `map_layers()` (geometry dispatch, groups, colors, popups, raster seam,
  leaflet return) -> Task 1. Covered.
- `add_sf_layer()` shared helper + `extract_polygon_collection()` move -> Task 1.
  Covered.
- `map_crosswalk()` thin wrapper, contract preserved -> Task 2 + regression
  guard. Covered.
- `map_nearest()` deferred -> Memory reconciliation (TODO). Covered.
- Doc consistency (README/ROADMAP in-repo; memory) -> Task 3 + Memory section.
  Covered.
- Validation incl. render-and-send HTML -> Task 4. Covered.
- Name is `map_layers()` (not `map()`) -> Task 1 impl. Covered.

**Placeholder scan:** No TBD/TODO; every code step shows full code; every run
step shows command + expected result. Clean.

**Type consistency:** `map_layers(..., colors)`, `layer_group_labels(layers)`,
`add_sf_layer(map, layer, group, color)`, `extract_polygon_collection(layer)`,
`map_crosswalk(layers, from_ids, to_ids)` used identically across tasks, tests,
and docs. Consistent.
