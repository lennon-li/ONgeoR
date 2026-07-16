#' Retrieve Public Health Unit boundaries
#'
#' Retrieves Ontario Public Health Unit (PHU) boundaries from the LIO
#' Open Data REST service (`LIO_Open09/44`).
#'
#' @param simplify Logical. If `TRUE`, requests generalized geometry from the
#'   service (`maxAllowableOffset = 10`) to reduce payload size. Defaults to
#'   `FALSE`: independently simplifying each PHU polygon distorts shared
#'   borders between adjacent units, which can misassign points near a
#'   boundary. This layer is small (34 features) and fast to fetch at full
#'   precision, so simplification is opt-in rather than default.
#' @param refresh Logical. If `TRUE`, bypasses any cached copy and re-fetches
#'   from the live API. Defaults to `FALSE`.
#'
#' @return An `sf` object of PHU boundary polygons, with `source_url`,
#'   `source_name`, and `retrieved_at` attributes attached for provenance.
#'
#' @examples
#' if (interactive()) {
#'   phu <- retrieve_phu()
#' }
#'
#' @export
retrieve_phu <- function(simplify = FALSE, refresh = FALSE) {
  fetch_lio_sf(
    service_layer = "LIO_Open09/44",
    source_name = "MOH Public Health Unit Boundary",
    simplify = simplify,
    refresh = refresh
  )
}

#' Retrieve Ontario Health Region boundaries
#'
#' Retrieves Ontario Health Region boundaries from the LIO Open Data REST
#' service (`LIO_Open09/52`).
#'
#' @param simplify Logical. If `TRUE` (the default), requests generalized
#'   geometry from the service. Unlike [retrieve_phu()], this layer's
#'   full-precision geometry is unreliable to fetch: these 6 regions are
#'   province-scale with much more complex boundaries than the 34 PHUs, and
#'   the LIO ArcGIS service intermittently fails ("Could not access any
#'   server machines") on the unsimplified request for this specific layer.
#'   Set to `FALSE` if you need full precision and are prepared to retry on
#'   failure.
#' @param refresh Logical. If `TRUE`, bypasses any cached copy and re-fetches
#'   from the live API. Defaults to `FALSE`.
#'
#' @return An `sf` object of Ontario Health Region boundary polygons, with
#'   `source_url`, `source_name`, and `retrieved_at` attributes attached.
#'
#' @examples
#' if (interactive()) {
#'   health_regions <- retrieve_health_region()
#' }
#'
#' @export
retrieve_health_region <- function(simplify = TRUE, refresh = FALSE) {
  fetch_lio_sf(
    service_layer = "LIO_Open09/52",
    source_name = "Ontario Health Region",
    simplify = simplify,
    refresh = refresh
  )
}

#' Retrieve municipal boundaries
#'
#' Retrieves Ontario municipal boundaries from the LIO Open Data REST
#' service, either the upper/district tier (`LIO_Open03/13`) or the
#' lower/single tier (`LIO_Open03/14`).
#'
#' @param tier Character. Either `"upper"` (upper-tier and district
#'   municipalities) or `"lower"` (lower-tier and single-tier
#'   municipalities). Defaults to `"upper"`.
#' @param simplify Logical. If `TRUE` (the default), requests generalized
#'   geometry from the service.
#' @param refresh Logical. If `TRUE`, bypasses any cached copy and re-fetches
#'   from the live API. Defaults to `FALSE`.
#'
#' @return An `sf` object of municipal boundary polygons, with `source_url`,
#'   `source_name`, and `retrieved_at` attributes attached.
#'
#' @examples
#' if (interactive()) {
#'   upper_tier <- retrieve_municipal("upper")
#' }
#'
#' @export
retrieve_municipal <- function(tier = c("upper", "lower"), simplify = TRUE,
                               refresh = FALSE) {
  tier <- match.arg(tier)

  if (tier == "upper") {
    fetch_lio_sf(
      service_layer = "LIO_Open03/13",
      source_name = "Municipal Bnd Upper And Dist",
      simplify = simplify,
      refresh = refresh
    )
  } else {
    fetch_lio_sf(
      service_layer = "LIO_Open03/14",
      source_name = "Municipal Bnd Lower And Single",
      simplify = simplify,
      refresh = refresh
    )
  }
}

