fixture_adjacent_squares <- function() {
  square <- function(x) sf::st_polygon(list(rbind(
    c(x, 0), c(x + 1, 0), c(x + 1, 1), c(x, 1), c(x, 0)
  )))
  list(
    source = fixture_provenance(sf::st_sf(
      SRC_ID = "S1", SRC_NAME = "Source Square",
      geometry = sf::st_sfc(square(0), crs = 3347)
    )),
    target = fixture_provenance(sf::st_sf(
      TGT_ID = "T1", TGT_NAME = "Target Square",
      geometry = sf::st_sfc(square(1), crs = 3347)
    ))
  )
}

fixture_overlapping_squares <- function() {
  square <- function(x) sf::st_polygon(list(rbind(
    c(x, 0), c(x + 1, 0), c(x + 1, 1), c(x, 1), c(x, 0)
  )))
  list(
    source = fixture_provenance(sf::st_sf(
      SRC_ID = c("S1", "S2"),
      SRC_NAME = c("Source A", "Source B"),
      POP = c(100L, 200L),
      geometry = sf::st_sfc(square(0), square(1), crs = 3347)
    )),
    target = fixture_provenance(sf::st_sf(
      TGT_ID = c("T1", "T2", "T3"),
      TGT_NAME = c("Target A", "Target B", "Target C"),
      REGION = c("R1", "R2", "R3"),
      geometry = sf::st_sfc(
        sf::st_polygon(list(rbind(
          c(0, 0), c(1.5, 0), c(1.5, 1), c(0, 1), c(0, 0)
        ))),
        sf::st_polygon(list(rbind(
          c(1.5, 0), c(2, 0), c(2, 1), c(1.5, 1), c(1.5, 0)
        ))),
        sf::st_polygon(list(rbind(
          c(5, 0), c(6, 0), c(6, 1), c(5, 1), c(5, 0)
        ))),
        crs = 3347
      )
    ))
  )
}

test_that("build_intersection emits the documented fixed columns in order", {
  layers <- fixture_overlapping_squares()
  result <- build_intersection(layers$source, layers$target)

  fixed_cols <- c(
    "interaction_id", "target_id", "target_name", "target_source",
    "source_id", "source_name", "source_source", "relation",
    "overlap_area_m2", "share_of_target", "share_of_source",
    "match_distance_km"
  )
  expect_equal(colnames(result)[seq_along(fixed_cols)], fixed_cols)

  tail_cols <- c(
    "source_url_source", "source_url_target", "retrieved_at", "simplify_used"
  )
  n <- ncol(result)
  expect_equal(colnames(result)[(n - 3):n], tail_cols)
})

test_that("build_intersection carries all attributes with src_/tgt_ prefixes", {
  layers <- fixture_overlapping_squares()
  result <- build_intersection(layers$source, layers$target)

  expect_true("src_SRC_ID" %in% colnames(result))
  expect_true("src_SRC_NAME" %in% colnames(result))
  expect_true("src_POP" %in% colnames(result))
  expect_true("tgt_TGT_ID" %in% colnames(result))
  expect_true("tgt_TGT_NAME" %in% colnames(result))
  expect_true("tgt_REGION" %in% colnames(result))

  row_s1 <- result[result$source_id == "S1", ]
  expect_equal(row_s1$src_SRC_NAME[1], "Source A")
  # Carrying attributes through means carrying their types too, including when
  # unmatched targets force an rbind of NA-filled rows onto the matched ones.
  expect_type(row_s1$src_POP, "integer")
  expect_equal(row_s1$src_POP[1], 100L)
  expect_equal(row_s1$tgt_REGION[1], "R1")
})

