library(shiny)
library(bslib)
library(leaflet)
library(promises)
library(future)
library(DT)

# ExtendedTask (used for all async flows below) needs shiny >= 1.8.0.
if (utils::packageVersion("shiny") < "1.8.0") {
  stop(
    "The ONgeoR Shiny app requires shiny >= 1.8.0 (for ExtendedTask); ",
    "installed: ", utils::packageVersion("shiny")
  )
}

# plan() returns the previous plan; restore it when the app stops so a
# multisession plan does not leak into the caller's R session.
.previous_future_plan <- future::plan(future::multisession)
shiny::onStop(function() future::plan(.previous_future_plan))

`%||%` <- function(a, b) if (is.null(a)) b else a

source_choices <- function() {
  sources <- ONgeoR::list_sources()
  stats::setNames(sources$source_id, source_choice_labels(sources))
}

# Maps a source's registry geography_type to the display-label type suffix.
source_type_suffix <- function(geography_type) {
  switch(geography_type,
    boundary = "Polygon",
    facility = "Point",
    raster   = "Raster",
    geography_type)
}

# Appends "(Type)" to each source's display name, e.g.
# "MOH Service Location (Point)". Used by both the flat and grouped choice
# builders so labels stay consistent everywhere a source picker appears.
source_choice_labels <- function(sources) {
  sprintf("%s (%s)", sources$name, vapply(sources$geography_type, source_type_suffix, character(1)))
}

# Grouped-choices form for use with selectInput's optgroup support:
# list("Polygons" = c(label = id, ...), "Points" = c(...), "Rasters" = c(...)).
# Any geography_type outside boundary/facility/raster is bucketed into an
# "Other" group, which is only added if such sources exist.
source_choices_grouped <- function() {
  sources <- ONgeoR::list_sources()
  labels <- source_choice_labels(sources)
  values <- stats::setNames(sources$source_id, labels)

  group_of <- vapply(sources$geography_type, function(gt) {
    switch(gt,
      boundary = "Polygons",
      facility = "Points",
      raster   = "Rasters",
      "Other")
  }, character(1))

  group_order <- c("Polygons", "Points", "Rasters", "Other")
  groups <- lapply(group_order, function(g) values[group_of == g])
  names(groups) <- group_order
  groups[lengths(groups) > 0]
}

# Removes `exclude_id` from whichever group of a grouped-choices list
# contains it, then drops any group left empty - used by the mutual-exclusion
# observers so the two source pickers can never hold the same value while
# still presenting grouped (optgroup) choices.
remove_choice_grouped <- function(groups, exclude_id) {
  groups <- lapply(groups, function(g) g[g != exclude_id])
  groups[lengths(groups) > 0]
}

# First value in a grouped-choices list, in group order - used to pick a
# fallback selection when the previously selected id has been excluded.
first_choice_grouped <- function(groups) {
  for (g in groups) {
    if (length(g) > 0) return(g[[1]])
  }
  NULL
}

is_facility_source <- function(source_id) {
  identical(ONgeoR::get_source(source_id)$geography_type, "facility")
}

# Maps a source's registry geography_type to a small geometry kind token used
# to drive the per-layer style controls and the relationship line.
geom_kind <- function(source_id) {
  switch(ONgeoR::get_source(source_id)$geography_type,
    boundary = "polygon",
    facility = "point",
    raster   = "raster",
    "polygon")
}

# Same kind token, derived from an already-retrieved layer object, so the style
# read for the map always matches the geometry that will actually be drawn.
layer_geom <- function(layer) {
  if (inherits(layer, "SpatRaster")) {
    return("raster")
  }
  geometry_types <- unique(as.character(sf::st_geometry_type(layer)))
  if (all(geometry_types %in% c("POINT", "MULTIPOINT"))) "point" else "polygon"
}

# Colored badge descriptor for a source's registry geography_type.
source_geom_label <- function(source_id) {
  gt <- ONgeoR::get_source(source_id)$geography_type
  switch(gt,
    boundary = list(text = "Polygon", class = "geo-polygon"),
    facility = list(text = "Point",   class = "geo-point"),
    raster   = list(text = "Raster",  class = "geo-raster"),
    list(text = gt, class = "geo-other"))
}

geo_badge <- function(source_id) {
  lbl <- source_geom_label(source_id)
  tags$span(class = paste("geo-badge", lbl$class), lbl$text)
}

# Full explanatory text shown in the pairing-info modal after every
# successful preview (see the preview_btn observeEvent in the server).
# `kinds` is the unsorted c(base_kind, overlay_kind) pair.
pairing_explanation_text <- function(kinds) {
  if ("raster" %in% kinds) {
    paste("Raster linking samples cell values - no match rule to choose.",
      "The output is a linked values table, not a crosswalk.")
  } else if (all(kinds == "point")) {
    paste("Both layers are points - containment linking does not apply.",
      "Use the Find Nearest tab for point-to-point matching.")
  } else if ("point" %in% kinds && "polygon" %in% kinds) {
    "One layer is point facilities; each point is matched to the boundary it falls inside."
  } else {
    paste("Both layers are boundaries. Use \"Any overlap\" if either was",
      "simplified/generalized - \"Fully inside\" can miss matches near",
      "simplified edges. \"Treat overlay as points\" reduces each overlay",
      "polygon to an interior point for a fast one-to-one assignment;",
      "\"Assign by largest overlap\" gives each overlay polygon to the",
      "boundary it shares the most area with (the coverage column reports",
      "that share).")
  }
}

