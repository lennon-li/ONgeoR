# ONgeoR Roadmap

This document describes the phased delivery plan for the ONgeoR package. The guiding principle: start small and demonstrate the core loop on real Ontario data, then grow the source registry and linking functions as verified sources accumulate.

## Current Status: Pre-v0.1 (Repository Bootstrapped)

- [x] Repository created
- [x] README written
- [x] Full vision plan captured (`projects/ongeor/FULL_PLAN.md`)
- [x] Reconnaissance brief drafted for data-source inventory
- [ ] GeoHub / LIO REST API inventory complete (in progress)
- [ ] Source URLs verified for at least one real dataset

---

## v0.1 — MVP

**Goal:** An installable R package that demonstrates the core loop (registry → retrieve → link → crosswalk → map) on real Ontario data from the LIO REST API.

### Package skeleton
- [ ] `DESCRIPTION`, `NAMESPACE`, `LICENSE`, `.Rbuildignore`
- [ ] R 4.1+ minimum (to match sf / modern tidyverse)
- [ ] Imports: `sf`, `dplyr`, `tibble`, `yaml`, `cli`, `httr2`, `ggplot2`, `rlang`

### Source registry
- [ ] `inst/sources/sources.yml` with ≥3 verified LIO Open Data layers:
    - `phu_boundaries` → LIO_Open09 / layer 44 (MOH Public Health Unit Boundary)
    - `ontario_health_regions` → LIO_Open09 / layer 52 (Ontario Health Region)
    - `municipal_boundaries` → LIO_Open03 / layers 13 + 14
    - `airports` → LIO_Open05 / layers 0, 1
- [ ] `list_sources()` — print available sources with type, geography, status
- [ ] `get_source(id)` — return metadata for one source as a list/tibble
- [ ] `validate_source_registry()` — assert required fields exist on every entry

### Data retrieval
- [ ] `retrieve_source(id)` — general fetcher that reads YAML, hits the ArcGIS REST endpoint with `f=geojson`, caches under `tools::R_user_dir("ongeor", "cache")`, returns `sf`
- [ ] Per-source cache keying by layer URL + retrieval timestamp
- [ ] Error handling: HTTP failures, empty results, non-FeatureLayer responses

### Spatial linking
- [ ] `point_to_polygon(points, polygons, lon, lat, crs)` — generic point-in-polygon join
- [ ] `point_to_phu(points, ...)` — convenience wrapper over `point_to_polygon` with PHU layer
- [ ] `polygon_to_polygon(from, to, method)` — intersect / contains / within for boundary layers (municipality → PHU, etc.)
- [ ] `nearest_facility(points, facilities, n, max_distance_km)` — `sf::st_nearest_feature` with distance calculation
- [ ] `build_crosswalk(from, to, method)` — auditable link table with standard output schema:
    - `input_id, input_name, input_type, input_source`
    - `target_id, target_name, target_type, target_source`
    - `match_method, match_distance_km, match_confidence`
    - `source_url, source_date, retrieved_at, ongeor_version`

### Mapping
- [ ] `map_boundaries(boundaries, fill, title)` — ggplot2 + sf plot of one or more boundary layers

### Tests
- [ ] `testthat` suite using **synthetic data only** (no real geodata in tests)
- [ ] Source registry loads + validates required fields
- [ ] Point-in-polygon join returns correct polygon for synthetic points
- [ ] Nearest-facility returns correct row + distance
- [ ] Crosswalk output has the required schema columns

### Documentation
- [ ] README (exists) with positioning, install, quickstart
- [ ] `roxygen2` documentation on every exported function
- [ ] `devtools::check()` passes with 0 errors, 0 warnings

### Success criteria
`devtools::check()` clean, source registry validates, synthetic point → PHU join works, crosswalk output schema matches spec, zero real geodata bundled.

---

## v0.2 — Broaden Sources and Linking Functions

- [ ] Add more LIO layers to registry (environmental health, schools, child care if present on LIO)
- [ ] `retrieve_boundary()` and `retrieve_facilities()` as typed wrappers
- [ ] `facility_to_phu()`, `facility_to_region()`, `facilities_within()` (radius search)
- [ ] Resolver stubs: `resolve_postal()` that requires a user-supplied source (PCCF etc.) — explicit `stop()` until a licensed source is provided
- [ ] Additional map functions: `map_facilities()`, `map_crosswalk()`, `map_nearest()`
- [ ] Three vignettes: `getting-started`, `adding-data-sources`, `building-crosswalks`
- [ ] GitHub issue templates: `data-source-request.yml`, `bug_report.yml`, `feature_request.yml`
- [ ] Full facility group taxonomy (`healthcare`, `congregate_living`, `education_childcare`, `transportation`, `environmental_health`, `community_services`)

---

## v0.3 — Resolvers and Community Sources

- [ ] `resolve_location()`, `resolve_facility()`, `resolve_airport()`, `resolve_terminal()`
- [ ] User-supplied postal code source integration (PCCF workflow)
- [ ] `add_source_template()` — scaffolds a new YAML entry for contributor PRs
- [ ] Community-contributed sources from GitHub issue templates
- [ ] Optional interactive maps (`leaflet`, `mapview`) behind `Suggests`

---

## v1.0 — Production Readiness

- [ ] `pkgdown` documentation site
- [ ] GitHub Actions R-CMD-check workflow (ubuntu, macos, windows)
- [ ] `cran-comments.md` and CRAN submission prep (if desired)
- [ ] Performance evaluation: large boundary layers, `data.table` / `arrow` backends
- [ ] Integration layer for `cancensus` (census geographies) and `tidytransit` (GTFS)

---

## Non-Goals (Explicit)

- Bundling boundary files or facility datasets inside the package
- Hosting or mirroring licensed data (PCCF, proprietary facility lists)
- Replacing authoritative sources — ONgeoR retrieves from them, it does not supersede them
- Real-time data feeds — sources are snapshot-retrievable, not streaming

---

## Constraints (Always)

- No unverified source URLs in the registry — placeholders are fine, lying URLs are not
- No bundled data larger than a few KB (synthetic test fixtures only)
- Every function that touches external data must attach retrieval metadata to its output
- `devtools::check()` stays clean at every version
