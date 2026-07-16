#' Build an auditable crosswalk table between two geographic layers
#'
#' Joins two `sf` layers (e.g. municipalities to Public Health Units) and
#' returns a tidy crosswalk table with full source provenance.
#'
#' @param from An `sf` object: the source layer (e.g. municipal boundaries).
#' @param to An `sf` object: the target layer (e.g. PHU boundaries).
#' @param method Character. Spatial join predicate: `"within"` (default) or
#'   `"intersects"`. If `method = "within"` and `from` is polygonal while
#'   `to` is point-type, the join direction is geometrically degenerate (a
#'   polygon is never "within" a point). In that case `build_crosswalk()`
#'   auto-corrects by joining `to` within `from` instead, emits an
#'   informative message, and builds the same output schema from the
#'   corrected join.
#'
#' @return A [tibble::tibble()] with columns `from_id`, `from_name`,
#'   `from_source`, `to_id`, `to_name`, `to_source`, `match_method`,
#'   `match_distance_km` (always `NA`, reserved for nearest-neighbour
#'   matching in a future version), `source_url_from`, `source_url_to`, and
#'   `retrieved_at`.
#'
#' @examples
#' if (interactive()) {
#'   upper_tier <- retrieve_municipal("upper")
#'   phu <- retrieve_phu()
#'   crosswalk <- build_crosswalk(upper_tier, phu, method = "within")
#' }
#'
#' @export
build_crosswalk <- function(from, to, method = c("within", "intersects")) {
  method <- match.arg(method)

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

  from_id_col <- guess_id_col(from)
  from_name_col <- guess_name_col(from)
  to_id_col <- guess_id_col(to)
  to_name_col <- guess_name_col(to)

  tibble::tibble(
    from_id = as.character(linked[[from_id_col]]),
    from_name = as.character(linked[[from_name_col]]),
    from_source = provenance_attr(from, "source_name"),
    to_id = as.character(linked[[to_id_col]]),
    to_name = as.character(linked[[to_name_col]]),
    to_source = provenance_attr(to, "source_name"),
    match_method = method,
    match_distance_km = NA_real_,
    source_url_from = provenance_attr(from, "source_url"),
    source_url_to = provenance_attr(to, "source_url"),
    retrieved_at = provenance_attr(to, "retrieved_at")
  )
}
