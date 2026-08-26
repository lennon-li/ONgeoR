test_that("run_app is exported and the shiny app directory exists", {
  expect_true(is.function(ONgeoR::run_app))
  app_dir <- system.file("shiny", package = "ONgeoR")
  if (!nzchar(app_dir)) app_dir <- dirname(shiny_app_file())
  expect_true(file.exists(file.path(app_dir, "app.R")))
})

test_that("inst/shiny/app.R parses without syntax errors", {
  app_path <- system.file("shiny", "app.R", package = "ONgeoR")
  if (!nzchar(app_path)) app_path <- shiny_app_file()
  expect_error(parse(app_path), NA)
})