test_that("build_intersection handles shared column names without overwrite", {
  square <- function(x) sf::st_polygon(list(rbind(
    c(x, 0), c(x + 1, 0), c(x + 1, 1), c(x, 1), c(x, 0)
  )))
  source <- fixture_provenance(sf::st_sf(
    NAME = "Source Name", MUNID = "M1",
    geometry = sf::st_sfc(square(0), crs = 3347)
  ))
  target <- fixture_provenance(sf::st_sf(
    NAME = "Target Name", MUNID = "M2",
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(0, 0), c(2, 0), c(2, 1), c(0, 1), c(0, 0)
    ))), crs = 3347)
  ))

  result <- build_intersection(source, target)

  expect_true("src_NAME" %in% colnames(result))
  expect_true("tgt_NAME" %in% colnames(result))
  expect_true("src_MUNID" %in% colnames(result))
  expect_true("tgt_MUNID" %in% colnames(result))
  expect_equal(result$src_NAME[1], "Source Name")
  expect_equal(result$tgt_NAME[1], "Target Name")
  expect_equal(result$src_MUNID[1], "M1")
  expect_equal(result$tgt_MUNID[1], "M2")
})

test_that("boundary-touching polygons produce no row", {
  layers <- fixture_adjacent_squares()
  result <- build_intersection(layers$source, layers$target)

  matched <- result[!is.na(result$source_id), ]
  expect_equal(nrow(matched), 0)
  expect_equal(nrow(result), 1)
  expect_true(is.na(result$source_id[1]))
  expect_equal(result$target_id[1], "T1")
})

test_that("min_overlap filters pairs below threshold", {
  layers <- fixture_overlapping_squares()
  result_default <- build_intersection(layers$source, layers$target)
  matched_default <- result_default[!is.na(result_default$source_id), ]

  big_area <- max(matched_default$overlap_area_m2) * 0.9
  result_filtered <- build_intersection(
    layers$source, layers$target, min_overlap = big_area
  )
  matched_filtered <- result_filtered[!is.na(result_filtered$source_id), ]

  expect_true(nrow(matched_filtered) < nrow(matched_default))
  expect_true(all(matched_filtered$overlap_area_m2 > big_area))
})

test_that("summarise_by_target returns exactly nrow(target) rows", {
  layers <- fixture_overlapping_squares()
  result <- build_intersection(layers$source, layers$target)
  summary_tbl <- summarise_by_target(result)

  expect_equal(nrow(summary_tbl), nrow(layers$target))
  expect_equal(sort(summary_tbl$target_id), sort(c("T1", "T2", "T3")))

  t3 <- summary_tbl[summary_tbl$target_id == "T3", ]
  expect_equal(t3$n_source, 0L)
  expect_true(is.na(t3$source_ids))
})

test_that("summarise_by_target delimited columns preserve order", {
  layers <- fixture_overlapping_squares()
  result <- build_intersection(layers$source, layers$target)
  summary_tbl <- summarise_by_target(result)

  t1 <- summary_tbl[summary_tbl$target_id == "T1", ]
  expect_equal(t1$n_source, 2L)
  ids <- strsplit(t1$source_ids, "; ")[[1]]
  expect_equal(sort(ids), c("S1", "S2"))
  expect_true(t1$covered_share > 0)
  expect_true(t1$covered_share <= 1 + 1e-6)
})

test_that("interaction_id is unique and stable across runs", {
  layers <- fixture_overlapping_squares()
  r1 <- build_intersection(layers$source, layers$target)
  r2 <- build_intersection(layers$source, layers$target)

  expect_equal(anyDuplicated(r1$interaction_id), 0L)
  expect_equal(r1$interaction_id, r2$interaction_id)
})

test_that("build_nearest_pairs returns one row per target with distance", {
  source_pts <- fixture_provenance(sf::st_as_sf(
    tibble::tibble(src_id = c("A", "B"), x = c(0, 10), y = c(0, 0)),
    coords = c("x", "y"), crs = 3347
  ))
  target_pts <- fixture_provenance(sf::st_as_sf(
    tibble::tibble(
      tgt_id = c("X", "Y", "Z"),
      x = c(1, 9, 20), y = c(0, 0, 0)
    ),
    coords = c("x", "y"), crs = 3347
  ))

  result <- build_nearest_pairs(source_pts, target_pts)

  expect_equal(nrow(result), 3)
  expect_equal(result$relation, rep("nearest", 3))
  expect_true(all(!is.na(result$match_distance_km)))
  expect_true(all(is.na(result$overlap_area_m2)))
  expect_true(all(is.na(result$share_of_target)))
})

