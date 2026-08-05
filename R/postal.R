opcc_m5_url <- paste0(
  "https://raw.githubusercontent.com/lennon-li/OPCC/",
  "4b8fb74f04a27d31b8601e94a00de98d6a7281c6/releases/m5/2026-07-20/",
  "opcc_m5_da_correspondence.csv.gz"
)
opcc_m5_expected_sha256 <-
  "b0d7d79942634d2ba634761ccf10b9cea4e6d4256f1ff41d54d4a6cc20765068"
opcc_m5_cache_key <- "opcc-m5-da__4b8fb74f"

postal_cache_meta <- function(retrieved_at = format(Sys.time(), tz = "UTC")) {
  list(
    source_name = "OPCC M5 DA correspondence",
    source_url = opcc_m5_url,
    retrieved_at = retrieved_at,
    artifact_sha256 = opcc_m5_expected_sha256
  )
}

opcc_m5_sha256 <- function(raw) {
  path <- tempfile(fileext = ".csv.gz")
  on.exit(unlink(path), add = TRUE)
  writeBin(raw, path)
  unname(tools::sha256sum(path))
}

opcc_m5_verify_checksum <- function(raw) {
  actual <- opcc_m5_sha256(raw)
  if (!identical(actual, opcc_m5_expected_sha256)) {
    abort_lio_retrieval(sprintf(
      paste0(
        "Could not verify the OPCC M5 DA correspondence artifact: expected ",
        "SHA-256 %s but downloaded SHA-256 %s."
      ),
      opcc_m5_expected_sha256,
      actual
    ))
  }
  invisible(raw)
}

opcc_m5_download_gzip <- function() {
  tryCatch(
    httr2::request(opcc_m5_url) |>
      httr2::req_perform() |>
      httr2::resp_body_raw(),
    error = function(cnd) {
      abort_lio_retrieval(
        "Could not retrieve the OPCC M5 DA correspondence artifact.",
        parent = cnd
      )
    }
  )
}

