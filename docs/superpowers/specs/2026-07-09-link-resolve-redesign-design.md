# ONgeoR link + resolve API redesign

- Date: 2026-07-09
- Status: Approved design, pending implementation plan
- Author: Ming (Claude Code), with Lennon
- Scope: spatial linking + attribute resolving layers. Retrieval layer
  (`retrieve_*`) deliberately deferred to a separate pass.

## Problem

The package's API drifted into writing one function per named source instead
of per operation. The linking layer is internally inconsistent:
`polygon_to_polygon()` is generic by geometry type, but `points_to_phu()` is
hardcoded to one target; `resolve_airport()` hardcodes a source even though
its logic (id/name matching) is source-agnostic.

The drift was not a deliberate override of a clean design. The planning docs
themselves listed both styles side by side (`FULL_PLAN.md` names both a
generic `point_to_polygon()` and specific `point_to_phu()`/
`point_to_health_region()`), and `ROADMAP.md` Phase 2 operationalized the
specific `points_to_phu()` as the deliverable under a "prove it for PHU
first" framing. Each later addition copied the nearest existing example, and
the dispatch packets explicitly said "follow the existing convention of
specific named functions" -- propagating the source-specific style. Even
`DECISIONS.md`'s raster note cited the inconsistent pair
(`points_to_phu()`, `polygon_to_polygon()`) as if it were a coherent model.

`DECISIONS.md` does, however, already record the correct mental model: raster
linking reduces to point-in-polygon (raster cell -> centroid -> point-in-
polygon; point -> raster cell bbox -> point-in-polygon). That is a
geometry-type-based model. The code just never honored it for the point and
resolve cases.

## Design principle

Dispatch on **geometry type** (spatial linking) and on **attribute**
(resolving), never on named source. Four verbs replace nine functions.

## The verbs

### 1. `link()` -- topological join (R/link.R)

```r
link(source, target, predicate = c("within", "intersects", "contains"))
```

Answers "which target geometry does each source relate to?" Covers
point->polygon, polygon->polygon, and (through the raster seam)
raster->polygon and point->raster.

- `source`: an `sf` object (points or polygons), a `data.frame` with `lon`/
  `lat` columns (converted to `sf` points, CRS 4326 -- preserving today's
  `points_to_phu()` convenience), or a `SpatRaster` (routes to the raster
  seam, see below).
- `target`: an `sf` object (typically polygons).
- `predicate`: maps to `sf::st_within` / `sf::st_intersects` /
  `sf::st_contains`; used as the `join=` predicate in `sf::st_join()`.
- Returns: a `tibble::tibble()` of the source's non-geometry columns + the
  matched target's non-geometry columns + provenance columns `source_url`,
  `target_url`, `retrieved_at`. Column-name collisions between source and
  target follow `sf::st_join()`'s default `.x`/`.y` suffixing (documented).
- Absorbs: `points_to_phu()`, `polygon_to_polygon()`.

Predicate default is `"within"` (textbook-correct: source within target).
The roxygen help must prominently document that real, simplified boundary
data (e.g. municipal boundaries fetched with `simplify = TRUE`) frequently
needs `"intersects"` instead, because `"within"` misses matches against
generalized borders. This is why `cli.R`'s `cross_crosswalk()` hardcodes
`"intersects"`. We keep `"within"` as the default but flag the tradeoff
rather than silently defaulting to `"intersects"`.

### 2. `nearest()` -- proximity join (R/link.R)

```r
nearest(source, target, k = 1, max_dist_km = NULL)
```

For each source geometry, the `k` nearest targets in ascending distance,
optionally capped at `max_dist_km`. `k = Inf, max_dist_km = 5` means "all
targets within 5 km" -- so this single verb honestly absorbs both
`nearest_facility()` and `facilities_within()`.

- `source`/`target`: `sf` (or `data.frame` lon/lat for source). Distances
  computed with `sf::st_distance()` on CRS 4326 geometries directly (no
  reprojection): `sf::sf_use_s2()` is `TRUE`, so the S2 backend returns
  correct geodesic distances natively. Converted to kilometers.
- Semantics: take up to `k` nearest targets per source; when `max_dist_km`
  is set, additionally drop any beyond that distance. A source with no
  targets in range contributes zero rows (no `NA` row). If a source has
  fewer than `k` targets available, return all of them (no padding).
- Returns: source columns + `rank` (1 = nearest) + matched target columns +
  `distance_km` + provenance (`source_url`, `target_url`, `retrieved_at`).
- Absorbs: `nearest_facility()`, `facilities_within()`, and the internal
  `facility_distance_matrix_km()` helper (folded in).
