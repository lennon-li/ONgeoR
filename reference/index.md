# Package index

## Retrieve data

Functions to retrieve Ontario spatial layers from authoritative sources.

- [`retrieve_phu()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_phu.md)
  : Retrieve Public Health Unit boundaries
- [`retrieve_phu_simple()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_phu_simple.md)
  : Retrieve simplified Public Health Unit boundaries
- [`retrieve_health_region()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_health_region.md)
  : Retrieve Ontario Health Region boundaries
- [`retrieve_municipal()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_municipal.md)
  : Retrieve municipal boundaries
- [`retrieve_moh_service_locations()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_moh_service_locations.md)
  : Retrieve MOH service locations
- [`retrieve_airport()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_airport.md)
  : Retrieve airport boundaries
- [`retrieve_conservation_authority()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_conservation_authority.md)
  : Retrieve Conservation Authority administrative areas
- [`retrieve_orwn_station()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_orwn_station.md)
  : Retrieve Ontario Railway Network (ORWN) station points
- [`retrieve_waste_management()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_waste_management.md)
  : Retrieve waste management site boundaries
- [`retrieve_monitoring_stations()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_monitoring_stations.md)
  : Retrieve monitoring station points
- [`retrieve_monitoring_stations_simple()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_monitoring_stations_simple.md)
  : Retrieve bundled monitoring station points
- [`retrieve_hive()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_hive.md)
  : Retrieve HIVE Grid boundaries
- [`retrieve_synthetic_raster()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_synthetic_raster.md)
  : Retrieve a synthetic coarse air-quality raster
- [`retrieve_source()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_source.md)
  : Retrieve a layer by source registry id

## Link and crosswalk

Core spatial linking and crosswalk-building functions.

- [`link()`](https://lennon-li.github.io/ONgeoR/reference/link.md) :
  Link geometries to a target layer by spatial relationship
- [`nearest()`](https://lennon-li.github.io/ONgeoR/reference/nearest.md)
  : Find the nearest targets to each source geometry
- [`build_link()`](https://lennon-li.github.io/ONgeoR/reference/build_link.md)
  : Link two layers with no method choice
- [`build_crosswalk()`](https://lennon-li.github.io/ONgeoR/reference/build_crosswalk.md)
  : Build an auditable crosswalk table between two geographic layers
- [`build_intersection()`](https://lennon-li.github.io/ONgeoR/reference/build_intersection.md)
  : Build a polygon-to-polygon intersection table
- [`build_nearest_layers()`](https://lennon-li.github.io/ONgeoR/reference/build_nearest_layers.md)
  : Build layers for a nearest-neighbour map
- [`build_nearest_pairs()`](https://lennon-li.github.io/ONgeoR/reference/build_nearest_pairs.md)
  : Build a point-to-point nearest-match table
- [`summarise_by_target()`](https://lennon-li.github.io/ONgeoR/reference/summarise_by_target.md)
  : Summarise an intersection or nearest table by target
- [`extract_polygon_collection()`](https://lennon-li.github.io/ONgeoR/reference/extract_polygon_collection.md)
  : Reduce GEOMETRYCOLLECTION geometries to their polygon parts

## Resolve and identify

Resolve records by identifier or name.

- [`resolve()`](https://lennon-li.github.io/ONgeoR/reference/resolve.md)
  : Resolve records from a layer by an identifier or name
- [`resolve_postal()`](https://lennon-li.github.io/ONgeoR/reference/resolve_postal.md)
  : Resolve Ontario postal codes to dissemination areas
- [`normalize_postal_code()`](https://lennon-li.github.io/ONgeoR/reference/normalize_postal_code.md)
  : Normalize postal codes to the correspondence's own format
- [`guess_name_col()`](https://lennon-li.github.io/ONgeoR/reference/guess_name_col.md)
  : Guess a name column in an sf/data.frame layer

## Map

Draw interactive Leaflet maps.

- [`map_layers()`](https://lennon-li.github.io/ONgeoR/reference/map_layers.md)
  : Map one or more layers on an interactive leaflet map
- [`map_crosswalk()`](https://lennon-li.github.io/ONgeoR/reference/map_crosswalk.md)
  : Map crosswalk source layers
- [`map_nearest()`](https://lennon-li.github.io/ONgeoR/reference/map_nearest.md)
  : Map nearest targets and their connections to source points

## Source registry

Browse and query the built-in source metadata registry.

- [`list_sources()`](https://lennon-li.github.io/ONgeoR/reference/list_sources.md)
  : List available data sources
- [`get_source()`](https://lennon-li.github.io/ONgeoR/reference/get_source.md)
  : Get metadata for one data source

## Cache

Inspect and clear the on-disk retrieval cache.

- [`list_cache()`](https://lennon-li.github.io/ONgeoR/reference/list_cache.md)
  : List Cached ONgeoR Data
- [`clear_cache()`](https://lennon-li.github.io/ONgeoR/reference/clear_cache.md)
  : Clear Cached ONgeoR Data

## Reproducibility

Generate reproducible R scripts from a linking run.

- [`render_reproducer_script()`](https://lennon-li.github.io/ONgeoR/reference/render_reproducer_script.md)
  : Render a reproducible R script for a CLI run
- [`render_postal_reproducer_script()`](https://lennon-li.github.io/ONgeoR/reference/render_postal_reproducer_script.md)
  : Render a postal-code reproducer script

## Data

Built-in datasets bundled with the package.

- [`hive`](https://lennon-li.github.io/ONgeoR/reference/hive.md) : HIVE
  Grid (Levels 1-3): a built-in hierarchical boundary dataset
