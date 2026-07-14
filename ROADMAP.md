# ONgeoR Roadmap

Updated 2026-07-14. Reflects the current implemented state.
`devtools::check()`: 0 errors / 0 warnings / 0 notes.

## Where the package is today

The retrieve → link → crosswalk → map core is **built and live-verified**:

- **Retrieval** — all 7 registered Ontario GeoHub sources (`retrieve_phu()`,
  `retrieve_health_region()`, `retrieve_municipal()`,
  `retrieve_moh_service_locations()` with bounded pagination,
  `retrieve_airport()`, `retrieve_waste_management()`), each with provenance
  and per-layer `simplify` defaults chosen by live testing.
- **On-disk cache** — `~/.cache/R/ONgeoR`, no auto-expiry (boundary data
  changes on the order of years); `--refresh`/`refresh =` to bypass.
- **Four-verb API** — `link()` (topological, by geometry type), `nearest()`
  (proximity/radius), `resolve()` (attribute lookup), `build_crosswalk()`
  (provenance table). No per-source linking functions; raster seam stubbed
  in `link()`.
- **Mapping** — `map_layers()` generic leaflet primitive (dispatches on
  geometry type, auto colors, layer toggle); `map_crosswalk()` as a thin
  wrapper; `map_nearest()` for source points, matched targets, and connector
  lines.
- **CLI** — `Rscript inst/cli/ongeor.R <from_ids> <to_ids> [dir] [--refresh]`
  emits `crosswalk.csv`, self-contained `map.html`, and a standalone
  `reproduce.R`.

## v0.2 — Hardening (next; do this before the UI)

Small, bounded work that makes interactive use dependable. The LIO API has
demonstrated flakiness (504s / "could not access server machines" on some
layers); a script user retries by hand, a UI user just sees a broken app.

- [x] **Bounded retry/backoff** in `fetch_lio_sf()` via `httr2::req_retry()` —
  2–3 attempts, exponential backoff, retry only on transient classes
  (429/5xx/connect timeouts). Deliberately narrow; do NOT reintroduce
  per-object-id fallback loops (see project memory: reverted scope-creep).
- [x] **Actionable error messages** — every user-facing abort says which
  source/layer failed and what to try (`refresh = TRUE`, retry later,
  `simplify` note).
- [x] **Progress signaling** — `cli`/`rlang` progress or messages on fetches
  >2s, so both console and UI users see life during 5–30s retrievals.
- [x] **`map_nearest()`** — composite of `nearest()` + `map_layers()` with
  connector lines (deferred from the map_layers pass).
- [x] **Getting-started vignette** — one end-to-end story (retrieve → link →
  crosswalk → map). The building-crosswalks and adding-data-sources vignettes
  are also complete.
- [x] **Repo hygiene** — removed the obsolete root Phase-1 scripts
  (`test_lio_api.R`, `test_lio_count.R`, `test_spatial_join.R`) and the tracked
  rendered `geohub-inventory.html`; retained the Markdown and CSV inventory.

## v0.3 — Shiny UI (start once retry/backoff + progress land)

**Goal:** a thin UI over the package — no logic in the app that isn't already
a package function. The CLI proved the workflow; the UI is the same workflow
with pickers.

- [ ] MVP: pick from-sources and to-sources (from `list_sources()`) →
  build crosswalk → show table + `map_layers()` leaflet → download
  `crosswalk.csv` / `map.html` / `reproduce.R` (reuse
  `render_reproducer_script()`).
- [ ] Long fetches run async (`ExtendedTask`/promises) with the v0.2 progress
  hooks; cache makes repeat runs fast.
- [ ] `nearest()` tab: upload points CSV → nearest facilities → `map_nearest()`.
- [ ] Ship as `inst/shiny/` + `run_app()` export (package stays
  installable without Shiny: `Suggests`, not `Imports`).

## v0.4 — Expansion (order by demand, not sequence)

- [ ] **Raster linking** — design already decided (cell-centroid → polygon;
  point → cell-bbox; see project memory DECISIONS). Add `terra` to
  `DESCRIPTION` first; implement inside the existing `link()` seam.
- [ ] **New sources** — census subdivisions (StatCan), transit, environment;
  each needs a registry entry + live simplify/pagination testing.
- [ ] **Performance** — spatial-indexed nearest-neighbor for large point sets
  (current full distance matrix is fine at present scale).
- [ ] pkgdown site and GitHub issue templates.

## Blocked (data-source questions, not code)

- `resolve_postal()` — needs a licensed/user-supplied PCCF; no free LIO
  equivalent. Decide the source before building anything.
- `resolve_terminal()` — no registered LIO source (ORWN Station/rail is
  FALSE-flagged); scope undefined.