test_that("build_nearest_pairs swap detection: row count matches target", {
  source_pts <- fixture_provenance(sf::st_as_sf(
    tibble::tibble(src_id = paste0("S", 1:5), x = 1:5 * 100, y = rep(0, 5)),
    coords = c("x", "y"), crs = 3347
  ))
  target_pts <- fixture_provenance(sf::st_as_sf(
    tibble::tibble(tgt_id = paste0("T", 1:2), x = c(150, 450), y = c(0, 0)),
    coords = c("x", "y"), crs = 3347
  ))

  result <- build_nearest_pairs(source_pts, target_pts)

  # If the swap were backwards, nrow would be 5 (one per source) not 2.
  expect_equal(nrow(result), 2)
  expect_equal(sort(result$target_id), c("T1", "T2"))
})

test_that("build_link dispatches point x point to build_nearest_pairs", {
  pts_a <- fixture_provenance(sf::st_as_sf(
    tibble::tibble(src_id = "A", x = 0, y = 0),
    coords = c("x", "y"), crs = 3347
  ))
  pts_b <- fixture_provenance(sf::st_as_sf(
    tibble::tibble(tgt_id = "B", x = 1, y = 0),
    coords = c("x", "y"), crs = 3347
  ))

  result <- build_link(pts_a, pts_b)
  expect_equal(result$relation, "nearest")
  expect_true(!is.na(result$match_distance_km))
})

test_that("build_link dispatches polygon x polygon to build_intersection", {
  layers <- fixture_overlapping_squares()
  result <- build_link(layers$source, layers$target)

  expect_true("overlap_area_m2" %in% colnames(result))
  expect_true("share_of_target" %in% colnames(result))
  matched <- result[!is.na(result$source_id), ]
  expect_equal(matched$relation[1], "intersects")
})

test_that("build_link dispatches point x polygon to build_crosswalk", {
  poly <- fixture_polygons()
  pts <- fixture_points()

  result <- build_link(pts, poly)
  expect_true("match_method" %in% colnames(result))
  expect_true("from_id" %in% colnames(result))
})

test_that("no output column holds geometry", {
  layers <- fixture_overlapping_squares()
  result <- build_intersection(layers$source, layers$target)

  for (col in colnames(result)) {
    expect_false(
      inherits(result[[col]], "sfc"),
      label = paste("Column", col, "must not be geometry")
    )
  }
  expect_false(inherits(result, "sf"))
})

test_that("property: share_of_target sums to <= 1 per target", {
  layers <- fixture_overlapping_squares()
  result <- build_intersection(layers$source, layers$target)
  matched <- result[!is.na(result$source_id), ]

  sums <- tapply(matched$share_of_target, matched$target_id, sum)
  expect_true(all(sums <= 1 + 1e-6))
})

test_that("property: share_of_source sums to <= 1 per source", {
  layers <- fixture_overlapping_squares()
  result <- build_intersection(layers$source, layers$target)
  matched <- result[!is.na(result$source_id), ]

  sums <- tapply(matched$share_of_source, matched$source_id, sum)
  expect_true(all(sums <= 1 + 1e-6))
})

test_that("build_intersection aborts for non-polygon source", {
  pts <- fixture_points()
  poly <- fixture_polygons()

  expect_error(
    build_intersection(pts, poly),
    class = "ongeor_intersection_source_not_polygon"
  )
})

test_that("build_intersection aborts for non-polygon target", {
  pts <- fixture_points()
  poly <- fixture_polygons()

  expect_error(
    build_intersection(poly, pts),
    class = "ongeor_intersection_target_not_polygon"
  )
})

test_that("link_matrix_df has nine rows and no line geometry", {
  m <- ONgeoR:::link_matrix_df()

  expect_equal(nrow(m), 9)
  expect_equal(
    colnames(m),
    c("source_kind", "target_kind", "mode", "what_it_does", "output")
  )
  expect_false("line" %in% m$source_kind)
  expect_false("line" %in% m$target_kind)
  expect_equal(
    sort(unique(c(m$source_kind, m$target_kind))),
    c("point", "polygon", "raster")
  )
})

