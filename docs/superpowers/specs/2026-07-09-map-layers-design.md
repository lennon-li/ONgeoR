# ONgeoR map_layers() design

- Date: 2026-07-09
- Status: Approved design, pending implementation plan
- Author: Ming (Claude Code), with Lennon
- Scope: a generic mapping primitive + refactor of the existing
  `map_crosswalk()`. `map_nearest()` deferred to TODO.

## Problem

The roadmap plans per-purpose map functions -- `map_boundaries()` (polygons),
`map_facilities()` (points), `map_nearest()`, `map_crosswalk()`. Building
`map_boundaries`/`map_facilities` as separate functions would re-introduce the
exact per-purpose drift the link+resolve redesign just removed: they differ
only by geometry type. And the geometry-type dispatch already exists -- it is
inlined inside the current `map_crosswalk()` (a loop over layers branching on
`sf::st_geometry_type()`: polygon -> `addPolygons`, point -> `addCircleMarkers`).
It just is not extracted into a reusable primitive.

## Design principle

Mapping follows the same model as linking: one generic primitive dispatching on
geometry type, plus thin opinionated composites on top. `map_layers()` is the
mapping analog of `link()`; `map_crosswalk()` (and future `map_nearest()`) are
the analog of `build_crosswalk()`.

## map_layers() (new, R/map.R)

```r
map_layers(..., colors = NULL)
```

Draws one or more `sf` layers on a single leaflet map, dispatching per layer on
geometry type.

- `...`: one or more `sf` objects (points or polygons). May be named; names set
  the layer's group label (see below). A `SpatRaster` argument aborts with the
  same "raster not yet implemented" seam as `link()` (consistency; raster
  rendering is future work).
- `colors`: optional character vector of colors, one per layer (recycled if
  shorter, named by group if named). If `NULL` (default), distinct colors are
  auto-assigned from a fixed qualitative palette.

Per-layer behavior:
- Geometry dispatch: `POINT`/`MULTIPOINT` -> `leaflet::addCircleMarkers`
  (radius 4, no stroke, fillOpacity 0.8); `POLYGON`/`MULTIPOLYGON`/
  `GEOMETRYCOLLECTION` -> `leaflet::addPolygons` (weight 1, fillOpacity 0.2).
  Any other geometry type aborts with an informative message naming the
  offending type(s). This matches the current `map_crosswalk()` behavior
  exactly, including `GEOMETRYCOLLECTION` handling via
  `extract_polygon_collection()` and dropping empty geometries before drawing.
- Group label (for the layers-control toggle), in priority order:
  1. the argument name, if the layer was passed as a named argument;
  2. the layer's `source_name` provenance attribute, if present;
  3. `"Layer N"` (1-based position) as a last resort.
- Color: each group gets a distinct color (from `colors` if supplied, else the
  auto palette), applied as the marker fill / polygon fill+stroke color.
- Popups: from `guess_name_col()` on each layer (existing helper), matching the
  current map behavior.

Map assembly:
- `leaflet::leaflet() |> leaflet::addTiles()` base, then each layer added with
  its `group`, then `leaflet::addLayersControl(overlayGroups = <all groups>,
  options = layersControlOptions(collapsed = FALSE))`.
- Returns a `leaflet` htmlwidget (also class `htmlwidget`), so callers can pipe
  further leaflet calls.

### Shared internal helper

Extract the per-layer drawing into an internal, non-exported helper in
`R/map.R`:

```r
add_sf_layer(map, layer, group, color)
```

It performs the geometry-type dispatch (point/polygon/geometrycollection/abort)
and returns the updated map. Both `map_layers()` and the refactored
`map_crosswalk()` call it. The `extract_polygon_collection()` helper (currently
in `R/cli.R`) moves to `R/map.R` alongside it, since it is a map-drawing
concern.

## map_crosswalk() refactor (R/cli.R)

