#' Read a bundled sf layer from an .rds file
#'
#' The bundled layers are plain `readRDS()` reads that never call into sf, so
#' nothing would otherwise load the sf namespace. Without it loaded, sf's S3
#' methods are not registered and `[` falls through to `[.data.frame`, which
#' silently degrades the geometry column from `sfc` to a bare list: the object
#' still prints as `sf` and still carries an `sf_column` attribute, but the
#' next spatial operation fails far from the cause with
#' "attr(obj, \"sf_column\") does not point to a geometry column".
#'
#' Loading the namespace before handing the object back makes subsetting behave
#' for callers who have not attached sf themselves.
#'
#' @return The `sf` object stored at `path`.
#' @keywords internal
#' @noRd
read_bundled_sf <- function(path) {
  loadNamespace("sf")
  readRDS(path)
}

census_ontario_pruid <- "35"

#' Validate an EPSG:4326 bounding box
#'
#' Shared by every retrieval entry point that takes a `bbox`, so a caller sees
#' one convention and one error message no matter which layer is being
#' windowed.
#'
#' @return A numeric vector `c(xmin, ymin, xmax, ymax)`.
#' @keywords internal
#' @noRd
bbox_envelope_values <- function(bbox) {
  values <- as.numeric(bbox)
  if (length(values) != 4 || any(!is.finite(values)) ||
      values[1] >= values[3] || values[2] >= values[4]) {
    rlang::abort(
      "`bbox` must be an sf bbox or numeric xmin, ymin, xmax, ymax in EPSG:4326."
    )
  }
  values
}

census_bbox_geometry <- function(bbox) {
  paste(bbox_envelope_values(bbox), collapse = ",")
}

#' Retrieve an Ontario 2021 census boundary layer
#'
#' Retrieves one of the registered StatCan 2021 census cartographic boundary
#' layers. Requests always apply the Ontario `PRUID = '35'` filter on the
#' server, so Canada-wide features are never downloaded.
#'
#' @param source_id Character scalar naming a registered `census_*` source.
#' @param bbox An `sf` bbox or numeric `xmin, ymin, xmax, ymax` vector in
#'   EPSG:4326. When supplied, requests only features intersecting the envelope.
#' @param simplify Logical. Whether to request generalized geometry.
#' @param refresh Logical. Whether to bypass the local cache.
#' @param max_age Numeric or `NULL`. Maximum acceptable cache age in days.
#'
#' @return An `sf` object in EPSG:4326 with retrieval provenance attributes.
#'
#' @examples
#' \dontrun{
#' census_divisions <- retrieve_census("census_cd_2021")
#' }
#'
#' @export
retrieve_census <- function(source_id, bbox = NULL, simplify = TRUE,
                            refresh = FALSE, max_age = NULL) {
  if (!is.character(source_id) || length(source_id) != 1 ||
      is.na(source_id) || !startsWith(source_id, "census_")) {
    rlang::abort("`source_id` must name a registered census_* source.")
  }
  source <- get_source(source_id)
  if (!identical(source$provider, "statcan_census")) {
    rlang::abort("`source_id` must name a registered census_* source.")
  }
  if (identical(source_id, "census_da_2021") && is.null(bbox)) {
    rlang::warn(
      "Retrieving all Ontario dissemination areas (20,465 features) may be slow; supply `bbox` when possible."
    )
  }

  geometry <- if (is.null(bbox)) NULL else census_bbox_geometry(bbox)
  cache_source_name <- if (is.null(geometry)) {
    source$name
  } else {
    paste0(source$name, " [bbox=", geometry, "]")
  }
  result <- fetch_lio_sf(
    service_layer = source$service_layer,
    source_name = cache_source_name,
    where = sprintf("PRUID='%s'", census_ontario_pruid),
    simplify = simplify,
    refresh = refresh,
    paginate = TRUE,
    max_age = max_age,
    endpoint = source$source_url,
    out_sr = 4326,
    geometry = geometry,
    geometry_type = if (is.null(geometry)) NULL else "esriGeometryEnvelope",
    in_sr = if (is.null(geometry)) NULL else 4326,
    spatial_rel = if (is.null(geometry)) NULL else "esriSpatialRelIntersects",
    validate_feature_count = is.null(bbox)
  )
  attr(result, "source_name") <- source$name
  result
}