# Builds the styled pairing-info modal shown after every successful preview.
# Uses a custom header row (logo + info-sign icon + relationship title)
# instead of modalDialog's plain `title`, so title = NULL and the header is
# rendered as part of the body content, wrapped in class "info-modal" for the
# CSS in theme.css to target. The information source sign is written as the
# HTML entity &#8505; via HTML() rather than a literal unicode character, to
# keep this file ASCII-only.
pairing_info_modal <- function(kinds) {
  modalDialog(
    title = NULL,
    tags$div(class = "info-modal",
      tags$div(class = "info-modal-header",
        tags$img(src = "logo.png", class = "info-modal-logo"),
        tags$span(class = "info-modal-icon", HTML("&#8505;")),
        tags$h4(relationship_text(kinds[1], kinds[2]))
      ),
      tags$p(pairing_explanation_text(kinds))
    ),
    footer = modalButton("OK"),
    easyClose = FALSE
  )
}

# One-line plain-language description of how two geometry kinds relate.
relationship_text <- function(a, b) {
  kinds <- c(a, b)
  if (all(kinds == "polygon")) {
    "Polygon overlap"
  } else if ("raster" %in% kinds && "polygon" %in% kinds) {
    "Raster-to-boundary"
  } else if ("raster" %in% kinds && "point" %in% kinds) {
    "Point-to-raster sampling"
  } else if (all(kinds == "raster")) {
    "Raster-to-raster"
  } else if ("point" %in% kinds && "polygon" %in% kinds) {
    "Point-in-boundary containment"
  } else {
    "Point-to-point"
  }
}

# Owner-approved combination matrix. Rendered verbatim in the in-app "?" help
# modal and mirrored in the crosswalks vignette + build_crosswalk()/link()
# roxygen so all three places tell the same story. ASCII only.
link_matrix_table <- function() {
  row <- function(types, does, output) {
    tags$tr(tags$td(types), tags$td(does), tags$td(output))
  }
  tagList(
    tags$table(class = "link-matrix",
      tags$thead(tags$tr(
        tags$th("Layer types"), tags$th("What linking does"), tags$th("Output")
      )),
      tags$tbody(
        row("Polygon base x Point overlay",
          "Point-in-boundary containment (within); points are always the from side internally.",
          "Crosswalk"),
        row("Polygon x Polygon",
          paste("Your choice of four rules: within / intersects /",
            "point_on_surface (interior representative point, not centroid) /",
            "largest_overlap (majority shared area; coverage 0-1 reports the",
            "winner's share)."),
          "Crosswalk"),
        row("Point x Raster (either slot order)",
          paste("Sampling - each point gets the value of the cell containing",
            "it (cell treated as its bounding-box polygon)."),
          "Linked values table"),
        row("Raster x Polygon (either slot order)",
          paste("Cell sampling into boundaries - raster reduced to",
            "cell-centroid points, each assigned to its containing boundary",
            "and carrying its value."),
          "Linked values table"),
        row("Point x Point",
          paste("Nearest matching (Find Nearest tab; k, max distance) - not a",
            "containment link."),
          "Nearest table"),
        row("Raster x Raster",
          "Not supported; align/resample with terra first.",
          "-")
      )
    ),
    tags$p(class = "text-muted",
      paste("Linking never creates or emits geometry - overlap areas are",
        "internal arithmetic only. The coverage column is populated only by",
        "largest_overlap, where it reports the winning boundary's share (0-1)",
        "of the source polygon's area."))
  )
}

color_choices <- c(
  "Blue" = "#2a78d6", "Green" = "#1baf7a", "Orange" = "#eb6834",
  "Red" = "#e34948", "Purple" = "#4a3aa7", "Black" = "#1a1a1a",
  "Gray" = "#898781"
)

# basemap_groups defines the display order for the native Leaflet control.
# "None" intentionally has no associated tile layer.
basemap_groups <- c(
  "Light", "Dark", "OpenStreetMap", "Satellite",
  "Topographic", "Streets", "Voyager", "None"
)

# Emits the geometry-specific style controls for a single layer slot. `prefix`
# namespaces the input IDs (base/overlay/src/tgt); `geom` selects which set of
# controls to show; `accent` (a color from color_choices) is the default for
# that layer slot's primary color input(s), so a slot's map style starts out
# matching its slot-accent color (blue for base/src, green for overlay/tgt).
# Rendered dynamically so switching a source's geometry swaps its controls.
layer_style_controls <- function(prefix, geom, accent = "#2a78d6") {
  if (identical(geom, "raster")) {
    tagList(
      selectInput(paste0(prefix, "_raster_palette"), "Palette",
        choices = c("Viridis", "Magma", "Blues"), selected = "Viridis"),
      sliderInput(paste0(prefix, "_raster_opacity"), "Layer opacity",
        min = 0, max = 1, value = 0.8, step = 0.05, ticks = FALSE)
    )
  } else if (identical(geom, "point")) {
    tagList(
      selectInput(paste0(prefix, "_point_color"), "Point color",
        choices = color_choices, selected = accent),
      sliderInput(paste0(prefix, "_point_size"), "Point size",
        min = 2, max = 12, value = 5, step = 1, ticks = FALSE),
      selectInput(paste0(prefix, "_point_shape"), "Point shape",
        choices = c("Circle" = "circle", "Square" = "square"), selected = "circle")
    )
  } else {
    tagList(
      selectInput(paste0(prefix, "_line_color"), "Boundary line color",
        choices = color_choices, selected = accent),
      selectInput(paste0(prefix, "_fill_color"), "Boundary fill color",
        choices = color_choices, selected = accent),
      sliderInput(paste0(prefix, "_fill_opacity"), "Fill opacity",
        min = 0, max = 1, value = 0.25, step = 0.05, ticks = FALSE)
    )
  }
}

