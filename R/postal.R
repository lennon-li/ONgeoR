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
