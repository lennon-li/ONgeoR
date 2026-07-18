#' Build an auditable crosswalk table between two geographic layers
#'
#' Joins two `sf` layers (e.g. municipalities to Public Health Units) and
#' returns a tidy crosswalk table with full source provenance.
#'
#' @param from An `sf` object: the source layer (e.g. municipal boundaries).
#' @param to An `sf` object: the target layer (e.g. PHU boundaries).
#' @param method Character. Assignment rule for the crosswalk:
#'   * `"within"` (default) / `"intersects"`: spatial-join predicate. If
#'     `method = "within"` and `from` is polygonal while `to` is point-type,
#'     the join direction is geometrically degenerate (a polygon is never
#'     "within" a point). In that case `build_crosswalk()` auto-corrects by
#'     joining `to` within `from` instead, emits an informative message, and
#'     builds the same output schema from the corrected join.
#'   * `"point_on_surface"`: representative-point assignment for point-like
#'     `from` polygons. Each `from` polygon is reduced to a single
#'     guaranteed-interior point (`sf::st_point_on_surface()`, not the
#'     centroid, which can fall outside a concave polygon) and joined
#'     `"within"` the `to` boundaries. `to` must be a polygon layer.
#'   * `"largest_overlap"`: same-scale polygon-to-polygon assignment. Each
#'     `from` polygon is assigned to the single `to` polygon it shares the
#'     largest intersection area with, and the `coverage` column reports that
#'     winner's share of the `from` polygon's area. Both layers must be
#'     polygonal.
#'   * `"weighted"`: polygon-to-polygon apportionment. Every intersecting
#'     `to` polygon is retained, with `coverage` reporting its share of the
#'     `from` polygon's area. Coverage values for a `from` polygon sum to at
#'     most 1, and equal 1 only when the `to` layer fully covers it. The
#'     `largest_overlap` result is the argmax row of the weighted result.
#'
#'   `build_crosswalk()` returns an assignment table only: it never emits or
#'   contains geometry. `"largest_overlap"` uses intersection internally as
#'   area arithmetic only.
#'
#' @return A [tibble::tibble()] with columns `from_id`, `from_name`,
#'   `from_source`, `to_id`, `to_name`, `to_source`, `match_method`,
#'   `match_distance_km` (always `NA`, reserved for nearest-neighbour
#'   matching in a future version), `coverage` (the winner's area share for
#'   `"largest_overlap"`, each intersecting pair's area share for `"weighted"`,
#'   otherwise `NA`), `from_id_col`, `to_id_col`, `source_url_from`,
#'   `source_url_to`, and `retrieved_at`.
#'
#' @seealso The "What linking does, by layer types" section of
#'   `vignette("building-crosswalks", package = "ONgeoR")` tabulates which
#'   operation each pair of layer geometries selects (polygon/point/raster),
#'   including where the `coverage` column comes from.
#'
#' @examples
#' if (interactive()) {
#'   upper_tier <- retrieve_municipal("upper")
#'   phu <- retrieve_phu()
#'   crosswalk <- build_crosswalk(upper_tier, phu, method = "within")
#' }
#'
#' @export
build_crosswalk <- function(from, to,
                            method = c("within", "intersects",
                                       "point_on_surface", "largest_overlap",
                                       "weighted")) {
  method <- match.arg(method)

  from_id_col <- layer_id_col(from)
  from_name_col <- layer_name_col(from)
  to_id_col <- layer_id_col(to)
  to_name_col <- layer_name_col(to)

  coverage <- NA_real_

  if (method %in% c("largest_overlap", "weighted")) {
    if (method == "weighted") {
      assignment <- crosswalk_weighted_overlap(from, to)
      from_index <- assignment$from_index
      to_index <- assignment$to_index
      coverage <- assignment$coverage
    } else {
      assignment <- crosswalk_largest_overlap(from, to)
      from_index <- seq_len(nrow(from))
      to_index <- assignment$winner
      coverage <- assignment$coverage
    }
    from_id <- as.character(from[[from_id_col]])[from_index]
    from_name <- as.character(from[[from_name_col]])[from_index]
    to_id <- as.character(to[[to_id_col]])[to_index]
    to_name <- as.character(to[[to_name_col]])[to_index]
  } else if (method == "point_on_surface") {
    if (!is_polygon_geom(to)) {
      rlang::abort(
        paste(
          "method = \"point_on_surface\" reduces `from` to representative",
          "points and joins them within `to`, so `to` must be a",
          "polygon/boundary layer, not points. Use method = \"within\" or",
          "\"intersects\" (or nearest()) for a point `to` layer."
        ),
        class = "ongeor_crosswalk_point_on_surface_needs_polygon"
      )
    }
    from_points <- point_on_surface_layer(from)
    linked <- link(from_points, to, predicate = "within")
    from_id <- as.character(linked[[from_id_col]])
    from_name <- as.character(linked[[from_name_col]])
    to_id <- as.character(linked[[to_id_col]])
    to_name <- as.character(linked[[to_name_col]])
  } else {
    if (method == "within" && is_polygon_geom(from) && is_point_geom(to)) {
      rlang::inform(
        paste(
          "build_crosswalk(): auto-corrected join direction for a",
          "point-in-boundary match (from is polygonal, to is point-type);",
          "linking `to` within `from` instead of `from` within `to`."
        ),
        class = "ongeor_crosswalk_reordered"
      )
      linked <- link(to, from, predicate = method)
    } else {
      linked <- link(from, to, predicate = method)
    }
    from_id <- as.character(linked[[from_id_col]])
    from_name <- as.character(linked[[from_name_col]])
    to_id <- as.character(linked[[to_id_col]])
    to_name <- as.character(linked[[to_name_col]])
  }

  tibble::tibble(
    from_id = from_id,
    from_name = from_name,
    from_source = provenance_attr(from, "source_name"),
    to_id = to_id,
    to_name = to_name,
    to_source = provenance_attr(to, "source_name"),
    match_method = method,
    match_distance_km = NA_real_,
    coverage = coverage,
    from_id_col = from_id_col,
    to_id_col = to_id_col,
    source_url_from = provenance_attr(from, "source_url"),
    source_url_to = provenance_attr(to, "source_url"),
    retrieved_at = provenance_attr(to, "retrieved_at")
  )
}

