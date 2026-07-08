# ONgeoR

ONgeoR is a lightweight R package for resolving Ontario locations, facilities, and infrastructure to public-health and health-system geography.

It helps users retrieve external source data, link locations to Public Health Units and Ontario Health Regions, build auditable crosswalk files, and create simple maps.

ONgeoR does not aim to be a permanent storehouse of Ontario geospatial data. Instead, it provides reproducible workflows and source metadata so users can retrieve, validate, link, and document data from authoritative external sources.

## Why

Public health analysts, epidemiologists, and health-system planners in Ontario frequently need to:
- Map facilities (hospitals, long-term care homes, schools) to Public Health Units
- Link locations to Ontario Health Regions
- Build crosswalks between different geographic boundaries
- Document data sources and their provenance

ONgeoR provides a standardized, reproducible framework for these tasks without bundling large geospatial datasets that become stale or require constant maintenance.

## What ONgeoR Does

- Provides a source registry with metadata for Ontario geospatial datasets
- Retrieves data from authoritative external sources (Ontario GeoHub, Statistics Canada, etc.)
- Performs spatial linking operations (point-in-polygon, nearest-facility lookup)
- Generates auditable crosswalk tables with full provenance metadata
- Creates simple boundary and facility maps using ggplot2 + sf

## What ONgeoR Does Not Do

- Bundle large geospatial datasets inside the package
- Permanently maintain or host boundary files
- Provide licensed or restricted data (e.g., PCCF postal code files)
- Replace authoritative data sources — it retrieves from them, not replaces them

## Design Principles

1. **External data, not bundled** — all data is retrieved from authoritative sources at runtime
2. **Source metadata tracking** — every retrieval records source URL, date, and license
3. **Reproducible workflows** — crosswalks include full provenance (source, date, retrieval timestamp)
4. **Lightweight dependencies** — minimal package footprint (sf, dplyr, httr2, yaml, ggplot2)
5. **Community-extensible** — users can suggest new data sources via GitHub issues

## Installation

```r
# Install from GitHub
# install.packages("remotes")
remotes::install_github("lennon-li/ONgeoR")
```

## Quick Start

```r
library(ONgeoR)

# List available data sources
list_sources()

# Get metadata for a specific source
get_source("phu_boundaries")

# Retrieve PHU boundaries from Ontario GeoHub
phu <- retrieve_boundary("phu_boundaries")

# Create sample points (e.g., hospitals)
points <- data.frame(
  id = 1:3,
  lon = c(-79.38, -75.70, -80.50),
  lat = c(43.65, 46.45, 43.53)
)

# Link points to Public Health Units
result <- point_to_phu(points, phu)
print(result)

# Build a crosswalk table
crosswalk <- build_crosswalk(points, phu, method = "within")
```

## Data Sources

ONgeoR retrieves data from authoritative Ontario sources including:
- **Ontario GeoHub** (geohub.lio.gov.on.ca) — provincial boundaries, facilities, infrastructure
- **Statistics Canada** — census geographies (when available as open data)
- **Ministry of Health** — health facility locations

All sources are documented in the package's source registry with metadata including:
- Source owner and jurisdiction
- License terms
- Update frequency
- Direct download URLs

## Contributing New Data Sources

Users can suggest new Ontario data sources by opening a GitHub issue using the "Data source request" template. Include:
- Source name and URL
- Description of what the source contains
- Known license or terms of use
- Any concerns about quality or completeness

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the full development plan.

## License

MIT

## Contact

Lennon Li — lennon.li@example.com
