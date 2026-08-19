# The 2021 Ontario Marginalization Index (ON-Marg) is published by Public
# Health Ontario and Unity Health Toronto as a single multi-sheet workbook,
# one sheet per geography. Its licence permits non-commercial use with credit
# and forbids modifying the content, so ONgeoR never bundles, caches to disk,
# or rewrites it: the workbook is fetched at runtime, verified against a
# pinned checksum, held in memory for the life of the R process only, and its
# values are passed through untouched. Only column NAMES are normalised (the
# published names carry a per-sheet geography suffix, e.g.
# `households_dwellings_DA21` vs `households_dwellings_CTUID`, which makes a
# geography-agnostic API impossible), and the mapping is documented in
# retrieve_onmarg().
onmarg_url <- paste0(
  "https://www.publichealthontario.ca/-/media/Data-Files/index-on-marg.xlsx",
  "?rev=f5d2d60add6c492e9422812608c0486a&sc_lang=en",
  "&hash=257B9E1B4C34CE33D29B3C80631E4F6E"
)

onmarg_expected_sha256 <-
  "1f0d6d2964ebe8d8b00f43355854f1797898d569e2d462e7a6ea59f5fda1eade"

onmarg_source_name <- "2021 Ontario Marginalization Index (ON-Marg)"

onmarg_citation <- paste(
  "Matheson FI (Unity Health Toronto), Moloney G (Unity Health Toronto),",
  "van Ingen T (Public Health Ontario). 2021 Ontario marginalization index.",
  "Toronto, ON: St. Michael's Hospital (Unity Health Toronto); 2023."
)

# Per-process store. Deliberately NOT the ONgeoR disk cache: ON-Marg is
# fetched, used, and forgotten when the session ends.
onmarg_store <- new.env(parent = emptyenv())

# The correspondence between an ON-Marg sheet and the ONgeoR boundary source it
# can be joined to. `uid` is the sheet's own key column; `target_key` is the
# column that key appears under in the boundary layer - identical for every
# census geography, but ON-Marg calls the Public Health Unit key `HUID` where
# the MOH boundary layer calls it `PHU_ID` (verified: the two key sets match
# exactly, 34/34, against the pre-2025 PHU layer).
#
# `source_id` is NA for the two LHIN geographies: the index publishes them, but
# ONgeoR has no LHIN boundary source to attach them to.
#
# `quintiles` records which sheets carry quintile columns in addition to the
# factor scores. The workbook's own Variable Descriptions note lists five
# geographies here and omits LHIN sub-region, but the LHINSRUID sheet does ship
# quintiles - this column follows the data, not the note.
onmarg_geography_table <- function() {
  data.frame(
    geography  = c("da", "ct", "ada", "csd", "ccs", "cd", "cma", "phu",
                   "lhin", "lhin_sr"),
    label      = c("Dissemination Area", "Census Tract",
                   "Aggregate Dissemination Area", "Census Subdivision",
                   "Census Consolidated Subdivision", "Census Division",
                   "Census Metropolitan Area", "Public Health Unit",
                   "Local Health Integration Network",
                   "Local Health Integration Network Sub-Region"),
    sheet      = c("DA_2021", "2021_CTUID", "2021_ADAUID", "2021_CSDUID",
                   "2021_CCSUID", "2021_CDUID", "2021_CMAUID", "2021_HUID",
                   "2021_LHINUID", "2021_LHINSRUID"),
    uid        = c("DAUID", "CTUID", "ADAUID", "CSDUID", "CCSUID", "CDUID",
                   "CMAUID", "HUID", "LHINUID", "LHINSRUID"),
    target_key = c("DAUID", "CTUID", "ADAUID", "CSDUID", "CCSUID", "CDUID",
                   "CMAUID", "PHU_ID", "LHINUID", "LHINSRUID"),
    source_id  = c("census_da_2021", "census_ct_2021", "census_ada_2021",
                   "census_csd_2021", "census_ccs_2021", "census_cd_2021",
                   "census_cma_2021", "phu_boundaries_pre2025",
                   NA_character_, NA_character_),
    quintiles  = c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE,
                   FALSE, TRUE),
    stringsAsFactors = FALSE
  )
}

