#' HIVE Grid (Levels 1-3): a built-in hierarchical boundary dataset
#'
#' @description
#' The HIVE Grid is a custom hierarchical polygon grid covering Ontario,
#' developed and maintained by the package author outside of any public
#' government data service. It is bundled with ONgeoR as a static built-in
#' dataset (`inst/extdata/hive.rds`), accessed via [retrieve_hive()] or
#' `retrieve_source("hive")`, rather than fetched live like the LIO-backed
#' `retrieve_*()` functions.
#'
#' The version shipped with the package has been simplified
#' (`sf::st_simplify(dTolerance = 100, preserveTopology = TRUE)`, applied in
#' the source's native projected/meter CRS) and reprojected to EPSG:4326 for
#' interactive (leaflet) mapping. The full-resolution source shapefile is
#' maintained by the author outside the package and is not distributed here.
#'
#' @details
#' Columns:
#' \describe{
#'   \item{GRID_ID}{Grid cell identifier.}
#'   \item{Level}{Hierarchy level of the grid cell (1, 2, or 3).}
#'   \item{HIVE_ID}{HIVE identifier for the grid cell.}
#'   \item{geometry}{`MULTIPOLYGON` geometry, EPSG:4326.}
#' }
#'
#' The dataset contains 1629 features across all three hierarchy levels.
#' See `data-raw/hive.R` for the full, reproducible preparation pipeline
#' (extraction, simplification, reprojection, column selection) used to
#' generate `inst/extdata/hive.rds` from the author's source shapefile.
#'
#' @seealso [retrieve_hive()]
#' @name hive
#' @keywords internal
NULL

#' Monitoring Station Point (bundled snapshot)
#'
#' @description
#' A bundled snapshot of Ontario water and weather monitoring station point
#' locations from LIO layer `LIO_Open08/30`, shipped as
#' `inst/extdata/monitoring_stations.rds` and accessed via
#' [retrieve_monitoring_stations_bundled()]. For up-to-date retrieval from the
#' live LIO service, use [retrieve_monitoring_stations()] instead.
#'
#' @details
#' Columns:
#' \describe{
#'   \item{OGF_ID}{Ontario Geo Fabric identifier.}
#'   \item{STATION_NAME}{Station name.}
#'   \item{STATION_IDENT}{Station identifier.}
#'   \item{NETWORK_NAME}{Name of the monitoring network the station belongs to.}
#'   \item{DATA_COLLECTION_METHOD}{Data collection method.}
#'   \item{geometry}{`POINT` geometry, EPSG:4326.}
#' }
#'
#' The dataset contains 2407 features. The live origin layer is larger
#' (2588 stations as of 2026-08-03): the bundled file is a frozen
#' 2023-06-23 GeoHub snapshot, and the gap is explained in
#' `data-raw/monitoring_stations.R`.
#' See `data-raw/monitoring_stations.R` for the reproducible preparation
#' pipeline (download, column selection) used to generate
#' `inst/extdata/monitoring_stations.rds`.
#'
#' @section Provenance:
#' Published by the Ontario Ministry of Natural Resources and Forestry.
#'
#' @section Licence:
#' Open Government Licence - Ontario.
#'
#' @seealso [retrieve_monitoring_stations_bundled()]
#' @name monitoring_stations
#' @keywords internal
NULL
