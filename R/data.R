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