test_that("duplicate target ids abort rather than collapsing in the summary", {
  square <- function(x) sf::st_polygon(list(rbind(
    c(x, 0), c(x + 1, 0), c(x + 1, 1), c(x, 1), c(x, 0)
  )))
  source <- fixture_provenance(sf::st_sf(
    SRC_ID = "S1", SRC_NAME = "Source A",
    geometry = sf::st_sfc(square(0), crs = 3347)
  ))
  # Two DISTINCT features sharing one id. Without the guard these collapse to a
  # single summary row and the one-row-per-target guarantee fails silently.
  target <- fixture_provenance(sf::st_sf(
    TGT_ID = c("T1", "T1"), TGT_NAME = c("X", "Y"),
    geometry = sf::st_sfc(square(0), square(2), crs = 3347)
  ))

  expect_error(
    build_intersection(source, target),
    class = "ongeor_duplicate_target_ids"
  )
})

test_that("duplicate source ids abort", {
  square <- function(x) sf::st_polygon(list(rbind(
    c(x, 0), c(x + 1, 0), c(x + 1, 1), c(x, 1), c(x, 0)
  )))
  source <- fixture_provenance(sf::st_sf(
    SRC_ID = c("S1", "S1"), SRC_NAME = c("A", "B"),
    geometry = sf::st_sfc(square(0), square(2), crs = 3347)
  ))
  target <- fixture_provenance(sf::st_sf(
    TGT_ID = "T1", TGT_NAME = "X",
    geometry = sf::st_sfc(square(0), crs = 3347)
  ))

  expect_error(
    build_intersection(source, target),
    class = "ongeor_duplicate_source_ids"
  )
})

test_that("summarise_by_target row count equals target count for unique ids", {
  layers <- fixture_overlapping_squares()
  pairs <- build_intersection(layers$source, layers$target)
  summary_tbl <- summarise_by_target(pairs)

  expect_equal(nrow(summary_tbl), nrow(layers$target))
  expect_false(anyDuplicated(summary_tbl$target_id) > 0)
})

test_that("build_nearest_pairs works when both layers share column names", {
  # Every LIO point layer carries OGF_ID / OBJECTID / *_DATETIME, so shared
  # names are the normal case, not an edge case. Fixtures with disjoint names
  # hid a defect that broke all 30 ordered pairs of registered point sources.
  mk <- function(ids, xs) {
    fixture_provenance(sf::st_as_sf(
      tibble::tibble(
        OGF_ID = ids, OBJECTID = seq_along(ids),
        EFFECTIVE_DATETIME = rep("2026-01-01", length(ids)),
        NAME = paste0("N", ids),
        x = xs, y = rep(0, length(xs))
      ),
      coords = c("x", "y"), crs = 3347
    ))
  }
  source_pts <- mk(c("S1", "S2"), c(0, 100))
  target_pts <- mk(c("T1", "T2", "T3"), c(5, 95, 400))

  result <- build_nearest_pairs(source_pts, target_pts)

  expect_equal(nrow(result), nrow(target_pts))
  expect_true(all(!is.na(result$match_distance_km)))
  # Both sides survive under their own prefixes rather than colliding.
  expect_true(all(c("src_OGF_ID", "tgt_OGF_ID") %in% colnames(result)))
  expect_equal(result$tgt_OGF_ID, c("T1", "T2", "T3"))
  expect_equal(result$src_OGF_ID, c("S1", "S2", "S2"))
})

test_that("nearest() disambiguates shared column names instead of failing", {
  mk <- function(ids, xs) fixture_provenance(sf::st_as_sf(
    tibble::tibble(OGF_ID = ids, NAME = paste0("N", ids),
                   x = xs, y = rep(0, length(xs))),
    coords = c("x", "y"), crs = 3347
  ))
  a <- mk(c("A", "B"), c(0, 10))
  b <- mk(c("C", "D"), c(1, 11))

  expect_message(res <- nearest(a, b), class = "ongeor_nearest_renamed_columns")

  # Source keeps its names; the target copies are suffixed, so both survive.
  expect_true(all(c("OGF_ID", "NAME") %in% colnames(res)))
  expect_true(any(grepl("^OGF_ID\\.", colnames(res))))
  expect_equal(nrow(res), nrow(a))
  expect_true(all(!is.na(res$distance_km)))
})

