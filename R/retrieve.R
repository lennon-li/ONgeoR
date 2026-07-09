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

#' Retrieve MOH service locations
#'
#' Retrieves Ministry of Health service location points (hospitals, clinics,
#' and other health service facilities) from the LIO Open Data REST service
#' (`LIO_Open09/26`), optionally filtered by service type.
#'
#' Note: this source has 11,625 features; v0.1 does not implement
#' pagination, so results are limited to what the service returns for a
#' single request (subject to the server's own record-count cap). Use
#' `service_type` to narrow the query and stay within that limit.
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
    refresh = refresh
  )
}
