#' Link geometries to a target layer by spatial relationship
#'
#' Joins a source layer to a target layer using a spatial predicate. Covers
#' point-in-polygon and polygon-to-polygon joins. Raster sources are planned
#' (reduced to centroids per the package's raster linking model) but not yet
#' implemented.
#'
#' @param source An `sf` object (points or polygons), or a `data.frame` with
#'   `lon` and `lat` columns (assumed CRS 4326 / WGS 84). A `SpatRaster`
#'   routes to the raster-reduction path (not yet implemented).
#' @param target An `sf` object, typically polygons.
#' @param predicate Character. Spatial join predicate: `"within"` (default),
#'   `"intersects"`, or `"contains"`. Note: simplified boundary data (e.g.
#'   municipal boundaries retrieved with `simplify = TRUE`) often needs
#'   `"intersects"`, because `"within"` misses matches against generalized
#'   borders. For very complex geometry, simplify first
#'   (retrieve with `simplify = TRUE`, or `sf::st_simplify()`) then link.
#'
#' @return A [tibble::tibble()] with the source's non-geometry columns, the
#'   matched target columns, and `source_url` / `target_url` / `retrieved_at`
#'   provenance columns. Column-name collisions between source and target
#'   follow `sf::st_join()`'s default `.x`/`.y` suffixing.
#'
#' @examples
#' if (interactive()) {
#'   points <- data.frame(lon = -79.3832, lat = 43.6532)
#'   result <- link(points, retrieve_phu())
#' }
#'
#' @export
link <- function(source, target,
                 predicate = c("within", "intersects", "contains")) {
  predicate <- match.arg(predicate)

  if (inherits(source, "SpatRaster") || inherits(target, "SpatRaster")) {
    rlang::abort(
      "raster linking not yet implemented; see the package raster linking model"
    )
  }

  if (inherits(source, "data.frame") && !inherits(source, "sf")) {
    source <- sf::st_as_sf(source, coords = c("lon", "lat"), crs = 4326)
  }

  predicate_fn <- switch(predicate,
    within = sf::st_within,
    intersects = sf::st_intersects,
    contains = sf::st_contains
  )

  joined <- sf::st_join(source, target, join = predicate_fn)
  result <- tibble::as_tibble(sf::st_drop_geometry(joined))

  result$source_url <- provenance_attr(source, "source_url")
  result$target_url <- provenance_attr(target, "source_url")
  result$retrieved_at <- provenance_attr(target, "retrieved_at")

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