test_that("simplify_used carries the provenance attribute when present", {
  square <- function(x) sf::st_polygon(list(rbind(
    c(x, 0), c(x + 1, 0), c(x + 1, 1), c(x, 1), c(x, 0)
  )))
  source <- fixture_provenance(sf::st_sf(
    SRC_ID = "S1", SRC_NAME = "Source Square",
    geometry = sf::st_sfc(square(0), crs = 3347)
  ))
  attr(source, "simplify") <- 1e-04
  target <- fixture_provenance(sf::st_sf(
    TGT_ID = "T1", TGT_NAME = "Target Square",
    geometry = sf::st_sfc(square(0), crs = 3347)
  ))

  result <- build_intersection(source, target)

  expect_true(all(!is.na(result$simplify_used)))
  expect_equal(unique(result$simplify_used), 1e-04)
})

test_that("simplify_used is NA without error when the attribute is absent", {
  layers <- fixture_overlapping_squares()

  result <- build_intersection(layers$source, layers$target)

  expect_true(all(is.na(result$simplify_used)))
})

test_that("build_nearest_pairs simplify_used carries the attribute when present", {
  source_pts <- fixture_provenance(sf::st_as_sf(
    tibble::tibble(src_id = c("A", "B"), x = c(0, 10), y = c(0, 0)),
    coords = c("x", "y"), crs = 3347
  ))
  attr(source_pts, "simplify") <- 0
  target_pts <- fixture_provenance(sf::st_as_sf(
    tibble::tibble(
      tgt_id = c("X", "Y", "Z"),
      x = c(1, 9, 20), y = c(0, 0, 0)
    ),
    coords = c("x", "y"), crs = 3347
  ))

  result <- build_nearest_pairs(source_pts, target_pts)

  expect_true(all(!is.na(result$simplify_used)))
  expect_equal(unique(result$simplify_used), 0)
})

test_that("summarise_by_target output is stable across optimization", {
  square <- function(x) sf::st_polygon(list(rbind(
    c(x, 0), c(x + 1, 0), c(x + 1, 1), c(x, 1), c(x, 0)
  )))
  
  source <- fixture_provenance(sf::st_sf(
    SRC_ID = c("S1", "S2", "S3", "S4"),
    SRC_NAME = c("Source A", "Source B", "Source C", "Source D"),
    POP = c(100L, 200L, 300L, 400L),
    geometry = sf::st_sfc(square(0), square(1), square(5), square(6), crs = 3347)
  ))
  
  target <- fixture_provenance(sf::st_sf(
    TGT_ID = c("T1", "T2", "T3"),
    TGT_NAME = c("Target A", "Target B", "Target C"),
    REGION = c("R1", "R2", "R3"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(
        c(0, 0), c(2.5, 0), c(2.5, 1), c(0, 1), c(0, 0)
      ))),
      sf::st_polygon(list(rbind(
        c(5, 0), c(6, 0), c(6, 1), c(5, 1), c(5, 0)
      ))),
      sf::st_polygon(list(rbind(
        c(10, 0), c(11, 0), c(11, 1), c(10, 1), c(10, 0)
      ))),
      crs = 3347
    )
  ))
  
  pairs <- build_intersection(source, target)
  result <- summarise_by_target(pairs)
  
  expect_equal(nrow(result), 3)
  expect_equal(result$target_id, c("T1", "T2", "T3"))
  
  t1 <- result[result$target_id == "T1", ]
  expect_equal(t1$n_source, 2L)
  expect_equal(t1$target_name, "Target A")
  expect_equal(t1$tgt_REGION, "R1")
  expect_true(t1$covered_share > 0)
  
  t2 <- result[result$target_id == "T2", ]
  expect_equal(t2$n_source, 1L)
  expect_equal(t2$source_ids, "S3")
  
  t3 <- result[result$target_id == "T3", ]
  expect_equal(t3$n_source, 0L)
  expect_true(is.na(t3$source_ids))
  expect_equal(t3$covered_share, 0)
})
