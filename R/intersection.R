#' Build a polygon-to-polygon intersection table
#'
#' Computes every overlapping pair between a source polygon layer and a target
#' polygon layer using a single vectorized `sf::st_intersection()` call, and
#' returns one row per pair with area shares. Targets with no overlap at all
#' receive one explicit all-NA-match row so every target feature is represented.
#'
#' @param source An `sf` polygon layer (the matched unit).
#' @param target An `sf` polygon layer (the index unit).
#' @param min_overlap Numeric. Minimum intersection area in square metres for a
#'   pair to be retained. Defaults to `0`, meaning strictly greater than zero
#'   (boundary-touching polygons that share only an edge are excluded).
#'
#' @return A [tibble::tibble()] with one row per overlapping pair (plus
#'   all-NA-match rows for unmatched targets). Fixed columns: `interaction_id`,
#'   `target_id`, `target_name`, `target_source`, `source_id`, `source_name`,
#'   `source_source`, `relation`, `overlap_area_m2`, `share_of_target`,
#'   `share_of_source`, `match_distance_km`, then every source attribute
#'   prefixed `src_`, every target attribute prefixed `tgt_`, then
#'   `source_url_source`, `source_url_target`, `retrieved_at`, `simplify_used`.
#'   No geometry column is ever emitted.
#'
#' @examples
#' if (interactive()) {
#'   municipal <- retrieve_municipal("upper")
#'   phu <- retrieve_phu()
#'   pairs <- build_intersection(municipal, phu)
#' }
#'
#' @export
build_intersection <- function(source, target, min_overlap = 0) {
  if (!is_polygon_geom(source)) {
    rlang::abort(
      paste(
        "build_intersection() requires `source` to be a polygon layer.",
        "For point layers, use build_link() which dispatches automatically."
      ),
      class = "ongeor_intersection_source_not_polygon"
    )
  }
  if (!is_polygon_geom(target)) {
    rlang::abort(
      paste(
        "build_intersection() requires `target` to be a polygon layer.",
        "For point layers, use build_link() which dispatches automatically."
      ),
      class = "ongeor_intersection_target_not_polygon"
    )
  }

  source_id_col <- layer_id_col(source)
  source_name_col <- layer_name_col(source)
  target_id_col <- layer_id_col(target)
  target_name_col <- layer_name_col(target)

  abort_on_duplicate_ids(source, source_id_col, target, target_id_col)

  source_geom <- sf::st_transform(sf::st_geometry(source), 3347)
  target_geom <- sf::st_transform(sf::st_geometry(target), 3347)

  inters <- sf::st_intersection(source_geom, target_geom)
  idx <- attr(inters, "idx")
  areas <- as.numeric(sf::st_area(inters))

  keep <- areas > min_overlap
  src_idx <- idx[keep, 1]
  tgt_idx <- idx[keep, 2]
  pair_areas <- areas[keep]

  source_areas <- as.numeric(sf::st_area(source_geom))
  target_areas <- as.numeric(sf::st_area(target_geom))

  share_tgt <- round(pair_areas / target_areas[tgt_idx], 3)
  share_src <- round(pair_areas / source_areas[src_idx], 3)

  source_data <- tibble::as_tibble(sf::st_drop_geometry(source))
  target_data <- tibble::as_tibble(sf::st_drop_geometry(target))

  src_cols <- paste0("src_", colnames(source_data))
  tgt_cols <- paste0("tgt_", colnames(target_data))

  all_names <- c(
    "interaction_id", "target_id", "target_name", "target_source",
    "source_id", "source_name", "source_source", "relation",
    "overlap_area_m2", "share_of_target", "share_of_source",
    "match_distance_km", src_cols, tgt_cols,
    "source_url_source", "source_url_target", "retrieved_at", "simplify_used"
  )
  dupes <- all_names[duplicated(all_names)]
  if (length(dupes) > 0) {
    rlang::abort(
      paste(
        "Column name collision after src_/tgt_ prefixing:",
        paste(unique(dupes), collapse = ", ")
      ),
      class = "ongeor_intersection_column_collision"
    )
  }

  n_pairs <- length(src_idx)

  if (n_pairs > 0) {
    src_carried <- source_data[src_idx, , drop = FALSE]
    tgt_carried <- target_data[tgt_idx, , drop = FALSE]
    colnames(src_carried) <- src_cols
    colnames(tgt_carried) <- tgt_cols

    target_ids <- as.character(target_data[[target_id_col]][tgt_idx])
    source_ids <- as.character(source_data[[source_id_col]][src_idx])

    matched <- tibble::tibble(
      interaction_id = paste0(target_ids, "__", source_ids),
      target_id = target_ids,
      target_name = as.character(target_data[[target_name_col]][tgt_idx]),
      target_source = provenance_attr(target, "source_name"),
      source_id = source_ids,
      source_name = as.character(source_data[[source_name_col]][src_idx]),
      source_source = provenance_attr(source, "source_name"),
      relation = "intersects",
      overlap_area_m2 = pair_areas,
      share_of_target = share_tgt,
      share_of_source = share_src,
      match_distance_km = NA_real_
    )
    matched <- dplyr_bind_cols(matched, src_carried, tgt_carried)
    matched$source_url_source <- provenance_attr(source, "source_url")
    matched$source_url_target <- provenance_attr(target, "source_url")
    matched$retrieved_at <- provenance_attr(target, "retrieved_at")
    matched$simplify_used <- provenance_attr(source, "simplify")
  } else {
    matched <- empty_intersection_output(
      src_cols, tgt_cols, source_data, target_data
    )
  }

  matched_targets <- unique(tgt_idx)
  unmatched <- setdiff(seq_len(nrow(target)), matched_targets)

  if (length(unmatched) > 0) {
    um_tgt_carried <- target_data[unmatched, , drop = FALSE]
    colnames(um_tgt_carried) <- tgt_cols
    um_target_ids <- as.character(target_data[[target_id_col]][unmatched])

    um_src <- source_data[rep(NA_integer_, length(unmatched)), , drop = FALSE]
    colnames(um_src) <- src_cols

    unmatched_rows <- tibble::tibble(
      interaction_id = paste0(um_target_ids, "__", NA_character_),
      target_id = um_target_ids,
      target_name = as.character(target_data[[target_name_col]][unmatched]),
      target_source = provenance_attr(target, "source_name"),
      source_id = NA_character_,
      source_name = NA_character_,
      source_source = provenance_attr(source, "source_name"),
      relation = NA_character_,
      overlap_area_m2 = NA_real_,
      share_of_target = NA_real_,
      share_of_source = NA_real_,
      match_distance_km = NA_real_
    )
    unmatched_rows <- dplyr_bind_cols(unmatched_rows, um_src, um_tgt_carried)
    unmatched_rows$source_url_source <- provenance_attr(source, "source_url")
    unmatched_rows$source_url_target <- provenance_attr(target, "source_url")
    unmatched_rows$retrieved_at <- provenance_attr(target, "retrieved_at")
    unmatched_rows$simplify_used <- provenance_attr(source, "simplify")

    result <- rbind(matched, unmatched_rows)
  } else {
    result <- matched
  }

  if (anyDuplicated(result$interaction_id) > 0) {
    rlang::abort(
      paste(
        "interaction_id is not unique; the id columns of one or both layers",
        "contain duplicate values."
      ),
      class = "ongeor_intersection_id_not_unique"
    )
  }

  result
}

