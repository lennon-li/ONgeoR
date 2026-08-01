#' @importFrom htmlwidgets saveWidget
NULL

#' Retrieve a layer by source registry id
#'
#' Dispatches to the appropriate `retrieve_*()` function for a given source
#' id, so callers can retrieve any registered layer without knowing which
#' underlying retrieval function backs it.
#'
#' @param source_id Character scalar. A source id from [list_sources()].
#' @param refresh Logical. If `TRUE`, bypasses any cached copy and re-fetches
#'   from the live API. Defaults to `FALSE`.
#' @param max_age Maximum cache age in days for registry-backed LIO sources.
#'   Defaults to `NULL`, which accepts any cached copy.
#'
#' @return An `sf` object, or a `SpatRaster` for raster sources (e.g.
#'   `"synthetic_air_quality"`).
#'
#' @examples
#' \dontrun{
#' # Retrieves from the Ontario LIO REST service and caches the result.
#' phu <- retrieve_source("phu_boundaries")
#' }
#'
#' @export
retrieve_source <- function(source_id, refresh = FALSE, max_age = NULL) {
  switch(source_id,
    phu_boundaries = retrieve_phu(refresh = refresh),
    ontario_health_regions = retrieve_health_region(refresh = refresh),
    municipal_upper = retrieve_municipal("upper", refresh = refresh),
    municipal_lower = retrieve_municipal("lower", refresh = refresh),
    airport_official = retrieve_airport(refresh = refresh),
    waste_management_site = retrieve_waste_management(refresh = refresh),
    moh_service_locations = retrieve_moh_service_locations(refresh = refresh),
    synthetic_air_quality = retrieve_synthetic_raster(refresh = refresh),
    hive = retrieve_hive(refresh = refresh),
    conservation_authority = retrieve_conservation_authority(refresh = refresh),
    orwn_station = retrieve_orwn_station(refresh = refresh),
    monitoring_stations = retrieve_monitoring_stations(refresh = refresh),
    monitoring_stations_simple = retrieve_monitoring_stations_simple(),
    {
      valid_ids <- list_sources()$source_id
      if (source_id %in% valid_ids) {
        source <- get_source(source_id)
        if (!is.null(source$service_layer)) {
          return(fetch_lio_sf(
            service_layer = source$service_layer,
            source_name = source$name,
            simplify = source$simplify %||% TRUE,
            paginate = source$paginate %||% FALSE,
            refresh = refresh,
            max_age = max_age
          ))
        }
      }
      rlang::abort(sprintf(
        "Unknown source_id '%s'. Valid source ids are: %s.",
        source_id,
        paste(valid_ids, collapse = ", ")
      ))
    }
  )
}

#' Retrieve a layer by source registry id (internal alias)
#'
#' @param source_id Character scalar. A source id from [list_sources()].
#' @param refresh Logical. If `TRUE`, bypasses any cached copy and re-fetches
#'   from the live API.
#'
#' @return An `sf` object.
#' @keywords internal
#' @noRd
retrieve_by_source_id <- function(source_id, refresh = FALSE) {
  retrieve_source(source_id, refresh = refresh)
}

#' Retrieve distinct source layers
#'
#' @param source_ids Character vector of source ids from [list_sources()].
#' @param refresh Logical. If `TRUE`, bypasses any cached copy and re-fetches
#'   from the live API.
#'
#' @return A named list of `sf` objects keyed by source id.
#' @keywords internal
#' @noRd
retrieve_layers <- function(source_ids, refresh = FALSE) {
  source_ids <- unique(source_ids)
  layers <- lapply(source_ids, retrieve_source, refresh = refresh)
  stats::setNames(layers, source_ids)
}

#' Build crosswalks for every from/to source id pair
#'
#' @param from_ids Character vector of source ids.
#' @param to_ids Character vector of source ids.
#' @param refresh Logical. If `TRUE`, bypasses any cached copy and re-fetches
#'   from the live API.
#' @param method Character. Crosswalk assignment rule passed to
#'   [build_crosswalk()] for every pair. Defaults to `"intersects"`.
#'
#' @return A [tibble::tibble()] containing all pairwise crosswalk rows.
#' @keywords internal
#' @noRd
cross_crosswalk <- function(from_ids, to_ids, refresh = FALSE,
                            method = "intersects") {
  pairs <- expand.grid(
    from_id = from_ids,
    to_id = to_ids,
    stringsAsFactors = FALSE
  )
  layers <- retrieve_layers(unique(c(from_ids, to_ids)), refresh = refresh)

  results <- lapply(seq_len(nrow(pairs)), function(i) {
    from_id <- pairs$from_id[[i]]
    to_id <- pairs$to_id[[i]]
    crosswalk <- build_crosswalk(
      layers[[from_id]],
      layers[[to_id]],
      method = method
    )
    crosswalk$from_source_id <- from_id
    crosswalk$to_source_id <- to_id
    crosswalk
  })

  do.call(rbind, results)
}

#' Map crosswalk source layers
#'
#' @description
#' Builds an interactive Leaflet map with one toggleable group for each
#' distinct source id used in a crosswalk workflow. Polygon layers are rendered
#' as polygons and point layers are rendered as circle markers. Popups show the
#' layer's guessed name field.
#'
#' @param layers A named list of `sf` objects keyed by source id.
#' @param from_ids Character vector of source ids used as crosswalk sources.
#' @param to_ids Character vector of source ids used as crosswalk targets.
#'
#' @return A `leaflet` htmlwidget.
#'
#' @examples
#' layers <- list(
#'   hive = retrieve_hive()[1:50, ],
#'   phu = retrieve_phu_simple()
#' )
#' map_crosswalk(layers, from_ids = "hive", to_ids = "phu")
#'
#' @export
map_crosswalk <- function(layers, from_ids, to_ids) {
  ids <- unique(c(from_ids, to_ids))
  do.call(map_layers, layers[ids])
}