# Static connector-line controls for the Find Nearest tab.
connector_style_controls <- function() {
  tagList(
    selectInput("conn_color", "Line color",
      choices = c(color_choices, "Stone" = "#52514e"), selected = "#52514e"),
    sliderInput("conn_weight", "Line weight",
      min = 1, max = 5, value = 1, step = 1, ticks = FALSE),
    sliderInput("conn_opacity", "Line opacity",
      min = 0, max = 1, value = 0.7, step = 0.05, ticks = FALSE)
  )
}

# Reads back the style list for one layer slot, keyed on the layer's actual
# geometry. Every field falls back to a default so the map never fails when an
# input has not been rendered yet (e.g. a picker changed after a build).
# `accent` mirrors the default passed to layer_style_controls() for the same
# slot, so the fallback color agrees with what the (not-yet-rendered) control
# would have defaulted to.
read_layer_style <- function(input, prefix, geom, accent = "#2a78d6") {
  g <- function(suffix) input[[paste0(prefix, "_", suffix)]]
  if (identical(geom, "raster")) {
    list(
      raster_palette = g("raster_palette") %||% "Viridis",
      raster_opacity = g("raster_opacity") %||% 0.8
    )
  } else if (identical(geom, "point")) {
    list(
      point_color = g("point_color") %||% accent,
      point_size = g("point_size") %||% 5,
      point_shape = g("point_shape") %||% "circle"
    )
  } else {
    list(
      line_color = g("line_color") %||% accent,
      fill_color = g("fill_color") %||% accent,
      fill_opacity = g("fill_opacity") %||% 0.25
    )
  }
}

# Renders real (clickable) downloadButtons when an item's `ready` field is
# TRUE, otherwise visually-matching but non-functional disabled buttons - so
# each sidebar download is only ever clickable once the map/data it points to
# exists. Readiness is per-item (item$ready) so, e.g., map.html can be ready
# before crosswalk.csv is.
download_or_disabled <- function(items) {
  tagList(lapply(items, function(item) {
    if (isTRUE(item$ready)) {
      downloadButton(item$id, item$label, class = "btn-outline-secondary w-100 mb-1")
    } else {
      tags$button(
        item$label, type = "button", class = "btn btn-outline-secondary w-100 mb-1",
        disabled = "disabled"
      )
    }
  }))
}

# Adds every real basemap choice as its own named tile group. "Light" is
# added first, so it is the default visible base layer.
base_leaflet_layers <- function(map) {
  map <- leaflet::addProviderTiles(map, "CartoDB.Positron", group = "Light")
  map <- leaflet::addProviderTiles(map, "CartoDB.DarkMatter", group = "Dark")
  map <- leaflet::addProviderTiles(map, "OpenStreetMap.Mapnik", group = "OpenStreetMap")
  map <- leaflet::addProviderTiles(map, "Esri.WorldImagery", group = "Satellite")
  map <- leaflet::addProviderTiles(map, "Esri.WorldTopoMap", group = "Topographic")
  map <- leaflet::addProviderTiles(map, "Esri.WorldStreetMap", group = "Streets")
  map <- leaflet::addProviderTiles(map, "CartoDB.Voyager", group = "Voyager")
  map
}

add_styled_sf_layer <- function(map, layer, group, style) {
  if (inherits(layer, "SpatRaster")) {
    if (!requireNamespace("terra", quietly = TRUE)) {
      rlang::abort("Package 'terra' is required to render raster layers.")
    }
    map <- leaflet::addRasterImage(
      map, layer, group = group,
      opacity = style$raster_opacity,
      colors = leaflet::colorNumeric(
        style$raster_palette, terra::values(layer), na.color = "transparent"
      )
    )
    return(map)
  }

  name_col <- ONgeoR:::guess_name_col(layer)
  geometry_types <- unique(as.character(sf::st_geometry_type(layer)))
  polygon_types <- c("POLYGON", "MULTIPOLYGON", "GEOMETRYCOLLECTION")

  if (all(geometry_types %in% c("POINT", "MULTIPOINT"))) {
    popups <- as.character(layer[[name_col]])
    if (identical(style$point_shape, "square")) {
      buf_deg <- style$point_size * 0.0015
      coords <- sf::st_coordinates(layer)
      map <- leaflet::addRectangles(
        map,
        lng1 = coords[, 1] - buf_deg, lat1 = coords[, 2] - buf_deg,
        lng2 = coords[, 1] + buf_deg, lat2 = coords[, 2] + buf_deg,
        group = group, popup = popups,
        color = style$point_color, fillColor = style$point_color,
        fillOpacity = 0.8, weight = 1
      )
    } else {
      map <- leaflet::addCircleMarkers(
        map,
        data = layer, group = group, popup = popups,
        radius = style$point_size, stroke = FALSE,
        fillColor = style$point_color, fillOpacity = 0.8
      )
    }
  } else if (all(geometry_types %in% polygon_types)) {
    polygon_layer <- if ("GEOMETRYCOLLECTION" %in% geometry_types) {
      ONgeoR:::extract_polygon_collection(layer)
    } else {
      layer
    }
    polygon_layer <- polygon_layer[!sf::st_is_empty(polygon_layer), ]
    popups <- as.character(polygon_layer[[name_col]])
    map <- leaflet::addPolygons(
      map,
      data = polygon_layer, group = group, popup = popups,
      weight = 2, color = style$line_color,
      fillColor = style$fill_color, fillOpacity = style$fill_opacity
    )
  } else {
    rlang::abort(sprintf(
      "Layer '%s' has unsupported geometry type(s): %s.",
      group, paste(geometry_types, collapse = ", ")
    ))
  }
  map
}

