# ONgeoR Roadmap

Updated 2026-07-16. This file is the active project task list and should reflect
shipped repository state. Completed implementation plans belong in project
history, not in the pending queue.

## Current status

ONgeoR has a functional package, CLI, and Shiny MVP. The retrieve → link →
crosswalk → map workflow is implemented and live-verified.

### Shipped

- **Retrieval** — seven registered Ontario GeoHub sources with provenance,
  bounded pagination, retry/backoff, actionable errors, progress messages, and
  source-specific simplification defaults.
- **Caching** — on-disk cache at `~/.cache/R/ONgeoR`; `refresh = TRUE` and CLI
  `--refresh` bypass cached data.
- **Core API** — `link()`, `nearest()`, `resolve()`, and `build_crosswalk()`.
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

### P0 — Reconcile project state

- [x] Remove completed v0.2 and Shiny MVP work from the pending task list.
- [ ] Update `DESCRIPTION` to an appropriate development version, such as
  `0.3.0.9000`, or document a different versioning convention.
- [ ] Update the README version label and describe the Shiny MVP as shipped.
- [ ] Replace or deliberately remove placeholder contact details in
  `DESCRIPTION` and README.
- [ ] Define explicit v0.3 acceptance criteria and record the validation result
  when the milestone closes.

**Acceptance gate:** repository documentation, package metadata, and the actual
implementation describe the same product state.

### P0 — Make the Shiny app a thin package interface

The app should coordinate inputs and outputs. Spatial, retrieval, validation,
and map-construction logic should live in testable package functions.

- [ ] Replace `ONgeoR:::` calls in `inst/shiny/app.R` with supported package
  interfaces.
- [ ] Formalize a public or stable internal source-ID retrieval interface.
- [ ] Move nearest-match layer and connector construction out of `app.R` into a
  package function shared with `map_nearest()`.
- [ ] Move geometry dispatch and styled-layer rendering into `map_layers()` or
  a reusable package-level mapping interface.
- [ ] Enforce or validate point-to-polygon argument direction in the core API so
  the app does not silently repair invalid ordering.
- [ ] Make layer styling behaviour explicit: either support per-layer styles or
  remove comments and controls implying that capability.
- [ ] Ensure nearest maps add only one Leaflet layers control and browser-test
  the `None` basemap behaviour.

**Acceptance gate:** `app.R` contains reactive orchestration and presentation,
not a second implementation of package algorithms.

### P0 — Build a repeatable validation suite

- [ ] Add `shiny::testServer()` coverage for the Link and Find Nearest tabs.
- [ ] Test source selection, facility/boundary ordering, successful reruns, and
  state reset after failed operations.
- [ ] Test malformed CSV files, missing `lon`/`lat`, empty nearest results,
  invalid distance settings, and retrieval failures.
- [ ] Test download readiness and generation of CSV, HTML map, and reproduction
  script outputs.
- [ ] Add stable synthetic `sf` fixtures so normal tests do not require live
  GeoHub access.
- [ ] Add one browser-level smoke test using `shinytest2` or the existing
  Playwright approach.
- [ ] Run a complete package check after the newest UI changes and record the
  result; do not rely on the clean check that preceded them.

**Acceptance gate:** both workflows can be exercised automatically from input
to downloadable output, including expected failure paths.

### P1 — Add repository automation

- [ ] Add R CMD check for Ubuntu, Windows, and macOS.
- [ ] Verify package installation and vignette builds in CI.
- [ ] Run the browser smoke test on Ubuntu.
- [ ] Keep live-source integration checks separate from deterministic unit tests
  and run them on a schedule or manual trigger.
- [ ] Add a visible status badge only after the workflow is stable.

**Acceptance gate:** changes to `main` receive repeatable package, test, and UI
validation without depending on Ontario GeoHub availability.

### P1 — Improve Shiny responsiveness

- [ ] Move slow retrieval and spatial operations to `ExtendedTask`, promises,
  or another supported asynchronous pattern.
- [ ] Prevent stale results when inputs change while a task is running.
- [ ] Provide clear running, failed, cancelled, and completed states.
- [ ] Confirm that cached repeat runs remain fast and do not unnecessarily start
  background work.

**Acceptance gate:** a slow or temporarily unavailable external source does not
freeze the user interface or leave misleading prior results visible.

### P1 — Public release readiness

- [ ] Add pkgdown configuration and publish documentation.
- [ ] Add GitHub issue templates, including a structured data-source request.
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

- **Postal-code resolution** — requires a licensed or user-supplied PCCF-like
  source. Define licensing, local-data input, provenance, and non-distribution
  behaviour before implementing `resolve_postal()`.
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