#' ON-Marg geographies and the boundary layers they attach to
#'
#' Lists the geographies published in the 2021 Ontario Marginalization Index
#' (ON-Marg), the key column each one is published under, and the ONgeoR
#' boundary source whose features that key identifies. This is a static
#' correspondence table: it performs no download.
#'
#' Two geographies (`"lhin"`, `"lhin_sr"`) have no `source_id`, because ONgeoR
#' does not currently provide Local Health Integration Network boundaries.
#' Their marginalization values are still retrievable with
#' [retrieve_onmarg()]; they simply cannot be attached to a layer.
#'
#' ON-Marg 2021 reports Public Health Units on the pre-2025, 34-unit geography
#' (`phu_boundaries_pre2025`). There is no correspondence for the post-2025,
#' 29-unit geography returned by [retrieve_phu()].
#'
#' @return A [tibble::tibble()] with columns `geography` (the token accepted by
#'   [retrieve_onmarg()]), `label`, `sheet` (the workbook sheet it is read
#'   from), `uid` (the key column as published), `target_key` (the column that
#'   key appears under in the boundary layer), `source_id` (the ONgeoR source,
#'   or `NA`), and `quintiles` (whether quintile columns are published for that
#'   geography as well as factor scores).
#'
#' @seealso [retrieve_onmarg()] to fetch the values, [add_onmarg()] to attach
#'   them to a layer.
#'
#' @examples
#' onmarg_geographies()
#'
#' @export
onmarg_geographies <- function() {
  tibble::as_tibble(onmarg_geography_table())
}

onmarg_geography_row <- function(geography) {
  table <- onmarg_geography_table()
  if (!is.character(geography) || length(geography) != 1 || is.na(geography)) {
    rlang::abort("`geography` must be a single geography token. See onmarg_geographies().")
  }
  idx <- match(geography, table$geography)
  if (is.na(idx)) {
    rlang::abort(sprintf(
      "Unknown ON-Marg geography '%s'. Available: %s.",
      geography, paste(table$geography, collapse = ", ")
    ))
  }
  table[idx, , drop = FALSE]
}

onmarg_sha256 <- function(raw) {
  path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(path), add = TRUE)
  writeBin(raw, path)
  unname(tools::sha256sum(path))
}

# A checksum mismatch means Public Health Ontario republished the workbook
# behind the same revision-pinned URL. Proceeding would attach values whose
# provenance ONgeoR cannot state, so this aborts rather than warning.
onmarg_verify_checksum <- function(raw) {
  actual <- onmarg_sha256(raw)
  if (!identical(actual, onmarg_expected_sha256)) {
    abort_lio_retrieval(sprintf(
      paste0(
        "Could not verify the ON-Marg workbook: expected SHA-256 %s but ",
        "downloaded SHA-256 %s. The published file has changed; ONgeoR needs ",
        "to be updated to the new release before its values can be used."
      ),
      onmarg_expected_sha256,
      actual
    ))
  }
  invisible(raw)
}

onmarg_download <- function() {
  tryCatch(
    httr2::request(onmarg_url) |>
      httr2::req_perform() |>
      httr2::resp_body_raw(),
    error = function(cnd) {
      abort_lio_retrieval(
        "Could not retrieve the ON-Marg workbook from Public Health Ontario.",
        parent = cnd
      )
    }
  )
}

# Downloads the workbook at most once per R session. `refresh = TRUE` forces a
# re-download; nothing is ever written to the ONgeoR cache directory.
onmarg_workbook <- function(refresh = FALSE) {
  if (!refresh && !is.null(onmarg_store$raw)) {
    return(onmarg_store$raw)
  }
  raw <- onmarg_download()
  onmarg_verify_checksum(raw)
  onmarg_store$raw <- raw
  raw
}

# readxl needs a path, so the workbook touches the filesystem for exactly as
# long as one sheet takes to parse, in the session temp directory, and is
# removed on exit even if the read fails.
onmarg_read_sheet <- function(raw, sheet) {
  rlang::check_installed("readxl", reason = "to read the ON-Marg workbook.")
  path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(path), add = TRUE)
  writeBin(raw, path)
  # Read every column as text: the census tract key is a decimal-looking string
  # ("5050001.04") that a numeric read would round-trip into a value no longer
  # equal to the boundary layer's own CTUID. Measures are coerced back to
  # numeric below, from the published representation, unchanged.
  as.data.frame(
    readxl::read_excel(path, sheet = sheet, col_types = "text",
      .name_repair = "minimal"),
    stringsAsFactors = FALSE
  )
}

onmarg_measure_stems <- function() {
  c(
    households_dwellings = "households_dwellings",
    material_resources   = "material_resources",
    age_labourforce      = "age_labourforce",
    racialized_nc_pop    = "racialized_nc_pop"
  )
}

# Published names carry a per-sheet suffix and inconsistent case
# (`Pop2021`/`pop2021`, `racialized_NC_pop_DA21`/`racialized_nc_pop_CTUID`), so
# they are mapped onto one stable `onmarg_*` set. Values are untouched.
onmarg_rename <- function(nms, uid) {
  out <- nms
  lower <- tolower(nms)
  out[lower == tolower(uid)] <- uid
  out[lower == "pop2021"] <- "onmarg_pop2021"
  for (stem in onmarg_measure_stems()) {
    is_quintile <- grepl(paste0("^", stem, "_q_"), lower)
    is_score <- grepl(paste0("^", stem, "_"), lower) & !is_quintile
    out[is_quintile] <- paste0("onmarg_", stem, "_q")
    out[is_score] <- paste0("onmarg_", stem)
  }
  out
}