# `styles` is a named list parallel to `layers`: styles[[nm]] is the per-layer
# style for layers[[nm]].
render_styled_map <- function(layers, styles) {
  map <- base_leaflet_layers(leaflet::leaflet())
  for (nm in names(layers)) {
    map <- add_styled_sf_layer(map, layers[[nm]], nm, styles[[nm]])
  }
  # Only "Light" (added first, above) starts visible; hide the other real
  # tile groups so the layers control's radio behavior starts from a single
  # clean default instead of stacking all tile layers.
  map <- leaflet::hideGroup(
    map,
    c(
      "Dark", "OpenStreetMap", "Satellite",
      "Topographic", "Streets", "Voyager"
    )
  )
  leaflet::addLayersControl(
    map,
    baseGroups = basemap_groups,
    overlayGroups = names(layers),
    options = leaflet::layersControlOptions(collapsed = FALSE)
  )
}

add_nearest_connectors <- function(map, layers, connectors, conn_style) {
  if (is.null(connectors) || nrow(connectors) == 0) {
    return(map)
  }

  map <- leaflet::addPolylines(
    map,
    data = connectors, group = "Connections",
    color = conn_style$color, weight = conn_style$weight,
    opacity = conn_style$opacity, dashArray = "4,4"
  )
  leaflet::addLayersControl(
    map,
    baseGroups = basemap_groups,
    overlayGroups = c(names(layers), "Connections"),
    options = leaflet::layersControlOptions(collapsed = FALSE)
  )
}

# Reproduces the keyed nearest-match + connector-line construction from the
# package's internal map_nearest() (R/map.R), so this app can style each
# layer independently instead of taking map_nearest()'s baked-in colors.
nearest_layers <- function(source, target, k, max_dist_km) {
  keyed_source <- source
  keyed_target <- target
  source_columns <- setdiff(names(source), attr(source, "sf_column"))
  target_columns <- setdiff(names(target), attr(target, "sf_column"))
  combined_columns <- make.unique(c(source_columns, target_columns))
  names(keyed_target)[match(target_columns, names(keyed_target))] <-
    combined_columns[length(source_columns) + seq_along(target_columns)]

  key_names <- make.unique(c(
    names(keyed_source), names(keyed_target),
    ".ongeor_source_row", ".ongeor_target_row"
  ))
  source_key <- key_names[length(key_names) - 1]
  target_key <- key_names[length(key_names)]
  keyed_source[[source_key]] <- seq_len(nrow(source))
  keyed_target[[target_key]] <- seq_len(nrow(target))

  matches <- ONgeoR::nearest(keyed_source, keyed_target, k = k, max_dist_km = max_dist_km)
  if (nrow(matches) == 0) {
    return(list(source = source, matched_target = target[0, , drop = FALSE], connectors = NULL, table = matches))
  }

  source_rows <- matches[[source_key]]
  target_rows <- matches[[target_key]]
  matched_target <- target[unique(target_rows), , drop = FALSE]
  connector_geometry <- lapply(seq_along(source_rows), function(i) {
    sf::st_nearest_points(
      source[source_rows[i], , drop = FALSE],
      target[target_rows[i], , drop = FALSE],
      pairwise = TRUE
    )[[1]]
  })
  connectors <- sf::st_sf(
    distance_km = matches$distance_km,
    geometry = sf::st_sfc(connector_geometry, crs = sf::st_crs(source))
  )

  list(source = source, matched_target = matched_target, connectors = connectors, table = matches)
}

