test_that("source selections update geometry and relationship displays", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  testthat::local_mocked_bindings(
    list_sources = shiny_fixture_registry,
    get_source = shiny_fixture_metadata,
    .package = "ONgeoR"
  )
  server <- load_shiny_server()

  shiny::testServer(server, {
    expect_match(rendered_html(output$link_task_status), "Idle")
    session$setInputs(
      base_layer = "base_polygon",
      overlay_source = "overlay_point"
    )

    expect_match(rendered_html(output$base_geom_badge), "Polygon")
    expect_match(rendered_html(output$overlay_geom_badge), "Point")
    expect_match(
      rendered_html(output$link_relationship),
      "Point-in-boundary containment"
    )
    expect_null(cw_result$crosswalk)
    expect_null(cw_result$previewed)
  })
})

test_that("changing a selection invalidates preview-based Link gating", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  layers <- shiny_fixture_layers()
  testthat::local_mocked_bindings(
    list_sources = shiny_fixture_registry,
    get_source = shiny_fixture_metadata,
    retrieve_source = function(source_id, refresh = FALSE, ...) {
      layers[[source_id]]
    },
    .package = "ONgeoR"
  )
  server <- load_shiny_server()
  use_sequential_futures()

  shiny::testServer(server, {
    session$setInputs(
      base_layer = "base_polygon",
      overlay_source = "overlay_point",
      preview_btn = 1
    )
    expect_identical(
      wait_for_extended_task(preview_task, session),
      "success"
    )
    expect_match(rendered_html(output$build_btn_ui), "id=\"build_btn\"")
    expect_false(grepl("disabled", rendered_html(output$build_btn_ui)))

    session$setInputs(overlay_source = "other_polygon")

    expect_match(rendered_html(output$build_btn_ui), "disabled")
    expect_null(cw_result$previewed)
  })
})

test_that("preview then Link produces a crosswalk and enables downloads", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  layers <- shiny_fixture_layers()
  testthat::local_mocked_bindings(
    list_sources = shiny_fixture_registry,
    get_source = shiny_fixture_metadata,
    retrieve_source = function(source_id, refresh = FALSE, ...) {
      layers[[source_id]]
    },
    build_crosswalk = function(from, to, method = "within", ...) {
      tibble::tibble(from_id = 1:2, to_id = c("P1", "P2"))
    },
    .package = "ONgeoR"
  )
  server <- load_shiny_server()
  use_sequential_futures()

  shiny::testServer(server, {
    session$setInputs(
      base_layer = "base_polygon",
      overlay_source = "overlay_point",
      method = "within",
      preview_btn = 1
    )
    expect_identical(
      wait_for_extended_task(preview_task, session),
      "success"
    )

    session$setInputs(build_btn = 1)
    expect_identical(wait_for_extended_task(build_task, session), "success")

    expect_s3_class(cw_result$crosswalk, "data.frame")
    expect_gt(nrow(cw_result$crosswalk), 0)
    downloads <- rendered_html(output$link_downloads_ui)
    expect_match(downloads, "id=\"dl_cw_csv\"")
    expect_match(downloads, "id=\"dl_cw_script\"")

    expected_file <- withr::local_tempfile(fileext = ".csv")
    utils::write.csv(cw_result$crosswalk, expected_file, row.names = FALSE)
    actual_file <- output$dl_cw_csv
    expect_equal(
      readBin(actual_file, what = "raw", n = file.info(actual_file)$size),
      readBin(expected_file, what = "raw", n = file.info(expected_file)$size)
    )
  })
})

test_that("Link discards a completion invalidated by changed inputs", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  layers <- shiny_fixture_layers()
  testthat::local_mocked_bindings(
    list_sources = shiny_fixture_registry,
    get_source = shiny_fixture_metadata,
    retrieve_source = function(source_id, refresh = FALSE, ...) {
      Sys.sleep(0.05)
      layers[[source_id]]
    },
    build_crosswalk = function(from, to, method = "within", ...) {
      tibble::tibble(from_id = 1L, to_id = "P1")
    },
    .package = "ONgeoR"
  )
  server <- load_shiny_server()
  use_sequential_futures()

  shiny::testServer(server, {
    session$setInputs(
      base_layer = "base_polygon",
      overlay_source = "overlay_point",
      method = "within",
      build_btn = 1
    )
    expect_match(rendered_html(output$link_task_status), "Running")

    session$setInputs(method = "intersects")
    expect_match(rendered_html(output$link_task_status), "Cancelled")

    expect_identical(wait_for_extended_task(build_task, session), "success")
    expect_null(cw_result$crosswalk)
    expect_null(cw_result$linked)
    expect_match(rendered_html(output$link_downloads_ui), "disabled")
    expect_match(rendered_html(output$link_task_status), "Cancelled")
  })
})

