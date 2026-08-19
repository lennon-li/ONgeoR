# ON-Marg is fetched at runtime and never stored, so these tests carry no
# workbook fixture: the licensed content would have to be redistributed in the
# repository to provide one. onmarg_read_sheet() is mocked instead, returning
# frames that reproduce the published column names verbatim.

clear_onmarg_store <- function(env = parent.frame()) {
  withr::defer(rm(list = ls(ONgeoR:::onmarg_store), envir = ONgeoR:::onmarg_store),
    envir = env)
  rm(list = ls(ONgeoR:::onmarg_store), envir = ONgeoR:::onmarg_store)
}

# Column names exactly as the DA_2021 sheet publishes them, including the
# capitalised Pop2021 and the capitalised NC in the racialized stem.
onmarg_da_sheet <- function() {
  data.frame(
    DAUID = c("35010155", "35010156", "35010157"),
    Pop2021 = c("457", "449", "472"),
    households_dwellings_DA21 = c("0.148238968", "-7.2157512E-3", "1.84728E-2"),
    material_resources_DA21 = c("-0.21648785", "0.06374774", "0.1"),
    age_labourforce_DA21 = c("0.1998417", "0.2464814", "0.3"),
    racialized_NC_pop_DA21 = c("-1.322399", "-1.345976", "-1.4"),
    households_dwellings_q_DA21 = c("4", "4", "5"),
    material_resources_q_DA21 = c("3", "4", "4"),
    age_labourforce_q_DA21 = c("4", "4", "5"),
    racialized_NC_pop_q_DA21 = c("1", "1", "2"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

# The PHU sheet: no quintiles, plus a name column that would collide with the
# boundary layer's own.
onmarg_phu_sheet <- function() {
  data.frame(
    HUID = c("P1", "P2", "P9"),
    pop2021 = c("111694", "144771", "1"),
    households_dwellings_HUID = c("0.237", "-8.44E-2", "0.5"),
    material_resources_HUID = c("0.404", "0.153", "0.6"),
    age_labourforce_HUID = c("0.789", "-8.4E-2", "0.7"),
    racialized_nc_pop_HUID = c("-0.865", "-0.386", "-0.8"),
    HU_NAME = c("Fixture Health Unit 1", "Fixture Health Unit 2", "Absent"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

local_onmarg_sheet <- function(sheet_fn, env = parent.frame()) {
  testthat::local_mocked_bindings(
    onmarg_workbook = function(refresh = FALSE) as.raw(0L),
    onmarg_read_sheet = function(raw, sheet) sheet_fn(),
    .package = "ONgeoR",
    .env = env
  )
}

test_that("onmarg_geographies() describes every published geography", {
  geos <- onmarg_geographies()

  expect_s3_class(geos, "tbl_df")
  expect_equal(nrow(geos), 10)
  expect_setequal(
    names(geos),
    c("geography", "label", "sheet", "uid", "target_key", "source_id", "quintiles")
  )
  expect_false(any(duplicated(geos$geography)))
  expect_false(any(duplicated(geos$sheet)))
})

test_that("every mapped ON-Marg geography names a registered source", {
  geos <- onmarg_geographies()
  mapped <- geos$source_id[!is.na(geos$source_id)]

  expect_length(mapped, 8)
  expect_true(all(mapped %in% list_sources()$source_id))
})

test_that("ON-Marg PHU values map to the pre-2025 boundary and its key column", {
  phu <- onmarg_geographies()[onmarg_geographies()$geography == "phu", ]

  # ON-Marg 2021 publishes 34 health units; retrieve_phu() returns the 29-unit
  # post-2025 geography, which the index has no correspondence for.
  expect_equal(phu$source_id, "phu_boundaries_pre2025")
  expect_equal(phu$uid, "HUID")
  expect_equal(phu$target_key, "PHU_ID")
})

test_that("the LHIN geographies are published but unattachable", {
  geos <- onmarg_geographies()
  lhin <- geos[geos$geography %in% c("lhin", "lhin_sr"), ]

  expect_equal(nrow(lhin), 2)
  expect_true(all(is.na(lhin$source_id)))
})

test_that("quintile availability follows the data, not the workbook's note", {
  geos <- onmarg_geographies()
  quintile_geos <- geos$geography[geos$quintiles]

  # The workbook's Variable Descriptions sheet lists five geographies and omits
  # LHIN sub-region, but the LHINSRUID sheet does publish quintiles.
  expect_setequal(quintile_geos, c("da", "ct", "ada", "csd", "ccs", "lhin_sr"))
})

test_that("published column names normalise to one stable set", {
  renamed <- ONgeoR:::onmarg_rename(names(onmarg_da_sheet()), "DAUID")

  expect_equal(renamed[1], "DAUID")
  expect_equal(renamed[2], "onmarg_pop2021")
  expect_true("onmarg_households_dwellings" %in% renamed)
  expect_true("onmarg_racialized_nc_pop" %in% renamed)
  expect_true("onmarg_racialized_nc_pop_q" %in% renamed)
  expect_false(any(grepl("DA21", renamed)))
})

test_that("a quintile column is never mistaken for its factor score", {
  renamed <- ONgeoR:::onmarg_rename(
    c("households_dwellings_CTUID", "households_dwellings_q_CTUID"), "CTUID"
  )

  expect_equal(renamed, c("onmarg_households_dwellings", "onmarg_households_dwellings_q"))
})

test_that("retrieve_onmarg() returns normalised values with provenance", {
  clear_onmarg_store()
  local_onmarg_sheet(onmarg_da_sheet)

  result <- retrieve_onmarg("da")

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 3)
  expect_type(result$DAUID, "character")
  expect_type(result$onmarg_households_dwellings, "double")
  expect_equal(result$onmarg_material_resources[1], -0.21648785)
  expect_equal(result$onmarg_households_dwellings_q, c(4, 4, 5))
  expect_equal(attr(result, "source_name"), ONgeoR:::onmarg_source_name)
  expect_match(attr(result, "source_url"), "index-on-marg.xlsx", fixed = TRUE)
  expect_false(is.null(attr(result, "retrieved_at")))
  expect_match(attr(result, "citation"), "Matheson")
})

test_that("a decimal-looking key survives the read as published", {
  clear_onmarg_store()
  ct_sheet <- function() {
    data.frame(
      CTUID = c("5050001.04", "5050001.10"),
      pop2021 = c("2865", "5882"),
      households_dwellings_CTUID = c("0.738", "-0.441"),
      stringsAsFactors = FALSE, check.names = FALSE
    )
  }
  local_onmarg_sheet(ct_sheet)

  result <- retrieve_onmarg("ct")

  # Read as numeric, "5050001.10" would come back "5050001.1" and never match
  # the boundary layer's own CTUID.
  expect_equal(result$CTUID, c("5050001.04", "5050001.10"))
})

test_that("retrieve_onmarg() reads the workbook once per session", {
  clear_onmarg_store()
  reads <- 0L
  local_mocked_bindings(
    onmarg_workbook = function(refresh = FALSE) as.raw(0L),
    onmarg_read_sheet = function(raw, sheet) {
      reads <<- reads + 1L
      onmarg_da_sheet()
    },
    .package = "ONgeoR"
  )

  retrieve_onmarg("da")
  retrieve_onmarg("da")

  expect_equal(reads, 1L)
})

test_that("retrieve_onmarg() writes nothing to the ONgeoR cache", {
  clear_onmarg_store()
  cache_dir <- tempfile("ongeor-onmarg-cache-")
  dir.create(cache_dir, recursive = TRUE)
  local_mocked_bindings(
    ongeor_cache_dir = function() cache_dir,
    onmarg_workbook = function(refresh = FALSE) as.raw(0L),
    onmarg_read_sheet = function(raw, sheet) onmarg_da_sheet(),
    .package = "ONgeoR"
  )

  retrieve_onmarg("da")

  # The licence permits use, not redistribution or retention.
  expect_length(list.files(cache_dir, recursive = TRUE), 0)
})

test_that("retrieve_onmarg() rejects an unknown geography", {
  expect_error(retrieve_onmarg("dauid"), "Unknown ON-Marg geography")
  expect_error(retrieve_onmarg(c("da", "ct")), "single geography token")
})

test_that("a republished workbook fails the checksum instead of being used", {
  expect_error(
    ONgeoR:::onmarg_verify_checksum(as.raw(c(1L, 2L, 3L))),
    class = "ongeor_retrieval_error"
  )
  expect_error(
    ONgeoR:::onmarg_verify_checksum(as.raw(c(1L, 2L, 3L))),
    "published file has changed"
  )
})

test_that("add_onmarg() attaches values to a boundary layer by its own key", {
  clear_onmarg_store()
  local_onmarg_sheet(onmarg_phu_sheet)
  phu <- fixture_polygons()

  expect_message(result <- add_onmarg(phu, "phu"), "matched 2 of 3")

  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 3)
  expect_equal(as.character(sf::st_geometry_type(result)),
    as.character(sf::st_geometry_type(phu)))
  expect_equal(result$onmarg_households_dwellings, c(0.237, -0.0844, NA))
  expect_equal(result$onmarg_material_resources[2], 0.153)
})

test_that("add_onmarg() detects the geography from the layer's key column", {
  clear_onmarg_store()
  local_onmarg_sheet(onmarg_phu_sheet)

  result <- suppressMessages(add_onmarg(fixture_polygons()))

  expect_true("onmarg_age_labourforce" %in% names(result))
})

test_that("a registered layer's own id column resolves a multi-key layer", {
  clear_onmarg_store()
  csd_sheet <- function() {
    data.frame(
      CSDUID = c("3501005", "3501011"),
      pop2021 = c("13330", "61415"),
      households_dwellings_CSDUID = c("-0.344", "0.337"),
      CSDNAME = c("South Glengarry", "Cornwall"),
      stringsAsFactors = FALSE, check.names = FALSE
    )
  }
  local_onmarg_sheet(csd_sheet)
  # A retrieved census subdivision carries the CDUID above it as well as its
  # own CSDUID; the registry says which one identifies its features.
  csds <- data.frame(
    CSDUID = c("3501005", "3501011"),
    CDUID = c("3501", "3501"),
    stringsAsFactors = FALSE
  )
  attr(csds, "source_name") <- get_source("census_csd_2021")$name

  result <- suppressMessages(add_onmarg(csds))

  expect_equal(result$onmarg_households_dwellings, c(-0.344, 0.337))
})

test_that("add_onmarg() refuses to guess when the key is absent or ambiguous", {
  no_key <- data.frame(id = 1:2)
  expect_error(add_onmarg(no_key), "none of the ON-Marg key columns")

  both_keys <- data.frame(DAUID = "35010155", CTUID = "5050001.04")
  expect_error(add_onmarg(both_keys), "it carries several")
})

test_that("add_onmarg() reports a named geography whose key is missing", {
  expect_error(
    add_onmarg(data.frame(DAUID = "35010155"), "phu"),
    "does not carry the key column 'PHU_ID'"
  )
})

test_that("add_onmarg() attaches only the requested measures", {
  clear_onmarg_store()
  local_onmarg_sheet(onmarg_da_sheet)
  das <- data.frame(DAUID = c("35010155", "35010156"), stringsAsFactors = FALSE)

  scores_only <- suppressMessages(
    add_onmarg(das, "da", quintiles = FALSE, dimensions = "material_resources")
  )
  with_population <- suppressMessages(
    add_onmarg(das, "da", scores = FALSE, quintiles = FALSE, population = TRUE)
  )

  expect_equal(setdiff(names(scores_only), "DAUID"), "onmarg_material_resources")
  expect_equal(setdiff(names(with_population), "DAUID"), "onmarg_pop2021")
  expect_equal(with_population$onmarg_pop2021, c(457, 449))
})

test_that("add_onmarg() errors rather than returning an unchanged layer", {
  clear_onmarg_store()
  local_onmarg_sheet(onmarg_da_sheet)
  das <- data.frame(DAUID = "35010155", stringsAsFactors = FALSE)

  expect_error(
    add_onmarg(das, "da", scores = FALSE, quintiles = FALSE, population = FALSE),
    "No ON-Marg columns were selected"
  )
})

test_that("add_onmarg() does not attach a name column that would collide", {
  clear_onmarg_store()
  local_onmarg_sheet(onmarg_phu_sheet)

  result <- suppressMessages(add_onmarg(fixture_polygons(), "phu"))

  # The boundary layer already carries PHU_NAME_ENG; HU_NAME restates it.
  expect_false("HU_NAME" %in% names(result))
  expect_true("PHU_NAME_ENG" %in% names(result))
})

test_that("a geography without quintiles simply attaches none", {
  clear_onmarg_store()
  local_onmarg_sheet(onmarg_phu_sheet)

  result <- suppressMessages(add_onmarg(fixture_polygons(), "phu", quintiles = TRUE))

  expect_length(grep("_q$", names(result)), 0)
  expect_true("onmarg_racialized_nc_pop" %in% names(result))
})

test_that("add_onmarg() rejects a non-data-frame layer", {
  expect_error(add_onmarg(1:3), "must be a data frame")
})