#' Build a point-to-point nearest-match table
#'
#' Matches each target point to its single nearest source point. Returns the
#' same column schema as [build_intersection()] so the two are row-bindable.
#'
#' @param source An `sf` point layer (the candidate matches).
#' @param target An `sf` point layer (the units to be matched).
#'
#' @return A [tibble::tibble()] with one row per target feature. Fixed columns
#'   match [build_intersection()]; `relation` is `"nearest"`,
#'   `match_distance_km` is populated, and `overlap_area_m2`,
#'   `share_of_target`, `share_of_source` are `NA`.
#'
#' @examples
#' if (interactive()) {
#'   stations <- retrieve_orwn_station()
#'   airports <- retrieve_airport()
#'   pairs <- build_nearest_pairs(stations, airports)
#' }
#'
#' @export
build_nearest_pairs <- function(source, target) {
  if (!is_point_geom(source)) {
    rlang::abort(
      paste(
        "build_nearest_pairs() requires `source` to be a point layer.",
        "For polygon layers, use build_link() which dispatches automatically."
      ),
      class = "ongeor_nearest_pairs_source_not_point"
    )
  }
  if (!is_point_geom(target)) {
    rlang::abort(
      paste(
        "build_nearest_pairs() requires `target` to be a point layer.",
        "For polygon layers, use build_link() which dispatches automatically."
      ),
      class = "ongeor_nearest_pairs_target_not_point"
    )
  }

  source_id_col <- layer_id_col(source)
  source_name_col <- layer_name_col(source)
  target_id_col <- layer_id_col(target)
  target_name_col <- layer_name_col(target)

  abort_on_duplicate_ids(source, source_id_col, target, target_id_col)

  source_data <- tibble::as_tibble(sf::st_drop_geometry(source))
  target_data <- tibble::as_tibble(sf::st_drop_geometry(target))

  # nearest() cbinds both layers' attribute tables without prefixing, so any
  # column name they share is fatal - and every LIO point layer carries the
  # same OGF_ID / OBJECTID / *_DATETIME metadata fields, which made all 30
  # ordered pairs of registered point sources fail. Route only distinctly
  # named row indices through it and attach the attributes here, where the
  # src_/tgt_ prefixes already keep the two sides apart.
  #
  # nearest(source, target, k) returns k nearest targets per source, and we
  # want the nearest source per target, so the arguments are swapped.
  tgt_min <- sf::st_sf(
    .tgt_row = seq_len(nrow(target)),
    geometry = sf::st_geometry(target)
  )
  src_min <- sf::st_sf(
    .src_row = seq_len(nrow(source)),
    geometry = sf::st_geometry(source)
  )
  nrst <- nearest(tgt_min, src_min, k = 1)

  tgt_idx <- nrst$.tgt_row
  src_idx <- nrst$.src_row

  tgt_slice <- target_data[tgt_idx, , drop = FALSE]
  src_slice <- source_data[src_idx, , drop = FALSE]

  src_cols <- paste0("src_", colnames(source_data))
  tgt_cols <- paste0("tgt_", colnames(target_data))

  all_names <- c(
    "interaction_id", "target_id", "target_name", "target_source",
    "source_id", "source_name", "source_source", "relation",
    "overlap_area_m2", "share_of_target", "share_of_source",
    "match_distance_km", src_cols, tgt_cols,
    "source_url_source", "source_url_target", "retrieved_at", "simplify_used"
  )
  dupes <- all_names[duplicated(all_names)]
  if (length(dupes) > 0) {
    rlang::abort(
      paste(
        "Column name collision after src_/tgt_ prefixing:",
        paste(unique(dupes), collapse = ", ")
      ),
      class = "ongeor_nearest_pairs_column_collision"
    )
  }

  target_ids <- as.character(tgt_slice[[target_id_col]])
  source_ids <- as.character(src_slice[[source_id_col]])

  src_carried <- src_slice
  colnames(src_carried) <- src_cols
  tgt_carried <- tgt_slice
  colnames(tgt_carried) <- tgt_cols

  result <- tibble::tibble(
    interaction_id = paste0(target_ids, "__", source_ids),
    target_id = target_ids,
    target_name = as.character(tgt_slice[[target_name_col]]),
    target_source = provenance_attr(target, "source_name"),
    source_id = source_ids,
    source_name = as.character(src_slice[[source_name_col]]),
    source_source = provenance_attr(source, "source_name"),
    relation = "nearest",
    overlap_area_m2 = NA_real_,
    share_of_target = NA_real_,
    share_of_source = NA_real_,
    match_distance_km = nrst$distance_km
  )
  result <- dplyr_bind_cols(result, src_carried, tgt_carried)
  result$source_url_source <- provenance_attr(source, "source_url")
  result$source_url_target <- provenance_attr(target, "source_url")
  result$retrieved_at <- provenance_attr(target, "retrieved_at")
  result$simplify_used <- provenance_attr(source, "simplify")

  result
}