#' Reduce a from layer to guaranteed-interior representative points
#'
#' Replaces each `from` polygon with its `sf::st_point_on_surface()` point
#' (always interior, unlike a centroid). Point layers are returned unchanged.
#' The reduction runs on the geometry only (an `sfc`, so sf does not warn that
#' attributes are assumed constant) and on a projected transform (EPSG:3347,
#' Statistics Canada Lambert) so sf does not warn about lon/lat planar
#' operations; the points are transformed back to the `from` layer's CRS. The
#' returned object keeps the `from` layer's attribute columns and provenance
#' attributes, so `guess_id_col()` / `guess_name_col()` work unchanged.
#'
#' @param from An `sf` object of polygons (or points).
#' @return An `sf` object of the `from` attributes with `POINT` geometry.
#' @keywords internal
#' @noRd
point_on_surface_layer <- function(from) {
  if (is_point_geom(from)) {
    return(from)
  }
  crs_from <- sf::st_crs(from)
  geom_proj <- sf::st_transform(sf::st_geometry(from), 3347)
  points <- sf::st_transform(sf::st_point_on_surface(geom_proj), crs_from)
  out <- from
  sf::st_geometry(out) <- points
  out
}

#' Assign each from polygon to the largest-overlap to polygon
#'
#' For each `from` polygon, finds the `to` polygon with which it shares the
#' greatest intersection area and reports that winner and the winner's share of
#' the `from` polygon's area (in (0, 1]). Candidate pairs come from
#' `sf::st_intersects()`; areas are computed on a projected transform
#' (EPSG:3347) for robust planar arithmetic, on geometry-only `sfc` extracts so
#' sf does not warn about attribute constancy. A `from` polygon with no
#' intersecting `to` polygon yields `NA` winner and `NA` coverage (mirroring a
#' left join keeping unmatched rows). No geometry is returned; intersection is
#' used only as area arithmetic.
#'
#' @param from,to `sf` polygon layers.
#' @return A list with `winner` (integer index into `to`, `NA` when unmatched)
#'   and `coverage` (numeric, `NA` when unmatched), both of length `nrow(from)`.
#' @keywords internal
#' @noRd
crosswalk_largest_overlap <- function(from, to) {
  if (!is_polygon_geom(from) || !is_polygon_geom(to)) {
    rlang::abort(
      paste(
        "method = \"largest_overlap\" requires both `from` and `to` to be",
        "polygon layers. For a point layer, use method = \"within\" /",
        "\"intersects\" (or nearest()) instead."
      ),
      class = "ongeor_crosswalk_largest_overlap_needs_polygons"
    )
  }

  from_geom <- sf::st_transform(sf::st_geometry(from), 3347)
  to_geom <- sf::st_transform(sf::st_geometry(to), 3347)

  candidates <- sf::st_intersects(from_geom, to_geom)
  from_areas <- as.numeric(sf::st_area(from_geom))

  n <- length(from_geom)
  winner <- rep(NA_integer_, n)
  coverage <- rep(NA_real_, n)

  for (i in seq_len(n)) {
    cand <- candidates[[i]]
    if (length(cand) == 0) {
      next
    }
    inter_areas <- vapply(cand, function(j) {
      inter <- sf::st_intersection(from_geom[i], to_geom[j])
      if (length(inter) == 0) {
        return(0)
      }
      sum(as.numeric(sf::st_area(inter)))
    }, numeric(1))
    best <- which.max(inter_areas)
    winner[i] <- cand[best]
    coverage[i] <- inter_areas[best] / from_areas[i]
  }

  list(winner = winner, coverage = coverage)
}