#' Render a reproducible R script for a CLI run
#'
#' @param from_ids Character vector of source ids used as crosswalk sources.
#' @param to_ids Character vector of source ids used as crosswalk targets.
#' @param output_dir Character scalar output directory.
#' @param method Character. Crosswalk assignment rule recorded in the script
#'   and passed to [build_crosswalk()] for every pair, so the script rebuilds
#'   the crosswalk with the same rule as the run it documents. Defaults to
#'   `"intersects"`.
#'
#' @return A character vector containing valid R code.
#'
#' @examples
#' render_reproducer_script("airport_official", "phu_boundaries", "output")
#'
#' @family app support interfaces
#' @export
render_reproducer_script <- function(from_ids, to_ids, output_dir,
                                     method = "intersects") {
  source_ids <- unique(c(from_ids, to_ids))
  layer_calls <- vapply(source_ids, source_retrieve_call, character(1))
  layer_lines <- sprintf("  %s = %s", source_ids, layer_calls)

  paste0(
    "library(ONgeoR)\n\n",
    "from_ids <- ", deparse_chr(from_ids), "\n",
    "to_ids <- ", deparse_chr(to_ids), "\n",
    "method <- ", deparse_chr(method), "\n",
    "output_dir <- ", deparse_chr(output_dir), "\n\n",
    "layers <- list(\n",
    paste(layer_lines, collapse = ",\n"),
    "\n)\n\n",
    # A single pair - what the app always emits - goes straight through
    # build_crosswalk() on the layers already retrieved above. cross_crosswalk()
    # is for the CLI's multi-pair cross product: it re-retrieves every layer and
    # appends from_source_id/to_source_id to disambiguate pairs, so using it here
    # would both double the downloads and produce a 16-column CSV where the app
    # hands the user 14.
    if (length(from_ids) == 1L && length(to_ids) == 1L) {
      "cw <- build_crosswalk(layers[[from_ids]], layers[[to_ids]], method = method)\n"
    } else {
      "cw <- ONgeoR:::cross_crosswalk(from_ids, to_ids, method = method)\n"
    },
    "map <- map_crosswalk(layers, from_ids, to_ids)\n\n",
    "dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)\n",
    "write.csv(cw, file.path(output_dir, \"mapping.csv\"), row.names = FALSE)\n",
    "htmlwidgets::saveWidget(map, file.path(output_dir, \"map.html\"), selfcontained = TRUE)\n",
    "writeLines(\n",
    "  ONgeoR:::render_reproducer_script(from_ids, to_ids, output_dir, method = method),\n",
    "  file.path(output_dir, \"reproduce.R\")\n",
    ")\n"
  )
}

#' Render a postal-code reproducer script
#'
#' @param input_file Character scalar path to the user's input file.
#' @param postal_col Character scalar naming the postal-code column in the
#'   input file.
#' @param output_dir Character scalar output directory.
#'
#' @return A character scalar containing valid R code.
#'
#' @examples
#' render_postal_reproducer_script("records.csv", "postal_code", tempdir())
#'
#' @family app support interfaces
#' @export
render_postal_reproducer_script <- function(input_file, postal_col, output_dir) {
  paste0(
    "library(ONgeoR)\n\n",
    "# Point this at your own input file.\n",
    "input_file <- ", deparse_chr(input_file), "\n",
    "postal_col <- ", deparse_chr(postal_col), "\n",
    "output_dir <- ", deparse_chr(output_dir), "\n\n",
    "records <- utils::read.csv(input_file, stringsAsFactors = FALSE, ",
    "check.names = FALSE)\n",
    "postal_links <- resolve_postal(records[[postal_col]], all_links = TRUE)\n",
    "joined <- merge(\n",
    "  records, postal_links,\n",
    "  by.x = postal_col, by.y = \"postal_code\",\n",
    "  all.x = TRUE, sort = FALSE\n",
    ")\n\n",
    "dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)\n",
    "utils::write.csv(joined, file.path(output_dir, \"postal_da.csv\"), ",
    "row.names = FALSE)\n"
  )
}

source_retrieve_call <- function(source_id) {
  switch(source_id,
    phu_boundaries = "retrieve_phu()",
    ontario_health_regions = "retrieve_health_region()",
    municipal_upper = "retrieve_municipal(\"upper\")",
    municipal_lower = "retrieve_municipal(\"lower\")",
    airport_official = "retrieve_airport()",
    waste_management_site = "retrieve_waste_management()",
    moh_service_locations = "retrieve_moh_service_locations()",
    conservation_authority = "retrieve_conservation_authority()",
    orwn_station = "retrieve_orwn_station()",
    monitoring_stations = "retrieve_monitoring_stations()",
    monitoring_stations_simple = "retrieve_monitoring_stations_simple()",
    synthetic_air_quality = "retrieve_synthetic_raster()",
    hive = "retrieve_hive()",
    {
      valid_ids <- list_sources()$source_id
      if (source_id %in% valid_ids) {
        source <- get_source(source_id)
        if (!is.null(source$service_layer)) {
          return(sprintf('retrieve_source("%s")', source_id))
        }
      }
      rlang::abort(sprintf(
        "Unknown source_id '%s'. Valid source ids are: %s.",
        source_id,
        paste(valid_ids, collapse = ", ")
      ))
    }
  )
}

deparse_chr <- function(x) {
  paste(deparse(x), collapse = "")
}
