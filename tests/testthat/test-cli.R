make_cli_layers <- function() {
  phu_poly <- sf::st_polygon(list(rbind(
    c(-80, 44), c(-79, 44), c(-79, 43), c(-80, 43), c(-80, 44)
  )))
  phu <- sf::st_sf(
    PHU_ID = 1,
    PHU_NAME_ENG = "Test Health Unit A",
    geometry = sf::st_sfc(phu_poly, crs = 4326)
  )
  attr(phu, "source_name") <- "MOH Public Health Unit Boundary"
  attr(phu, "source_url") <- "https://example.com/phu"
  attr(phu, "retrieved_at") <- as.POSIXct("2026-07-08 00:00:00", tz = "UTC")

  health_region <- sf::st_sf(
    OH_REGION_ID = 10,
    ENGLISH_NAME = "Test Health Region",
    geometry = sf::st_sfc(phu_poly, crs = 4326)
  )
  attr(health_region, "source_name") <- "Ontario Health Region"
  attr(health_region, "source_url") <- "https://example.com/health-region"
  attr(health_region, "retrieved_at") <- as.POSIXct("2026-07-08 00:00:00", tz = "UTC")

  municipal_poly <- sf::st_polygon(list(rbind(
    c(-79.8, 43.8), c(-79.2, 43.8), c(-79.2, 43.2), c(-79.8, 43.2), c(-79.8, 43.8)
  )))
  municipal_upper <- sf::st_sf(
    MUNID = 100,
    MUNICIPAL_NAME = "Test Upper Municipality",
    geometry = sf::st_sfc(municipal_poly, crs = 4326)
  )
  attr(municipal_upper, "source_name") <- "Municipal Bnd Upper And Dist"
  attr(municipal_upper, "source_url") <- "https://example.com/municipal-upper"

  municipal_lower <- sf::st_sf(
    MUNID = 200,
    MUNICIPAL_NAME = "Test Lower Municipality",
    geometry = sf::st_sfc(municipal_poly, crs = 4326)
  )
  attr(municipal_lower, "source_name") <- "Municipal Bnd Lower And Single"
  attr(municipal_lower, "source_url") <- "https://example.com/municipal-lower"

  airport <- sf::st_sf(
    AIRPORT_IDENT = "ABC",
    NAME = "Test Airport",
    AIRPORT_TYPE = "Registered Aerodrome",
    geometry = sf::st_sfc(municipal_poly, crs = 4326)
  )
  attr(airport, "source_name") <- "Airport Official"
  attr(airport, "source_url") <- "https://example.com/airport"

  waste_site <- sf::st_sf(
    SITE_NAME = "Test Waste Site",
    PRIMARY_CLASSIFICATION = "Landfill",
    STATUS = "Open",
    geometry = sf::st_sfc(municipal_poly, crs = 4326)
  )
  attr(waste_site, "source_name") <- "Waste Management Site"
  attr(waste_site, "source_url") <- "https://example.com/waste-site"

  service_locations <- sf::st_as_sf(
    data.frame(
      MOH_SERVICE_PROVIDER_IDENT = 300,
      ENGLISH_NAME = "Test Clinic",
      lon = -79.5,
      lat = 43.5
    ),
    coords = c("lon", "lat"),
    crs = 4326
  )
  attr(service_locations, "source_name") <- "MOH Service Location"
  attr(service_locations, "source_url") <- "https://example.com/service-locations"

  list(
    phu_boundaries = phu,
    ontario_health_regions = health_region,
    municipal_upper = municipal_upper,
    municipal_lower = municipal_lower,
    airport_official = airport,
    waste_management_site = waste_site,
    moh_service_locations = service_locations
  )
}

test_that("retrieve_by_source_id errors clearly on unknown ids", {
  expect_error(
    retrieve_by_source_id("bogus_id"),
    "Unknown source_id 'bogus_id'.*Valid source ids are"
  )
})

test_that("retrieve_source errors clearly on unknown ids", {
  expect_error(
    retrieve_source("bogus_id"),
    "Unknown source_id 'bogus_id'.*Valid source ids are"
  )
})

