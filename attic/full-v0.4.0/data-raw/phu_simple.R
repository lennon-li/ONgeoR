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
#   roughly 200 KB while preserving all 34 PHU features and shared borders.
#   Simplification is performed in EPSG:3161 (Ontario MNR Lambert, metres),
#   then reprojected back to the source CRS.
#
# Run from the package root: source("data-raw/phu_simple.R")

# Load the package so retrieve_phu() is available, and load sf explicitly
# so the geometry operations are available in the script environment.
devtools::load_all(".")

# Retrieve full-resolution PHU boundaries from the live LIO service.
phu <- retrieve_phu(simplify = FALSE)

# Save the source CRS so we can transform back to it after simplification.
source_crs <- sf::st_crs(phu)

# Simplify in a projected CRS (Ontario MNR Lambert, metres) so dTolerance
# is in metres and shared borders remain aligned.
phu_3161 <- sf::st_transform(phu, 3161)
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
  nrow(phu_simple) == 34,
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
