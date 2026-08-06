
# ONgeoR

[![R-CMD-check](https://github.com/lennon-li/ONgeoR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/lennon-li/ONgeoR/actions/workflows/R-CMD-check.yaml)

ONgeoR is a lightweight R package for resolving Ontario locations,
facilities, and infrastructure to public-health and health-system
geography.

It helps users retrieve external source data, link locations to Public
Health Units and Ontario Health Regions, build auditable crosswalk
files, and create simple maps.

ONgeoR does not aim to be a permanent storehouse of Ontario geospatial
data. Instead, it provides reproducible workflows and source metadata so
users can retrieve, validate, link, and document data from authoritative
external sources.

## Why

Public health analysts, epidemiologists, and health-system planners in
Ontario frequently need to:

- Map facilities (hospitals, long-term care homes, schools) to Public
  Health Units
- Link locations to Ontario Health Regions
- Build crosswalks between different geographic boundaries
- Document data sources and their provenance

ONgeoR provides a standardized, reproducible framework for these tasks
without bundling large geospatial datasets that become stale or require
constant maintenance.

## What ONgeoR Does (v0.4)

- Provides a source registry with metadata for Tier 1 Ontario GeoHub
  (LIO) datasets
- Retrieves PHU boundaries, Ontario Health Regions, municipal
  boundaries, MOH service locations, airports, waste management sites,
  conservation authorities, ORWN railway stations, and Ontario water and
  weather monitoring stations at runtime, plus a bundled HIVE grid, a
  bundled offline subset of 2,407 monitoring stations, and a synthetic
  raster surface
- Links geometries by type with `link()` (point-in-polygon,
  polygon-to-polygon, and raster sampling) and `nearest()` (k-nearest
  and radius search), resolves records by identifier or name with
  `resolve()`, resolves Ontario postal codes to dissemination areas with
  `resolve_postal()`, and provides `build_link()` as a single no-choice
  entry point that picks the linking operation from the geometry pair
- Generates auditable crosswalk tables with full provenance metadata via
  `build_crosswalk()`, including weighted apportionment;
  `build_intersection()` returns every overlapping polygon pair with
  area shares in one pass
- Draws interactive leaflet maps with `map_layers()` and nearest-match
  maps with `map_nearest()`
- A point-and-click Shiny app is provided by the companion package
  [ONgeoRapp](https://github.com/lennon-li/ONgeoRapp)

See [ROADMAP.md](ROADMAP.md) for planned additional sources and
performance work.

## What ONgeoR Does Not Do

- Bundle large geospatial datasets inside the package
- Permanently maintain or host boundary files
- Provide licensed or restricted data (e.g., PCCF postal code files)
- Replace authoritative data sources -- it retrieves from them, not
  replaces them

## Design Principles

1.  **External data, not bundled** -- all data is retrieved from
    authoritative sources at runtime
2.  **Source metadata tracking** -- every retrieval records source URL,
    date, and license
3.  **Reproducible workflows** -- crosswalks include full provenance
    (source, date, retrieval timestamp)
4.  **Lightweight dependencies** -- minimal package footprint (sf,
    httr2, yaml, tibble, rlang, leaflet, terra, htmlwidgets)
5.  **Community-extensible** -- users can suggest new data sources via
    GitHub issues

## Installation

``` r
# Install from GitHub
# install.packages("pak")
pak::pkg_install("github::lennon-li/ONgeoR")
```

## Quick Start

``` r
library(ONgeoR)

# List available data sources
list_sources()

# Get metadata for a specific source
get_source("phu_boundaries")

# Retrieve PHU boundaries from the Ontario GeoHub (LIO) REST service
phu <- retrieve_phu()

# Create sample points (e.g., hospitals)
points <- data.frame(
  point_name = c("Toronto", "Ottawa", "Thunder Bay"),
  lon = c(-79.3832, -75.6972, -89.6306),
  lat = c(43.6532, 45.4215, 48.3822)
)

# Link points to Public Health Units (point-in-polygon)
result <- link(points, phu)
print(result)

# Find the 3 nearest MOH service locations to each point
facilities <- nearest(points, retrieve_moh_service_locations(), k = 3)

# Resolve an airport by its identifier
airport <- resolve(retrieve_airport(), "CYYZ")

# Ontario water and weather monitoring stations (bundled, works offline)
stations <- retrieve_monitoring_stations_simple()

# Resolve postal codes to dissemination areas (first call downloads the
# correspondence table and caches it)
postal <- resolve_postal(c("M5S 2C6", "K1A 0N9"))

# Build a crosswalk table between two polygon layers
municipal <- retrieve_municipal("upper")
crosswalk <- build_crosswalk(municipal, phu, method = "intersects")

# Or use build_link() to let the geometry pair decide automatically
result <- build_link(municipal, phu)

# Draw an interactive map of health-unit boundaries and hospitals
map_layers(phu, retrieve_moh_service_locations(service_type = "Hospital"))
```

## Geometry linking matrix

`build_link()` inspects the geometry types of the two layers and
dispatches to the appropriate operation. The table below is rendered
from the same matrix that drives the Shiny app.

| source_kind | target_kind | mode                          | what_it_does                                                                                               | output              |
|:------------|:------------|:------------------------------|:-----------------------------------------------------------------------------------------------------------|:--------------------|
| point       | point       | Nearest                       | Each target point is matched to its single nearest source point.                                           | nearest table       |
| point       | polygon     | Containment                   | Each point is matched to the boundary it falls inside.                                                     | crosswalk           |
| point       | raster      | Sampling                      | Each point takes the value of the cell containing it.                                                      | linked values table |
| polygon     | point       | Containment                   | Direction is auto-corrected internally.                                                                    | crosswalk           |
| polygon     | polygon     | Intersection                  | Every overlapping pair, with the share of each target covered and the share of each source falling inside. | intersection table  |
| polygon     | raster      | Sampling                      | Each polygon samples the raster values it overlaps.                                                        | linked values table |
| raster      | point       | Sampling                      | Raster reduced to cell centroids.                                                                          | linked values table |
| raster      | polygon     | Cell sampling into boundaries | Each cell centroid is matched to the boundary it falls inside.                                             | linked values table |
| raster      | raster      | Not supported                 | Not supported; align/resample with terra first.                                                            | none                |

## Shiny app

The point-and-click app lives in its own package,
[**ONgeoRapp**](https://github.com/lennon-li/ONgeoRapp). Select a Source
layer and a Target layer, click **Preview on map**, then **Join** to
produce a downloadable crosswalk table — no R code required.

<div class="figure">

<img src="man/figures/app-shiny.png" alt="The ONgeoRapp Shiny app showing PHU boundaries and MOH service locations previewed on the map" width="100%" />
<p class="caption">
ONgeoRapp: PHU boundaries and MOH service locations previewed before
joining.
</p>

</div>

``` r
pak::pkg_install("github::lennon-li/ONgeoRapp")
ONgeoRapp::run_app()
```

It was split out so that ONgeoR itself stays a lean data-and-linking
package.

## Documentation

- [Getting started](vignettes/getting-started.Rmd)
- [Building crosswalks](vignettes/building-crosswalks.Rmd)
- [Adding data sources](vignettes/adding-data-sources.Rmd)
- [Launching and using the app](https://github.com/lennon-li/ONgeoRapp)

## Data Sources

ONgeoR retrieves data from authoritative Ontario sources including:

- **Ontario GeoHub** (geohub.lio.gov.on.ca) -- provincial boundaries,
  facilities, infrastructure
- **Ministry of Health** -- health facility locations (via the GeoHub
  LIO services)

Statistics Canada census geographies are planned for a future release
(see the roadmap).

All sources are documented in the package's source registry with
metadata including:

- Source owner and jurisdiction
- License terms
- Update frequency
- Direct download URLs

## Contributing New Data Sources

Users can suggest new Ontario data sources by opening a GitHub issue
using the "Data source request" template. Include:

- Source name and URL
- Description of what the source contains
- Known license or terms of use
- Any concerns about quality or completeness

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the full development plan.

## License

MIT

## Contact

Lennon Li -- <lennon.yeli@gmail.com>
