# ONgeoR Roadmap

Updated 2026-07-18. This file is the active project task list and should reflect
shipped repository state. Completed implementation plans belong in project
history, not in the pending queue.

## Current status

ONgeoR has a functional package, CLI, and Shiny MVP. The retrieve → link →
crosswalk → map workflow is implemented and live-verified.

### Shipped

- **Retrieval** — seven registered Ontario GeoHub sources with provenance,
  bounded pagination with truncation detection, retry/backoff, actionable
  errors, progress messages, cache max_age, and
  source-specific simplification defaults.
- **Caching** — on-disk cache at `~/.cache/R/ONgeoR`; `refresh = TRUE` and CLI
  `--refresh` bypass cached data.
- **Core API** — `link()`, `nearest()`, `resolve()`, and `build_crosswalk()`;
  weighted crosswalks and registry-driven column selection are shipped.
- **Mapping** — `map_layers()`, `map_crosswalk()`, and `map_nearest()`.
- **CLI** — creates `crosswalk.csv`, self-contained `map.html`, and a standalone
  `reproduce.R` script.
- **Documentation** — getting-started, crosswalk, and data-source contribution
  vignettes.
- **Shiny MVP** — source linking, nearest-facility search, interactive maps,
  data tables, map styling, basemap selection, and downloads through
  `run_app()`.
- **Repository hygiene** — obsolete phase-one scripts and rendered inventory
  output removed.

## Current milestone — v0.3 consolidation

**Goal:** make the shipped MVP internally consistent, package-driven rather
than app-driven, repeatably tested, and protected by CI before adding more data
sources or raster support.

**Status 2026-07-18:** [issue #1](https://github.com/lennon-li/ONgeoR/issues/1)
is complete (commits `9dda143`, `bed1602`); evidence is recorded per item
below. Residual validation gaps are listed as new unchecked items — close
them opportunistically, they do not block v0.4.

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
- [ ] Residual validation gaps (non-blocking): invalid-distance and mocked
  retrieval-failure testServer paths; end-to-end download handler content;
  browser coverage of basemap switching incl. `None`.

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
- [ ] Add a visible status badge only after the workflow is stable.

**Acceptance gate:** changes to `main` receive repeatable package, test, and UI
validation without depending on Ontario GeoHub availability.

### P1 — Improve Shiny responsiveness

- [x] Move slow retrieval and spatial operations to `ExtendedTask`, promises,
  or another supported asynchronous pattern.
- Evidence: ExtendedTask + promises/future (multisession) with plan-restore
  on stop, merged in PR #4 (`1eab55e`).
- [ ] Prevent stale results when inputs change while a task is running.
- [ ] Provide clear running, failed, cancelled, and completed states.
- [ ] Confirm that cached repeat runs remain fast and do not unnecessarily start
  background work.

**Acceptance gate:** a slow or temporarily unavailable external source does not
freeze the user interface or leave misleading prior results visible.

### P1 — Public release readiness

- [ ] Add pkgdown configuration and publish documentation.
- [x] Add GitHub issue templates, including a structured data-source request.
- Evidence: three templates incl. data-source-request, PR #5 (`1eab55e`).
- [ ] Review package title and description for CRAN-style software-name and API
  formatting before any submission.
- [ ] Review examples for runtime, network dependence, and correct use of
  `\donttest{}` versus `\dontrun{}`.
- [ ] Perform a clean installation and check in a fresh environment.

**Acceptance gate:** a new user can install the package, understand its scope,
run a documented workflow, and report a source or software problem.

## v0.4 — Expansion after v0.3 passes

Expansion is demand-driven. Do not begin these items until the v0.3 acceptance
gates above are satisfied.

- [ ] **Statistics Canada census subdivisions** — preferred first new source;
  add a registry entry, provenance, retrieval implementation, live
  simplification/pagination validation, tests, and documentation.
- [ ] **Additional sources** — transit and environmental layers, ordered by a
  documented user need rather than source availability alone.
- [ ] **Nearest-neighbour performance** — replace the full distance matrix with
  a spatial-indexed approach only when realistic benchmarks show the current
  implementation is inadequate.
- [ ] **Raster linking** — implement through the existing `link()` seam only
  after a concrete use case and validation dataset are defined; add `terra`
  deliberately rather than pre-emptively.

## Blocked decisions

These are data-governance or scope questions, not implementation tasks.

- **Postal-code resolution** — design decided 2026-07-16 (no PCCF required):
  `resolve_postal()` on free centroids with an optional BYO-PCCF seam, output
  feeding the normal linking verbs. Centroid source pending one decision:
  GeoNames (0.27 km median deviation) vs the OPCC project's NAR-derived open
  centroids (100% SLI coverage, ~0 km median; OPCC M2 correspondence table
  closed 2026-07-18). Awaiting Lennon's go.
- **Transportation terminals** — no suitable registered LIO source has been
  confirmed. Define terminal types, authoritative sources, and expected lookup
  behaviour before implementing `resolve_terminal()`.

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
