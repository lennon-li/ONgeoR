#' @importFrom htmlwidgets saveWidget
NULL

#' Retrieve a layer by source registry id
#'
#' @param source_id Character scalar. A source id from [list_sources()].
#'
#' @return An `sf` object.
#' @keywords internal
#' @noRd
retrieve_by_source_id <- function(source_id) {
  switch(source_id,
    phu_boundaries = retrieve_phu(),
    ontario_health_regions = retrieve_health_region(),
    municipal_upper = retrieve_municipal("upper"),
    municipal_lower = retrieve_municipal("lower"),
    moh_service_locations = retrieve_moh_service_locations(),
    {
      valid_ids <- list_sources()$source_id
      rlang::abort(sprintf(
        "Unknown source_id '%s'. Valid source ids are: %s.",
        source_id,
        paste(valid_ids, collapse = ", ")
      ))
    }
  )
}

#' Retrieve distinct source layers
#'
#' @param source_ids Character vector of source ids from [list_sources()].
#'
#' @return A named list of `sf` objects keyed by source id.
#' @keywords internal
#' @noRd
retrieve_layers <- function(source_ids) {
  source_ids <- unique(source_ids)
  layers <- lapply(source_ids, retrieve_by_source_id)
  stats::setNames(layers, source_ids)
}

#' Build crosswalks for every from/to source id pair
#'
#' @param from_ids Character vector of source ids.
#' @param to_ids Character vector of source ids.
#'
#' @return A [tibble::tibble()] containing all pairwise crosswalk rows.
#' @keywords internal
#' @noRd
cross_crosswalk <- function(from_ids, to_ids) {
  pairs <- expand.grid(
    from_id = from_ids,
    to_id = to_ids,
    stringsAsFactors = FALSE
  )
  layers <- retrieve_layers(unique(c(from_ids, to_ids)))

  results <- lapply(seq_len(nrow(pairs)), function(i) {
    from_id <- pairs$from_id[[i]]
    to_id <- pairs$to_id[[i]]
    crosswalk <- build_crosswalk(
      layers[[from_id]],
      layers[[to_id]],
      method = "intersects"
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
#' if (interactive()) {
#'   from_ids <- "municipal_upper"
#'   to_ids <- "phu_boundaries"
#'   layers <- retrieve_layers(c(from_ids, to_ids))
#'   map_crosswalk(layers, from_ids, to_ids)
#' }
#'
#' @export
map_crosswalk <- function(layers, from_ids, to_ids) {
  source_ids <- unique(c(from_ids, to_ids))
  map <- leaflet::leaflet() |>
    leaflet::addTiles()

  for (source_id in source_ids) {
    layer <- layers[[source_id]]
    name_col <- guess_name_col(layer)
    geometry_types <- unique(as.character(sf::st_geometry_type(layer)))
    polygon_types <- c("POLYGON", "MULTIPOLYGON", "GEOMETRYCOLLECTION")

    if (all(geometry_types %in% c("POINT", "MULTIPOINT"))) {
      popups <- as.character(layer[[name_col]])
      map <- leaflet::addCircleMarkers(
        map,
        data = layer,
        group = source_id,
        popup = popups,
        radius = 4,
        stroke = FALSE,
        fillOpacity = 0.8
      )
    } else if (all(geometry_types %in% polygon_types)) {
      polygon_layer <- if ("GEOMETRYCOLLECTION" %in% geometry_types) {
        extract_polygon_collection(layer)
      } else {
        layer
      }
      polygon_layer <- polygon_layer[!sf::st_is_empty(polygon_layer), ]
      popups <- as.character(polygon_layer[[name_col]])
      map <- leaflet::addPolygons(
        map,
        data = polygon_layer,
        group = source_id,
        popup = popups,
        weight = 1,
        fillOpacity = 0.2
      )
    } else {
      rlang::abort(sprintf(
        "Source id '%s' has unsupported geometry type(s): %s.",
        source_id,
        paste(geometry_types, collapse = ", ")
      ))
    }
  }

  leaflet::addLayersControl(
    map,
    overlayGroups = source_ids,
    options = leaflet::layersControlOptions(collapsed = FALSE)
  )
}

extract_polygon_collection <- function(layer) {
  geometries <- sf::st_geometry(layer)
  polygon_geometries <- lapply(geometries, function(geometry) {
    geometry_type <- as.character(sf::st_geometry_type(geometry))
    if (geometry_type != "GEOMETRYCOLLECTION") {
      return(geometry)
    }

    extracted <- suppressWarnings(
      sf::st_collection_extract(
        sf::st_sfc(geometry, crs = sf::st_crs(layer)),
        "POLYGON"
      )
    )
    if (length(extracted) == 0) {
      return(sf::st_polygon())
    }
    sf::st_combine(extracted)[[1]]
  })

  sf::st_geometry(layer) <- sf::st_sfc(polygon_geometries, crs = sf::st_crs(layer))
  layer
}

#' Render a reproducible R script for a CLI run
#'
#' @param from_ids Character vector of source ids used as crosswalk sources.
#' @param to_ids Character vector of source ids used as crosswalk targets.
#' @param output_dir Character scalar output directory.
#'
#' @return A character vector containing valid R code.
#' @keywords internal
#' @noRd
render_reproducer_script <- function(from_ids, to_ids, output_dir) {
  source_ids <- unique(c(from_ids, to_ids))
  layer_calls <- vapply(source_ids, source_retrieve_call, character(1))
  layer_lines <- sprintf("  %s = %s", source_ids, layer_calls)

  paste0(
    "library(ONgeoR)\n\n",
    "from_ids <- ", deparse_chr(from_ids), "\n",
    "to_ids <- ", deparse_chr(to_ids), "\n",
    "output_dir <- ", deparse_chr(output_dir), "\n\n",
    "layers <- list(\n",
    paste(layer_lines, collapse = ",\n"),
    "\n)\n\n",
    "cw <- ONgeoR:::cross_crosswalk(from_ids, to_ids)\n",
    "map <- map_crosswalk(layers, from_ids, to_ids)\n\n",
    "dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)\n",
    "write.csv(cw, file.path(output_dir, \"crosswalk.csv\"), row.names = FALSE)\n",
    "htmlwidgets::saveWidget(map, file.path(output_dir, \"map.html\"), selfcontained = TRUE)\n",
    "writeLines(\n",
    "  ONgeoR:::render_reproducer_script(from_ids, to_ids, output_dir),\n",
    "  file.path(output_dir, \"reproduce.R\")\n",
    ")\n"
  )
}

source_retrieve_call <- function(source_id) {
  switch(source_id,
    phu_boundaries = "retrieve_phu()",
    ontario_health_regions = "retrieve_health_region()",
    municipal_upper = "retrieve_municipal(\"upper\")",
    municipal_lower = "retrieve_municipal(\"lower\")",
    moh_service_locations = "retrieve_moh_service_locations()",
    {
      valid_ids <- list_sources()$source_id
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