test_that("Link surfaces retrieval failures without retaining results", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  testthat::local_mocked_bindings(
    list_sources = shiny_fixture_registry,
    get_source = shiny_fixture_metadata,
    retrieve_source = function(source_id, refresh = FALSE, ...) {
      rlang::abort("Fixture retrieval failed.")
    },
    .package = "ONgeoR"
  )
  server <- load_shiny_server()
  use_sequential_futures()

  shiny::testServer(server, {
    session$setInputs(
      base_layer = "base_polygon",
      overlay_source = "overlay_point",
      method = "within",
      build_btn = 1
    )
    expect_warning(
      wait_for_extended_task(build_task, session),
      "An error occurred when invoking the ExtendedTask",
      fixed = TRUE
    )
    expect_null(cw_result$crosswalk)
    expect_match(rendered_html(output$link_task_status), "Failed")
    expect_match(
      rendered_html(output$link_task_status),
      "Fixture retrieval failed",
      fixed = TRUE
    )
  })
})

test_that("repeat Link runs use cached retrieval without re-fetching", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  layers <- shiny_fixture_layers()
  retrieval_count <- 0L
  testthat::local_mocked_bindings(
    list_sources = shiny_fixture_registry,
    get_source = shiny_fixture_metadata,
    retrieve_source = function(source_id, refresh = FALSE, ...) {
      Sys.sleep(0.1)
      retrieval_count <<- retrieval_count + 1L
      layers[[source_id]]
    },
    build_crosswalk = function(from, to, method = "within", ...) {
      tibble::tibble(from_id = 1L, to_id = "P1")
    },
    .package = "ONgeoR"
  )
  server <- load_shiny_server()
  use_sequential_futures()

  shiny::testServer(server, {
    session$setInputs(
      base_layer = "base_polygon",
      overlay_source = "overlay_point",
      method = "within"
    )

    first_started <- Sys.time()
    session$setInputs(build_btn = 1)
    expect_identical(wait_for_extended_task(build_task, session), "success")
    first_elapsed <- as.numeric(difftime(
      Sys.time(), first_started, units = "secs"
    ))

    second_started <- Sys.time()
    session$setInputs(build_btn = 2)
    expect_identical(wait_for_extended_task(build_task, session), "success")
    second_elapsed <- as.numeric(difftime(
      Sys.time(), second_started, units = "secs"
    ))

    expect_equal(retrieval_count, 2L)
    expect_lt(second_elapsed, first_elapsed)
    expect_match(rendered_html(output$link_task_status), "Completed")
    expect_match(
      rendered_html(output$link_task_status),
      "no work restarted"
    )
  })
})

test_that("Link passes a point overlay as the crosswalk from layer", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  layers <- shiny_fixture_layers()
  calls <- new.env(parent = emptyenv())
  calls$from <- NULL
  calls$to <- NULL
  testthat::local_mocked_bindings(
    list_sources = shiny_fixture_registry,
    get_source = shiny_fixture_metadata,
    retrieve_source = function(source_id, refresh = FALSE, ...) {
      layers[[source_id]]
    },
    build_crosswalk = function(from, to, method = "within", ...) {
      calls$from <- from
      calls$to <- to
      tibble::tibble(from_id = 1L, to_id = "P1")
    },
    .package = "ONgeoR"
  )
  server <- load_shiny_server()
  use_sequential_futures()

  shiny::testServer(server, {
    session$setInputs(
      base_layer = "base_polygon",
      overlay_source = "overlay_point",
      method = "within",
      build_btn = 1
    )
    expect_identical(wait_for_extended_task(build_task, session), "success")
  })

  expect_identical(calls$from, layers$overlay_point)
  expect_identical(calls$to, layers$base_polygon)

  # SKIPPED: app.R always passes overlay_sf as `from` for vector links, so a
  # point in the base picker is passed as `to`. Covering the universal rule in
  # both picker orders requires the forbidden app.R behavior change.
})