#' Summarise an intersection or nearest table by target
#'
#' Collapses a pairs table (from [build_intersection()] or
#' [build_nearest_pairs()]) to exactly one row per distinct target, with
#' multi-valued fields as `"; "`-delimited strings.
#'
#' @param pairs A tibble produced by [build_intersection()] or
#'   [build_nearest_pairs()].
#'
#' @return A [tibble::tibble()] with exactly one row per distinct target.
#'   Columns: `target_id`, `target_name`, `target_source`, `n_source`,
#'   `source_ids`, `source_names`, `shares_of_target`, `shares_of_source`,
#'   `dominant_source_id`, `dominant_source_name`,
#'   `dominant_share_of_target`, `covered_share`, `match_distance_km`,
#'   all `tgt_*` attributes, and provenance columns.
#'
#' @examples
#' if (interactive()) {
#'   pairs <- build_intersection(retrieve_municipal("upper"), retrieve_phu())
#'   summary_tbl <- summarise_by_target(pairs)
#' }
#'
#' @export
summarise_by_target <- function(pairs) {
  target_ids <- unique(pairs$target_id)

  tgt_attr_cols <- grep("^tgt_", colnames(pairs), value = TRUE)
  src_attr_cols <- grep("^src_", colnames(pairs), value = TRUE)

  rows <- lapply(target_ids, function(tid) {
    if (is.na(tid)) {
      sub <- pairs[is.na(pairs$target_id), , drop = FALSE]
    } else {
      sub <- pairs[pairs$target_id == tid & !is.na(pairs$source_id), , drop = FALSE]
    }
    all_sub <- pairs[!is.na(pairs$target_id) & pairs$target_id == tid, , drop = FALSE]
    if (nrow(all_sub) == 0) all_sub <- pairs[is.na(pairs$target_id), , drop = FALSE]

    n_source <- nrow(sub)

    if (n_source == 0) {
      tgt_vals <- if (nrow(all_sub) > 0) all_sub[1, tgt_attr_cols, drop = FALSE] else NULL
      row <- tibble::tibble(
        target_id = tid,
        target_name = if (nrow(all_sub) > 0) all_sub$target_name[1] else NA_character_,
        target_source = if (nrow(all_sub) > 0) all_sub$target_source[1] else NA_character_,
        n_source = 0L,
        source_ids = NA_character_,
        source_names = NA_character_,
        shares_of_target = NA_character_,
        shares_of_source = NA_character_,
        dominant_source_id = NA_character_,
        dominant_source_name = NA_character_,
        dominant_share_of_target = NA_real_,
        covered_share = 0,
        match_distance_km = NA_real_
      )
      for (col in src_attr_cols) {
        row[[col]] <- NA_character_
      }
      if (!is.null(tgt_vals)) {
        row <- dplyr_bind_cols(row, tibble::as_tibble(tgt_vals))
      }
      row$source_url_source <- if (nrow(all_sub) > 0) all_sub$source_url_source[1] else NA_character_
      row$source_url_target <- if (nrow(all_sub) > 0) all_sub$source_url_target[1] else NA_character_
      row$retrieved_at <- if (nrow(all_sub) > 0) all_sub$retrieved_at[1] else NA
      row$simplify_used <- if (nrow(all_sub) > 0) all_sub$simplify_used[1] else NA
      return(row)
    }

    shares_tgt <- sub$share_of_target
    dominant_idx <- which.max(shares_tgt)

    row <- tibble::tibble(
      target_id = tid,
      target_name = sub$target_name[1],
      target_source = sub$target_source[1],
      n_source = n_source,
      source_ids = paste(sub$source_id, collapse = "; "),
      source_names = paste(sub$source_name, collapse = "; "),
      shares_of_target = paste(shares_tgt, collapse = "; "),
      shares_of_source = paste(sub$share_of_source, collapse = "; "),
      dominant_source_id = sub$source_id[dominant_idx],
      dominant_source_name = sub$source_name[dominant_idx],
      dominant_share_of_target = shares_tgt[dominant_idx],
      covered_share = sum(shares_tgt, na.rm = TRUE),
      match_distance_km = if (all(is.na(sub$match_distance_km))) {
        NA_real_
      } else {
        sub$match_distance_km[dominant_idx]
      }
    )
    for (col in src_attr_cols) {
      row[[col]] <- paste(as.character(sub[[col]]), collapse = "; ")
    }
    row <- dplyr_bind_cols(row, tibble::as_tibble(sub[1, tgt_attr_cols, drop = FALSE]))
    row$source_url_source <- sub$source_url_source[1]
    row$source_url_target <- sub$source_url_target[1]
    row$retrieved_at <- sub$retrieved_at[1]
    row$simplify_used <- sub$simplify_used[1]
    row
  })

  do.call(rbind, rows)
}

