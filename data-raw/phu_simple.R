# data-raw/phu_simple.R
#
# Reproducible prep script for the built-in simplified Public Health Unit
# boundary layer (inst/extdata/phu_simple.rds).
#
# Source: Ontario Public Health Unit boundaries, distributed under the
# Open Government Licence - Ontario via the Land Information Ontario (LIO)
# Open Data REST service.
#
# Why 250 m?
#   The simplified layer is drawn as an always-on reference outline in the
#   Shiny app at Ontario-wide zoom levels.  At that scale a 250 m tolerance
#   is visually indistinguishable from the full-resolution boundary.
#   The unsimplified PHU layer is about 2.5 MB, which is too large for the
#   CRAN package-size budget.  A 250 m simplification yields a file of
#   roughly 200 KB while preserving all 29 post-2025 PHU features and shared
#   borders. Ontario amalgamated PHUs in 2025 (34 -> 29); the pre-2025
#   34-feature snapshot is retained at inst/extdata/phu_simple_pre2025.rds.
#   Simplification is performed in EPSG:3161 (Ontario MNR Lambert, metres),
#   then reprojected back to the source CRS.
#
# Run from the package root: source("data-raw/phu_simple.R")

# Load the package so retrieve_phu() is available, and load sf explicitly
# so the geometry operations are available in the script environment.
devtools::load_all(".")

# Retrieve PHU boundaries from the live LIO service.
#
# refresh = TRUE is load-bearing, not defensive. Cache entries never expire
# (max_age defaults to NULL), so a warm cache can hold a pre-2025 34-feature
# response indefinitely -- exactly what happened on 2026-08-06, when this
# script silently rebuilt from a 2026-07-18 cache entry and tripped the
# feature-count assertion below. A snapshot build must always go to the wire.
#
# simplify = TRUE (server-side generalization) rather than FALSE. The
# full-resolution request is roughly 400 KB per feature, and asking for all
# 29 in one page now returns HTTP 504 from the service -- measured 2026-08-06,
# two minutes to fail. Since the product of this script is a 250 m simplified
# reference outline either way, requesting generalized geometry costs nothing
# visible and makes the build reproducible instead of dependent on a gateway
# timeout. The 250 m pass below still runs, so output resolution is unchanged.
phu <- retrieve_phu(simplify = TRUE, refresh = TRUE)

# Save the source CRS so we can transform back to it after simplification.
source_crs <- sf::st_crs(phu)

# Work in a projected CRS (Ontario MNR Lambert, metres) so both the area
# threshold and dTolerance are in metres and shared borders stay aligned.
phu_3161 <- sf::st_transform(phu, 3161)

# Drop sub-visible island parts BEFORE simplifying.
#
# Why: the post-2025 layer arrives as 37,061 separate polygon parts across 29
# features -- Ontario's lakes and islands. st_simplify(preserveTopology = TRUE)
# enforces a minimum ring per part, so part count, not vertex density, sets the
# floor: 250 m yields 173k vertices and 500 m only 163k. No tolerance escapes it.
# Dropping parts below 1 km2 leaves 320 parts / ~20.5k vertices, matching the
# 20,290 vertices the pre-2025 layer has always shipped. At the Ontario-wide
# zoom this layer is drawn at, a sub-1-km2 island is smaller than a pixel.
#
# This is a REFERENCE OUTLINE only (retrieve_phu_simple(), the app's furniture).
# Analysis must use retrieve_phu(), which is untouched by this script.
min_part_area_m2 <- 1e6

parts <- suppressWarnings(sf::st_cast(sf::st_cast(phu_3161, "MULTIPOLYGON"), "POLYGON"))
# st_cast repeats each source row's attributes across its parts; recover the
# originating row index so attributes are carried, not aggregated away.
row_index <- rep(seq_len(nrow(phu_3161)), vapply(sf::st_geometry(phu_3161), length, integer(1)))
keep <- as.numeric(sf::st_area(parts)) >= min_part_area_m2

geom <- sf::st_sfc(lapply(seq_len(nrow(phu_3161)), function(i) {
  sel <- which(row_index == i & keep)
  # Never let a feature vanish: if every part is below threshold, keep its
  # largest one so all 29 PHUs survive.
  if (length(sel) == 0) sel <- which(row_index == i)[which.max(
    as.numeric(sf::st_area(parts[which(row_index == i), ]))
  )]
  sf::st_cast(sf::st_combine(sf::st_geometry(parts)[sel]), "MULTIPOLYGON")[[1]]
}), crs = sf::st_crs(phu_3161))

phu_3161 <- sf::st_set_geometry(phu_3161, geom)

phu_3161_simplified <- sf::st_simplify(
  phu_3161,
  dTolerance = 250,
  preserveTopology = TRUE
)

# Return to the original CRS used by retrieve_phu().
phu_simple <- sf::st_transform(phu_3161_simplified, source_crs)

# Simplification can occasionally collapse a MULTIPOLYGON to a single POLYGON
# or alter geometry type mix.  Cast to a uniform MULTIPOLYGON column so the
# layer is predictable for downstream mapping code.
phu_simple <- sf::st_cast(phu_simple, "MULTIPOLYGON")

# Preserve the same provenance attributes as the full-resolution source.
attr(phu_simple, "source_name") <- attr(phu, "source_name")
attr(phu_simple, "source_url") <- attr(phu, "source_url")
attr(phu_simple, "retrieved_at") <- attr(phu, "retrieved_at")

# Verify the simplified layer is fit for use before writing it out.
stopifnot(
  nrow(phu_simple) == 29,
  all(!sf::st_is_empty(phu_simple)),
  all(as.character(sf::st_geometry_type(phu_simple)) == "MULTIPOLYGON"),
  sf::st_crs(phu_simple) == source_crs
)

saveRDS(phu_simple, "inst/extdata/phu_simple.rds", compress = "xz")

message(sprintf(
  "Wrote inst/extdata/phu_simple.rds: %d features, %.2f KB",
  nrow(phu_simple),
  file.size("inst/extdata/phu_simple.rds") / 1024
))