opcc_m5_parse_gzip <- function(raw) {
  path <- tempfile(fileext = ".csv.gz")
  on.exit(unlink(path), add = TRUE)
  writeBin(raw, path)
  data <- utils::read.csv(
    gzfile(path),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  tibble::tibble(
    postal_code = as.character(data$postal_code),
    DAUID = as.character(data$DAUID),
    allocation_weight = as.numeric(data$allocation_weight),
    n_contributing_dbs = as.integer(data$n_contributing_dbs),
    census_vintage = as.character(data$census_vintages),
    best_link = as.logical(data$best_link)
  )
}

opcc_m5_correspondence <- function() {
  cached <- cache_read(opcc_m5_cache_key)
  meta <- cache_read_meta(opcc_m5_cache_key)
  if (!is.null(cached)) {
    return(list(data = cached, meta = meta %||% postal_cache_meta()))
  }

  raw <- opcc_m5_download_gzip()
  opcc_m5_verify_checksum(raw)
  data <- opcc_m5_parse_gzip(raw)
  meta <- postal_cache_meta()
  cache_write(opcc_m5_cache_key, data, meta)

  list(data = data, meta = meta)
}

opcc_m1_url <- paste0(
  "https://raw.githubusercontent.com/lennon-li/OPCC/",
  "b334a920a92b0b73d6b91a03e5dd3d68c9c709fa/releases/m1/",
  "2026-06-26-nar-geonames-centroids/opcc_m1_centroids.csv.gz"
)
opcc_m1_expected_sha256 <-
  "79b6eaf29480a5f151c307a5a103174c072f99701c3247661f001d9ffd338b62"
opcc_m1_cache_key <- "opcc-m1-centroids__b334a920"

opcc_m1_cache_meta <- function(retrieved_at = format(Sys.time(), tz = "UTC")) {
  list(
    source_name = "OPCC M1 postal centroids",
    source_url = opcc_m1_url,
    retrieved_at = retrieved_at,
    artifact_sha256 = opcc_m1_expected_sha256
  )
}

opcc_m1_sha256 <- function(raw) {
  path <- tempfile(fileext = ".csv.gz")
  on.exit(unlink(path), add = TRUE)
  writeBin(raw, path)
  unname(tools::sha256sum(path))
}

opcc_m1_verify_checksum <- function(raw) {
  actual <- opcc_m1_sha256(raw)
  if (!identical(actual, opcc_m1_expected_sha256)) {
    abort_lio_retrieval(sprintf(
      paste0(
        "Could not verify the OPCC M1 centroid artifact: expected ",
        "SHA-256 %s but downloaded SHA-256 %s."
      ),
      opcc_m1_expected_sha256,
      actual
    ))
  }
  invisible(raw)
}

opcc_m1_download_gzip <- function() {
  tryCatch(
    httr2::request(opcc_m1_url) |>
      httr2::req_perform() |>
      httr2::resp_body_raw(),
    error = function(cnd) {
      abort_lio_retrieval(
        "Could not retrieve the OPCC M1 centroid artifact.",
        parent = cnd
      )
    }
  )
}

opcc_m1_parse_gzip <- function(raw) {
  path <- tempfile(fileext = ".csv.gz")
  on.exit(unlink(path), add = TRUE)
  writeBin(raw, path)
  data <- utils::read.csv(
    gzfile(path),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  tibble::tibble(
    postal_code = as.character(data$postal_code),
    latitude = as.numeric(data$latitude),
    longitude = as.numeric(data$longitude),
    point_source = as.character(data$point_source),
    point_method = as.character(data$point_method)
  )
}

opcc_m1_centroids <- function() {
  cached <- cache_read(opcc_m1_cache_key)
  meta <- cache_read_meta(opcc_m1_cache_key)
  if (!is.null(cached)) {
    return(list(data = cached, meta = meta %||% opcc_m1_cache_meta()))
  }

  raw <- opcc_m1_download_gzip()
  opcc_m1_verify_checksum(raw)
  data <- opcc_m1_parse_gzip(raw)
  meta <- opcc_m1_cache_meta()
  cache_write(opcc_m1_cache_key, data, meta)

  list(data = data, meta = meta)
}

#' Normalize postal codes to the correspondence's own format
#'
#' Uppercases, strips whitespace, and re-inserts a single space in the middle
#' of a six-character code, producing the `"A1A 1A1"` form that
#' [resolve_postal()] reports in its `postal_code` column. Use it to build a
#' join key on your own records: joining on the column as typed silently drops
#' every code that was not already in that exact form.
#'
#' @param x Character vector of postal codes.
#'
#' @return A character vector the same length as `x`.
#'
#' @examples
#' normalize_postal_code(c("m5v3a8", "M5V 3A8", " m5v 3a8 "))
#'
#' @export
normalize_postal_code <- function(x) {
  compact <- toupper(gsub("[[:space:]]", "", x))
  valid_length <- !is.na(compact) & nchar(compact) == 6L
  compact[valid_length] <- paste0(
    substr(compact[valid_length], 1L, 3L), " ",
    substr(compact[valid_length], 4L, 6L)
  )
  compact
}

postal_result_template <- function() {
  tibble::tibble(
    postal_code = character(),
    DAUID = character(),
    allocation_weight = numeric(),
    n_contributing_dbs = integer(),
    census_vintage = character(),
    source_url = character(),
    retrieved_at = character()
  )
}

#' Resolve Ontario postal codes to dissemination areas
#'
#' Downloads and verifies the immutable OPCC M5 postal-code to dissemination
#' area correspondence, then caches the parsed table locally. Postal codes are
#' matched after uppercasing and normalizing whitespace.
#'
#' @param x Character vector of Ontario postal codes.
#' @param all_links Logical scalar. If `FALSE` (default), return the one
#'   best link for each postal code. If `TRUE`, return every dissemination-area
#'   link.
#'
#' @return A [tibble::tibble()] with postal-code links, source URL, and
#'   retrieval time. An unmatched postal code yields one row with `NA` data
#'   columns; a single combined warning lists all unmatched postal codes.
#'
#' @section Coverage:
#' The correspondence covers 282,409 Ontario postal codes across 529 forward
#' sortation areas, and is derived by rolling dissemination blocks up to
#' dissemination areas (2021 census vintage). Postal codes with no residential
#' dissemination block behind them are therefore absent - notably large-volume
#' receiver codes assigned to a single building, such as much of the federal
#' `K1A` range. An absent code is reported as an unmatched value, not an error.
#'
#' About 7.8 percent of postal codes span more than one dissemination area. For
#' those, the default single row is the highest-weight link, and
#' `allocation_weight` is returned so the caller can see how much of the postal
#' code it represents; that share is below one half for roughly 1,850 codes.
#' Use `all_links = TRUE` when apportioning a quantity rather than labelling a
#' record.
#'
#' @examples
#' \dontrun{
#' resolve_postal(c("K1A0B1", "M5V 3A8"))
#' }
#'
#' @export
resolve_postal <- function(x, all_links = FALSE) {
  if (!is.character(x)) {
    rlang::abort("`x` must be a character vector.")
  }
  if (!is.logical(all_links) || length(all_links) != 1L || is.na(all_links)) {
    rlang::abort("`all_links` must be a single non-missing logical value.")
  }

  correspondence <- opcc_m5_correspondence()
  data <- correspondence$data
  meta <- correspondence$meta
  source_url <- meta$source_url %||% opcc_m5_url
  retrieved_at <- meta$retrieved_at %||% NA_character_
  postal_codes <- normalize_postal_code(x)
  unmatched <- character()

  results <- lapply(postal_codes, function(postal_code) {
    matches <- which(data$postal_code == postal_code)
    if (!all_links) {
      matches <- matches[data$best_link[matches]]
    }

    if (length(matches) == 0L) {
      unmatched <<- c(unmatched, postal_code)
      result <- postal_result_template()[NA_integer_, , drop = FALSE]
      result$postal_code <- postal_code
    } else {
      result <- data[matches, c(
        "postal_code", "DAUID", "allocation_weight", "n_contributing_dbs",
        "census_vintage"
      )]
    }
    result$source_url <- source_url
    result$retrieved_at <- retrieved_at
    result
  })

  result <- if (length(results) == 0L) {
    postal_result_template()
  } else {
    do.call(rbind, results)
  }

  if (length(unmatched) > 0L) {
    rlang::warn(paste0(
      "resolve_postal(): no match found for: ",
      paste(unmatched, collapse = ", ")
    ))
  }

  result
}

postal_point_result_template <- function() {
  tibble::tibble(
    postal_code = character(),
    latitude = numeric(),
    longitude = numeric(),
    point_source = character(),
    point_method = character(),
    source_url = character(),
    retrieved_at = character()
  )
}

postal_points_as_sf <- function(result) {
  keep <- !is.na(result$latitude) & !is.na(result$longitude)
  dropped <- sum(!keep)
  result <- result[keep, , drop = FALSE]

  if (dropped > 0L) {
    rlang::warn(sprintf(
      paste0(
        "resolve_postal_points(): dropped %d row%s without coordinates ",
        "(unmatched postal codes and point_source \"none\")."
      ),
      dropped,
      if (dropped == 1L) "" else "s"
    ))
  }

  if (nrow(result) == 0L) {
    return(sf::st_sf(result, geometry = sf::st_sfc(crs = 4326)))
  }

  sf::st_as_sf(result, coords = c("longitude", "latitude"), crs = 4326)
}

#' Resolve Ontario postal codes to point coordinates
#'
#' Downloads and verifies the immutable OPCC M1 postal-code centroid release,
#' then caches the parsed table locally. Postal codes are matched after
#' uppercasing and normalizing whitespace.
#'
#' @param x Character vector of Ontario postal codes.
#' @param as_sf Logical scalar. If `FALSE` (default), return a tibble. If
#'   `TRUE`, return an `sf` POINT layer in EPSG:4326.
#'
#' @return With `as_sf = FALSE`, a [tibble::tibble()] with one row per input
#'   element, in input order: postal code, coordinates, point provenance,
#'   source URL, and retrieval time. With `as_sf = TRUE`, an `sf` POINT layer
#'   in EPSG:4326 containing only the rows with coordinates. An unmatched
#'   postal code, or a matched code whose `point_source` is `"none"`, yields
#'   one row with `NA` coordinates; a single combined warning lists all
#'   unmatched postal codes.
#'
#' @section Coverage:
#' The release covers 299,796 Ontario postal codes: 282,409 matched by
#' `nar_centroid` (address-derived coordinates), 17,373 by `geonames`
#' (place-level coordinates, coarser), and 14 reported as `none`, which have
#' no coordinates and are returned as `NA`.
#'
#' @examples
#' \dontrun{
#' resolve_postal_points(c("K1A0B1", "M5V 3A8"))
#' resolve_postal_points("M5V 3A8", as_sf = TRUE)
#' }
#'
#' @export
resolve_postal_points <- function(x, as_sf = FALSE) {
  if (!is.character(x)) {
    rlang::abort("`x` must be a character vector.")
  }
  if (!is.logical(as_sf) || length(as_sf) != 1L || is.na(as_sf)) {
    rlang::abort("`as_sf` must be a single non-missing logical value.")
  }

  centroids <- opcc_m1_centroids()
  data <- centroids$data
  meta <- centroids$meta
  source_url <- meta$source_url %||% opcc_m1_url
  retrieved_at <- meta$retrieved_at %||% NA_character_
  postal_codes <- normalize_postal_code(x)
  unmatched <- character()

  results <- lapply(postal_codes, function(postal_code) {
    row <- match(postal_code, data$postal_code)

    if (is.na(row)) {
      unmatched <<- c(unmatched, postal_code)
      result <- postal_point_result_template()[NA_integer_, , drop = FALSE]
      result$postal_code <- postal_code
    } else {
      result <- data[row, c(
        "postal_code", "latitude", "longitude", "point_source", "point_method"
      )]
    }
    result$source_url <- source_url
    result$retrieved_at <- retrieved_at
    result
  })

  result <- if (length(results) == 0L) {
    postal_point_result_template()
  } else {
    do.call(rbind, results)
  }

  if (length(unmatched) > 0L) {
    rlang::warn(paste0(
      "resolve_postal_points(): no match found for: ",
      paste(unmatched, collapse = ", ")
    ))
  }

  if (as_sf) {
    return(postal_points_as_sf(result))
  }

  result
}