- Known limitation (documented, unchanged from today): uses a full
  source-by-target distance matrix, not a spatial index. Fine at current
  scale; not optimized for very large inputs. Performance work is a v0.3+
  concern per the roadmap.

### 3. `resolve()` -- attribute lookup (R/resolve.R)

```r
resolve(layer, query,
        by     = c("ident", "name"),
        column = NULL,
        match  = NULL)
```

Not a spatial operation: given a human-supplied code or name, return the
matching record(s). Opinionated defaults with an override.

- Target column: if `column` is supplied, use it; otherwise pick it from
  `by` using the existing `guess_id_col()` / `guess_name_col()` helpers
  (`by = "ident"` -> id column, `by = "name"` -> name column).
- Match mode: if `match` is supplied (`"exact"` or `"substring"`), use it;
  otherwise derive from `by` (`ident` -> `"exact"`, `name` -> `"substring"`).
  (`match` defaults to `NULL` so the by-derived default can apply;
  validate against `c("exact", "substring")` when non-NULL.)
- Matching: `"exact"` is case-insensitive equality on the column;
  `"substring"` is case-insensitive `grepl()`.
- Returns: a `tibble::tibble()` with a `query` column (echoing which input
  produced each row), all of the layer's non-geometry columns for matches,
  and provenance (`source_url`, `retrieved_at`). A query with no match
  yields one row with `NA` data columns; after processing all queries, a
  single combined `rlang::warn()` lists every unmatched query value
  (preserving `resolve_airport()`'s exact no-match behavior).
- Absorbs: `resolve_airport()` (its `by = "ident"`/`"name"` behavior is the
  common-case specialization of this generic).

Examples the generic must support:

```r
resolve(airports, "CYYZ")                             # auto id, exact
resolve(airports, "toronto", by = "name")             # auto name, substring
resolve(moh, "M5B", column = "POSTAL_CODE")           # arbitrary col, exact
resolve(moh, "Hosp", column = "SERVICE_TYPE",
        match = "substring")
```

### 4. `build_crosswalk()` -- audit report (R/crosswalk.R)

**Public contract unchanged.** Signature and output schema stay exactly as
today. Reimplemented as a thin opinionated wrapper over `link()`: call
`link(from, to, predicate = method)`, then reshape into the canonical
`from_id`, `from_name`, `from_source`, `to_id`, `to_name`, `to_source`,
`match_method`, `match_distance_km`, `source_url_from`, `source_url_to`,
`retrieved_at` schema using `guess_id_col()`/`guess_name_col()`.
`match_distance_km` stays `NA` (reserved). This is the clean separation:
`link()` is the mechanism; `build_crosswalk()` is the opinionated audit
report on top of it. `tests/testthat/test-crosswalk.R` stays untouched and
serves as the regression guard proving the contract held.

## Raster seam (design now, build later)

`link()` detects `inherits(source, "SpatRaster")` (or target) and routes to
an internal raster-reduction path. For this pass that path is a clear stub:
`rlang::abort("raster linking not yet implemented; see DECISIONS.md raster
linking model")`. No `terra` code executes, no raster tests are written. The
`DECISIONS.md` rules (raster -> centroid -> point-in-polygon; point ->
raster cell bbox -> point-in-polygon) slot into this seam when raster work
is scheduled. `link()`'s roxygen documents raster as a planned capability.

## Migration (clean break)

v0.1 is pre-release (GitHub only, not on CRAN, no external users), so old
names are deleted outright rather than deprecated.

- Delete: `points_to_phu`, `polygon_to_polygon`, `nearest_facility`,
  `facilities_within` (R/link.R); `resolve_airport` (R/resolve.R). Fold away
  `facility_distance_matrix_km`.
- Add: `link`, `nearest` (R/link.R); `resolve` (R/resolve.R).
- Reimplement: `build_crosswalk` on `link` (R/crosswalk.R), same
  signature/output.
- Tests: rewrite `test-link.R` (cover `link` for point->polygon and
  polygon->polygon across predicates; `nearest` for k, k>available,
  max_dist_km radius, zero-in-range) and `test-resolve.R` (ident/name auto,
  column+match override, no-match warning, mixed matched/unmatched).
  `test-crosswalk.R` unchanged (regression guard).
- `cli.R`: unchanged -- it only calls `build_crosswalk`, whose contract is
  preserved. Verified before and re-verified after.
- Regenerate `NAMESPACE` and `man/`.

### Files touched (implementation, in-repo)

`R/link.R`, `R/resolve.R`, `R/crosswalk.R`, `tests/testthat/test-link.R`,
`tests/testthat/test-resolve.R`, `README.md`, `ROADMAP.md`, `NAMESPACE`,
`man/*`. Not touched: `R/cli.R`, `R/retrieve.R`, `R/cache.R`, `R/utils.R`,
`inst/extdata/sources.yaml`, `tests/testthat/test-crosswalk.R`,
`tests/testthat/test-cli.R`, `tests/testthat/test-cache.R`,
`tests/testthat/test-retrieve.R`.

## Documentation consistency

A requirement of this work: every doc that describes the function surface
must reflect the four-verb model. A consequence of the redesign is that it
**shrinks** the planned surface -- several roadmapped functions collapse into
`link()` and should be struck, not renamed:

- `point_to_health_region` -> `link(points, regions)`
- `facility_to_phu` -> `link(facilities, phu)`
- `facility_to_region` -> `link(facilities, regions)`
- `point_to_polygon` (generic, planned) -> `link()`

### In-repo docs (implementation scope)

- `README.md`: Quick Start currently shows `points_to_phu(points, phu)` and
  `build_crosswalk(...)`. Update the linking example to `link(points, phu)`;
  the `build_crosswalk` example stays valid. Add a one-line mention of
  `nearest()` and `resolve()` in the "What ONgeoR Does" list.
- `ROADMAP.md`: Phase 2 lists `points_to_phu()` as a deliverable; Phase 3
  and "Future" reference nearest-facility lookups by the old framing. Update
  function names to `link()`/`nearest()`/`resolve()` and remove the
  now-subsumed `facility_to_*`/`point_to_health_region` items.

### Memory docs (Ming reconciles in the obsidian repo, not Jax)

- `projects/ongeor/FULL_PLAN.md`: reconcile the "Spatial Linking" and
  "Resolvers" function lists to the four-verb model; mark the subsumed
  functions as collapsed into `link()`; note `FULL_PLAN.md`'s file layout is
  historical/aspirational and this spec is the current source of truth.
- `projects/ongeor/TODO.md`: remove `facility_to_phu()` / `facility_to_region()`
  (subsumed by `link()`); update the resolver line to `resolve()`; record
  this redesign.
- `projects/ongeor/CURRENT_STATE.md`: document the four-verb API and the
  clean-break migration.
- `projects/ongeor/DECISIONS.md`: update the raster note to reference
  `link()` (not `points_to_phu()`/`polygon_to_polygon()`); record the
  redesign decision and its rationale; and close the previously-open
  polygon->polygon complex-ops question in favor of simplify-first (no
  zonal/overlay subsystem).

## Provenance column standardization

Today's linking functions attach provenance inconsistently (`points_to_phu`
-> `source_url`; `polygon_to_polygon` -> `source_url_to`). The new `link()`
and `nearest()` standardize on `source_url` (source layer, `NA` when the
source is user-supplied points with no provenance attribute), `target_url`
(target layer), and `retrieved_at` (target's retrieval time).
`build_crosswalk()` maps these onto its existing canonical
`source_url_from`/`source_url_to` schema so its output is unchanged.

## Non-goals / deferred

- Retrieval layer redesign (`retrieve_*` -> `retrieve_source(id)`): deferred
  to a separate pass. Its per-source quirks (simplify defaults, pagination)
  are real config and make it a riskier, different collapse.
- Raster implementation: seam only this pass.
- Polygon->polygon complex/zonal operations (fractional coverage,
  area-weighted overlay): not built, and not needed. Decided 2026-07-09 --
  this closes the open `DECISIONS.md` question in favor of simplify-first:
  for complex geometries, simplify first (either retrieve with
  `simplify = TRUE` for server-side generalization, or `sf::st_simplify()`
  client-side), then use `link()` with a standard predicate. No
  zonal/overlay subsystem, and `link()` gains no `simplify` parameter --
  simplification is a user pre-step, not a link responsibility.
- No new data sources.

## Testing strategy

- Unit tests use synthetic `sf` data only (matching the existing suite); no
  live API calls in automated tests.
- `test-crosswalk.R` is the regression guard that `build_crosswalk()`'s
  contract survived the reimplementation.
- Ming live-verifies each new verb against real LIO data before commit, as
  done for all prior ONgeoR work (retrieve, pagination, resolve_airport,
  nearest_facility).
- Acceptance: `devtools::check()` reports 0 errors / 0 warnings / 0 notes.

## Open flag (decided, recorded here)

`link()`/`build_crosswalk()` default `predicate = "within"`. Documented with
a prominent caveat that simplified boundary data often needs `"intersects"`.
Default not changed.
