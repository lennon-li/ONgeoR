testthat::skip_if_not_installed("shinytest2")
testthat::skip_on_cran()

chrome <- tryCatch(
  suppressWarnings(chromote::find_chrome()),
  error = function(cnd) NULL
)
if (is.null(chrome) || !nzchar(chrome)) {
  testthat::skip("Chrome is not available to chromote.")
}

# AppDriver launches the app in a child R process, which resolves ONgeoR from
# the installed library, not from devtools::load_all() in this session. Under
# R CMD check (and CI) the package is installed, so the smoke runs there.
if (exists(".__DEVTOOLS__", envir = asNamespace("ONgeoR"))) {
  testthat::skip(
    "browser smoke needs an installed ONgeoR (runs under R CMD check/CI)"
  )
}

test_that("Shiny app boots and exposes its offline workflow controls", {
  app <- shinytest2::AppDriver$new(
    app_dir = dirname(shiny_app_file()),
    name = "app-smoke",
    variant = NULL,
    load_timeout = 30 * 1000
  )
  withr::defer(app$stop())

  navbar <- app$get_html("nav.navbar")
  expect_match(navbar, "Link", fixed = TRUE)
  expect_match(navbar, "Find Nearest", fixed = TRUE)

  expect_match(app$get_html("#base_layer"), "base_layer", fixed = TRUE)
  expect_match(
    app$get_html("#overlay_source"),
    "overlay_source",
    fixed = TRUE
  )
  expect_true(app$get_js(
    "document.querySelector('#build_btn_ui button').disabled"
  ))

  app$click(selector = "a[data-value='Find Nearest']")

  expect_true(app$get_js(
    "document.querySelector(\"a[data-value='Find Nearest']\").classList.contains('active')"
  ))
  expect_match(app$get_html("#points_csv"), "points_csv", fixed = TRUE)
})
