# ONgeoR Roadmap

Updated 2026-08-21. This file is the active project task list and should reflect
shipped repository state. Completed implementation plans belong in project
history, not in the pending queue.

## Current status

ONgeoR 0.4.0 is feature-complete for the retrieve → link → crosswalk → map
workflow, with the Shiny app split out to its own package
([ONgeoRapp](https://github.com/lennon-li/ONgeoRapp)) so that ONgeoR can go to
CRAN. Pre-submission checks are verified (R CMD check --as-cran clean);
submission itself is pending.

**Scope note.** This file tracks ONgeoR only. Work that belongs to the Shiny
app now lives in ONgeoRapp's own queue; items still listed here that are
app-owned are marked as such and should be moved, not worked, from this repo.

### Shipped

- **Retrieval** — 45 registered sources, including the bundled HIVE grid,
  a bundled 2,407-station monitoring subset, and a synthetic raster, with
  provenance,
  bounded pagination with truncation detection, retry/backoff, actionable
  errors, progress messages, cache max_age, and
  source-specific simplification defaults. Live monitoring-station retrieval
  paginates automatically across pages of 2,000 features.
- **Caching** — on-disk cache at `~/.cache/R/ONgeoR`; `refresh = TRUE` and CLI
  `--refresh` bypass cached data.
- **Core API** — `link()`, `nearest()`, `resolve()`, and `build_crosswalk()`;
  weighted crosswalks and registry-driven column selection are shipped.
- **Mapping** — `map_layers()`, `map_crosswalk()`, and `map_nearest()`.
- **CLI** — creates `crosswalk.csv`, self-contained `map.html`, and a standalone
  `reproduce.R` script.
- **Documentation** — getting-started, crosswalk, and data-source contribution
  vignettes.
- **Postal resolution** — `resolve_postal()` maps Ontario postal codes to
  dissemination areas from the OPCC M5 correspondence (checksum-verified,
  cached after first download); `normalize_postal_code()` and
  `render_postal_reproducer_script(all_links = )` included.
  `resolve_postal_points()` returns coordinates for a named list of codes, and
  `retrieve_postal_points(bbox = )` offers the whole OPCC M1 release (299,782
  placeable codes) as an ordinary retrievable layer, registered as source id
  `postal_points` (`bcc868e`).
- **Statistics Canada 2021 census geography** — fourteen retrievable
  boundary sources (`census_pr_2021` through `census_fsa_2021`), including
  census subdivisions, dissemination areas, and forward sortation areas, with
  a shared bbox convention for windowing large layers.
- **ON-Marg marginalization** — `retrieve_onmarg()`, `add_onmarg()`, and
  `onmarg_geographies()` attach the 2021 PHO measures to a boundary layer
  (`b33311d`). The workbook's licence forbids modification, so it is fetched
  at runtime against a pinned SHA-256 and held in session memory only: never
  bundled, never written to the disk cache. Join keys come from the registry's
  `key_fields`, never from `guess_id_col()`. Eight of ten sheets map to a
  retrievable boundary layer; LHIN and LHIN sub-region have none.
- **Raster linking** — `link()` samples a `SpatRaster` through the existing
  geometry-dispatch seam, `map_layers()` draws it, and `terra` is a declared
  import. Raster-to-raster linking is refused explicitly.
- **Shiny app** — split to its own package
  [ONgeoRapp](https://github.com/lennon-li/ONgeoRapp): source linking,
  nearest-facility search, postal-to-DA joining, interactive maps,
  data tables, map styling, basemap selection, and downloads.
- **Repository hygiene** — obsolete phase-one scripts and rendered inventory
  output removed.

## Current milestone — v0.3 consolidation

**Status 2026-08-04:** complete and superseded — v0.4.0 has shipped (app
split, postal resolution, monitoring stations, HIVE validity repair). The
remaining open item is the CRAN submission itself; see `cran-comments.md`.

**Goal:** make the shipped MVP internally consistent, package-driven rather
than app-driven, repeatably tested, and protected by CI before adding more data
sources or raster support.

**Status 2026-07-18:** [issue #1](https://github.com/lennon-li/ONgeoR/issues/1)
is complete (commits `9dda143`, `bed1602`); evidence is recorded per item
below. Residual validation gaps are listed as new unchecked items — close
them opportunistically, they do not block v0.4.

### v0.3.1 registry-drift fix pass (2026-07-19)

An audit found that the v0.3 "same product state" gate had regressed when the
conservation authority and ORWN station sources were added: the registry, the
`retrieve_source()` dispatch, the reproducer's call table, and the app/vignette
prose had drifted apart. Fixed in this pass:

- [x] `retrieve_source()` dispatches `conservation_authority` and
  `orwn_station`; `source_retrieve_call()` covers those plus
  `synthetic_air_quality` and `hive`.
- [x] Registry-dispatch completeness tests: every `list_sources()` id must
  dispatch through `retrieve_source()` and `source_retrieve_call()`, so a
  future registry addition fails tests until both switches are extended.
- [x] `reproduce.R` now reproduces the app run: overlay-as-from direction and
  the user's chosen match rule are recorded (`render_reproducer_script()` and
  `cross_crosswalk()` gained a `method` argument); the download is disabled
  for raster runs, whose linked-values output the script cannot rebuild.
- [x] Cache `retrieved_at` metadata written in UTC (was local time parsed as
  UTC, inflating cache ages by the UTC offset), with a timezone round-trip
  test.
- [x] Pagination advances by rows actually returned, not requested page size,
  and aborts on an empty truncated page — guards against silent feature loss
  if the server caps pages below `resultRecordCount`.
- [x] `weighted` match rule exposed in the app; app help modal, vignette, and
  roxygen tell the same five-rule story again.
- [x] `run_app()` checks all app dependencies (`shiny`, `bslib`, `DT`,
  `promises`, `future`) up front.
- [x] README/ROADMAP staleness: raster linking described as shipped, all
  eleven registry sources listed, Statistics Canada marked planned, shiny-app
  vignette linked, source count corrected.
- Evidence: suite 568 pass / 0 fail / 0 skip after changes (2026-07-19);
  baseline before changes 471 pass / 0 fail. Implementation: venQ-supervised
  worker packets for the mechanical fixes plus direct edits for multi-file
  changes; full trial log in the agent memory repo.

Residual (non-blocking). Status as of the 2026-08-21 audit:

- [x] `nearest()` does not validate `k`. Fixed: `validate_k()` rejects a `k`
  that is not a single positive whole number or `Inf`, with condition class
  `ongeor_invalid_k`. `k = 0` was the damaging case — it returned an empty
  tibble with no condition, so "no matches found" and "you asked for zero
  matches" were indistinguishable.
- [x] `clear_cache(source_id)` fails on a corrupt sidecar. Fixed:
  `clear_cache()` and `list_cache()` now read sidecars through
  `cache_read_sidecar()`, which returns `NULL` instead of aborting, and warn
  with class `ongeor_unreadable_sidecar`. A targeted clear leaves an
  unattributable entry in place and names the way out; `list_cache()` reports
  it with `NA` metadata rather than hiding it.
- [ ] Registry YAML re-read on every `load_source_registry()` call
  (memoization). Measured 2026-08-21 at 2.8 ms per parse across four call
  sites; `registry_entry_for()` pays it once per layer. Real but small, and a
  memo has to be keyed so that a `data-raw` edit to `sources.yaml` cannot be
  served stale.
- [ ] Raster runs still have no reproducer story.
- [ ] **ONgeoRapp-owned:** app "Use my own file" controls are inert
  placeholders — hide or implement. Move to that repo's queue.

### P0 — Reconcile project state

- [x] Remove completed v0.2 and Shiny MVP work from the pending task list.
- [x] Update `DESCRIPTION` to an appropriate development version, such as
  `0.3.0.9000`, or document a different versioning convention.
- Evidence: done in v0.3 bugfix pass, 2026-07-18.
- [x] Update the README version label and describe the Shiny MVP as shipped.
- Evidence: done in v0.3 bugfix pass, 2026-07-18.
- [x] Replace or deliberately remove placeholder contact details in
  `DESCRIPTION` and README.
- Evidence: done in v0.3 bugfix pass, 2026-07-18.
- [x] Define explicit v0.3 acceptance criteria and record the validation result
  when the milestone closes.
- Evidence: the acceptance gates below served as the criteria; validation
  recorded 2026-07-18 — suite 501 pass / 0 fail, offline-deterministic
  (passes with network blocked); `R CMD check --as-cran` 0/0/0 Status OK;
  browser smoke 7/7 in headless Chrome (installed-mode).

**Acceptance gate:** repository documentation, package metadata, and the actual
implementation describe the same product state.

### P0 — Make the Shiny app a thin package interface

The app should coordinate inputs and outputs. Spatial, retrieval, validation,
and map-construction logic should live in testable package functions.

- [x] Replace `ONgeoR:::` calls in `inst/shiny/app.R` with supported package
  interfaces.
- Evidence: zero `:::` in app.R; `guess_name_col()`,
  `extract_polygon_collection()`, `render_reproducer_script()` exported
  (`9dda143`).
- [x] Formalize a public or stable internal source-ID retrieval interface.
- Evidence: `retrieve_source()` exported (`d9d0d0c`); used by CLI, app, and
  `tools/live-smoke.R`.
- [x] Move nearest-match layer and connector construction out of `app.R` into a
  package function shared with `map_nearest()`.
- Evidence: `build_nearest_layers()` exported; `map_nearest()` delegates to
  it; app's 48-line duplicate removed (`9dda143`).
- [x] Move geometry dispatch and styled-layer rendering into `map_layers()` or
  a reusable package-level mapping interface.
- Evidence: resolved by design decision, not literal move — the algorithmic
  duplication (nearest/connector construction) moved into the package;
  styled rendering stays app-level as pure presentation (deliberate
  2026-07-15 decision to bypass `map_layers()` baked-in colors). The
  acceptance gate below is satisfied: no package algorithm is
  reimplemented in app.R.
- [x] Enforce or validate point-to-polygon argument direction in the core API so
  the app does not silently repair invalid ordering.
- Evidence: `link()` degenerate-within warning + `build_crosswalk()`
  auto-correct with inform (`d9d0d0c`); app applies the universal
  overlay-as-from rule (`a4d1778`); direction asserted in the testServer
  suite (`9dda143`).
- [x] Make layer styling behaviour explicit: either support per-layer styles or
  remove comments and controls implying that capability.
- Evidence: per-layer folded style accordions shipped in the
  awareness-first redesign (`a4d1778`).
- [x] Ensure nearest maps add only one Leaflet layers control and browser-test
  the `None` basemap behaviour.
- Evidence: double-control bug found and fixed in `9dda143` (exactly one
  control on every nearest path, empty matches included). `None` basemap
  was browser-verified 2026-07-15 (Playwright); not re-covered by the
  current smoke test — see residual item below.

**Acceptance gate:** `app.R` contains reactive orchestration and presentation,
not a second implementation of package algorithms.

### P0 — Build a repeatable validation suite

- [x] Add `shiny::testServer()` coverage for the Link and Find Nearest tabs.
- Evidence: `tests/testthat/test-shiny-server.R` + `helper-shiny.R`
  (30 assertions, retrieval mocked at the package boundary; `9dda143`).
- [x] Test source selection, facility/boundary ordering, successful reruns, and
  state reset after failed operations.
- Evidence: covered in the testServer suite (selection/type display,
  direction, preview invalidation on selection change; `9dda143`).
- [x] Test malformed CSV files, missing `lon`/`lat`, empty nearest results,
  invalid distance settings, and retrieval failures.
- Evidence: malformed CSV (missing lat -> error state, no table) and
  zero-row results covered (`9dda143`). Invalid distance settings and
  mocked retrieval-failure paths are NOT yet covered — residual item below.
- [x] Test download readiness and generation of CSV, HTML map, and reproduction
  script outputs.
- Evidence: readiness covered incl. the zero-row fix (`9dda143`);
  generation of the three outputs is exercised at the unit level
  (`render_reproducer_script()` exported and tested) but download handlers
  are not driven end-to-end — folded into the residual item below.
- [x] Add stable synthetic `sf` fixtures so normal tests do not require live
  GeoHub access.
- Evidence: `helper-fixtures.R` (`b13a1a5`); whole suite passes with
  networking blocked (dead-proxy run, 2026-07-18).
- [x] Add one browser-level smoke test using `shinytest2` or the existing
  Playwright approach.
- Evidence: `test-app-smoke.R`, shinytest2 + chromote in Suggests
  (`bed1602`, `d972f7e`); 7/7 in headless Chrome installed-mode; skips
  under dev-loading and when Chrome is absent.
- [x] Run a complete package check after the newest UI changes and record the
  result; do not rely on the clean check that preceded them.
- Evidence: `R CMD check --as-cran` 0/0/0 Status OK, 2026-07-18, after all
  consolidation changes.
- [x] Residual validation gaps (non-blocking): invalid-distance and mocked
  retrieval-failure testServer paths; end-to-end download handler content.
- Evidence: added to `test-shiny-server.R` (2026-07-20); suite 609 pass /
  0 fail, `R CMD check --as-cran` 0 errors / 0 warnings.
- [x] Browser coverage of basemap switching incl. `None`.
- Evidence: `test-app-smoke.R` drives all five basemap options in headless
  Chrome (`None` asserted tile-less). **Runs offline and ungated as of
  2026-07-20**: 22 assertions, 0 failures, 0 skips.
  `R CMD check --as-cran`: 0 errors, 0 warnings, 1 NOTE.
- The "detritus in the temp directory - com.google.Chrome.*" NOTE was
  **first dismissed as cosmetic, and that was a mistake**: it was reporting
  the exact leak that caused the startup timeouts below. Resolved by the
  teardown in `test-app-smoke.R`, which removes the NOTE and the flakiness
  together. A check NOTE about leftover state is evidence about the
  environment, not a formatting complaint.
- [x] **Basemap smoke no longer needs network or an opt-in gate.** It was
  gated behind `ONGEOR_BASEMAP_SMOKE=true` because switching basemaps needed
  a rendered Leaflet widget, a widget needed a successful preview, a preview
  needed two sources, and only one source (`hive`) was bundled — so the
  second always came from GeoHub. Resolved by bundling
  `inst/extdata/phu_simple.rds` (PHU boundaries simplified at 250 m, 202 KB)
  and drawing it as an always-on map furniture layer, so the widget exists at
  app load with no preview and no retrieval. The gate and the preview/modal
  scaffolding it required are deleted.
- [ ] **OPEN, ONgeoRapp-owned since the app split: browser-suite startup
  timeouts, cause UNKNOWN.** The app and its browser suite no longer live in
  this repo; this entry is kept intact because it carries a retraction that
  must travel with the item, and should be moved to ONgeoRapp's queue rather
  than worked from here. `AppDriver`
  intermittently reports "app failed to start up within N seconds". The app
  starts normally and never signals ready: no R error, no traceback, no
  `shiny:error`. Measured 2026-07-20 at roughly a **50% failure rate on
  unchanged code**, same commit and same machine.
- Five mechanisms proposed and each **falsified by measurement**: map-layer
  payload size (2.19 vs 1.46 MB), feature count (34 -> 1629 features moves
  serialisation only 1.0 s -> 2.0 s), vertex count, SVG-vs-canvas rendering
  (0.3 s either way), and accumulated `TMPDIR/com.google.Chrome.*` dirs (a run
  failed with a completely clean TMPDIR). Whole render path costs ~5 s against
  a 90 s budget, so the time is not going into the map.
- **RETRACTION.** Commits 4b0b8ef / 59cc4f0 claim hive's 2.19 MB widget caused
  this. That claim is WRONG. It rested on single runs per condition through an
  instrument later shown to be ~50% flaky. Dropping hive from startup is still
  correct — users should not pay for a layer they did not request — but the
  stated reason was not established.
- **The test also SKIPS in CI**, so removing the `ONGEOR_BASEMAP_SMOKE` gate
  bought nothing there: all three platforms report "AppDriver can not be
  initialized as {chromote} can not be started" and the matrix stays green.
  Making it genuinely run in CI needs `chromote::set_chrome_args("--no-sandbox")`
  or equivalent — but it should NOT be enabled until the flakiness above is
  understood, or CI goes red half the time.
- Chrome does leak ~2 temp dirs per launch (this is what the `R CMD check`
  "detritus in the temp directory" NOTE reports); `test-app-smoke.R` now cleans
  up after itself. Worth doing on its own merits, but it does NOT fix the
  flakiness - that was tested and disproved.
- Still true and worth keeping: this failure was invisible to
  `devtools::test()`, which stayed green at 634+ passes throughout. The
  browser test is the only thing that starts a real Shiny process.
- Fixes applied: `hive` simplified in place at 250 m
  (`data-raw/hive_simplify.R`, 575 KB -> 354 KB on disk, all 1629 cells and
  the all-MULTIPOLYGON contract preserved), and `hive` is no longer drawn at
  load at all. `leaflet::hideGroup()` only hides client-side, so an
  "unchecked" furniture layer still ships its full geometry to every browser;
  `hive` is now reached through the source pickers, where its cost is paid on
  request. Guarded by a test asserting no `addPolygons` call for `hive`
  exists in the load-time widget.
- NOT established: why 2.19 MB exceeded a 90 s startup budget when the
  geometry serialises in ~2.8 s. The differential is unambiguous and
  reproducible; the mechanism is not explained, and AppDriver's readiness
  detection is the untested part. Do not cite a specific mechanism here
  without measuring it.
- [x] Raster palette bug (found while adding the above): every raster preview
  produced an empty map because the palette choices shipped as
  `"Viridis"`/`"Magma"`, which `leaflet::colorNumeric()` only rejects when the
  palette is *applied*, not when it is built. Fixed to `"viridis"`/`"magma"`
  with a regression test covering every offered palette value.
- [x] **FIXED: raster layers did not render in the live app.** Root cause: a
  `SpatRaster` is an external pointer to a C++ object, and that pointer does
  NOT survive being returned from a `multisession` future worker - it arrives
  NULL, and the first later use fails with "NULL value passed as symbol
  address". `sf` layers are plain R data and cross fine, which is why only
  raster pairings broke. The failure was silent in the UI: the map rendered
  empty with no `shiny:value` and no `shiny:error`, and map.html downloaded a
  ~32 KB stub instead of ~2.7 MB.
- Fix: `pack_spatial()` / `unpack_spatial()` in `inst/shiny/app.R` wrap the
  raster with `terra::wrap()` before it leaves the worker and restore it with
  `terra::unwrap()` on arrival, applied at every future boundary
  (`preview_task` and both `build_task` return paths).
- Evidence: live browser, `hive + synthetic_air_quality` after the fix - map
  440,145 chars (was 0), layers control present (was absent), 18 raster canvas
  tiles (was 0), map.html download 2,806,750 bytes (was ~32 KB), matching the
  offline 2,741 KB baseline. Visually confirmed: HIVE hex grid and the PM2.5
  surface render together correctly.
- Regression test: `test-shiny-server.R` "rasters are packed across the future
  boundary and survive" asserts the wrap/unwrap contract including a real
  serialize/unserialize round trip; verified to FAIL when the helpers are
  reduced to pass-through.
- Why every existing test missed it: the offline suite runs
  `use_sequential_futures()`, so nothing ever crossed a process boundary, and
  `render_styled_map()` in-process was always fine. Only a live browser run
  with a real multisession worker reproduced it.
- Note for future browser tests: leaflet 2.2.3 draws a SpatRaster as a CANVAS
  grid layer (`options = gridOptions()`), not an `img.leaflet-image-layer`
  overlay - asserting on that img selector gives a false negative.

**Acceptance gate:** both workflows can be exercised automatically from input
to downloadable output, including expected failure paths.

### P1 — Add repository automation

- [x] Add R CMD check for Ubuntu, Windows, and macOS.
- Evidence: `.github/workflows/R-CMD-check.yaml` (`9dda143`); first run
  green on all three OSes (run 29668240825).
- [x] Verify package installation and vignette builds in CI.
- Evidence: vignettes build inside the check job (no
  `--no-build-vignettes`); install exercised by check on 3 OSes.
- [x] Run the browser smoke test on Ubuntu.
- Evidence: the smoke test runs inside the check matrix (r-lib
  check-r-package sets NOT_CRAN=true and installs the package); green on
  all three OSes at `d972f7e` (run 29668874746). That run also caught an
  undeclared chromote Suggests dependency first (`bed1602` run failed) —
  CI doing its job on day one.
- [x] Keep live-source integration checks separate from deterministic unit tests
  and run them on a schedule or manual trigger.
- Evidence: `live-geohub.yaml` (workflow_dispatch + weekly cron); first
  manual run green (run 29668390742), 34 PHUs / 403 airports live.
- [x] Add a visible status badge only after the workflow is stable.
- Evidence: `README.md` R-CMD-check badge added (2026-07-20), linking to
  `.github/workflows/R-CMD-check.yaml`; workflow proven green on all 3 OSes
  across multiple runs before the badge was added.

**Acceptance gate:** changes to `main` receive repeatable package, test, and UI
validation without depending on Ontario GeoHub availability.

### P1 — Improve Shiny responsiveness

- [x] Move slow retrieval and spatial operations to `ExtendedTask`, promises,
  or another supported asynchronous pattern.
- Evidence: ExtendedTask + promises/future (multisession) with plan-restore
  on stop, merged in PR #4 (`1eab55e`).
- [x] Prevent stale results when inputs change while a task is running.
- Evidence: generation counters (`preview_generation`/`link_generation`,
  bumped on every relevant input change) are carried through each
  ExtendedTask and checked before results are stored, so a completion whose
  inputs have moved on is discarded. Test: "Link discards a completion
  invalidated by changed inputs" (`test-shiny-server.R`).
- [x] Provide clear running, failed, cancelled, and completed states.
- Evidence: `task_status_ui()` renders idle/running/failed/cancelled/completed
  with a `data-state` attribute; wired into both tabs via `link_task_status`
  and `nearest_task_status`. Tests assert Running, Cancelled, Failed (with the
  error text) and Completed.
- [x] Confirm that cached repeat runs remain fast and do not unnecessarily start
  background work.
- Evidence: test "repeat Link runs use cached retrieval without re-fetching"
  asserts the second identical run is faster than the first and that no extra
  retrieval work is started.

**Acceptance gate:** a slow or temporarily unavailable external source does not
freeze the user interface or leave misleading prior results visible.

### P1 — Public release readiness

- [x] Add pkgdown configuration and publish documentation.
- Evidence: `_pkgdown.yml` (`.Rbuildignore`d so it does not trip the
  top-level-files check), `.github/workflows/pkgdown.yaml`, and a `gh-pages`
  branch publishing to <https://lennon-li.github.io/ONgeoR/>, which is the URL
  carried in `DESCRIPTION`. Deployment is automated on push to `main`.
- Site is current as of 2026-09-03: run
  [33791092310](https://github.com/lennon-li/ONgeoR/actions/runs/33791092310)
  for `e7727db` (the monitoring-stations rename) succeeded in 2m36s. See the
  resolved infrastructure item below for the timeout this closes out.
- [x] Add GitHub issue templates, including a structured data-source request.
- Evidence: three templates incl. data-source-request, PR #5 (`1eab55e`).
- [x] Review package title and description for CRAN-style software-name and API
  formatting before any submission.
- Evidence: Title already compliant (title case, no trailing period, does not
  open with the package name or an article). Description reworded to expand
  LIO and REST on first use.
- [x] Review examples for runtime, network dependence, and correct use of
  `\donttest{}` versus `\dontrun{}`.
- Evidence: every network-touching example is already wrapped in
  `if (interactive()) { ... }`, which `R CMD check` skips - equivalent to
  `\donttest{}` here. Audited all `@examples` blocks in `R/*.R`; no changes
  needed, and `devtools::document()` produces no man/ or NAMESPACE drift.
- [x] Perform a clean installation and check in a fresh environment.
- Evidence: installed into an empty library via
  `.libPaths(c("/tmp/ongeor-clean-lib", .libPaths())); devtools::install()`;
  install succeeded and `library(ONgeoR)` loaded 0.3.0.9000 cleanly.

**Acceptance gate:** a new user can install the package, understand its scope,
run a documented workflow, and report a source or software problem.

## v0.4 — Expansion after v0.3 passes

Expansion is demand-driven. Do not begin these items until the v0.3 acceptance
gates above are satisfied.

- [x] **Statistics Canada census subdivisions** — shipped, and wider than the
  original item: fourteen 2021 census geographies are registered
  (`census_pr_2021` … `census_fsa_2021`), `census_csd_2021` being the
  subdivisions asked for here. Covered by `tests/testthat/test-census.R`; the
  two live checks are `skip_on_cran()` + `skip_if_offline()`.
- [ ] **Additional sources** — transit and environmental layers, ordered by a
  documented user need rather than source availability alone.
- [ ] **Nearest-neighbour performance** — replace the full distance matrix with
  a spatial-indexed approach only when realistic benchmarks show the current
  implementation is inadequate. `nearest()` aborts with
  `ongeor_nearest_too_large` above 10 million distances rather than trying.
- [x] **Raster linking** — shipped through the existing `link()` seam;
  `terra` is a declared import, `map_layers()` draws a `SpatRaster`, and
  raster-to-raster linking is refused explicitly. Note that
  `DECISIONS.md` still describes raster as a future seam rather than an
  active workstream: the seam is implemented, not extended.
- [x] **`build_intersection()` fails on bundled HIVE Level 1/2 cells**
  (found 2026-07-31) — fixed 2026-08-03 by `data-raw/hive_make_valid.R`, which
  repairs only the 8 cells that were invalid under planar GEOS (one "Hole lies
  outside shell", seven "Nested shells") with `MakeValid` in EPSG:3347, leaving
  every other cell byte-identical. Do not route the grid through an s2-based
  rebuild; a previous attempt moved every vertex by up to ~2 degrees.
- Evidence (re-verified 2026-08-21 against the installed package, offline):
  `build_intersection(retrieve_hive(), retrieve_phu_simple())` returns 1,917
  rows over all 1,629 cells and 29 PHUs, with no `TopologyException`. This is
  the plain full-grid call, not the Level 3 subset the examples use, so it does
  not close by way of green examples.

### Resolved — infrastructure

- [x] **pkgdown CI on `main` exceeded its 30-minute limit and was cancelled**
  (found 2026-08-21) — did not recur. Run
  [32275659041](https://github.com/lennon-li/ONgeoR/actions/runs/32275659041)
  for `bcc868e` was killed at 30m6s by the job timeout, leaving the published
  site stale at `b33311d`. **The cause was never established** — the
  immediately preceding pkgdown runs took 2m33s and 2m43s, and
  `R-CMD-check` for the same commit passed in 11m27s on all three platforms,
  so it was specific to the pkgdown job with only one occurrence.
  Re-checked 2026-09-03: four pkgdown runs since then
  (`32991078204` … `33082082837`, one per subsequent push) all completed
  in 2-3 minutes, including the run for `55d98bc` — the commit immediately
  before this repo's monitoring-stations rename — so the site was already
  current, contradicting the earlier "stale" note above written before this
  check. A fifth run,
  [33791092310](https://github.com/lennon-li/ONgeoR/actions/runs/33791092310)
  for `e7727db`, was triggered fresh and also succeeded in 2m36s. Treated as
  a one-off runner flake (unresolved but not reproducing) rather than a
  standing infrastructure problem; reopen if it recurs.

### Open — ONgeoRapp-owned, listed here only until moved

- [ ] **Surface source unavailability explicitly in the app** (Lennon,
  2026-07-31) — when a layer cannot be retrieved, ONgeoRapp must say so in the
  UI, naming the source and the reason, so a user reads "the data service is
  not answering" rather than concluding the app is broken. `retrieve_*()`
  already raises a classed `ongeor_retrieval_error` with an informative
  message (`R/utils.R:297`); the gap is that the app does not surface it
  distinctly from any other failure. The **ONgeoR-side** obligation is the only
  part this repo owns: keep the condition class stable and keep the message
  naming the source. Prompted by finding that asgard cannot reach
  `ws.lioservices.lrc.gov.on.ca` at all, which is exactly the situation a user
  would misread as a broken app.

## Blocked decisions

These are data-governance or scope questions, not implementation tasks.

- **Postal-code resolution** — **resolved and shipped.** The centroid-source
  question ("GeoNames vs the OPCC NAR-derived open centroids") was settled in
  favour of the OPCC release: `resolve_postal()` uses the M5 correspondence for
  postal-to-DA, and `resolve_postal_points()` / `retrieve_postal_points()` use
  the M1 centroids, both checksum-verified and cached. The BYO-PCCF seam was
  not needed and was not built.
- **ON-Marg redistribution** — settled. The PHO workbook licence forbids
  modification, so ONgeoR fetches it at runtime against a pinned SHA-256 and
  keeps it in session memory only: never bundled, never cached to disk, never
  altered, and a checksum mismatch aborts. Lennon confirmed on 2026-08-19 that
  he holds permission to expose ON-Marg through the hosted app; that permission
  does not change the handling, which is how the licence term is honoured
  rather than a workaround for the permission.
- **`retrieve_monitoring_stations*` naming** — resolved and shipped. Lennon
  decided 2026-09-03: `retrieve_monitoring_stations_simple()` renamed to
  `retrieve_monitoring_stations_bundled()` (registry source id
  `monitoring_stations_simple` -> `monitoring_stations_bundled`), because
  `_simple` elsewhere in this package (`retrieve_phu_simple()`) means
  "generalized geometry from the same live source," while this function meant
  "static bundled snapshot, different schema, frozen at 2023-06-23" — an
  unrelated axis the shared suffix misleadingly implied. `bundled` matches the
  name already used for the source in `sources.yaml`.

## Task discipline

- Keep only current and future work unchecked in this file.
- When a task is completed, update its checkbox and milestone status in the same
  change that closes the implementation handoff.
- Every milestone must state its acceptance gate and record evidence that the
  gate passed before the next milestone begins.
- Do not create source-specific linking functions when existing geometry-driven
  verbs already cover the operation.
- Do not add a source without provenance, licensing notes, deterministic tests,
  and live retrieval validation.
