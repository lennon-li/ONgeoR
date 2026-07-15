library(shiny)
library(bslib)
library(leaflet)

source_choices <- function() {
  sources <- ONgeoR::list_sources()
  stats::setNames(sources$source_id, sources$name)
}

ui <- bslib::page_navbar(
  title = "ONgeoR",
  theme = bslib::bs_theme(version = 5, primary = "#2a78d6", success = "#0ca30c"),
  bslib::nav_panel(
    "Build Crosswalk",
    bslib::layout_sidebar(
      fillable = FALSE,
      sidebar = bslib::sidebar(
        selectInput("from_source", "From source", choices = source_choices()),
        selectInput("to_source", "To source", choices = source_choices()),
        selectInput("method", "Method", choices = c("within", "intersects")),
        actionButton("build_btn", "Build crosswalk", class = "btn-primary")
      ),
      leafletOutput("cw_map", height = 320),
      tableOutput("cw_table"),
      downloadButton("dl_cw_csv", "crosswalk.csv"),
      downloadButton("dl_cw_map", "map.html"),
      downloadButton("dl_cw_script", "reproduce.R")
    )
  ),
  bslib::nav_panel(
    "Find Nearest",
    bslib::layout_sidebar(
      fillable = FALSE,
      sidebar = bslib::sidebar(
        fileInput("points_csv", "Source points (CSV with lon/lat columns)", accept = ".csv"),
        selectInput("target_source", "Target source", choices = source_choices()),
        numericInput("k", "k", value = 1, min = 1),
        numericInput("max_dist_km", "max_dist_km", value = 50, min = 0),
        actionButton("nearest_btn", "Find nearest", class = "btn-primary")
      ),
      leafletOutput("nearest_map", height = 320),
      tableOutput("nearest_table"),
      downloadButton("dl_nearest_csv", "nearest.csv"),
      downloadButton("dl_nearest_map", "map.html")
    )
  )
)

server <- function(input, output, session) {
  cw_result <- reactiveValues(crosswalk = NULL, map = NULL)

  observeEvent(input$build_btn, {
    req(input$from_source, input$to_source)
    withProgress(message = "Building crosswalk", value = 0.2, {
      tryCatch({
        from_layer <- ONgeoR:::retrieve_by_source_id(input$from_source)
        incProgress(0.3)
        to_layer <- ONgeoR:::retrieve_by_source_id(input$to_source)
        incProgress(0.3)
        cw_result$crosswalk <- ONgeoR::build_crosswalk(from_layer, to_layer, method = input$method)
        cw_result$map <- ONgeoR::map_layers(from_layer, to_layer)
        incProgress(0.2)
      }, error = function(e) {
        showNotification(conditionMessage(e), type = "error", duration = NULL)
      })
    })
  })

  output$cw_map <- renderLeaflet({
    req(cw_result$map)
    cw_result$map
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
      req(cw_result$map)
      htmlwidgets::saveWidget(cw_result$map, file, selfcontained = TRUE)
    }
  )
  output$dl_cw_script <- downloadHandler(
    filename = function() "reproduce.R",
    content = function(file) {
      req(input$from_source, input$to_source)
      writeLines(
        ONgeoR:::render_reproducer_script(input$from_source, input$to_source, "."),
        file
      )
    }
  )

  nearest_result <- reactiveValues(table = NULL, map = NULL)

  observeEvent(input$nearest_btn, {
    req(input$points_csv, input$target_source)
    withProgress(message = "Finding nearest", value = 0.2, {
      tryCatch({
        points <- utils::read.csv(input$points_csv$datapath)
        if (!all(c("lon", "lat") %in% names(points))) {
          rlang::abort("Uploaded CSV must have `lon` and `lat` columns.")
        }
        incProgress(0.2)
        target_layer <- ONgeoR:::retrieve_by_source_id(input$target_source)
        incProgress(0.3)
        nearest_result$table <- ONgeoR::nearest(
          points, target_layer, k = input$k, max_dist_km = input$max_dist_km
        )
        nearest_result$map <- ONgeoR::map_nearest(
          points, target_layer, k = input$k, max_dist_km = input$max_dist_km
        )
        incProgress(0.3)
      }, error = function(e) {
        showNotification(conditionMessage(e), type = "error", duration = NULL)
      })
    })
  })

  output$nearest_map <- renderLeaflet({
    req(nearest_result$map)
    nearest_result$map
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
      req(nearest_result$map)
      htmlwidgets::saveWidget(nearest_result$map, file, selfcontained = TRUE)
    }
  )
}

shiny::shinyApp(ui, server)