#' Retrieve airport boundaries
#'
#' Retrieves official airport boundaries from the LIO Open Data REST service
#' (`LIO_Open05/0`).
#'
#' @param simplify Logical. If `TRUE`, requests generalized geometry from the
#'   service (`maxAllowableOffset = 10`). Defaults to `FALSE`: confirmed live
#'   that the simplified request returns corrupted geometry for this layer
#'   (`GEOMETRYCOLLECTION` instead of polygons, for all 403 features) rather
#'   than valid generalized boundaries -- the same class of distortion
#'   documented for [retrieve_phu()], caught here by live-testing rather than
#'   assumed from feature count. Do not flip this default without re-testing
#'   live.
#' @param refresh Logical. If `TRUE`, bypasses any cached copy and re-fetches
#'   from the live API. Defaults to `FALSE`.
#'
#' @return An `sf` object of airport boundary polygons, with `source_url`,
#'   `source_name`, and `retrieved_at` attributes attached.
#'
#' @examples
#' if (interactive()) {
#'   airports <- retrieve_airport()
#' }
#'
#' @export
retrieve_airport <- function(simplify = FALSE, refresh = FALSE) {
  fetch_lio_sf(
    service_layer = "LIO_Open05/0",
    source_name = "Airport Official",
    simplify = simplify,
    refresh = refresh
  )
}

#' Retrieve waste management site boundaries
#'
#' Retrieves waste management site boundaries from the LIO Open Data REST
#' service (`LIO_Open08/9`).
#'
#' @param simplify Logical. If `TRUE`, requests generalized geometry from the
#'   service (`maxAllowableOffset = 10`). Defaults to `FALSE`: confirmed live
#'   that the simplified request returns corrupted geometry for this layer
#'   (`GEOMETRYCOLLECTION` instead of polygons, for all 813 features) rather
#'   than valid generalized boundaries -- the same class of distortion
#'   documented for [retrieve_phu()], caught here by live-testing rather than
#'   assumed from feature count. Do not flip this default without re-testing
#'   live.
#' @param refresh Logical. If `TRUE`, bypasses any cached copy and re-fetches
#'   from the live API. Defaults to `FALSE`.
#'
#' @return An `sf` object of waste management site boundary polygons, with
#'   `source_url`, `source_name`, and `retrieved_at` attributes attached.
#'
#' @examples
#' if (interactive()) {
#'   waste_sites <- retrieve_waste_management()
#' }
#'
#' @export
retrieve_waste_management <- function(simplify = FALSE, refresh = FALSE) {
  fetch_lio_sf(
    service_layer = "LIO_Open08/9",
    source_name = "Waste Management Site",
    simplify = simplify,
    refresh = refresh
  )
}

