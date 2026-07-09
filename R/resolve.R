#' Resolve airport records from an identifier or name
#'
#' Looks up one or more airport records from the airport layer returned by
#' [retrieve_airport()]. Identifier lookups match `AIRPORT_IDENT` exactly,
#' ignoring case. Name lookups match `NAME` by case-insensitive substring.
#'
#' @param query A character vector of one or more values to look up.
#' @param by Character. Either `"ident"` to match `AIRPORT_IDENT` exactly,
#'   ignoring case, or `"name"` to match `NAME` by case-insensitive substring.
#'   Defaults to `"ident"`.
#' @param airports An `sf` object of airport boundaries, as returned by
#'   [retrieve_airport()]. If `NULL` (the default), airport boundaries are
#'   retrieved automatically.
#'
#' @return A [tibble::tibble()] with a `query` column, all matching airport
#'   attribute columns, and `source_url` / `retrieved_at` provenance columns.
#'   Query values with no match return one row with `NA` airport attributes.
#'
#' @examples
#' if (interactive()) {
#'   airport <- resolve_airport("CYYZ")
#'   toronto_airports <- resolve_airport("toronto", by = "name")
#' }
#'
#' @export
resolve_airport <- function(query, by = c("ident", "name"), airports = NULL) {
  by <- match.arg(by)

  if (!is.character(query)) {
    rlang::abort("`query` must be a character vector.")
  }

  if (is.null(airports)) {
    airports <- retrieve_airport()
  }

  airport_data <- tibble::as_tibble(sf::st_drop_geometry(airports))
  unmatched <- character()

  results <- lapply(query, function(q) {
    if (by == "ident") {
      q_lower <- tolower(q)
      matches <- which(
        !is.na(q_lower) &
          !is.na(airport_data$AIRPORT_IDENT) &
          tolower(airport_data$AIRPORT_IDENT) == q_lower
      )
    } else {
      matches <- integer()
      if (!is.na(q)) {
        matches <- which(grepl(q, airport_data$NAME, ignore.case = TRUE, fixed = FALSE))
      }
    }

    if (length(matches) == 0) {
      unmatched <<- c(unmatched, q)
      matched <- airport_data[NA_integer_, , drop = FALSE]
    } else {
      matched <- airport_data[matches, , drop = FALSE]
    }

    tibble::add_column(matched, query = rep(q, nrow(matched)), .before = 1)
  })

  if (length(results) == 0) {
    result <- tibble::add_column(airport_data[0, , drop = FALSE], query = character(), .before = 1)
  } else {
    result <- do.call(rbind, results)
  }

  result$source_url <- attr(airports, "source_url")
  result$retrieved_at <- attr(airports, "retrieved_at")

  if (length(unmatched) > 0) {
    rlang::warn(
      paste0("resolve_airport(): no match found for: ", paste(unmatched, collapse = ", "))
    )
  }

  result
}