#' Retrieve Public Health Unit boundaries
#'
#' Retrieves Ontario Public Health Unit (PHU) boundaries from the LIO
#' Open Data REST service (`LIO_Open09/44`).
#'
#' @param simplify Logical. If `TRUE` (the default), requests generalized
#'   geometry from the service (`maxAllowableOffset = 1e-04`, i.e. 0.0001
#'   degrees, since the service returns EPSG:4326 -- roughly 11 m on the
#'   ground) to reduce payload size. Set to `FALSE` if you need full-precision
#'   geometry, but be aware that the LIO service may fail to serve the
#'   full-resolution layer intermittently; if that occurs, retry with
#'   `simplify = TRUE` or set `refresh = TRUE`.
#' @param refresh Logical. If `TRUE`, bypasses any cached copy and re-fetches
#'   from the live API. Defaults to `FALSE`.
#' @param max_age Numeric or `NULL`. Maximum acceptable cache age in days;
#'   older entries are re-fetched. Defaults to `NULL`.
#'
#' @return An `sf` object of PHU boundary polygons, with `source_url`,
#'   `source_name`, and `retrieved_at` attributes attached for provenance.
#'
#' @examples
#' \dontrun{
#' # Retrieves from the Ontario LIO REST service and caches the result.
#' phu <- retrieve_phu()
#' }
#'
#' @export
retrieve_phu <- function(simplify = TRUE, refresh = FALSE, max_age = NULL) {
  fetch_lio_sf(
    service_layer = "LIO_Open09/44",
    source_name = "MOH Public Health Unit Boundary",
    simplify = simplify,
    refresh = refresh, max_age = max_age
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
#' @param max_age Numeric or `NULL`. Maximum acceptable cache age in days;
#'   older entries are re-fetched. Defaults to `NULL`.
#'
#' @return An `sf` object of Ontario Health Region boundary polygons, with
#'   `source_url`, `source_name`, and `retrieved_at` attributes attached.
#'
#' @examples
#' \dontrun{
#' # Retrieves from the Ontario LIO REST service and caches the result.
#' health_regions <- retrieve_health_region()
#' }
#'
#' @export
retrieve_health_region <- function(simplify = TRUE, refresh = FALSE, max_age = NULL) {
  fetch_lio_sf(
    service_layer = "LIO_Open09/52",
    source_name = "Ontario Health Region",
    simplify = simplify,
    refresh = refresh, max_age = max_age
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
#' @param max_age Numeric or `NULL`. Maximum acceptable cache age in days;
#'   older entries are re-fetched. Defaults to `NULL`.
#'
#' @return An `sf` object of municipal boundary polygons, with `source_url`,
#'   `source_name`, and `retrieved_at` attributes attached.
#'
#' @examples
#' \dontrun{
#' # Retrieves from the Ontario LIO REST service and caches the result.
#' upper_tier <- retrieve_municipal("upper")
#' }
#'
#' @export
retrieve_municipal <- function(tier = c("upper", "lower"), simplify = TRUE,
                               refresh = FALSE, max_age = NULL) {
  tier <- match.arg(tier)

  if (tier == "upper") {
    fetch_lio_sf(
      service_layer = "LIO_Open03/13",
      source_name = "Municipal Bnd Upper And Dist",
      simplify = simplify,
      refresh = refresh, max_age = max_age
    )
  } else {
    fetch_lio_sf(
      service_layer = "LIO_Open03/14",
      source_name = "Municipal Bnd Lower And Single",
      simplify = simplify,
      refresh = refresh, max_age = max_age
    )
  }
}

#' Retrieve airport boundaries
#'
#' Retrieves official airport boundaries from the LIO Open Data REST service
#' (`LIO_Open05/0`).
#'
#' @param simplify Logical. If `TRUE`, requests generalized geometry from the
#'   service (`maxAllowableOffset = 1e-04`, i.e. 0.0001 degrees, since the
#'   service returns EPSG:4326 -- roughly 11 m on the ground). Defaults to
#'   `FALSE`: confirmed live that the simplified request returns corrupted
#'   geometry for this layer (`GEOMETRYCOLLECTION` instead of polygons, for
#'   all 403 features) rather than valid generalized boundaries -- the same
#'   class of distortion documented for [retrieve_phu()], caught here by
#'   live-testing rather than assumed from feature count. Do not flip this
#'   default without re-testing live.
#' @param refresh Logical. If `TRUE`, bypasses any cached copy and re-fetches
#'   from the live API. Defaults to `FALSE`.
#' @param max_age Numeric or `NULL`. Maximum acceptable cache age in days;
#'   older entries are re-fetched. Defaults to `NULL`.
#'
#' @return An `sf` object of airport boundary polygons, with `source_url`,
#'   `source_name`, and `retrieved_at` attributes attached.
#'
#' @examples
#' \dontrun{
#' # Retrieves from the Ontario LIO REST service and caches the result.
#' airports <- retrieve_airport()
#' }
#'
#' @export
retrieve_airport <- function(simplify = FALSE, refresh = FALSE, max_age = NULL) {
  fetch_lio_sf(
    service_layer = "LIO_Open05/0",
    source_name = "Airport Official",
    simplify = simplify,
    refresh = refresh, max_age = max_age
  )
}

#' Retrieve waste management site boundaries
#'
#' Retrieves waste management site boundaries from the LIO Open Data REST
#' service (`LIO_Open08/9`).
#'
#' @param simplify Logical. If `TRUE`, requests generalized geometry from the
#'   service (`maxAllowableOffset = 1e-04`, i.e. 0.0001 degrees, since the
#'   service returns EPSG:4326 -- roughly 11 m on the ground). Defaults to
#'   `FALSE`: confirmed live that the simplified request returns corrupted
#'   geometry for this layer (`GEOMETRYCOLLECTION` instead of polygons, for
#'   all 813 features) rather than valid generalized boundaries -- the same
#'   class of distortion documented for [retrieve_phu()], caught here by
#'   live-testing rather than assumed from feature count. Do not flip this
#'   default without re-testing live.
#' @param refresh Logical. If `TRUE`, bypasses any cached copy and re-fetches
#'   from the live API. Defaults to `FALSE`.
#' @param max_age Numeric or `NULL`. Maximum acceptable cache age in days;
#'   older entries are re-fetched. Defaults to `NULL`.
#'
#' @return An `sf` object of waste management site boundary polygons, with
#'   `source_url`, `source_name`, and `retrieved_at` attributes attached.
#'
#' @examples
#' \dontrun{
#' # Retrieves from the Ontario LIO REST service and caches the result.
#' waste_sites <- retrieve_waste_management()
#' }
#'
#' @export
retrieve_waste_management <- function(simplify = FALSE, refresh = FALSE, max_age = NULL) {
  fetch_lio_sf(
    service_layer = "LIO_Open08/9",
    source_name = "Waste Management Site",
    simplify = simplify,
    refresh = refresh, max_age = max_age
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
#' \donttest{
#' # first call bears the one-time terra/GDAL startup cost
#' r <- retrieve_synthetic_raster()
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
#' @param max_age Numeric or `NULL`. Maximum acceptable cache age in days;
#'   older entries are re-fetched. Defaults to `NULL`.
#'
#' @return An `sf` object of MOH service location points, with `source_url`,
#'   `source_name`, and `retrieved_at` attributes attached.
#'
#' @examples
#' \dontrun{
#' # Retrieves from the Ontario LIO REST service and caches the result.
#' hospitals <- retrieve_moh_service_locations(service_type = "Hospital")
#' }
#'
#' @export
retrieve_moh_service_locations <- function(service_type = NULL,
                                           refresh = FALSE, max_age = NULL) {
  where <- "1=1"
  if (!is.null(service_type)) {
    escaped_service_type <- gsub("'", "''", service_type)
    where <- sprintf("SERVICE_TYPE = '%s'", escaped_service_type)
  }

  fetch_lio_sf(
    service_layer = "LIO_Open09/26",
    source_name = "MOH Service Location",
    where = where,
    simplify = FALSE,
    refresh = refresh,
    paginate = TRUE,
    max_age = max_age
  )
}

#' Retrieve Conservation Authority administrative areas
#'
#' Retrieves Conservation Authority administrative area boundaries from the LIO
#' Open Data REST service (`LIO_Open03/11`).
#'
#' @param simplify Logical. If `TRUE` (the default), requests generalized
#'   geometry from the service. Conservation Authority boundaries are
#'   province-scale watersheds; simplification keeps the payload small without
#'   losing analytic utility for most crosswalk use-cases.
#' @param refresh Logical. If `TRUE`, bypasses any cached copy and re-fetches
#'   from the live API. Defaults to `FALSE`.
#' @param max_age Numeric or `NULL`. Maximum acceptable cache age in days;
#'   older entries are re-fetched. Defaults to `NULL`.
#'
#' @return An `sf` object of Conservation Authority boundary polygons, with
#'   `source_url`, `source_name`, and `retrieved_at` attributes attached for
#'   provenance.
#'
#' @examples
#' \dontrun{
#' # Retrieves from the Ontario LIO REST service and caches the result.
#' ca_areas <- retrieve_conservation_authority()
#' }
#'
#' @export
retrieve_conservation_authority <- function(simplify = TRUE, refresh = FALSE,
                                            max_age = NULL) {
  fetch_lio_sf(
    service_layer = "LIO_Open03/11",
    source_name = "Conservation Authority Admin Area",
    simplify = simplify,
    refresh = refresh, max_age = max_age
  )
}

#' Retrieve Ontario Railway Network (ORWN) station points
#'
#' Retrieves railway station point locations from the Ontario Railway Network
#' (ORWN) via the LIO Open Data REST service (`LIO_Open04/15`).
#'
#' @param refresh Logical. If `TRUE`, bypasses any cached copy and re-fetches
#'   from the live API. Defaults to `FALSE`.
#' @param max_age Numeric or `NULL`. Maximum acceptable cache age in days;
#'   older entries are re-fetched. Defaults to `NULL`.
#'
#' @return An `sf` object of ORWN station points, with `source_url`,
#'   `source_name`, and `retrieved_at` attributes attached for provenance.
#'
#' @examples
#' \dontrun{
#' # Retrieves from the Ontario LIO REST service and caches the result.
#' stations <- retrieve_orwn_station()
#' }
#'
#' @export
retrieve_orwn_station <- function(refresh = FALSE, max_age = NULL) {
  fetch_lio_sf(
    service_layer = "LIO_Open04/15",
    source_name = "ORWN Station",
    simplify = FALSE,
    refresh = refresh, max_age = max_age
  )
}

#' Retrieve monitoring station points
#'
#' Retrieves Ontario water and weather monitoring station point locations from
#' the LIO Open Data REST service (`LIO_Open08/30`).
#'
#' @param simplify Logical. If `TRUE` (the default), requests generalized
#'   geometry from the service. Monitoring stations are point features, so
#'   simplification has no visible effect but is kept for consistency with
#'   the other LIO retrievers.
#' @param refresh Logical. If `TRUE`, bypasses any cached copy and re-fetches
#'   from the live API. Defaults to `FALSE`.
#' @param max_age Numeric or `NULL`. Maximum acceptable cache age in days;
#'   older entries are re-fetched. Defaults to `NULL`.
#'
#' @return An `sf` object of monitoring station points, with `source_url`,
#'   `source_name`, and `retrieved_at` attributes attached for provenance.
#'
#' @examples
#' \dontrun{
#' stations <- retrieve_monitoring_stations()
#' }
#'
#' @export
retrieve_monitoring_stations <- function(simplify = TRUE, refresh = FALSE,
                                         max_age = NULL) {
  fetch_lio_sf(
    service_layer = "LIO_Open08/30",
    source_name = "Monitoring Station Point",
    simplify = simplify,
    refresh = refresh,
    # The live layer exceeds one page (maxRecordCount 2000, 2588 records as of
    # 2026-08-03); fetching without pagination aborts on the truncated page.
    paginate = TRUE,
    max_age = max_age
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
#' hive <- retrieve_hive()
#' nrow(hive)
#'
#' @export
retrieve_hive <- function(refresh = FALSE) {
  path <- hive_data_path()
  if (!nzchar(path)) {
    rlang::abort(
      "hive.rds is missing from the installed ONgeoR package; reinstall ONgeoR.",
      class = "ongeor_hive_missing"
    )
  }
  read_bundled_sf(path)
}

#' @keywords internal
#' @noRd
hive_data_path <- function() {
  system.file("extdata", "hive.rds", package = "ONgeoR")
}

#' Retrieve simplified Public Health Unit boundaries
#'
#' Returns the built-in simplified Ontario Public Health Unit (PHU) boundary
#' layer shipped in `inst/extdata/phu_simple.rds`.  This layer is intended as
#' a lightweight, always-on reference outline for the Shiny app and other
#' mapping code.  It is NOT a substitute for [retrieve_phu()]: use
#' [retrieve_phu()] when you need full-resolution, authoritative PHU
#' boundaries or up-to-date provenance.
#'
#' The built-in file was produced by fetching full-resolution PHU boundaries
#' from the LIO Open Data REST service, reprojecting to EPSG:3161
#' (Ontario MNR Lambert), simplifying with `sf::st_simplify(dTolerance = 250,
#' preserveTopology = TRUE)`, reprojecting back to the source CRS, and
#' casting to `MULTIPOLYGON`.  The source data are distributed under the
#' Open Government Licence - Ontario.
#'
#' @return An `sf` object of 34 simplified PHU boundary `MULTIPOLYGON`s, with
#'   `source_url`, `source_name`, and `retrieved_at` attributes inherited from
#'   the full-resolution source.
#'
#' @examples
#' phu_simple <- retrieve_phu_simple()
#' nrow(phu_simple)
#'
#' @export
retrieve_phu_simple <- function() {
  path <- phu_simple_data_path()
  if (!nzchar(path)) {
    rlang::abort(
      "phu_simple.rds is missing from the installed ONgeoR package; reinstall ONgeoR.",
      class = "ongeor_phu_simple_missing"
    )
  }
  read_bundled_sf(path)
}

#' @keywords internal
#' @noRd
phu_simple_data_path <- function() {
  system.file("extdata", "phu_simple.rds", package = "ONgeoR")
}

#' Retrieve the pre-2025 simplified Public Health Unit boundaries
#'
#' Returns the built-in pre-2025 Ontario Public Health Unit (PHU) boundary
#' layer shipped in `inst/extdata/phu_simple_pre2025.rds`. This 250 m
#' simplified snapshot preserves the 34-boundary PHU vintage that pre-dates
#' the 2025 boundary changes.
#'
#' LIO no longer serves this vintage, so the snapshot cannot be refreshed.
#' Use [retrieve_phu_simple()] for the current bundled PHU boundaries, or
#' [retrieve_phu()] for the current live LIO layer.
#'
#' @return An `sf` object of 34 simplified pre-2025 PHU boundary
#'   `MULTIPOLYGON`s in WGS 84.
#'
#' @examples
#' phu_pre2025 <- retrieve_phu_pre2025()
#' nrow(phu_pre2025)
#'
#' @export
retrieve_phu_pre2025 <- function() {
  path <- phu_pre2025_data_path()
  if (!nzchar(path)) {
    rlang::abort(
      paste0(
        "phu_simple_pre2025.rds is missing from the installed ONgeoR package; ",
        "reinstall ONgeoR."
      ),
      class = "ongeor_phu_pre2025_missing"
    )
  }
  read_bundled_sf(path)
}

#' @keywords internal
#' @noRd
phu_pre2025_data_path <- function() {
  system.file("extdata", "phu_simple_pre2025.rds", package = "ONgeoR")
}

#' Retrieve bundled monitoring station points
#'
#' Returns the built-in monitoring station point layer shipped in
#' `inst/extdata/monitoring_stations.rds`. This layer is intended for examples
#' and tests that need a real point-in-polygon join with no network access.
#' It is NOT a substitute for [retrieve_monitoring_stations()]: use
#' [retrieve_monitoring_stations()] when you need up-to-date, authoritative
#' monitoring station locations.
#'
#' The built-in file was downloaded from the Esri Hub export endpoint for LIO
#' layer `LIO_Open08/30` and subset to six columns to fit the CRAN package
#' size budget. The source data are published by the Ontario Ministry of
#' Natural Resources and Forestry under the Open Government Licence - Ontario.
#'
#' @return An `sf` object of monitoring station points (`OGF_ID`,
#'   `STATION_NAME`, `STATION_IDENT`, `NETWORK_NAME`, `DATA_COLLECTION_METHOD`,
#'   `geometry` columns) in EPSG:4326, with `source_url`, `source_name`, and
#'   `retrieved_at` attributes attached for provenance. `retrieved_at` is the
#'   snapshot instant of the bundled data, not the time of the call.
#'
#' @examples
#' stations <- retrieve_monitoring_stations_bundled()
#' nrow(stations)
#'
#' @export
retrieve_monitoring_stations_bundled <- function() {
  path <- monitoring_stations_data_path()
  if (!nzchar(path)) {
    rlang::abort(
      "monitoring_stations.rds is missing from the installed ONgeoR package; reinstall ONgeoR.",
      class = "ongeor_monitoring_stations_missing"
    )
  }
  result <- read_bundled_sf(path)

  # Unlike hive.rds and the phu_simple*.rds files, this snapshot was written by
  # a plain saveRDS() of the Hub export, so it carries no provenance attributes
  # of its own. Attaching them here rather than regenerating the binary keeps
  # the shipped .rds byte-identical. Without this, every crosswalk built
  # against this layer reported to_source / source_url_to / retrieved_at as NA.
  source <- get_source("monitoring_stations_bundled")
  attr(result, "source_name") <- source$name
  attr(result, "source_url") <- source$source_url
  attr(result, "retrieved_at") <- monitoring_stations_snapshot_time()
  result
}

#' Snapshot instant of the bundled monitoring station layer
#'
#' A property of the data, not of the call: every record in the frozen GeoHub
#' export carries `SYSTEM_DATETIME` 2023-06-23T10:55:20Z (see
#' `data-raw/monitoring_stations.R`). Stamping `Sys.time()` here would
#' misreport a 2023 snapshot as freshly retrieved.
#'
#' @keywords internal
#' @noRd
monitoring_stations_snapshot_time <- function() {
  as.POSIXct("2023-06-23 10:55:20", tz = "UTC")
}

#' @keywords internal
#' @noRd
monitoring_stations_data_path <- function() {
  system.file("extdata", "monitoring_stations.rds", package = "ONgeoR")
}