#' Link two layers with no method choice
#'
#' Infers the linking mode from the geometry types of the two layers and
#' dispatches to the appropriate implementation. Point-to-point uses nearest
#' matching; polygon-to-polygon uses intersection; all other combinations
#' delegate to the existing [build_crosswalk()] or [link()] unchanged.
#'
#' @param source An `sf` object or `SpatRaster`.
#' @param target An `sf` object or `SpatRaster`.
#'
#' @return A tibble whose schema depends on the dispatched implementation.
#'
#' @eval link_matrix_roxygen()
#'
#' @examples
#' if (interactive()) {
#'   municipal <- retrieve_municipal("upper")
#'   phu <- retrieve_phu()
#'   result <- build_link(municipal, phu)
#' }
#'
#' @export
build_link <- function(source, target) {
  source_is_raster <- inherits(source, "SpatRaster")
  target_is_raster <- inherits(target, "SpatRaster")

  if (source_is_raster || target_is_raster) {
    return(link(source, target))
  }

  if (is_point_geom(source) && is_point_geom(target)) {
    return(build_nearest_pairs(source, target))
  }

  if (is_polygon_geom(source) && is_polygon_geom(target)) {
    return(build_intersection(source, target))
  }

  build_crosswalk(source, target)
}

#' Geometry combination matrix for linking
#'
#' A data frame defining what each source-target geometry pair does. This is
#' the single source of truth rendered into the app, README, vignettes, and
#' roxygen by later stages.
#'
#' @return A [data.frame()] with columns `source_kind`, `target_kind`, `mode`,
#'   `what_it_does`, `output`. Nine rows: the ordered pairs of point, polygon,
#'   raster.
#' @keywords internal
#' @noRd
link_matrix_df <- function() {
  data.frame(
    source_kind = c(
      "point", "point", "point",
      "polygon", "polygon", "polygon",
      "raster", "raster", "raster"
    ),
    target_kind = c(
      "point", "polygon", "raster",
      "point", "polygon", "raster",
      "point", "polygon", "raster"
    ),
    mode = c(
      "Nearest", "Containment", "Sampling",
      "Containment", "Intersection", "Sampling",
      "Sampling", "Cell sampling into boundaries", "Not supported"
    ),
    what_it_does = c(
      "Each target point is matched to its single nearest source point.",
      "Each point is matched to the boundary it falls inside.",
      "Each point takes the value of the cell containing it.",
      "Direction is auto-corrected internally.",
      paste(
        "Every overlapping pair, with the share of each target covered",
        "and the share of each source falling inside."
      ),
      "Each polygon samples the raster values it overlaps.",
      "Raster reduced to cell centroids.",
      "Each cell centroid is matched to the boundary it falls inside.",
      "Not supported; align/resample with terra first."
    ),
    output = c(
      "nearest table", "crosswalk", "linked values table",
      "crosswalk", "intersection table", "linked values table",
      "linked values table", "linked values table", "none"
    ),
    stringsAsFactors = FALSE
  )
}

