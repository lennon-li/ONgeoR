# data-raw/hive.R
#
# Reproducible prep script for the built-in HIVE Grid dataset.
#
# Source: data/HIVE.zip (gitignored, not distributed with the package).
# That archive contains two things:
#   1. Level123_Merged_Clippedto16ADA.* -- a custom HIVE polygon shapefile
#      (Levels 1-3 hierarchical grid), which THIS script turns into the
#      built-in dataset at inst/extdata/hive.rds.
#   2. PCCF_ON_Nov2019_wHIVE_060920.xlsx -- a LICENSED Statistics Canada
#      Postal Code Conversion File. This script must NEVER extract, read,
#      reference, or copy that file anywhere. Only the shapefile members
#      are extracted below, into a tempdir that is removed when the script
#      finishes.
#
# Run from the package root: source("data-raw/hive.R")

library(sf)

zip_path <- "data/HIVE.zip"
shapefile_stem <- "Level123_Merged_Clippedto16ADA"
shapefile_members <- paste0(
  shapefile_stem,
  c(".shp", ".shx", ".dbf", ".prj", ".cpg")
)

extract_dir <- file.path(tempdir(), "ongeor_hive_extract")
dir.create(extract_dir, recursive = TRUE, showWarnings = FALSE)

# Extract ONLY the shapefile members -- never the .xlsx (PCCF, licensed).
unzip(zip_path, files = shapefile_members, exdir = extract_dir)

hive_raw <- sf::st_read(
  file.path(extract_dir, paste0(shapefile_stem, ".shp")),
  quiet = TRUE
)

# Clean up the extracted shapefile members immediately -- nothing from the
# source zip should linger on disk longer than needed to read it.
unlink(extract_dir, recursive = TRUE)

# Simplify in the native projected (meter) CRS -- Canada Albers Equal Area
# Conic. 100m tolerance verified to preserve all 1629 features with no
# empty geometries, at a final size of ~0.59MB.
hive_simplified <- sf::st_simplify(
  hive_raw,
  dTolerance = 100,
  preserveTopology = TRUE
)

# THEN reproject to WGS84 -- leaflet/interactive mapping needs EPSG:4326.
hive <- sf::st_transform(hive_simplified, 4326)

# Simplification occasionally collapses a MULTIPOLYGON feature down to a
# single-ring POLYGON. Cast back to a uniform MULTIPOLYGON geometry column
# so downstream consumers (leaflet, sf ops) see one consistent type.
hive <- sf::st_cast(hive, "MULTIPOLYGON")

# Keep only the stable identifier columns. Shape_Leng / Shape_Area are
# stale Albers-CRS metrics after reprojection and are dropped.
hive <- hive[, c("GRID_ID", "Level", "HIVE_ID")]

# Provenance attributes, read by the package's provenance_attr() helper.
# HIVE is a static, author-maintained dataset, so retrieved_at is fixed to
# the source shapefile's own creation date rather than Sys.time(), keeping
# the built-in dataset byte-for-byte reproducible across builds.
attr(hive, "source_name") <- "HIVE Grid (Levels 1-3)"
attr(hive, "source_url") <- "builtin://ongeor/hive"
attr(hive, "retrieved_at") <- as.POSIXct("2020-05-25", tz = "UTC")

stopifnot(
  nrow(hive) == 1629,
  all(!sf::st_is_empty(hive)),
  all(as.character(sf::st_geometry_type(hive)) == "MULTIPOLYGON"),
  sf::st_crs(hive)$epsg == 4326
)

saveRDS(hive, "inst/extdata/hive.rds", compress = "xz")

message(sprintf(
  "Wrote inst/extdata/hive.rds: %d features, %.2f MB",
  nrow(hive),
  file.size("inst/extdata/hive.rds") / 1024^2
))
