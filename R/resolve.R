#' Resolve records from a layer by an identifier or name
#'
#' Attribute lookup (not a spatial operation): given one or more query values,
#' return the matching record(s) from a layer. By default matches an id column
#' exactly or a name column by substring; either can be overridden.
#'
#' @param layer An `sf` object or `data.frame` with attribute columns.
#' @param query A character vector of one or more values to look up.
#' @param by Character. `"ident"` (default) uses the layer's id column with
#'   exact matching; `"name"` uses the name column with substring matching.
#'   The columns are auto-detected. Ignored when `column` is supplied.
#' @param column Character or `NULL`. Overrides the column to match against.
#' @param match Character or `NULL`. `"exact"` or `"substring"`. If `NULL`
#'   (default), derived from `by` (`ident` -> exact, `name` -> substring).
#'
#' @return A [tibble::tibble()] with a `query` column, the layer's non-geometry
#'   columns for matches, and `source_url` / `retrieved_at` provenance. A query
#'   with no match yields one row with `NA` data columns; a single combined
#'   warning lists all unmatched query values.
#'
#' @examples
#' if (interactive()) {
#'   airports <- retrieve_airport()
#'   resolve(airports, "CYYZ")
#'   resolve(airports, "toronto", by = "name")
#' }
#'
#' @export
resolve <- function(layer, query,
                    by = c("ident", "name"), column = NULL, match = NULL) {
  by <- match.arg(by)

  if (!is.character(query)) {
    rlang::abort("`query` must be a character vector.")
  }

  layer_data <- if (inherits(layer, "sf")) {
    tibble::as_tibble(sf::st_drop_geometry(layer))
  } else {
    tibble::as_tibble(layer)
  }

  if (is.null(column)) {
    column <- if (by == "ident") guess_id_col(layer) else guess_name_col(layer)
  }
  if (is.null(match)) {
    match <- if (by == "name") "substring" else "exact"
  }
  match <- rlang::arg_match(match, c("exact", "substring"))

  if (!column %in% colnames(layer_data)) {
    rlang::abort(sprintf("column `%s` not found in `layer`.", column))
  }

  values <- as.character(layer_data[[column]])
  unmatched <- character()

  results <- lapply(query, function(q) {
    if (is.na(q)) {
      matches <- integer()
    } else if (match == "exact") {
      matches <- which(!is.na(values) & tolower(values) == tolower(q))
    } else {
      matches <- which(grepl(q, values, ignore.case = TRUE))
    }

    if (length(matches) == 0) {
      unmatched <<- c(unmatched, q)
      matched <- layer_data[NA_integer_, , drop = FALSE]
    } else {
      matched <- layer_data[matches, , drop = FALSE]
    }
    tibble::add_column(matched, query = rep(q, nrow(matched)), .before = 1)
  })

  if (length(results) == 0) {
    result <- tibble::add_column(
      layer_data[0, , drop = FALSE], query = character(), .before = 1
    )
  } else {
    result <- do.call(rbind, results)
  }

  result$source_url <- provenance_attr(layer, "source_url")
  result$retrieved_at <- provenance_attr(layer, "retrieved_at")

  if (length(unmatched) > 0) {
    rlang::warn(
      paste0("resolve(): no match found for: ", paste(unmatched, collapse = ", "))
    )
  }

  result
}
