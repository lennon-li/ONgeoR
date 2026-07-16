library(shiny)
library(bslib)
library(leaflet)

source_choices <- function() {
  sources <- ONgeoR::list_sources()
  stats::setNames(sources$source_id, sources$name)
}

is_facility_source <- function(source_id) {
  identical(ONgeoR::get_source(source_id)$geography_type, "facility")
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

style_controls <- function(prefix) {
  tagList(
    selectInput(paste0(prefix, "_line_color"), "Boundary line color",
      choices = color_choices, selected = "#2a78d6"),
    selectInput(paste0(prefix, "_fill_color"), "Boundary fill color",
      choices = color_choices, selected = "#2a78d6"),
    selectInput(paste0(prefix, "_point_color"), "Point color",
      choices = color_choices, selected = "#e34948"),
    sliderInput(paste0(prefix, "_point_size"), "Point size",
      min = 2, max = 12, value = 5, step = 1),
    selectInput(paste0(prefix, "_point_shape"), "Point shape",
      choices = c("Circle" = "circle", "Square" = "square"), selected = "circle")
  )
}

read_style <- function(input, prefix) {
  list(
    line_color = input[[paste0(prefix, "_line_color")]],
    fill_color = input[[paste0(prefix, "_fill_color")]],
    point_color = input[[paste0(prefix, "_point_color")]],
    point_size = input[[paste0(prefix, "_point_size")]],
    point_shape = input[[paste0(prefix, "_point_shape")]]
  )
}

# Renders real (clickable) downloadButtons when `ready`, otherwise
# visually-matching but non-functional disabled buttons - so the sidebar
# download list is only ever clickable once the map/data it points to exist.
download_or_disabled <- function(ready, items) {
  tagList(lapply(items, function(item) {
    if (ready) {
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
      fillColor = style$fill_color, fillOpacity = 0.25
    )
  } else {
    rlang::abort(sprintf(
      "Layer '%s' has unsupported geometry type(s): %s.",
      group, paste(geometry_types, collapse = ", ")
    ))
  }
  map
}

render_styled_map <- function(layers, style) {
  map <- base_leaflet_layers(leaflet::leaflet())
  for (nm in names(layers)) {
    map <- add_styled_sf_layer(map, layers[[nm]], nm, style)
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

add_nearest_connectors <- function(map, layers, connectors) {
  if (is.null(connectors) || nrow(connectors) == 0) {
    return(map)
  }

  map <- leaflet::addPolylines(
    map,
    data = connectors, group = "Connections",
    color = "#52514e", weight = 1, opacity = 0.7, dashArray = "4,4"
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
  title = tags$img(src = "logo.png", height = "144px", style = "vertical-align: middle;"),
  theme = bslib::bs_theme(version = 5, primary = "#2a78d6", success = "#0ca30c"),
  header = tags$head(tags$link(rel = "stylesheet", href = "theme.css")),
  bslib::nav_panel(
    "Link",
    bslib::layout_sidebar(
      fillable = FALSE,
      sidebar = bslib::sidebar(
        width = 300,
        selectInput("base_layer", "Base layer", choices = source_choices(), selected = "phu_boundaries"),
        selectInput("overlay_source", "Overlay source", choices = source_choices(), selected = "moh_service_locations"),
        uiOutput("link_method_ui"),
        actionButton("build_btn", "Link", class = "btn-primary"),
        tags$hr(),
        style_controls("link"),
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
          tableOutput("cw_table")
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
        fileInput("points_csv", "Source points (CSV with lon/lat columns)", accept = ".csv"),
        selectInput("target_source", "Target source", choices = source_choices()),
        numericInput("k", "k", value = 1, min = 1),
        numericInput("max_dist_km", "max_dist_km", value = 50, min = 0),
        actionButton("nearest_btn", "Find nearest", class = "btn-primary"),
        tags$hr(),
        style_controls("nearest"),
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
          tableOutput("nearest_table")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  # --- Link tab -------------------------------------------------------

  observeEvent(input$base_layer, {
    choices <- source_choices()
    choices <- choices[choices != input$base_layer]
    selected <- if (input$overlay_source %in% choices) input$overlay_source else choices[1]
    updateSelectInput(session, "overlay_source", choices = choices, selected = selected)
  }, ignoreInit = TRUE)

  observeEvent(input$overlay_source, {
    choices <- source_choices()
    choices <- choices[choices != input$overlay_source]
    selected <- if (input$base_layer %in% choices) input$base_layer else choices[1]
    updateSelectInput(session, "base_layer", choices = choices, selected = selected)
  }, ignoreInit = TRUE)

  output$link_method_ui <- renderUI({
    req(input$base_layer, input$overlay_source)
    if (is_facility_source(input$base_layer) || is_facility_source(input$overlay_source)) {
      tagList(
        selectInput("method", "Match rule", choices = c("Point-in-boundary" = "within")),
        tags$p(class = "text-muted",
          "One layer is point facilities; each point is matched to the boundary it falls inside.")
      )
    } else {
      tagList(
        selectInput("method", "Match rule", choices = c(
          "Fully inside (within)" = "within",
          "Any overlap (intersects)" = "intersects"
        )),
        tags$p(class = "text-muted",
          "Both layers are boundaries. Use \"Any overlap\" if either was simplified/generalized - \"Fully inside\" can miss matches near simplified edges.")
      )
    }
  })

  cw_result <- reactiveValues(crosswalk = NULL, base_sf = NULL, overlay_sf = NULL)

  observeEvent(input$build_btn, {
    req(input$base_layer, input$overlay_source, input$method)
    withProgress(message = "Linking", value = 0.2, {
      tryCatch({
        base_sf <- ONgeoR:::retrieve_by_source_id(input$base_layer)
        incProgress(0.3)
        overlay_sf <- ONgeoR:::retrieve_by_source_id(input$overlay_source)
        incProgress(0.3)
        # build_crosswalk()/link() require the point/facility layer to be
        # `from` for a correct point-in-boundary join; a boundary `from`
        # against a point `to` silently returns all-NA matches. Reorder
        # regardless of which picker the user put the facility layer in.
        base_is_facility <- is_facility_source(input$base_layer)
        overlay_is_facility <- is_facility_source(input$overlay_source)
        if (overlay_is_facility && !base_is_facility) {
          from_sf <- overlay_sf
          to_sf <- base_sf
        } else {
          from_sf <- base_sf
          to_sf <- overlay_sf
        }
        cw_result$crosswalk <- ONgeoR::build_crosswalk(from_sf, to_sf, method = input$method)
        cw_result$base_sf <- base_sf
        cw_result$overlay_sf <- overlay_sf
        incProgress(0.2)
      }, error = function(e) {
        showNotification(conditionMessage(e), type = "error", duration = NULL)
      })
    })
  })

  link_map <- reactive({
    req(cw_result$base_sf, cw_result$overlay_sf)
    style <- read_style(input, "link")
    render_styled_map(
      list("Base layer" = cw_result$base_sf, "Overlay source" = cw_result$overlay_sf),
      style
    )
  })

  output$cw_map <- renderLeaflet({
    link_map()
  })
  output$cw_table <- renderTable({
    req(cw_result$crosswalk)
    utils::head(cw_result$crosswalk, 100)
  })

  output$dl_cw_csv <- downloadHandler(
    filename = function() "crosswalk.csv",
    content = function(file) {
      req(cw_result$crosswalk)
      utils::write.csv(cw_result$crosswalk, file, row.names = FALSE)
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
    ready <- !is.null(cw_result$crosswalk)
    download_or_disabled(ready, list(
      list(id = "dl_cw_map", label = "map.html"),
      list(id = "dl_cw_csv", label = "crosswalk.csv"),
      list(id = "dl_cw_script", label = "reproduce.R")
    ))
  })

  # --- Find Nearest tab ------------------------------------------------

  nearest_result <- reactiveValues(table = NULL, source_sf = NULL, target_sf = NULL,
    matched_target = NULL, connectors = NULL)

  observeEvent(input$nearest_btn, {
    req(input$points_csv, input$target_source)
    withProgress(message = "Finding nearest", value = 0.2, {
      tryCatch({
        points <- utils::read.csv(input$points_csv$datapath)
        if (!all(c("lon", "lat") %in% names(points))) {
          rlang::abort("Uploaded CSV must have `lon` and `lat` columns.")
        }
        source_sf <- sf::st_as_sf(points, coords = c("lon", "lat"), crs = 4326)
        incProgress(0.2)
        target_sf <- ONgeoR:::retrieve_by_source_id(input$target_source)
        incProgress(0.3)
        built <- nearest_layers(source_sf, target_sf, k = input$k, max_dist_km = input$max_dist_km)
        nearest_result$table <- built$table
        nearest_result$source_sf <- built$source
        nearest_result$matched_target <- built$matched_target
        nearest_result$connectors <- built$connectors
        incProgress(0.3)
      }, error = function(e) {
        showNotification(conditionMessage(e), type = "error", duration = NULL)
      })
    })
  })

  nearest_map <- reactive({
    req(nearest_result$source_sf)
    style <- read_style(input, "nearest")
    layers <- list("Source" = nearest_result$source_sf)
    if (!is.null(nearest_result$matched_target) && nrow(nearest_result$matched_target) > 0) {
      layers[["Matched targets"]] <- nearest_result$matched_target
    }
    map <- render_styled_map(layers, style)
    add_nearest_connectors(map, layers, nearest_result$connectors)
  })

  output$nearest_map <- renderLeaflet({
    nearest_map()
  })
  output$nearest_table <- renderTable({
    req(nearest_result$table)
    utils::head(nearest_result$table, 100)
  })

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
    download_or_disabled(ready, list(
      list(id = "dl_nearest_map", label = "map.html"),
      list(id = "dl_nearest_csv", label = "nearest.csv")
    ))
  })
}

shiny::shinyApp(ui, server)