test_that("Find Nearest handles valid and malformed uploaded CSV files", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  layers <- shiny_fixture_layers()
  nearest_impl <- ONgeoR::build_nearest_layers
  testthat::local_mocked_bindings(
    list_sources = shiny_fixture_registry,
    get_source = shiny_fixture_metadata,
    retrieve_source = function(source_id, refresh = FALSE, ...) {
      layers[[source_id]]
    },
    build_nearest_layers = function(source, target, ...) {
      nearest_impl(source, target, ...)
    },
    .package = "ONgeoR"
  )
  server <- load_shiny_server()
  use_sequential_futures()

  valid_csv <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(id = c("A", "B"), lon = c(0.2, 1.2), lat = c(0.2, 0.2)),
    valid_csv,
    row.names = FALSE
  )
  shiny::testServer(server, {
    session$setInputs(
      points_csv = list(
        name = "valid.csv",
        size = file.info(valid_csv)$size,
        type = "text/csv",
        datapath = valid_csv
      ),
      target_source = "overlay_point",
      k = 1,
      max_dist_km = NA_real_,
      nearest_btn = 1
    )
    expect_identical(wait_for_extended_task(nearest_task, session), "success")
    expect_s3_class(nearest_result$table, "data.frame")
    expect_gt(nrow(nearest_result$table), 0)
  })

  malformed_csv <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(id = "A", lon = 0.2),
    malformed_csv,
    row.names = FALSE
  )
  shiny::testServer(server, {
    session$setInputs(
      points_csv = list(
        name = "malformed.csv",
        size = file.info(malformed_csv)$size,
        type = "text/csv",
        datapath = malformed_csv
      ),
      target_source = "overlay_point",
      k = 1,
      max_dist_km = NA_real_,
      nearest_btn = 1
    )
    expect_warning(
      wait_for_extended_task(nearest_task, session),
      "An error occurred when invoking the ExtendedTask",
      fixed = TRUE
    )
    expect_identical(shiny::isolate(nearest_task$status()), "error")
    expect_error(
      nearest_task$result(),
      "Uploaded CSV must have `lon` and `lat` columns",
      fixed = TRUE
    )
    expect_null(nearest_result$table)
  })
})

test_that("an empty nearest result keeps an empty table", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  layers <- shiny_fixture_layers()
  testthat::local_mocked_bindings(
    list_sources = shiny_fixture_registry,
    get_source = shiny_fixture_metadata,
    retrieve_source = function(source_id, refresh = FALSE, ...) {
      layers[[source_id]]
    },
    build_nearest_layers = function(source, target, ...) {
      list(
        source = source,
        matched_target = target[0, , drop = FALSE],
        connectors = NULL,
        table = tibble::tibble(
          source_row = integer(),
          target_row = integer(),
          rank = integer(),
          distance_km = double()
        )
      )
    },
    .package = "ONgeoR"
  )
  server <- load_shiny_server()
  use_sequential_futures()

  points_csv <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(id = "A", lon = 0.2, lat = 0.2),
    points_csv,
    row.names = FALSE
  )
  shiny::testServer(server, {
    session$setInputs(
      points_csv = list(
        name = "points.csv",
        size = file.info(points_csv)$size,
        type = "text/csv",
        datapath = points_csv
      ),
      target_source = "overlay_point",
      k = 1,
      max_dist_km = 0,
      nearest_btn = 1
    )
    expect_identical(wait_for_extended_task(nearest_task, session), "success")
    expect_s3_class(nearest_result$table, "data.frame")
    expect_equal(nrow(nearest_result$table), 0)

    downloads <- rendered_html(output$nearest_downloads_ui)
    expect_match(downloads, "disabled")
  })
})

test_that("Find Nearest rejects invalid distance without invoking work", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  calls <- 0L
  testthat::local_mocked_bindings(
    list_sources = shiny_fixture_registry,
    get_source = shiny_fixture_metadata,
    retrieve_source = function(source_id, refresh = FALSE, ...) {
      calls <<- calls + 1L
      shiny_fixture_layers()[[source_id]]
    },
    .package = "ONgeoR"
  )
  server <- load_shiny_server()
  use_sequential_futures()

  points_csv <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(id = "A", lon = 0.2, lat = 0.2),
    points_csv,
    row.names = FALSE
  )
  shiny::testServer(server, {
    session$setInputs(
      points_csv = list(
        name = "points.csv",
        size = file.info(points_csv)$size,
        type = "text/csv",
        datapath = points_csv
      ),
      target_source = "overlay_point",
      k = 1,
      max_dist_km = -1,
      nearest_btn = 1
    )

    expect_equal(calls, 0L)
    expect_identical(shiny::isolate(nearest_task$status()), "initial")
    expect_match(rendered_html(output$nearest_task_status), "Failed")
    expect_match(
      rendered_html(output$nearest_task_status),
      "non-negative or blank"
    )
    expect_null(nearest_result$table)
  })
})