Public signature unchanged: `map_crosswalk(layers, from_ids, to_ids)`. It keeps
its CLI-facing role (taking the CLI's named layers-list keyed by source id) but
is reimplemented as a thin wrapper that selects the union of from/to layers and
delegates to `map_layers()`:

```r
map_crosswalk <- function(layers, from_ids, to_ids) {
  ids <- unique(c(from_ids, to_ids))
  do.call(map_layers, layers[ids])
}
```

Because `layers[ids]` is a named list keyed by source id, `map_layers()`
receives named arguments, so the layer-control groups are the source ids --
matching today's `map_crosswalk()` output (which grouped by source id). The
existing `tests/testthat/test-cli.R` assertions
(`map_crosswalk(...)` returns a `leaflet`/`htmlwidget`) are the regression guard
and stay UNCHANGED.

## Deferred to TODO

`map_nearest()` -- an opinionated composite showing input points, connector
lines to their nearest facilities, and the facilities themselves, built on
`map_layers()` and `nearest()`. Recorded as a v0.2 TODO item; not built this
pass.

## Files

- New: `R/map.R` (`map_layers()`, internal `add_sf_layer()`, moved
  `extract_polygon_collection()`), `tests/testthat/test-map.R`,
  `man/map_layers.Rd`.
- Modify: `R/cli.R` (`map_crosswalk()` reimplemented; `extract_polygon_collection()`
  removed -- moved to `R/map.R`), `NAMESPACE` (add `map_layers`).
- Untouched regression guard: `tests/testthat/test-cli.R`.
- Untouched: `R/link.R`, `R/resolve.R`, `R/retrieve.R`, `R/crosswalk.R`,
  `R/cache.R`, `R/utils.R`, `inst/extdata/sources.yaml`.

## Non-goals

- No `map_boundaries()`/`map_facilities()` -- subsumed by `map_layers()`.
- No `map_nearest()` this pass (TODO).
- No raster rendering -- seam aborts, same as `link()`.
- No new styling parameters beyond `colors=` (radius/opacity/weight stay at the
  current sensible defaults). Richer styling is future work if needed.
- No change to `map_crosswalk()`'s public signature or the CLI's behavior.

## Validation

- Unit tests (`tests/testthat/test-map.R`, synthetic sf data): `map_layers()`
  returns a `leaflet`/`htmlwidget`; a two-layer call yields two overlay groups
  with the expected labels (arg name, then `source_name`, then `"Layer N"`); a
  points layer and a polygons layer each render without error; a `SpatRaster`
  argument (faked via `structure(list(), class = "SpatRaster")`) aborts with
  "not yet implemented"; an unsupported geometry type aborts with an
  informative message.
- Regression: `tests/testthat/test-cli.R` (`map_crosswalk`) passes unchanged.
- `devtools::check()`: 0 errors / 0 warnings / 0 notes.
- Live render-and-look (Lennon asked for this explicitly): Ming builds
  `map_layers(retrieve_phu(), <MOH subset>)` against the real LIO API, saves it
  as a self-contained HTML via `htmlwidgets::saveWidget(..., selfcontained =
  TRUE)`, and sends it to Lennon to visually confirm it renders correctly
  (polygons + points, working toggle, correct labels) -- not just that it
  returns an object.

## Documentation consistency

- In-repo: `README.md` (mention `map_layers()` in the "What ONgeoR Does" list;
  optionally a Quick Start line), `ROADMAP.md` (replace
  `map_boundaries`/`map_facilities` references with `map_layers()`; note
  `map_nearest` deferred).
- Memory (Ming reconciles, obsidian): `CURRENT_STATE.md` (record `map_layers()`
  and the `map_crosswalk` refactor), `TODO.md` (remove
  `map_boundaries`/`map_facilities`; add `map_nearest()` as a deferred item),
  `FULL_PLAN.md` (mark the per-purpose Mapping list superseded, like the
  linking/resolvers lists).

## Open flags (decided, recorded)

- Name is `map_layers()`, not `map()`, to avoid masking `purrr::map` /
  `maps::map` when the package is attached.
- `map_crosswalk()` stays exported with an unchanged signature (thin wrapper),
  not demoted/unexported -- avoids a CLI break for no real gain.