test_that("retrieve_source fetches registry-only LIO sources", {
  calls <- list()
  testthat::local_mocked_bindings(
    list_sources = function() tibble::tibble(
      source_id = "registry_only",
      name = "Registry-only Layer",
      geography_type = "boundary",
      feature_count = 1L
    ),
    get_source = function(source_id) list(
      name = "Registry-only Layer",
      service_layer = "LIO_Open01/35",
      simplify = FALSE,
      paginate = TRUE
    ),
    fetch_lio_sf = function(service_layer, source_name, simplify, paginate,
                            refresh, max_age) {
      calls <<- list(
        service_layer = service_layer,
        source_name = source_name,
        simplify = simplify,
        paginate = paginate,
        refresh = refresh,
        max_age = max_age
      )
      sf::st_sf(
        geometry = sf::st_sfc(sf::st_point(c(-79, 44)), crs = 4326)
      )
    },
    .package = "ONgeoR"
  )

  layer <- retrieve_source("registry_only", refresh = TRUE, max_age = 2)

  expect_s3_class(layer, "sf")
  expect_identical(calls, list(
    service_layer = "LIO_Open01/35",
    source_name = "Registry-only Layer",
    simplify = FALSE,
    paginate = TRUE,
    refresh = TRUE,
    max_age = 2
  ))
})

test_that("retrieve_source retains named wrapper dispatch", {
  calls <- character()
  named_ids <- c(
    "phu_boundaries", "ontario_health_regions", "municipal_upper",
    "municipal_lower", "airport_official", "waste_management_site",
    "moh_service_locations", "synthetic_air_quality", "hive",
    "conservation_authority", "orwn_station"
  )
  wrapper <- function(id) {
    force(id)
    function(...) {
      calls <<- c(calls, id)
      sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(-79, 44)), crs = 4326))
    }
  }
  testthat::local_mocked_bindings(
    retrieve_phu = wrapper("phu_boundaries"),
    retrieve_health_region = wrapper("ontario_health_regions"),
    retrieve_municipal = function(tier, ...) wrapper(paste0("municipal_", tier))(),
    retrieve_airport = wrapper("airport_official"),
    retrieve_waste_management = wrapper("waste_management_site"),
    retrieve_moh_service_locations = wrapper("moh_service_locations"),
    retrieve_synthetic_raster = wrapper("synthetic_air_quality"),
    retrieve_hive = wrapper("hive"),
    retrieve_conservation_authority = wrapper("conservation_authority"),
    retrieve_orwn_station = wrapper("orwn_station"),
    .package = "ONgeoR"
  )

  lapply(named_ids, retrieve_source)

  expect_setequal(calls, named_ids)
})

test_that("retrieve_source dispatches to the right retrieval path", {
  layers <- make_cli_layers()
  testthat::local_mocked_bindings(
    retrieve_phu = function(refresh = FALSE) layers$phu_boundaries,
    .package = "ONgeoR"
  )

  phu <- retrieve_source("phu_boundaries")

  expect_equal(attr(phu, "source_name"), "MOH Public Health Unit Boundary")
})

test_that("retrieve_by_source_id delegates to retrieve_source", {
  layers <- make_cli_layers()
  testthat::local_mocked_bindings(
    retrieve_phu = function(refresh = FALSE) layers$phu_boundaries,
    .package = "ONgeoR"
  )

  phu <- retrieve_by_source_id("phu_boundaries")

  expect_equal(attr(phu, "source_name"), "MOH Public Health Unit Boundary")
})

test_that("retrieve_source dispatches the synthetic raster source", {
  r <- retrieve_source("synthetic_air_quality")

  expect_s4_class(r, "SpatRaster")
  expect_equal(names(r), "pm25")
})

test_that("cross_crosswalk stamps one from-to pair with registry ids", {
  layers <- make_cli_layers()
  testthat::local_mocked_bindings(
    retrieve_layers = function(source_ids, refresh = FALSE) layers[source_ids],
    .package = "ONgeoR"
  )

  crosswalk <- cross_crosswalk("municipal_upper", "phu_boundaries")

  expect_equal(nrow(crosswalk), 1)
  expect_equal(crosswalk$from_source_id, "municipal_upper")
  expect_equal(crosswalk$to_source_id, "phu_boundaries")
  expect_equal(crosswalk$match_method, "intersects")
})