test_that("Find Nearest reports completed and cancelled states", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  layers <- shiny_fixture_layers()
  testthat::local_mocked_bindings(
    list_sources = shiny_fixture_registry,
    get_source = shiny_fixture_metadata,
    retrieve_source = function(source_id, refresh = FALSE, ...) {
      Sys.sleep(0.05)
      layers[[source_id]]
    },
    build_nearest_layers = function(source, target, ...) {
      list(
        source = source,
        matched_target = target,
        connectors = NULL,
        table = tibble::tibble(
          source_row = 1L,
          target_row = 1L,
          rank = 1L,
          distance_km = 1
        )
      )
    },
    .package = "ONgeoR"
  )
  server <- load_shiny_server()
  use_sequential_futures()

  points_csv <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(id = "A", lon = 0.2, lat = 0.2),
    points_csv,
    row.names = FALSE
  )
  upload <- list(
    name = "points.csv",
    size = file.info(points_csv)$size,
    type = "text/csv",
    datapath = points_csv
  )

  shiny::testServer(server, {
    expect_match(rendered_html(output$nearest_task_status), "Idle")
    session$setInputs(
      points_csv = upload,
      target_source = "overlay_point",
      k = 1,
      max_dist_km = NA_real_,
      nearest_btn = 1
    )
    expect_match(rendered_html(output$nearest_task_status), "Running")
    expect_identical(wait_for_extended_task(nearest_task, session), "success")
    expect_match(rendered_html(output$nearest_task_status), "Completed")
    expect_s3_class(nearest_result$table, "data.frame")

    session$setInputs(nearest_btn = 2)
    expect_match(rendered_html(output$nearest_task_status), "Running")
    session$setInputs(k = 2)
    expect_match(rendered_html(output$nearest_task_status), "Cancelled")
    expect_identical(wait_for_extended_task(nearest_task, session), "success")
    expect_null(nearest_result$table)
    expect_match(rendered_html(output$nearest_task_status), "Cancelled")
  })
})

test_that("every offered raster palette actually renders a raster layer", {
  # leaflet::colorNumeric() accepts a wrong-case palette name when the palette
  # function is BUILT, and only fails later when addRasterImage() applies it -
  # so a bad default renders an empty map with no error surfaced in the UI.
  # The app shipped "Viridis"/"Magma" (invalid; leaflet wants them lowercase)
  # as the raster choices, with "Viridis" as the default, which silently broke
  # every raster preview. Guard each offered value end-to-end.
  env <- load_shiny_app_env()
  # Needs a real CRS and extent: addRasterImage() reprojects to EPSG:3857,
  # and a CRS-less raster fails in terra with "warp failure" before the
  # palette is ever applied.
  raster <- terra::rast(
    nrows = 4, ncols = 4,
    xmin = -80, xmax = -79, ymin = 43, ymax = 44,
    crs = "EPSG:4326", vals = seq_len(16)
  )

  # The default, with no style inputs registered yet.
  default_style <- env$read_layer_style(list(), "overlay", "raster")
  expect_no_error(
    env$add_styled_sf_layer(
      leaflet::leaflet(), raster, "Overlay source", default_style
    )
  )

  for (palette in c("viridis", "magma", "Blues")) {
    style <- env$read_layer_style(
      list(overlay_raster_palette = palette), "overlay", "raster"
    )
    expect_identical(style$raster_palette, palette)
    expect_no_error(
      env$add_styled_sf_layer(
        leaflet::leaflet(), raster, "Overlay source", style
      )
    )
  }
})

test_that("rasters are packed across the future boundary and survive", {
  # A SpatRaster is an external pointer; returning one straight out of a
  # multisession future delivers a NULL pointer, and the first later use dies
  # with "NULL value passed as symbol address". That broke every raster
  # preview in the live app (empty map, ~32 KB map.html) while sf pairings
  # were fine and every in-process/sequential test still passed. Guard the
  # wrap/unwrap contract directly so it cannot silently regress.
  env <- load_shiny_app_env()
  raster <- terra::rast(
    nrows = 4, ncols = 4,
    xmin = -80, xmax = -79, ymin = 43, ymax = 44,
    crs = "EPSG:4326", vals = seq_len(16)
  )

  packed <- env$pack_spatial(raster)
  expect_s4_class(packed, "PackedSpatRaster")

  restored <- env$unpack_spatial(packed)
  expect_s4_class(restored, "SpatRaster")
  expect_equal(as.integer(terra::values(restored)[, 1]), seq_len(16))

  # Non-raster payloads must pass through both helpers untouched.
  sf_layer <- shiny_fixture_layers()$base_polygon
  expect_identical(env$pack_spatial(sf_layer), sf_layer)
  expect_identical(env$unpack_spatial(sf_layer), sf_layer)

  # A packed raster must survive an actual serialize/unserialize round trip,
  # which is what crossing a worker boundary really does.
  round_tripped <- env$unpack_spatial(unserialize(serialize(packed, NULL)))
  expect_s4_class(round_tripped, "SpatRaster")
  expect_equal(as.integer(terra::values(round_tripped)[, 1]), seq_len(16))
})