#' Retrieve Ontario Marginalization Index (ON-Marg) values
#'
#' Fetches one geography's worth of the 2021 Ontario Marginalization Index from
#' Public Health Ontario. ON-Marg summarises four dimensions of marginalization
#' derived from the 2021 Census: households and dwellings (formerly residential
#' instability), material resources (formerly material deprivation), age and
#' labour force (formerly dependency), and racialized and newcomer populations
#' (formerly ethnic concentration).
#'
#' The workbook is downloaded at runtime, verified against a pinned SHA-256,
#' and held in memory for the life of the R process. Unlike ONgeoR's spatial
#' retrievals it is never written to the ONgeoR cache directory: its licence
#' permits non-commercial use with attribution and forbids modifying the
#' content, so ONgeoR neither redistributes nor stores it. Values are returned
#' exactly as published; only column names are normalised, because the
#' published names carry a per-sheet geography suffix:
#'
#' * `Pop2021` / `pop2021` becomes `onmarg_pop2021`
#' * `households_dwellings_*` becomes `onmarg_households_dwellings`
#' * `material_resources_*` becomes `onmarg_material_resources`
#' * `age_labourforce_*` becomes `onmarg_age_labourforce`
#' * `racialized_NC_pop_*` becomes `onmarg_racialized_nc_pop`
#' * the matching `*_q_*` columns take the same names with a `_q` suffix
#'
#' Higher factor scores mean more marginalization on that dimension. Quintiles
#' run 1 (least marginalized) to 5 (most), and are published for some
#' geographies only - see [onmarg_geographies()].
#'
#' Cite ON-Marg as: Matheson FI (Unity Health Toronto), Moloney G (Unity
#' Health Toronto), van Ingen T (Public Health Ontario). 2021 Ontario
#' marginalization index. Toronto, ON: St. Michael's Hospital (Unity Health
#' Toronto); 2023.
#'
#' @param geography Character scalar naming the geography, e.g. `"da"` or
#'   `"phu"`. See [onmarg_geographies()] for the full set.
#' @param refresh Logical. `TRUE` re-downloads the workbook instead of reusing
#'   the copy held for this session. Default `FALSE`.
#'
#' @return A [tibble::tibble()] with one row per feature of that geography: the
#'   key column under its published name (character), the `onmarg_*` measure
#'   columns (numeric), and the geography's own name column where the workbook
#'   publishes one. Carries `source_name`, `source_url`, `retrieved_at`, and
#'   `citation` attributes for provenance.
#'
#' @seealso [add_onmarg()] to attach these values to a boundary layer,
#'   [onmarg_geographies()] for the available geographies.
#'
#' @examplesIf interactive()
#' retrieve_onmarg("phu")
#'
#' @export
retrieve_onmarg <- function(geography, refresh = FALSE) {
  row <- onmarg_geography_row(geography)
  key <- paste0("sheet_", row$geography)

  if (!refresh && !is.null(onmarg_store[[key]])) {
    return(onmarg_store[[key]])
  }

  raw <- onmarg_workbook(refresh = refresh)
  data <- onmarg_read_sheet(raw, row$sheet)
  names(data) <- onmarg_rename(names(data), row$uid)

  if (!row$uid %in% names(data)) {
    abort_lio_retrieval(sprintf(
      "The ON-Marg sheet '%s' does not contain its expected key column '%s'.",
      row$sheet, row$uid
    ))
  }

  measure_cols <- grep("^onmarg_", names(data), value = TRUE)
  for (nm in measure_cols) {
    data[[nm]] <- suppressWarnings(as.numeric(data[[nm]]))
  }

  result <- tibble::as_tibble(data)
  attr(result, "source_name") <- onmarg_source_name
  attr(result, "source_url") <- onmarg_url
  attr(result, "retrieved_at") <- Sys.time()
  attr(result, "citation") <- onmarg_citation

  onmarg_store[[key]] <- result
  result
}

