#' @importFrom rlang .data
NULL

lio_base_url <- "https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA"

#' Build a LIO ArcGIS REST query URL
#'
#' @param service_layer Character. Service and layer path, e.g. `"LIO_Open09/44"`.
#' @param where Character. SQL-style filter expression. Defaults to `"1=1"`.
#' @param simplify Logical. Whether to request generalized geometry via
#'   `maxAllowableOffset`.
#' @param result_record_count Integer. Maximum number of records to request.
#'
#' @return A character scalar: the full query URL.
#' @keywords internal
#' @noRd
lio_query_url <- function(service_layer, where = "1=1", simplify = TRUE,
                          result_record_count = 2000) {
  params <- list(
    where = where,
    outFields = "*",
    f = "geojson",
    resultRecordCount = result_record_count
  )
  if (simplify) {
    params$maxAllowableOffset <- 10
  }

  parts <- strsplit(service_layer, "/", fixed = TRUE)[[1]]
  service <- parts[1]
  layer <- parts[2]

  httr2::request(paste0(lio_base_url, "/", service, "/MapServer/", layer, "/query")) |>
    httr2::req_url_query(!!!params) |>
    httr2::req_get_url()
}

#' Retrieve a LIO layer and convert it to an sf object with provenance
#'
#' @param service_layer Character. Service and layer path, e.g. `"LIO_Open09/44"`.
#' @param source_name Character. Human-readable source name for provenance.
#' @param where Character. SQL-style filter expression.
#' @param simplify Logical. Whether to request generalized geometry.
#' @param result_record_count Integer. Maximum number of records to request.
#' @param refresh Logical. If `TRUE`, bypasses any cached copy and re-fetches
#'   from the live API, overwriting the cache entry. Defaults to `FALSE`.
#'
#' @return An `sf` object with `source_url`, `source_name`, and `retrieved_at`
#'   attributes attached.
#' @keywords internal
#' @noRd
fetch_lio_sf <- function(service_layer, source_name, where = "1=1",
                         simplify = TRUE, result_record_count = 2000,
                         refresh = FALSE) {
  key <- cache_key(
    source_name = source_name,
    service_layer = service_layer,
    where = where,
    simplify = simplify,
    result_record_count = result_record_count
  )
  if (!refresh) {
    cached <- cache_read(key)
    if (!is.null(cached)) {
      return(cached)
    }
  }

  url <- lio_query_url(
    service_layer = service_layer,
    where = where,
    simplify = simplify,
    result_record_count = result_record_count
  )

  resp <- httr2::request(url) |> httr2::req_perform()
  geojson <- httr2::resp_body_string(resp)

  temp_file <- tempfile(fileext = ".geojson")
  on.exit(unlink(temp_file), add = TRUE)
  writeLines(geojson, temp_file)
  sf_obj <- sf::st_read(temp_file, quiet = TRUE)
  sf_obj <- sf::st_make_valid(sf_obj)

  attr(sf_obj, "source_url") <- url
  attr(sf_obj, "source_name") <- source_name
  attr(sf_obj, "retrieved_at") <- Sys.time()

  cache_write(
    key,
    sf_obj,
    meta = list(
      source_name = source_name,
      source_url = url,
      where = where,
      simplify = simplify,
      retrieved_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
    )
  )

  sf_obj
}

#' Guess an identifier column in an sf/data.frame layer
#'
#' @param x An `sf` object or `data.frame`.
#'
#' @return Character scalar: the guessed id column name. Falls back to the
#'   first non-geometry column if no `*ID` column is found.
#' @keywords internal
#' @noRd
generic_lio_fields <- c("OGF_ID", "OBJECTID")

guess_id_col <- function(x) {
  cols <- setdiff(colnames(x), attr(x, "sf_column"))
  candidates <- setdiff(cols, generic_lio_fields)
  id_cols <- candidates[grepl("ID$", candidates, ignore.case = TRUE)]
  if (length(id_cols) > 0) {
    return(id_cols[1])
  }
  id_cols <- cols[grepl("ID$", cols, ignore.case = TRUE)]
  if (length(id_cols) > 0) {
    return(id_cols[1])
  }
  cols[1]
}

#' Guess a name column in an sf/data.frame layer
#'
#' @param x An `sf` object or `data.frame`.
#'
#' @return Character scalar: the guessed name column name. Prefers an
#'   English name column, then any `*NAME*` column, then falls back to the
#'   first non-geometry column.
#' @keywords internal
#' @noRd
guess_name_col <- function(x) {
  cols <- setdiff(colnames(x), attr(x, "sf_column"))
  name_cols <- cols[grepl("NAME", cols, ignore.case = TRUE)]
  if (length(name_cols) == 0) {
    return(cols[1])
  }
  eng_cols <- name_cols[grepl("ENG", name_cols, ignore.case = TRUE)]
  if (length(eng_cols) > 0) {
    return(eng_cols[1])
  }
  name_cols[1]
}

#' Read a provenance attribute, falling back to NA
#'
#' @param x An object with provenance attributes (`source_url`,
#'   `source_name`, `retrieved_at`).
#' @param which Character. Attribute name to read.
#'
#' @return The attribute value, or `NA` if not present.
#' @keywords internal
#' @noRd
provenance_attr <- function(x, which) {
  val <- attr(x, which)
  if (is.null(val)) NA else val
}

#' Load the bundled source registry
#'
#' @return A named list of source metadata, keyed by source id.
#' @keywords internal
#' @noRd
load_source_registry <- function() {
  registry_path <- system.file("extdata", "sources.yaml", package = "ONgeoR")
  if (!nzchar(registry_path)) {
    rlang::abort("Could not locate inst/extdata/sources.yaml in the ONgeoR package.")
  }
  yaml::read_yaml(registry_path)$sources
}