crosswalk_weighted_overlap <- function(from, to) {
  if (!is_polygon_geom(from) || !is_polygon_geom(to)) {
    rlang::abort(
      paste(
        "method = \"weighted\" requires both `from` and `to` to be",
        "polygon layers. For a point layer, use method = \"within\" /",
        "\"intersects\" (or nearest()) instead."
      ),
      class = "ongeor_crosswalk_weighted_needs_polygons"
    )
  }

  from_geom <- sf::st_transform(sf::st_geometry(from), 3347)
  to_geom <- sf::st_transform(sf::st_geometry(to), 3347)
  candidates <- sf::st_intersects(from_geom, to_geom)
  from_areas <- as.numeric(sf::st_area(from_geom))
  from_index <- integer()
  to_index <- integer()
  coverage <- numeric()

  for (i in seq_along(candidates)) {
    cand <- candidates[[i]]
    if (length(cand) > 0) {
      inter_areas <- vapply(cand, function(j) {
        inter <- sf::st_intersection(from_geom[i], to_geom[j])
        if (length(inter) == 0) return(0)
        sum(as.numeric(sf::st_area(inter)))
      }, numeric(1))
      positive <- which(inter_areas > 0)
    } else {
      positive <- integer()
    }

    if (length(positive) == 0) {
      from_index <- c(from_index, i)
      to_index <- c(to_index, NA_integer_)
      coverage <- c(coverage, NA_real_)
    } else {
      from_index <- c(from_index, rep(i, length(positive)))
      to_index <- c(to_index, cand[positive])
      coverage <- c(coverage, inter_areas[positive] / from_areas[i])
    }
  }

  list(from_index = from_index, to_index = to_index, coverage = coverage)
}