#' Attach ON-Marg columns to an administrative boundary layer
#'
#' Adds the 2021 Ontario Marginalization Index measures to a layer whose
#' features are one of the geographies ON-Marg publishes, matching on the
#' layer's own key column. The layer is returned unchanged apart from the added
#' `onmarg_*` columns, so an `sf` object stays an `sf` object with its geometry
#' intact.
#'
#' The ON-Marg name columns (`CSDNAME`, `HU_NAME`, and similar) are deliberately
#' not attached: they restate a name the boundary layer already carries, under a
#' name that would collide with it.
#'
#' @param x A data frame or `sf` object carrying the geography's key column -
#'   for example the output of [retrieve_census()] or [retrieve_phu()].
#' @param geography Character scalar naming the ON-Marg geography, as in
#'   [retrieve_onmarg()]. `NULL` (the default) detects it from the key columns
#'   present in `x`, and errors if that is ambiguous or absent.
#' @param scores Logical. Attach the four factor-score columns. Default `TRUE`.
#' @param quintiles Logical. Attach the four quintile columns, where the
#'   geography publishes them. Default `TRUE`.
#' @param population Logical. Attach ON-Marg's own 2021 population count.
#'   Default `FALSE`, since boundary layers usually carry their own.
#' @param dimensions Character vector naming which of the four dimensions to
#'   attach: any of `"households_dwellings"`, `"material_resources"`,
#'   `"age_labourforce"`, `"racialized_nc_pop"`. Defaults to all four.
#' @param refresh Logical, passed to [retrieve_onmarg()].
#'
#' @return `x` with the requested `onmarg_*` columns added. Features with no
#'   ON-Marg row get `NA`; how many that was is reported in a message, because
#'   a key mismatch otherwise looks exactly like a successful join.
#'
#' @seealso [retrieve_onmarg()], [onmarg_geographies()].
#'
#' @examplesIf interactive()
#' phu <- retrieve_phu_pre2025()
#' add_onmarg(phu, "phu")
#'
#' @export
add_onmarg <- function(x, geography = NULL, scores = TRUE, quintiles = TRUE,
                       population = FALSE,
                       dimensions = names(onmarg_measure_stems()),
                       refresh = FALSE) {
  if (!is.data.frame(x)) {
    rlang::abort("`x` must be a data frame or sf object.")
  }
  dimensions <- match.arg(dimensions, names(onmarg_measure_stems()),
    several.ok = TRUE)

  table <- onmarg_geography_table()
  if (is.null(geography)) {
    present <- table$target_key %in% names(x)
    # A retrieved census layer often carries several UID columns (a census
    # subdivision knows its own CSDUID and the CDUID above it), so a bare
    # column scan is ambiguous more often than not. The source registry's
    # declared key fields settle it for a layer that carries provenance.
    # Deliberately not layer_id_col(): its guess_id_col() fallback would answer
    # for an unprovenanced layer too, and a guessed key here silently attaches
    # one geography's marginalization values to another's features.
    if (sum(present) > 1) {
      entry <- registry_entry_for(x)
      registered <- intersect(entry$key_fields %||% character(),
        table$target_key[present])
      if (length(registered) == 1) {
        present <- table$target_key == registered
      }
    }
    if (sum(present) != 1) {
      rlang::abort(sprintf(
        paste0(
          "Could not determine the ON-Marg geography of `x`: %s. Pass ",
          "`geography` explicitly - see onmarg_geographies()."
        ),
        if (sum(present) == 0) {
          "it carries none of the ON-Marg key columns"
        } else {
          paste0("it carries several (",
            paste(table$target_key[present], collapse = ", "), ")")
        }
      ))
    }
    geography <- table$geography[present]
  }

  row <- onmarg_geography_row(geography)
  if (!row$target_key %in% names(x)) {
    rlang::abort(sprintf(
      "`x` does not carry the key column '%s' that ON-Marg geography '%s' joins on.",
      row$target_key, row$geography
    ))
  }

  values <- retrieve_onmarg(row$geography, refresh = refresh)

  wanted <- character(0)
  if (isTRUE(population)) wanted <- c(wanted, "onmarg_pop2021")
  stems <- onmarg_measure_stems()[dimensions]
  if (isTRUE(scores)) wanted <- c(wanted, paste0("onmarg_", stems))
  if (isTRUE(quintiles)) wanted <- c(wanted, paste0("onmarg_", stems, "_q"))
  wanted <- intersect(wanted, names(values))

  if (!length(wanted)) {
    rlang::abort(sprintf(
      "No ON-Marg columns were selected for geography '%s'.", row$geography
    ))
  }

  idx <- match(as.character(x[[row$target_key]]),
    as.character(values[[row$uid]]))
  for (nm in wanted) {
    x[[nm]] <- values[[nm]][idx]
  }

  matched <- sum(!is.na(idx))
  rlang::inform(sprintf(
    "ON-Marg (%s): matched %s of %s features on %s; %s unmatched.",
    row$label, format(matched, big.mark = ","),
    format(nrow(x), big.mark = ","), row$target_key,
    format(nrow(x) - matched, big.mark = ",")
  ))

  x
}
