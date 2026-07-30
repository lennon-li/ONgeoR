#' Launch the ONgeoR Shiny app
#'
#' Launches a thin Shiny UI over the package: pick sources, build a
#' crosswalk, view the map and table, and download `mapping.csv`,
#' `map.html`, and `reproduce.R`. A second tab finds the nearest targets
#' to an uploaded set of points.
#'
#' @param ... Passed to [shiny::runApp()].
#'
#' @return Called for its side effect (launches the Shiny app). Invisibly
#'   returns `NULL`.
#'
#' @examples
#' if (interactive()) {
#'   run_app()
#' }
#'
#' @export
run_app <- function(...) {
  rlang::check_installed(
    c("shiny", "bslib", "DT", "promises", "future"),
    reason = "to run the ONgeoR Shiny app."
  )
  app_dir <- system.file("shiny", package = "ONgeoR")
  if (!nzchar(app_dir)) {
    rlang::abort("Could not find the ONgeoR Shiny app directory. Try re-installing the package.")
  }
  shiny::runApp(app_dir, ...)
}
