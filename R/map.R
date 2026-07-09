#' Map one or more layers on an interactive leaflet map
#'
#' Draws each `sf` layer on a single leaflet map, dispatching on geometry type:
#' polygons are drawn as filled outlines, points as circle markers. Layers get
#' a toggle in a layers-control. Raster layers are planned but not yet
#' implemented.
#'
#' @param ... One or more `sf` objects (points or polygons). Arguments may be
#'   named; a name sets that layer's group label. A `SpatRaster` argument
#'   aborts (raster mapping is not yet implemented).
#' @param colors Optional character vector of colors, one per layer (recycled if
#'   shorter). If `NULL` (default), distinct colors are assigned from a built-in
#'   qualitative palette.
#'
#' @return A `leaflet` htmlwidget.
#'
#' @examples
#' if (interactive()) {
#'   map_layers(retrieve_phu(), retrieve_moh_service_locations(service_type = "Hospital"))
#' }
#'
#' @export
map_layers <- function(..., colors = NULL) {
  layers <- list(...)
  if (length(layers) == 0) {
    rlang::abort("map_layers() requires at least one sf layer.")
  }

  for (layer in layers) {
    if (inherits(layer, "SpatRaster")) {
      rlang::abort(
        "raster mapping not yet implemented; see the package raster linking model"
      )
    }
  }

  groups <- layer_group_labels(layers)

  palette <- c(
    "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
    "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf"
  )
  layer_colors <- if (is.null(colors)) {
    palette[((seq_along(layers) - 1) %% length(palette)) + 1]
  } else {
    rep(colors, length.out = length(layers))
  }

  map <- leaflet::addTiles(leaflet::leaflet())
  for (i in seq_along(layers)) {
    map <- add_sf_layer(map, layers[[i]], groups[i], layer_colors[i])
  }

  leaflet::addLayersControl(
    map,
    overlayGroups = groups,
    options = leaflet::layersControlOptions(collapsed = FALSE)
  )
}

#' Derive group labels for map layers
#'
#' Priority: the argument name, then the layer's `source_name` provenance
#' attribute, then a positional `"Layer N"`.
#'
#' @param layers A list of `sf` layers, optionally named.
#' @return Character vector of group labels, one per layer.
#' @keywords internal
#' @noRd
layer_group_labels <- function(layers) {
  arg_names <- names(layers)
  vapply(seq_along(layers), function(i) {
    if (!is.null(arg_names) && nzchar(arg_names[i])) {
      return(arg_names[i])
    }
    src <- provenance_attr(layers[[i]], "source_name")
    if (!is.null(src) && !is.na(src) && nzchar(as.character(src))) {
      return(as.character(src))
    }
    paste("Layer", i)
  }, character(1))
}

#' Add a single sf layer to a leaflet map by geometry type
#'
#' @param map A leaflet map.
#' @param layer An `sf` object of points or polygons.
#' @param group Character group label for the layers-control.
#' @param color Character color for the layer.
#' @return The updated leaflet map.
#' @keywords internal
#' @noRd
add_sf_layer <- function(map, layer, group, color) {
  name_col <- guess_name_col(layer)
  geometry_types <- unique(as.character(sf::st_geometry_type(layer)))
  polygon_types <- c("POLYGON", "MULTIPOLYGON", "GEOMETRYCOLLECTION")

  if (all(geometry_types %in% c("POINT", "MULTIPOINT"))) {
    popups <- as.character(layer[[name_col]])
    leaflet::addCircleMarkers(
      map,
      data = layer,
      group = group,
      popup = popups,
      radius = 4,
      stroke = FALSE,
      fillColor = color,
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
    leaflet::addPolygons(
      map,
      data = polygon_layer,
      group = group,
      popup = popups,
      weight = 1,
      color = color,
      fillColor = color,
      fillOpacity = 0.2
    )
  } else {
    rlang::abort(sprintf(
      "Layer '%s' has unsupported geometry type(s): %s.",
      group,
      paste(geometry_types, collapse = ", ")
    ))
  }
}

#' Reduce GEOMETRYCOLLECTION geometries to their polygon parts
#'
#' @param layer An `sf` object that may contain `GEOMETRYCOLLECTION` geometries.
#' @return The `sf` object with each `GEOMETRYCOLLECTION` replaced by its
#'   combined polygon parts (empty polygon if it has none).
#' @keywords internal
#' @noRd
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
