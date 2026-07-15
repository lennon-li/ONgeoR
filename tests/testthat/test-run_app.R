test_that("run_app is exported and the shiny app directory exists", {
  expect_true(is.function(ONgeoR::run_app))
  app_dir <- system.file("shiny", package = "ONgeoR")
  expect_true(nzchar(app_dir))
  expect_true(file.exists(file.path(app_dir, "app.R")))
})

test_that("inst/shiny/app.R parses without syntax errors", {
  app_path <- system.file("shiny", "app.R", package = "ONgeoR")
  expect_error(parse(app_path), NA)
})
