#' Join points to Public Health Units
#'
#' Performs a point-in-polygon spatial join of point locations to Public
#' Health Unit (PHU) boundaries.
#'
#' @param points An `sf` object of points, or a `data.frame` with `lon` and
#'   `lat` columns (assumed CRS 4326 / WGS 84).
#' @param phu An `sf` object of PHU boundaries, as returned by
#'   [retrieve_phu()]. If `NULL` (the default), PHU boundaries are retrieved
#'   automatically.
#'
#' @return A [tibble::tibble()] with the original point data, the joined
#'   `PHU_ID` and `PHU_NAME_ENG` columns, and `source_url` / `retrieved_at`
#'   provenance columns.
#'
#' @examples
#' if (interactive()) {
#'   points <- data.frame(lon = -79.3832, lat = 43.6532)
#'   result <- points_to_phu(points)
#' }
#'
#' @export
points_to_phu <- function(points, phu = NULL) {
  if (is.null(phu)) {
    phu <- retrieve_phu()
  }

  if (inherits(points, "data.frame") && !inherits(points, "sf")) {
    points <- sf::st_as_sf(points, coords = c("lon", "lat"), crs = 4326)
  }

  joined <- sf::st_join(points, phu)

  result <- tibble::as_tibble(sf::st_drop_geometry(joined))
  result$source_url <- attr(phu, "source_url")
  result$retrieved_at <- attr(phu, "retrieved_at")

  result
}

#' Join a polygon layer to another polygon layer
#'
#' Performs a spatial join between two polygon layers, e.g. municipalities
#' to Public Health Units. Uses [sf::st_join()] with an intersects
#' predicate.
#'
#' @param from An `sf` object of polygons to be joined (e.g. municipalities).
#' @param to An `sf` object of polygons to join to (e.g. PHU boundaries).
#'
#' @return A [tibble::tibble()] with the attributes of `from` joined to the
#'   matching attributes of `to`, plus `source_url_to` / `retrieved_at`
#'   provenance columns describing `to`.
#'
#' @examples
#' if (interactive()) {
#'   upper_tier <- retrieve_municipal("upper")
#'   phu <- retrieve_phu()
#'   result <- polygon_to_polygon(upper_tier, phu)
#' }
#'
#' @export
polygon_to_polygon <- function(from, to) {
  joined <- sf::st_join(from, to, join = sf::st_intersects)

  result <- tibble::as_tibble(sf::st_drop_geometry(joined))
  result$source_url_to <- attr(to, "source_url")
  result$retrieved_at <- attr(to, "retrieved_at")

  result
}