#' Retrieve a synthetic coarse air-quality raster
#'
#' Generates a deterministic synthetic `SpatRaster` of ground-level PM2.5
#' (micrograms per cubic metre) covering Ontario. No raster source exists in
#' the Ontario GeoHub registry (every registered source is vector), so this
#' function provides a reproducible raster surface to exercise the package's
#' raster linking and mapping paths end-to-end.
#'
#' Values are a pure, deterministic function of each cell's centroid
#' coordinates: a smooth north-to-south gradient (higher over the populated
#' south) plus two fixed Gaussian hotspots near Toronto and Ottawa. There is
#' no random component, so two calls return identical rasters.
#'
#' @param refresh Logical. Accepted for signature uniformity with the other
#'   `retrieve_*()` functions but unused: synthetic data is computed on demand
#'   and needs no cache or network access. Defaults to `FALSE`.
#'
#' @return A single-layer `SpatRaster` (layer `"pm25"`) in EPSG:4326 spanning
#'   the Ontario bounding box, with `source_name`, `source_url`, and
#'   `retrieved_at` R attributes attached for provenance. Note that terra
#'   operations may drop these attributes; downstream code reads them through
#'   an NA-safe fallback.
#'
#' @examples
#' if (interactive()) {
#'   r <- retrieve_synthetic_raster()
#'   terra::plot(r)
#' }
#'
#' @export
retrieve_synthetic_raster <- function(refresh = FALSE) {
  r <- terra::rast(
    xmin = -95.2, xmax = -74.3, ymin = 41.7, ymax = 56.9,
    ncols = 42, nrows = 30,
    crs = "EPSG:4326"
  )

  coords <- terra::crds(r, na.rm = FALSE)
  lon <- coords[, 1]
  lat <- coords[, 2]

  ymin <- 41.7
  ymax <- 56.9
  south_fraction <- (ymax - lat) / (ymax - ymin)
  base <- 4 + 5 * south_fraction

  gaussian <- function(clon, clat, amp, sigma) {
    amp * exp(-((lon - clon)^2 + (lat - clat)^2) / (2 * sigma^2))
  }
  toronto <- gaussian(-79.4, 43.7, amp = 5, sigma = 0.8)
  ottawa <- gaussian(-75.7, 45.4, amp = 3.5, sigma = 0.8)

  pm25 <- base + toronto + ottawa
  pm25 <- pmin(pmax(pm25, 3), 15)

  terra::values(r) <- pm25
  names(r) <- "pm25"
  terra::varnames(r) <- "pm25"

  attr(r, "source_name") <- "Synthetic Air Quality Surface (PM2.5)"
  attr(r, "source_url") <- "synthetic://ongeor/pm25"
  attr(r, "retrieved_at") <- Sys.time()

  r
}

#' Retrieve MOH service locations
#'
#' Retrieves Ministry of Health service location points (hospitals, clinics,
#' and other health service facilities) from the LIO Open Data REST service
#' (`LIO_Open09/26`), optionally filtered by service type.
#'
#' @param service_type Character or `NULL`. If supplied, filters results to
#'   rows where `SERVICE_TYPE` equals this value. If `NULL` (the default),
#'   no filter is applied.
#' @param refresh Logical. If `TRUE`, bypasses any cached copy and re-fetches
#'   from the live API. Defaults to `FALSE`.
#'
#' @return An `sf` object of MOH service location points, with `source_url`,
#'   `source_name`, and `retrieved_at` attributes attached.
#'
#' @examples
#' if (interactive()) {
#'   hospitals <- retrieve_moh_service_locations(service_type = "Hospital")
#' }
#'
#' @export
retrieve_moh_service_locations <- function(service_type = NULL,
                                           refresh = FALSE) {
  where <- "1=1"
  if (!is.null(service_type)) {
    where <- sprintf("SERVICE_TYPE = '%s'", service_type)
  }

  fetch_lio_sf(
    service_layer = "LIO_Open09/26",
    source_name = "MOH Service Location",
    where = where,
    simplify = FALSE,
    refresh = refresh,
    paginate = TRUE
  )
}

#' Retrieve HIVE Grid boundaries
#'
#' Returns the built-in HIVE Grid dataset, a custom hierarchical polygon
#' grid (Levels 1-3, 1629 features) maintained by the package author. Unlike
#' the other `retrieve_*()` functions, this does not call a live web
#' service: the data ships with the package as a static, pre-simplified
#' `sf` object (see `data-raw/hive.R` for the reproducible prep pipeline
#' that generated it from the author's source shapefile).
#'
#' @param refresh Logical. Accepted for signature uniformity with the other
#'   `retrieve_*()` functions but unused: HIVE is a static built-in dataset
#'   with no live source to re-fetch from. Defaults to `FALSE`.
#'
#' @return An `sf` object of HIVE Grid polygons (`GRID_ID`, `Level`,
#'   `HIVE_ID` columns) in EPSG:4326, with `source_url`, `source_name`, and
#'   `retrieved_at` attributes attached for provenance.
#'
#' @examples
#' if (interactive()) {
#'   hive <- retrieve_hive()
#' }
#'
#' @export
retrieve_hive <- function(refresh = FALSE) {
  path <- system.file("extdata", "hive.rds", package = "ONgeoR")
  readRDS(path)
}