ui <- bslib::page_navbar(
  title = tags$img(src = "logo.png", height = "120px", style = "vertical-align: middle;"),
  theme = bslib::bs_theme(version = 5, primary = "#2a78d6", success = "#0ca30c"),
  header = tags$head(tags$link(rel = "stylesheet", href = "theme.css")),
  bslib::nav_panel(
    "Link",
    bslib::layout_sidebar(
      fillable = FALSE,
      sidebar = bslib::sidebar(
        width = 300,
        tags$div(class = "slot-block slot-base",
          selectInput("base_layer", "Base layer", choices = source_choices_grouped(), selected = "phu_boundaries"),
          tags$div(class = "slot-meta",
            uiOutput("base_geom_badge"),
            checkboxInput("base_upload_own", "Use my own file", FALSE)
          ),
          conditionalPanel(
            "input.base_upload_own",
            fileInput("base_own_file", NULL, buttonLabel = "Browse...",
              placeholder = "GeoJSON, GeoPackage, zipped shapefile, or GeoTIFF"),
            selectInput("base_own_type", "Layer type",
              c("Polygon" = "polygon", "Point" = "point", "Raster" = "raster")),
            tags$p(class = "text-muted", "Upload support is coming soon - this does not affect linking yet.")
          )
        ),
        tags$div(class = "slot-block slot-overlay",
          selectInput("overlay_source", "Overlay source", choices = source_choices_grouped(), selected = "moh_service_locations"),
          tags$div(class = "slot-meta",
            uiOutput("overlay_geom_badge"),
            checkboxInput("overlay_upload_own", "Use my own file", FALSE)
          ),
          conditionalPanel(
            "input.overlay_upload_own",
            fileInput("overlay_own_file", NULL, buttonLabel = "Browse...",
              placeholder = "GeoJSON, GeoPackage, zipped shapefile, or GeoTIFF"),
            selectInput("overlay_own_type", "Layer type",
              c("Polygon" = "polygon", "Point" = "point", "Raster" = "raster")),
            tags$p(class = "text-muted", "Upload support is coming soon - this does not affect linking yet.")
          )
        ),
        uiOutput("link_relationship"),
        uiOutput("link_method_ui"),
        actionButton("preview_btn", "Preview on map", class = "btn-preview w-100 mb-1"),
        uiOutput("build_btn_ui"),
        tags$hr(),
        bslib::accordion(
          open = FALSE,
          bslib::accordion_panel(
            tags$span(class = "slot-title slot-title-base", "Base layer style"),
            uiOutput("base_style_ui"),
            value = "Base layer style"
          ),
          bslib::accordion_panel(
            tags$span(class = "slot-title slot-title-overlay", "Overlay layer style"),
            uiOutput("overlay_style_ui"),
            value = "Overlay layer style"
          )
        ),
        tags$hr(),
        tags$strong("Downloads"),
        uiOutput("link_downloads_ui")
      ),
      bslib::navset_tab(
        bslib::nav_panel(
          "Map",
          leafletOutput("cw_map", height = "calc(100vh - 150px)")
        ),
        bslib::nav_panel(
          "Data",
          DT::dataTableOutput("cw_table")
        )
      )
    )
  ),
  bslib::nav_panel(
    "Find Nearest",
    bslib::layout_sidebar(
      fillable = FALSE,
      sidebar = bslib::sidebar(
        width = 300,
        tags$div(class = "slot-block slot-base",
          fileInput("points_csv", "Source points (CSV with lon/lat columns)", accept = ".csv")
        ),
        tags$div(class = "slot-block slot-overlay",
          selectInput("target_source", "Target source", choices = source_choices_grouped()),
          tags$div(class = "slot-meta",
            uiOutput("target_geom_badge"),
            checkboxInput("target_upload_own", "Use my own file", FALSE)
          ),
          conditionalPanel(
            "input.target_upload_own",
            fileInput("target_own_file", NULL, buttonLabel = "Browse...",
              placeholder = "GeoJSON, GeoPackage, zipped shapefile, or GeoTIFF"),
            selectInput("target_own_type", "Layer type",
              c("Polygon" = "polygon", "Point" = "point", "Raster" = "raster")),
            tags$p(class = "text-muted", "Upload support is coming soon - this does not affect linking yet.")
          )
        ),
        numericInput("k", "k", value = 1, min = 1),
        numericInput("max_dist_km", "max_dist_km", value = NA, min = 0),
        helpText("Leave blank for no distance cap."),
        actionButton("nearest_preview_btn", "Preview on map", class = "btn-preview w-100 mb-1"),
        actionButton("nearest_btn", "Find nearest", class = "btn-primary"),
        tags$hr(),
        bslib::accordion(
          open = FALSE,
          bslib::accordion_panel(
            tags$span(class = "slot-title slot-title-base", "Source points style"),
            uiOutput("src_style_ui"),
            value = "Source points style"
          ),
          bslib::accordion_panel(
            tags$span(class = "slot-title slot-title-overlay", "Matched targets style"),
            uiOutput("tgt_style_ui"),
            value = "Matched targets style"
          ),
          bslib::accordion_panel("Connector lines style", connector_style_controls())
        ),
        tags$hr(),
        tags$strong("Downloads"),
        uiOutput("nearest_downloads_ui")
      ),
      bslib::navset_tab(
        bslib::nav_panel(
          "Map",
          leafletOutput("nearest_map", height = "calc(100vh - 150px)")
        ),
        bslib::nav_panel(
          "Data",
          DT::dataTableOutput("nearest_table")
        )
      )
    )
  )
)