test_that("retrieve_by_source_id dispatches new registry ids", {
  layers <- make_cli_layers()
  testthat::local_mocked_bindings(
    retrieve_airport = function(refresh = FALSE) layers$airport_official,
    retrieve_waste_management = function(refresh = FALSE) layers$waste_management_site,
    .package = "ONgeoR"
  )

  airport <- retrieve_by_source_id("airport_official")
  waste_site <- retrieve_by_source_id("waste_management_site")

  expect_equal(attr(airport, "source_name"), "Airport Official")
  expect_equal(attr(waste_site, "source_name"), "Waste Management Site")
})

test_that("cross_crosswalk includes all 2x2 source id pairs", {
  layers <- make_cli_layers()
  testthat::local_mocked_bindings(
    retrieve_layers = function(source_ids, refresh = FALSE) layers[source_ids],
    .package = "ONgeoR"
  )

  crosswalk <- cross_crosswalk(
    c("municipal_upper", "municipal_lower"),
    c("phu_boundaries", "ontario_health_regions")
  )

  pair_keys <- paste(crosswalk$from_source_id, crosswalk$to_source_id, sep = "->")
  expect_equal(nrow(crosswalk), 4)
  expect_setequal(pair_keys, c(
    "municipal_upper->phu_boundaries",
    "municipal_lower->phu_boundaries",
    "municipal_upper->ontario_health_regions",
    "municipal_lower->ontario_health_regions"
  ))
})

test_that("map_crosswalk returns a leaflet htmlwidget for mixed layer types", {
  layers <- make_cli_layers()

  map <- map_crosswalk(
    layers,
    from_ids = "moh_service_locations",
    to_ids = "phu_boundaries"
  )

  expect_s3_class(map, "leaflet")
  expect_s3_class(map, "htmlwidget")
})

test_that("render_reproducer_script includes new registry retrieve calls", {
  script <- render_reproducer_script(
    from_ids = "airport_official",
    to_ids = "waste_management_site",
    output_dir = tempfile("ongeor-output-")
  )

  expect_match(script, "airport_official = retrieve_airport()", fixed = TRUE)
  expect_match(script, "waste_management_site = retrieve_waste_management()", fixed = TRUE)
})

test_that("every registered source id dispatches through retrieve_source", {
  testthat::local_mocked_bindings(
    fetch_lio_sf = function(service_layer, source_name, ...) {
      layer <- sf::st_sf(
        SOME_ID = 1,
        geometry = sf::st_sfc(sf::st_point(c(-79, 44)), crs = 4326)
      )
      attr(layer, "source_name") <- source_name
      layer
    },
    .package = "ONgeoR"
  )

  ids <- list_sources()$source_id
  for (id in ids) {
    result <- tryCatch(retrieve_source(id), error = function(e) e)
    expect_false(inherits(result, "error"), label = paste0("retrieve_source failed for id: ", id))
  }
})

test_that("every registered source id has a source_retrieve_call entry", {
  ids <- list_sources()$source_id
  for (id in ids) {
    result <- tryCatch(source_retrieve_call(id), error = function(e) e)
    expect_false(inherits(result, "error"), label = paste0("source_retrieve_call failed for id: ", id))
    if (!inherits(result, "error")) {
      expect_type(result, "character")
      expect_length(result, 1)
      expect_gt(nchar(result), 0)
    }
  }
})

test_that("cross_crosswalk passes the method through to build_crosswalk", {
  layers <- make_cli_layers()
  testthat::local_mocked_bindings(
    retrieve_layers = function(source_ids, refresh = FALSE) layers[source_ids],
    .package = "ONgeoR"
  )

  crosswalk <- cross_crosswalk("municipal_upper", "phu_boundaries",
    method = "within")

  expect_equal(unique(crosswalk$match_method), "within")
})

test_that("render_reproducer_script records the crosswalk method", {
  script <- render_reproducer_script(
    from_ids = "airport_official",
    to_ids = "phu_boundaries",
    output_dir = tempfile("ongeor-output-"),
    method = "largest_overlap"
  )

  expect_match(script, 'method <- "largest_overlap"', fixed = TRUE)
  expect_match(script, "cross_crosswalk(from_ids, to_ids, method = method)", fixed = TRUE)
  expect_match(script,
    "render_reproducer_script(from_ids, to_ids, output_dir, method = method)",
    fixed = TRUE
  )
})
