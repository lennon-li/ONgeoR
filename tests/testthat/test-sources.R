test_that("the PHU registry advertises current and pre-2025 boundaries", {
  sources <- list_sources()
  pre2025_row <- sources[sources$source_id == "phu_boundaries_pre2025", ]
  current_row <- sources[sources$source_id == "phu_boundaries", ]

  expect_equal(nrow(pre2025_row), 1L)
  expect_equal(unname(pre2025_row$geography_type), "boundary")
  expect_equal(unname(current_row$feature_count), 29L)
})