server <- function(input, output, session) {

  # --- Async tasks (ExtendedTask; requires shiny >= 1.8.0) -----------

  preview_task <- shiny::ExtendedTask$new(function(base_id, overlay_id) {
    promises::future_promise({
      base_sf    <- ONgeoR::retrieve_source(base_id)
      overlay_sf <- ONgeoR::retrieve_source(overlay_id)
      list(base_sf = base_sf, overlay_sf = overlay_sf,
           base_id = base_id, overlay_id = overlay_id)
    })
  })

  build_task <- shiny::ExtendedTask$new(function(base_id, overlay_id, method) {
    promises::future_promise({
      base_sf    <- ONgeoR::retrieve_source(base_id)
      overlay_sf <- ONgeoR::retrieve_source(overlay_id)
      base_kind    <- layer_geom(base_sf)
      overlay_kind <- layer_geom(overlay_sf)
      if (base_kind == "raster" || overlay_kind == "raster") {
        # Rasters are not crosswalk-able; route to link(), which is
        # raster-aware. Order so the raster sits where link()'s reduction is
        # semantically right: a raster SOURCE reduces to cell-centroid points
        # (raster + polygon case, cells into boundaries), a raster TARGET
        # reduces to cell polygons (point + raster case, sampling).
        # Both-raster is aborted by link() itself and surfaces via the
        # tryCatch in the status observer.
        if ("polygon" %in% c(base_kind, overlay_kind)) {
          if (base_kind == "raster") {
            from_sf <- base_sf; to_sf <- overlay_sf
          } else {
            from_sf <- overlay_sf; to_sf <- base_sf
          }
        } else {
          if (base_kind == "raster") {
            from_sf <- overlay_sf; to_sf <- base_sf
          } else {
            from_sf <- base_sf; to_sf <- overlay_sf
          }
        }
        linked <- ONgeoR::link(from_sf, to_sf, predicate = "within")
        list(crosswalk = NULL, linked = linked,
             base_sf = base_sf, overlay_sf = overlay_sf)
      } else {
        # Universal direction rule: every crosswalk row assigns an overlay
        # unit to the base polygon it belongs to (overlay is always from,
        # base always to) - e.g. each airport polygon is assigned to its
        # health unit, never the reverse.
        from_sf   <- overlay_sf
        to_sf     <- base_sf
        crosswalk <- ONgeoR::build_crosswalk(from_sf, to_sf, method = method)
        list(crosswalk = crosswalk, linked = NULL,
             base_sf = base_sf, overlay_sf = overlay_sf)
      }
    })
  })

  nearest_preview_task <- shiny::ExtendedTask$new(function(csv_path, target_id) {
    promises::future_promise({
      points <- utils::read.csv(csv_path)
      if (!all(c("lon", "lat") %in% names(points))) {
        rlang::abort("Uploaded CSV must have `lon` and `lat` columns.")
      }
      source_sf <- sf::st_as_sf(points, coords = c("lon", "lat"), crs = 4326)
      target_sf <- ONgeoR::retrieve_source(target_id)
      list(source_sf = source_sf, target_sf = target_sf)
    })
  })

  nearest_task <- shiny::ExtendedTask$new(function(csv_path, target_id, k_val, max_dist_km_val) {
    promises::future_promise({
      points <- utils::read.csv(csv_path)
      if (!all(c("lon", "lat") %in% names(points))) {
        rlang::abort("Uploaded CSV must have `lon` and `lat` columns.")
      }
      source_sf <- sf::st_as_sf(points, coords = c("lon", "lat"), crs = 4326)
      target_sf <- ONgeoR::retrieve_source(target_id)
      nearest_layers(source_sf, target_sf, k = k_val, max_dist_km = max_dist_km_val)
    })
  })

  # --- Link tab -------------------------------------------------------

  observeEvent(input$base_layer, {
    groups <- remove_choice_grouped(source_choices_grouped(), input$base_layer)
    selected <- if (input$overlay_source %in% unlist(groups)) {
      input$overlay_source
    } else {
      first_choice_grouped(groups)
    }
    updateSelectInput(session, "overlay_source", choices = groups, selected = selected)
  }, ignoreInit = TRUE)

  observeEvent(input$overlay_source, {
    groups <- remove_choice_grouped(source_choices_grouped(), input$overlay_source)
    selected <- if (input$base_layer %in% unlist(groups)) {
      input$base_layer
    } else {
      first_choice_grouped(groups)
    }
    updateSelectInput(session, "base_layer", choices = groups, selected = selected)
  }, ignoreInit = TRUE)

  # Geometry-type feedback badges, reactive the moment a picker changes.
  output$base_geom_badge <- renderUI({
    req(input$base_layer)
    geo_badge(input$base_layer)
  })
  output$overlay_geom_badge <- renderUI({
    req(input$overlay_source)
    geo_badge(input$overlay_source)
  })
  output$link_relationship <- renderUI({
    req(input$base_layer, input$overlay_source)
    tags$p(class = "geo-relationship text-muted",
      relationship_text(geom_kind(input$base_layer), geom_kind(input$overlay_source)))
  })

  # Per-layer style controls, driven by each selected source's geometry.
  output$base_style_ui <- renderUI({
    req(input$base_layer)
    layer_style_controls("base", geom_kind(input$base_layer), accent = "#2a78d6")
  })
  output$overlay_style_ui <- renderUI({
    req(input$overlay_source)
    layer_style_controls("overlay", geom_kind(input$overlay_source), accent = "#1baf7a")
  })

  output$link_method_ui <- renderUI({
    req(input$base_layer, input$overlay_source)
    base_k <- geom_kind(input$base_layer)
    overlay_k <- geom_kind(input$overlay_source)
    help_link <- actionLink("method_help", "?", class = "method-help",
      title = "How linking works, by layer types")

    if (base_k == "raster" || overlay_k == "raster") {
      # Raster pairings route through link(), which has no match rule to pick.
      # See pairing-explanation modal for details.
      help_link
    } else if (base_k == "point" && overlay_k == "point") {
      # Point-to-point containment is undefined; redirect to Find Nearest.
      # There is no dropdown here, so a short pointer stays in the sidebar;
      # the full redirect sentence is in the pairing-explanation modal.
      tagList(
        tags$p(class = "text-muted",
          "Points can't be linked here - see Find Nearest."),
        help_link
      )
    } else if (is_facility_source(input$base_layer) || is_facility_source(input$overlay_source)) {
      tagList(
        selectInput("method", "Match rule", choices = c("Point-in-boundary" = "within")),
        help_link
      )
    } else {
      tagList(
        selectInput("method", "Match rule", choices = c(
          "Fully inside (within)" = "within",
          "Any overlap (intersects)" = "intersects",
          "Treat overlay as points (fast)" = "point_on_surface",
          "Assign by largest overlap (accurate)" = "largest_overlap"
        )),
        help_link
      )
    }
  })

  observeEvent(input$method_help, {
    showModal(modalDialog(
      title = "How linking works, by layer types",
      link_matrix_table(),
      easyClose = TRUE, size = "l", footer = modalButton("Close")
    ))
  })

  cw_result <- reactiveValues(crosswalk = NULL, linked = NULL,
    base_sf = NULL, overlay_sf = NULL, previewed = NULL)

  # Link is gated on having previewed the CURRENT pair: enabled only when a
  # preview succeeded for exactly today's base_layer/overlay_source values
  # (so changing either picker re-greys it) and the pair is not point-point
  # (which stays permanently disabled, with a redirect message, since
  # containment linking is undefined for it - see link_method_ui above for
  # the parallel explanatory text).
  output$build_btn_ui <- renderUI({
    req(input$base_layer, input$overlay_source)
    point_point <- is_facility_source(input$base_layer) && is_facility_source(input$overlay_source)
    previewed_current <- identical(cw_result$previewed, c(input$base_layer, input$overlay_source))
    enabled <- previewed_current && !point_point
    build_running <- identical(build_task$status(), "running")

    if (build_running) {
      tags$button("Running...", type = "button",
        class = "btn btn-primary w-100", disabled = "disabled")
    } else if (enabled) {
      actionButton("build_btn", "Link", class = "btn-primary w-100")
    } else if (point_point) {
      tagList(
        tags$button("Link", type = "button", class = "btn btn-primary w-100", disabled = "disabled"),
        tags$p(class = "text-muted",
          "Both layers are points - use the Find Nearest tab for point-to-point matching.")
      )
    } else {
      tags$button("Link", type = "button", class = "btn btn-primary w-100", disabled = "disabled")
    }
  })

  # Retrieves and maps the two selected layers without linking them, so users
  # can see what they picked before committing to a (possibly slow) link run.
  # Unlike build_btn, this has no point-point guard - previewing two point
  # layers is just mapping, with no containment semantics involved - and no
  # raster/method branching, since it never calls build_crosswalk()/link().
  observe({
    label <- if (identical(preview_task$status(), "running")) "Running..." else "Preview on map"
    updateActionButton(session, "preview_btn", label = label)
  })

  observeEvent(input$preview_btn, {
    req(input$base_layer, input$overlay_source)
    preview_task$invoke(input$base_layer, input$overlay_source)
  })

  observeEvent(preview_task$status(), {
    s <- preview_task$status()
    if (!s %in% c("success", "error")) return()
    result <- tryCatch(preview_task$result(), error = function(e) e)
    if (inherits(result, "error")) {
      showNotification(conditionMessage(result), type = "error", duration = NULL)
      return()
    }
    cw_result$base_sf <- result$base_sf
    cw_result$overlay_sf <- result$overlay_sf
    # A fresh preview invalidates any stale link results - the Data tab
    # goes empty and the crosswalk/linked-csv and reproduce.R downloads
    # disable until Link is run again.
    cw_result$crosswalk <- NULL
    cw_result$linked <- NULL
    # Records exactly what was previewed, so the Link button's renderUI
    # can require the current picker values to match before enabling -
    # changing either picker after a preview re-greys Link. Only set on
    # success; an error path below leaves this untouched.
    cw_result$previewed <- c(result$base_id, result$overlay_id)
    # Every successful preview shows the pairing-info modal (styled with
    # a logo + info-sign header); a failed preview does not, since this
    # runs only after the tryCatch body's happy path completes.
    kinds <- c(geom_kind(result$base_id), geom_kind(result$overlay_id))
    showModal(pairing_info_modal(kinds))
  }, ignoreInit = TRUE)

  observeEvent(input$build_btn, {
    req(input$base_layer, input$overlay_source)
    # Point-to-point containment is undefined; the Link button's renderUI
    # (build_btn_ui) keeps Link permanently disabled for this pair, so the
    # on-click redirect notice that used to live here is no longer reachable
    # and has been removed - see link_method_ui for the still-shown
    # point-point explanatory message.
    build_task$invoke(input$base_layer, input$overlay_source, input$method %||% "within")
  })

  observeEvent(build_task$status(), {
    s <- build_task$status()
    if (!s %in% c("success", "error")) return()
    result <- tryCatch(build_task$result(), error = function(e) e)
    if (inherits(result, "error")) {
      showNotification(conditionMessage(result), type = "error", duration = NULL)
      return()
    }
    cw_result$crosswalk   <- result$crosswalk
    cw_result$linked      <- result$linked
    cw_result$base_sf     <- result$base_sf
    cw_result$overlay_sf  <- result$overlay_sf
  }, ignoreInit = TRUE)

  link_map <- reactive({
    req(cw_result$base_sf, cw_result$overlay_sf)
    layers <- list("Base layer" = cw_result$base_sf, "Overlay source" = cw_result$overlay_sf)
    styles <- list(
      "Base layer" = read_layer_style(input, "base", layer_geom(cw_result$base_sf), accent = "#2a78d6"),
      "Overlay source" = read_layer_style(input, "overlay", layer_geom(cw_result$overlay_sf), accent = "#1baf7a")
    )
    render_styled_map(layers, styles)
  })

  output$cw_map <- renderLeaflet({
    link_map()
  })
  # Shows whichever mode the last run produced: a crosswalk (build_crosswalk)
  # or a linked values table (raster runs via link()); the coverage column of a
  # largest_overlap crosswalk shows here naturally.
  output$cw_table <- DT::renderDataTable({
    tbl <- cw_result$crosswalk %||% cw_result$linked
    req(tbl)
    tbl
  }, rownames = FALSE, options = list(scrollX = TRUE, pageLength = 25))

  output$dl_cw_csv <- downloadHandler(
    filename = function() if (!is.null(cw_result$linked)) "linked.csv" else "crosswalk.csv",
    content = function(file) {
      tbl <- cw_result$crosswalk %||% cw_result$linked
      req(tbl)
      utils::write.csv(tbl, file, row.names = FALSE)
    }
  )
  output$dl_cw_map <- downloadHandler(
    filename = function() "map.html",
    content = function(file) {
      req(cw_result$base_sf, cw_result$overlay_sf)
      htmlwidgets::saveWidget(link_map(), file, selfcontained = TRUE)
    }
  )
  output$dl_cw_script <- downloadHandler(
    filename = function() "reproduce.R",
    content = function(file) {
      req(input$base_layer, input$overlay_source)
      writeLines(
        ONgeoR:::render_reproducer_script(input$base_layer, input$overlay_source, "."),
        file
      )
    }
  )

  output$link_downloads_ui <- renderUI({
    linked_run <- !is.null(cw_result$linked)
    link_ready <- !is.null(cw_result$crosswalk) || linked_run
    csv_label <- if (linked_run) "linked.csv" else "crosswalk.csv"
    download_or_disabled(list(
      list(id = "dl_cw_map", label = "map.html", ready = !is.null(cw_result$base_sf)),
      list(id = "dl_cw_csv", label = csv_label, ready = link_ready),
      list(id = "dl_cw_script", label = "reproduce.R", ready = link_ready)
    ))
  })

  # --- Find Nearest tab ------------------------------------------------

  # Geometry-type feedback badge for the target source.
  output$target_geom_badge <- renderUI({
    req(input$target_source)
    geo_badge(input$target_source)
  })

  # Source points are always points (uploaded lon/lat CSV); the target style
  # follows the selected target source's geometry.
  output$src_style_ui <- renderUI({
    layer_style_controls("src", "point", accent = "#2a78d6")
  })
  output$tgt_style_ui <- renderUI({
    req(input$target_source)
    layer_style_controls("tgt", geom_kind(input$target_source), accent = "#1baf7a")
  })

  nearest_result <- reactiveValues(table = NULL, source_sf = NULL, target_sf = NULL,
    matched_target = NULL, connectors = NULL, preview_target = NULL)

  # Retrieves and maps the uploaded source points and the selected target
  # source without running the nearest match, so users can see both layers
  # before committing to a (possibly slow) match. There is no matched_target
  # or connectors yet - nearest_map() draws the target under its own
  # "Target source" group (styled with the target accent) whenever
  # preview_target is set and matched_target is NULL.
  observe({
    label <- if (identical(nearest_preview_task$status(), "running")) "Running..." else "Preview on map"
    updateActionButton(session, "nearest_preview_btn", label = label)
  })

  observeEvent(input$nearest_preview_btn, {
    req(input$points_csv, input$target_source)
    nearest_preview_task$invoke(input$points_csv$datapath, input$target_source)
  })

  observeEvent(nearest_preview_task$status(), {
    s <- nearest_preview_task$status()
    if (!s %in% c("success", "error")) return()
    result <- tryCatch(nearest_preview_task$result(), error = function(e) e)
    if (inherits(result, "error")) {
      showNotification(conditionMessage(result), type = "error", duration = NULL)
      return()
    }
    nearest_result$source_sf     <- result$source_sf
    nearest_result$preview_target <- result$target_sf
    nearest_result$table         <- NULL
    nearest_result$matched_target <- NULL
    nearest_result$connectors    <- NULL
  }, ignoreInit = TRUE)

  observe({
    label <- if (identical(nearest_task$status(), "running")) "Running..." else "Find nearest"
    updateActionButton(session, "nearest_btn", label = label)
  })

  observeEvent(input$nearest_btn, {
    req(input$points_csv, input$target_source)
    max_dist_km_val <- if (is.na(input$max_dist_km) || is.null(input$max_dist_km)) NULL else input$max_dist_km
    nearest_task$invoke(input$points_csv$datapath, input$target_source, input$k, max_dist_km_val)
  })

  observeEvent(nearest_task$status(), {
    s <- nearest_task$status()
    if (!s %in% c("success", "error")) return()
    result <- tryCatch(nearest_task$result(), error = function(e) e)
    if (inherits(result, "error")) {
      showNotification(conditionMessage(result), type = "error", duration = NULL)
      return()
    }
    nearest_result$table          <- result$table
    nearest_result$source_sf      <- result$source
    nearest_result$matched_target <- result$matched_target
    nearest_result$connectors     <- result$connectors
    # A completed match supersedes any preview target layer.
    nearest_result$preview_target <- NULL
  }, ignoreInit = TRUE)

  nearest_map <- reactive({
    req(nearest_result$source_sf)
    layers <- list("Source" = nearest_result$source_sf)
    styles <- list("Source" = read_layer_style(input, "src", layer_geom(nearest_result$source_sf), accent = "#2a78d6"))
    if (!is.null(nearest_result$matched_target) && nrow(nearest_result$matched_target) > 0) {
      layers[["Matched targets"]] <- nearest_result$matched_target
      styles[["Matched targets"]] <-
        read_layer_style(input, "tgt", layer_geom(nearest_result$matched_target), accent = "#1baf7a")
    } else if (!is.null(nearest_result$preview_target)) {
      layers[["Target source"]] <- nearest_result$preview_target
      styles[["Target source"]] <-
        read_layer_style(input, "tgt", layer_geom(nearest_result$preview_target), accent = "#1baf7a")
    }
    map <- render_styled_map(layers, styles)
    conn_style <- list(
      color = input$conn_color %||% "#52514e",
      weight = input$conn_weight %||% 1,
      opacity = input$conn_opacity %||% 0.7
    )
    add_nearest_connectors(map, layers, nearest_result$connectors, conn_style)
  })

  output$nearest_map <- renderLeaflet({
    nearest_map()
  })
  output$nearest_table <- DT::renderDataTable({
    req(nearest_result$table)
    nearest_result$table
  }, rownames = FALSE, options = list(scrollX = TRUE, pageLength = 25))

  output$dl_nearest_csv <- downloadHandler(
    filename = function() "nearest.csv",
    content = function(file) {
      req(nearest_result$table)
      utils::write.csv(nearest_result$table, file, row.names = FALSE)
    }
  )
  output$dl_nearest_map <- downloadHandler(
    filename = function() "map.html",
    content = function(file) {
      req(nearest_result$source_sf)
      htmlwidgets::saveWidget(nearest_map(), file, selfcontained = TRUE)
    }
  )

  output$nearest_downloads_ui <- renderUI({
    ready <- !is.null(nearest_result$table)
    download_or_disabled(list(
      list(id = "dl_nearest_map", label = "map.html", ready = ready),
      list(id = "dl_nearest_csv", label = "nearest.csv", ready = ready)
    ))
  })
}

shiny::shinyApp(ui, server)
