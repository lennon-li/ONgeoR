# Simplify the bundled HIVE grid in place.
#
# WHY: the Shiny app draws HIVE as a map furniture layer, and the full
# resolution grid serialises to a 2.19 MB leaflet widget - large enough to
# matter on every app load. Simplifying at 250 m in EPSG:3161 cuts that to
# 1.46 MB (-33%) while preserving all 1629 cells intact.
#
# WHY 250 m: HIVE cells are ~3.2 km across, so a 250 m tolerance is about 8%
# of cell width and is not visible at the zoom levels this grid is displayed
# at. It matches the tolerance already used for inst/extdata/phu_simple.rds.
# Measured 2026-07-20: 50 m and 100 m give no useful reduction (2.18 / 2.16
# MB); 500 m reaches 1.21 MB but starts to visibly distort cell edges.
#
# THIS REPLACES THE BUNDLED DATA. Unlike phu_boundaries, HIVE has no upstream
# REST service - the bundled file is the only live copy. The full-resolution
# grid remains recoverable from git history:
#   git show <pre-simplification-commit>:inst/extdata/hive.rds > hive_raw.rds
#
# The script is idempotent: it refuses to run against an already-simplified
# file, so re-running cannot compound the tolerance.

library(sf)
devtools::load_all(".")

path <- system.file("extdata", "hive.rds", package = "ONgeoR")
hive <- readRDS(path)

if (!is.null(attr(hive, "ongeor_simplified_m"))) {
  stop(
    "inst/extdata/hive.rds is already simplified at ",
    attr(hive, "ongeor_simplified_m"), " m. Refusing to simplify again; ",
    "restore the raw grid from git history first.",
    call. = FALSE
  )
}

tolerance_m <- 250
keep <- attributes(hive)[c("source_name", "source_url", "retrieved_at")]

simplified <- st_transform(hive, 3161)
simplified <- st_simplify(
  simplified,
  dTolerance = tolerance_m,
  preserveTopology = TRUE
)
simplified <- st_transform(simplified, st_crs(hive))

# st_simplify demotes single-part MULTIPOLYGONs to POLYGON, which would break
# retrieve_hive()'s documented all-MULTIPOLYGON contract (test-hive.R asserts
# it). Cast back so the bundled type is unchanged by simplification.
simplified <- st_cast(simplified, "MULTIPOLYGON")

types <- unique(as.character(st_geometry_type(simplified)))
stopifnot(
  nrow(simplified) == nrow(hive),
  identical(types, "MULTIPOLYGON"),
  !any(st_is_empty(simplified))
)

for (nm in names(keep)) {
  attr(simplified, nm) <- keep[[nm]]
}
attr(simplified, "ongeor_simplified_m") <- tolerance_m

out <- file.path("inst", "extdata", "hive.rds")
saveRDS(simplified, out, compress = "xz")

cat(sprintf(
  "Wrote %s: %d features, %.1f KB, simplified at %d m\n",
  out, nrow(simplified), file.size(out) / 1024, tolerance_m
))
