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

#' Find the nearest targets to each source geometry
#'
#' For each source geometry, returns the `k` nearest targets in ascending
#' distance, optionally capped at `max_dist_km`. Use `k = Inf` with
#' `max_dist_km` for a pure radius search.
#'
#' @param source An `sf` object of points, or a `data.frame` with `lon`/`lat`
#'   columns (assumed CRS 4326 / WGS 84).
#' @param target An `sf` object of candidate geometries.
#' @param k Integer. Number of nearest targets to return per source. Defaults
#'   to `1`. If a source has fewer than `k` targets available, all are returned.
#' @param max_dist_km Numeric or `NULL`. If set, drop targets farther than this
#'   distance (km). Defaults to `NULL` (no cap). A source with no target in
#'   range contributes zero rows.
#'
#' @return A [tibble::tibble()] with the source columns, `rank` (1 = nearest),
#'   the matched target columns, `distance_km`, and `source_url` / `target_url`
#'   / `retrieved_at` provenance columns. Uses a full source-by-target distance
#'   matrix (not spatial-indexed); adequate at current scale.
#'
#' @examples
#' if (interactive()) {
#'   points <- data.frame(lon = -79.3832, lat = 43.6532)
#'   result <- nearest(points, retrieve_moh_service_locations(), k = 3)
#' }
#'
#' @export
nearest <- function(source, target, k = 1, max_dist_km = NULL) {
  if (inherits(source, "data.frame") && !inherits(source, "sf")) {
    source <- sf::st_as_sf(source, coords = c("lon", "lat"), crs = 4326)
  }

  source_data <- tibble::as_tibble(sf::st_drop_geometry(source))
  if (ncol(source_data) == 0) {
    source_data <- tibble::tibble(point_id = seq_len(nrow(source)))
  }
  target_data <- tibble::as_tibble(sf::st_drop_geometry(target))

  distances_km <- matrix(
    as.numeric(sf::st_distance(source, target)) / 1000,
    nrow = nrow(source), ncol = nrow(target)
  )

  rows <- vector("list", nrow(source))
  for (i in seq_len(nrow(source))) {
    ordered <- order(distances_km[i, ])
    idx <- ordered[seq_len(min(k, length(ordered)))]
    if (!is.null(max_dist_km)) {
      idx <- idx[distances_km[i, idx] <= max_dist_km]
    }
    if (length(idx) == 0) next

    rows[[i]] <- cbind(
      source_data[rep(i, length(idx)), , drop = FALSE],
      rank = seq_along(idx),
      target_data[idx, , drop = FALSE],
      distance_km = distances_km[i, idx]
    )
  }

  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) {
    result <- cbind(
      source_data[0, , drop = FALSE], rank = integer(),
      target_data[0, , drop = FALSE], distance_km = numeric()
    )
  } else {
    result <- do.call(rbind, rows)
  }

  result <- tibble::as_tibble(result)
  result$source_url <- provenance_attr(source, "source_url")
  result$target_url <- provenance_attr(target, "source_url")
  result$retrieved_at <- provenance_attr(target, "retrieved_at")

  result
}
