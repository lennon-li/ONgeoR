#' List available data sources
#'
#' Prints and returns the sources registered in ONgeoR's bundled source
#' registry (`inst/extdata/sources.yaml`).
#'
#' @return A [tibble::tibble()] with columns `source_id`, `name`,
#'   `geography_type`, and `feature_count`.
#'
#' @examples
#' list_sources()
#'
#' @export
list_sources <- function() {
  registry <- load_source_registry()

  tibble::tibble(
    source_id = names(registry),
    name = vapply(registry, function(x) x$name, character(1)),
    geography_type = vapply(registry, function(x) x$geography_type, character(1)),
    feature_count = vapply(registry, function(x) as.integer(x$feature_count), integer(1))
  )
}

#' Get metadata for one data source
#'
#' @param source_id Character. The source identifier, e.g. `"phu_boundaries"`.
#'   See [list_sources()] for available ids.
#'
#' @return A named list of metadata for the requested source: `name`,
#'   `service_layer`, `geography_type`, `feature_count`, `key_fields`,
#'   `license`, and `source_url`.
#'
#' @examples
#' get_source("phu_boundaries")
#'
#' @export
get_source <- function(source_id) {
  registry <- load_source_registry()

  if (!source_id %in% names(registry)) {
    rlang::abort(sprintf(
      "Unknown source_id '%s'. See list_sources() for available ids.",
      source_id
    ))
  }

  registry[[source_id]]
}