# Renders link_matrix_df() as roxygen so the man pages carry the same matrix as
# the app help modal, the README and the vignette. Inserted with @eval, which
# means the Rd is generated at document() time and cannot drift from the data.
link_matrix_roxygen <- function() {
  m <- link_matrix_df()
  items <- sprintf(
    "  \\item{%s to %s}{%s. %s Output: %s.}",
    m$source_kind, m$target_kind, m$mode, m$what_it_does, m$output
  )
  c(
    "@section Geometry combination matrix:",
    "What an operation does is determined by the geometry types of the two",
    "layers, not by a match-rule argument:",
    "\\describe{",
    items,
    "}"
  )
}

# The whole design rests on target_id identifying exactly one target feature:
# summarise_by_target() keys on it, so two distinct features sharing an id would
# silently collapse into one row and quietly break the one-row-per-target
# guarantee. interaction_id uniqueness does not catch this, because duplicate
# targets matched to different sources still produce unique pair ids. Fail loud
# and early instead, at the point where the id columns are chosen.
abort_on_duplicate_ids <- function(source, source_id_col, target, target_id_col) {
  target_ids <- sf::st_drop_geometry(target)[[target_id_col]]
  if (anyDuplicated(target_ids) > 0) {
    dupes <- unique(target_ids[duplicated(target_ids)])
    rlang::abort(
      paste0(
        "`target` column \"", target_id_col, "\" must uniquely identify each ",
        "feature, but these values repeat: ",
        paste(utils::head(dupes, 5), collapse = ", "),
        if (length(dupes) > 5) ", ..." else "",
        ". Every target feature would otherwise be collapsed by id in the ",
        "summary table. Deduplicate the layer or pick a different id field."
      ),
      class = "ongeor_duplicate_target_ids"
    )
  }

  source_ids <- sf::st_drop_geometry(source)[[source_id_col]]
  if (anyDuplicated(source_ids) > 0) {
    dupes <- unique(source_ids[duplicated(source_ids)])
    rlang::abort(
      paste0(
        "`source` column \"", source_id_col, "\" must uniquely identify each ",
        "feature, but these values repeat: ",
        paste(utils::head(dupes, 5), collapse = ", "),
        if (length(dupes) > 5) ", ..." else "",
        ". interaction_id would not distinguish the repeated features."
      ),
      class = "ongeor_duplicate_source_ids"
    )
  }

  invisible(NULL)
}

dplyr_bind_cols <- function(...) {
  dots <- list(...)
  out <- dots[[1]]
  for (i in seq_along(dots)[-1]) {
    for (nm in colnames(dots[[i]])) {
      out[[nm]] <- dots[[i]][[nm]]
    }
  }
  tibble::as_tibble(out)
}

empty_intersection_output <- function(src_cols, tgt_cols, source_data, target_data) {
  empty <- tibble::tibble(
    interaction_id = character(),
    target_id = character(),
    target_name = character(),
    target_source = character(),
    source_id = character(),
    source_name = character(),
    source_source = character(),
    relation = character(),
    overlap_area_m2 = numeric(),
    share_of_target = numeric(),
    share_of_source = numeric(),
    match_distance_km = numeric()
  )
  for (col in src_cols) empty[[col]] <- character()
  for (col in tgt_cols) empty[[col]] <- character()
  empty$source_url_source <- character()
  empty$source_url_target <- character()
  empty$retrieved_at <- as.POSIXct(character())
  empty$simplify_used <- character()
  empty
}
