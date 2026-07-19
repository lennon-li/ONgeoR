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
    expect_identical(cw_result$previewed, c(
      "base_polygon",
      "overlay_point"
    ))
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
