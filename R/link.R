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

#' Calculate point-to-facility distances
#'
#' @param points An `sf` point object.
#' @param facilities An `sf` point object.
#'
#' @return A numeric matrix of distances in kilometers, with one row per
#'   point and one column per facility.
#'
#' @noRd
facility_distance_matrix_km <- function(points, facilities) {
  distances_m <- sf::st_distance(points, facilities)

  matrix(
    as.numeric(distances_m) / 1000,
    nrow = nrow(distances_m),
    ncol = ncol(distances_m)
  )
}

#' Find the nearest facilities to points
#'
#' Finds the `k` nearest Ministry of Health service location facilities for
#' each input point.
#'
#' @param points An `sf` object of points, or a `data.frame` with `lon` and
#'   `lat` columns (assumed CRS 4326 / WGS 84).
#' @param facilities An `sf` point object of facilities, as returned by
#'   [retrieve_moh_service_locations()]. If `NULL` (the default), facilities
#'   are retrieved automatically.
#' @param k Integer. Number of nearest facilities to return per point.
#'   Defaults to `1`. If `k` exceeds the number of facilities, all facilities
#'   are returned for each point.
#' @param service_type Character or `NULL`. Passed to
#'   [retrieve_moh_service_locations()] when `facilities` is `NULL`; ignored
#'   when `facilities` is supplied directly.
#'
#' @return A [tibble::tibble()] with the original point data, a `rank` column,
#'   matched facility attributes, `distance_km`, and `source_url` /
#'   `retrieved_at` provenance columns. Distance calculation uses a full
#'   point-by-facility distance matrix, which may be memory-intensive for
#'   large inputs.
#'
#' @examples
#' if (interactive()) {
#'   points <- data.frame(lon = -79.3832, lat = 43.6532)
#'   result <- nearest_facility(points, k = 3, service_type = "Hospital")
#' }
#'
#' @export
nearest_facility <- function(points, facilities = NULL, k = 1,
                             service_type = NULL) {
  if (is.null(facilities)) {
    facilities <- retrieve_moh_service_locations(service_type = service_type)
  }

  if (inherits(points, "data.frame") && !inherits(points, "sf")) {
    points <- sf::st_as_sf(points, coords = c("lon", "lat"), crs = 4326)
  }

  point_data <- tibble::as_tibble(sf::st_drop_geometry(points))
  if (ncol(point_data) == 0) {
    point_data <- tibble::tibble(point_id = seq_len(nrow(points)))
  }

  facility_data <- tibble::as_tibble(sf::st_drop_geometry(facilities))
  distances_km <- facility_distance_matrix_km(points, facilities)
  max_k <- min(k, nrow(facilities))

  rows <- vector("list", nrow(points))
  for (point_index in seq_len(nrow(points))) {
    facility_indices <- order(distances_km[point_index, ])[seq_len(max_k)]

    rows[[point_index]] <- cbind(
      point_data[rep(point_index, max_k), , drop = FALSE],
      rank = seq_len(max_k),
      facility_data[facility_indices, , drop = FALSE],
      distance_km = distances_km[point_index, facility_indices]
    )
  }

  result <- tibble::as_tibble(do.call(rbind, rows))
  result$source_url <- attr(facilities, "source_url")
  result$retrieved_at <- attr(facilities, "retrieved_at")

  result
}

#' Find facilities within a radius of points
#'
#' Finds all Ministry of Health service location facilities within a radius
#' of each input point.
#'
#' @param points An `sf` object of points, or a `data.frame` with `lon` and
#'   `lat` columns (assumed CRS 4326 / WGS 84).
#' @param facilities An `sf` point object of facilities, as returned by
#'   [retrieve_moh_service_locations()]. If `NULL` (the default), facilities
#'   are retrieved automatically.
#' @param radius_km Numeric. Search radius in kilometers. Facilities with
#'   `distance_km <= radius_km` are included.
#' @param service_type Character or `NULL`. Passed to
#'   [retrieve_moh_service_locations()] when `facilities` is `NULL`; ignored
#'   when `facilities` is supplied directly.
#'
#' @return A [tibble::tibble()] with the original point data, matched facility
#'   attributes, `distance_km`, and `source_url` / `retrieved_at` provenance
#'   columns. Points with no facilities within the radius contribute zero
#'   rows. Distance calculation uses a full point-by-facility distance matrix,
#'   which may be memory-intensive for large inputs.
#'
#' @examples
#' if (interactive()) {
#'   points <- data.frame(lon = -79.3832, lat = 43.6532)
#'   result <- facilities_within(points, radius_km = 10)
#' }
#'
#' @export
facilities_within <- function(points, facilities = NULL, radius_km,
                              service_type = NULL) {
  if (is.null(facilities)) {
    facilities <- retrieve_moh_service_locations(service_type = service_type)
  }

  if (inherits(points, "data.frame") && !inherits(points, "sf")) {
    points <- sf::st_as_sf(points, coords = c("lon", "lat"), crs = 4326)
  }

  point_data <- tibble::as_tibble(sf::st_drop_geometry(points))
  if (ncol(point_data) == 0) {
    point_data <- tibble::tibble(point_id = seq_len(nrow(points)))
  }

  facility_data <- tibble::as_tibble(sf::st_drop_geometry(facilities))
  distances_km <- facility_distance_matrix_km(points, facilities)

  rows <- vector("list", nrow(points))
  for (point_index in seq_len(nrow(points))) {
    facility_indices <- which(distances_km[point_index, ] <= radius_km)
    facility_indices <- facility_indices[
      order(distances_km[point_index, facility_indices])
    ]

    if (length(facility_indices) > 0) {
      rows[[point_index]] <- cbind(
        point_data[rep(point_index, length(facility_indices)), , drop = FALSE],
        facility_data[facility_indices, , drop = FALSE],
        distance_km = distances_km[point_index, facility_indices]
      )
    }
  }

  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) {
    result <- cbind(
      point_data[0, , drop = FALSE],
      facility_data[0, , drop = FALSE],
      distance_km = numeric()
    )
  } else {
    result <- do.call(rbind, rows)
  }

  result <- tibble::as_tibble(result)
  result$source_url <- attr(facilities, "source_url")
  result$retrieved_at <- attr(facilities, "retrieved_at")

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
