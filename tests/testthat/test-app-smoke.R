testthat::skip_if_not_installed("shinytest2")
testthat::skip_on_cran()

chrome <- tryCatch(
  suppressWarnings(chromote::find_chrome()),
  error = function(cnd) NULL
)
if (is.null(chrome) || !nzchar(chrome)) {
  testthat::skip("Chrome is not available to chromote.")
}

# AppDriver launches the app in a child R process, which resolves ONgeoR from
# the installed library, not from devtools::load_all() in this session. Under
# R CMD check (and CI) the package is installed, so the smoke runs there.
if (exists(".__DEVTOOLS__", envir = asNamespace("ONgeoR"))) {
  testthat::skip(
    "browser smoke needs an installed ONgeoR (runs under R CMD check/CI)"
  )
}

test_that("Shiny app boots and exposes its offline workflow controls", {
  app <- shinytest2::AppDriver$new(
    app_dir = dirname(shiny_app_file()),
    name = "app-smoke",
    variant = NULL,
    load_timeout = 30 * 1000
  )
  withr::defer(app$stop())

  navbar <- app$get_html("nav.navbar")
  expect_match(navbar, "Link", fixed = TRUE)
  expect_match(navbar, "Find Nearest", fixed = TRUE)

  expect_match(app$get_html("#base_layer"), "base_layer", fixed = TRUE)
  expect_match(
    app$get_html("#overlay_source"),
    "overlay_source",
    fixed = TRUE
  )
  expect_true(app$get_js(
    "document.querySelector('#build_btn_ui button').disabled"
  ))

  app$click(selector = "a[data-value='Find Nearest']")

  expect_true(app$get_js(
    "document.querySelector(\"a[data-value='Find Nearest']\").classList.contains('active')"
  ))
  expect_match(app$get_html("#points_csv"), "points_csv", fixed = TRUE)
})

# This test drives a real preview so the Leaflet widget exists to switch
# basemaps on, which means it needs a source pair that actually renders.
#
# It uses hive + airport_official rather than the synthetic raster. The
# raster path was broken when this test was written (SpatRaster pointers did
# not survive the future worker) and is now fixed, but this pairing is kept
# because it is the cheapest one that reliably reaches a rendered map. Raster
# rendering has its own regression test in test-shiny-server.R.
#
# hive is bundled, but airport_official is retrieved from Ontario GeoHub, so
# this needs network. The deterministic R CMD check must not depend on GeoHub
# availability (ROADMAP P1 acceptance gate), hence the opt-in gate below.
if (!identical(tolower(Sys.getenv("ONGEOR_BASEMAP_SMOKE", "")), "true")) {
  testthat::skip(paste(
    "basemap browser smoke is opt-in: it retrieves airport_official from",
    "Ontario GeoHub, and the deterministic check must not depend on GeoHub",
    "availability. Set ONGEOR_BASEMAP_SMOKE=true to run it."
  ))
}

test_that("native map control switches every core basemap including None", {
  app <- shinytest2::AppDriver$new(
    app_dir = dirname(shiny_app_file()),
    name = "app-basemap-switching",
    variant = NULL,
    load_timeout = 90 * 1000
  )
  withr::defer(app$stop())

  app$set_inputs(
    base_layer = "hive",
    overlay_source = "airport_official"
  )
  app$click(selector = "#preview_btn")

  # A successful preview always opens this modal. Synchronize on it before
  # waiting for the Leaflet widget, then remove its focus trap.
  app$wait_for_js(
    "document.querySelector('.modal.show .info-modal') !== null",
    timeout = 180 * 1000
  )
  expect_false(app$get_js(
    "document.querySelector('#cw_map').classList.contains('shiny-output-error')"
  ))

  # Dismiss the modal so its backdrop stops intercepting clicks on the map.
  # Bootstrap fades the dialog in, and a click landing mid-transition is
  # swallowed, so wait until the footer button is actually hittable, click it
  # through the DOM (app$click() would also block waiting for server idle,
  # which a client-only dismiss never triggers), and retry while the backdrop
  # is still up. Removal is a second fade, so allow well over one frame.
  app$wait_for_js(
    "document.querySelector('.modal.show .modal-footer button') !== null",
    timeout = 30 * 1000
  )
  for (attempt in 1:10) {
    still_open <- app$get_js("document.querySelector('.modal.show') !== null")
    if (!isTRUE(still_open)) {
      break
    }
    app$run_js(
      "document.querySelector('.modal.show .modal-footer button').click();"
    )
    Sys.sleep(1)
  }
  app$wait_for_js(
    "document.querySelector('.modal.show') === null",
    timeout = 60 * 1000
  )

  app$wait_for_js(
    paste0(
      "document.querySelector(",
      "'#cw_map .leaflet-control-layers-base') !== null"
    ),
    timeout = 60 * 1000
  )

  label_selector <- "#cw_map .leaflet-control-layers-base label"
  tile_selector <- "#cw_map .leaflet-tile-pane img.leaflet-tile"

  select_basemap <- function(group, has_tiles) {
    click_script <- sprintf(
      paste0(
        "(function() {",
        "const labels = Array.from(document.querySelectorAll('%s'));",
        "const label = labels.find(function(item) {",
        "return item.textContent.trim() === '%s';",
        "});",
        "if (!label) return false;",
        "label.querySelector('input').click();",
        "return true;",
        "})()"
      ),
      label_selector,
      group
    )
    expect_true(app$get_js(click_script))

    selected_script <- sprintf(
      paste0(
        "(function() {",
        "const labels = Array.from(document.querySelectorAll('%s'));",
        "const selected = labels.find(function(item) {",
        "return item.querySelector('input').checked;",
        "});",
        "return selected ? selected.textContent.trim() : null;",
        "})()"
      ),
      label_selector
    )
    app$wait_for_js(
      sprintf("%s === '%s'", selected_script, group),
      timeout = 20 * 1000
    )
    expect_identical(app$get_js(selected_script), group)

    tile_count_script <- sprintf(
      "document.querySelectorAll('%s').length",
      tile_selector
    )
    if (has_tiles) {
      app$wait_for_js(
        sprintf("%s > 0", tile_count_script),
        timeout = 20 * 1000
      )
      expect_gt(app$get_js(tile_count_script), 0)
    } else {
      app$wait_for_js(
        sprintf("%s === 0", tile_count_script),
        timeout = 20 * 1000
      )
      expect_equal(app$get_js(tile_count_script), 0)
    }
  }

  select_basemap("Dark", has_tiles = TRUE)
  select_basemap("Light", has_tiles = TRUE)
  select_basemap("OpenStreetMap", has_tiles = TRUE)
  select_basemap("Satellite", has_tiles = TRUE)
  select_basemap("None", has_tiles = FALSE)
})
