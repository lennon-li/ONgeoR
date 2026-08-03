# Repair invalid geometries in the bundled HIVE grid.
#
# Found 2026-08-03: 8 of 1629 cells pass sf::st_is_valid() under s2 but are
# invalid under planar GEOS - one "Hole lies outside shell" (G-6) and seven
# "Nested shells" (A-5, AZ-63, BI-61, BM-58, BY-47, SD-359, KD-324),
# artifacts of the hierarchical aggregation. They make build_intersection()
# abort with TopologyException on Level 1/2 cells once the layer is
# transformed to a planar CRS (see TODO.md item 4).
#
# Repair is surgical: only the invalid cells are touched, with planar GEOS
# MakeValid in EPSG:3347 (the CRS build_intersection() uses), keeping only
# polygonal parts. Every other cell is left byte-identical. A previous
# attempt routed the whole layer through lio_make_valid() and moved every
# vertex by up to ~2 degrees via its s2 rebuild pass - do not route the
# grid through s2-based rebuilds.
#
# THIS REPLACES THE BUNDLED DATA. The pre-repair grid remains recoverable
# from git history:
#   git show <pre-repair-commit>:inst/extdata/hive.rds > hive_pre_repair.rds

devtools::load_all(".")
library(sf)

path <- file.path("inst", "extdata", "hive.rds")
hive <- readRDS(path)
stopifnot(inherits(hive, "sf"), nrow(hive) == 1629)

keep <- attributes(hive)[c(
  "source_name", "source_url", "retrieved_at", "ongeor_simplified_m"
)]

geom3347 <- st_transform(st_geometry(hive), 3347)
sf_use_s2(FALSE)
bad <- which(!st_is_valid(geom3347))
sf_use_s2(TRUE)
cat("invalid cells before repair:", length(bad), "->",
    paste(hive$GRID_ID[bad], collapse = ", "), "\n")
stopifnot(length(bad) > 0)

areas_before <- suppressMessages({
  sf_use_s2(FALSE); a <- as.numeric(st_area(geom3347)); sf_use_s2(TRUE); a
})

new_geom <- st_geometry(hive)
for (k in bad) {
  fixed <- st_make_valid(geom3347[k])
  parts <- st_collection_extract(st_sfc(fixed), "POLYGON")
  if (length(parts) == 0) {
    stop("repair lost all polygonal area for cell ", hive$GRID_ID[k],
         call. = FALSE)
  }
  combined <- st_cast(st_combine(parts), "MULTIPOLYGON")
  new_geom[k] <- st_transform(st_sfc(combined, crs = 3347), st_crs(hive))
}
st_geometry(hive) <- new_geom

geom3347_after <- st_transform(st_geometry(hive), 3347)
sf_use_s2(FALSE)
valid3347 <- st_is_valid(geom3347_after)
valid4326 <- st_is_valid(st_geometry(hive))
sf_use_s2(TRUE)
valid_s2 <- st_is_valid(st_geometry(hive))
stopifnot(all(valid3347), all(valid4326), all(valid_s2))

areas_after <- suppressMessages({
  sf_use_s2(FALSE); a <- as.numeric(st_area(geom3347_after)); sf_use_s2(TRUE); a
})
rel <- abs(areas_after - areas_before) / areas_before
cat("repaired cells, area change:\n")
for (k in bad) {
  cat("  ", hive$GRID_ID[k], hive$Level[k], "rel:",
      signif(rel[k], 4), "\n")
}
stopifnot(
  identical(nrow(hive), 1629L),
  !any(st_is_empty(hive)),
  all(as.character(st_geometry_type(hive)) == "MULTIPOLYGON")
)

for (nm in names(keep)) {
  if (!is.null(keep[[nm]])) attr(hive, nm) <- keep[[nm]]
}

saveRDS(hive, path, compress = "xz")
cat(sprintf("Wrote %s: 1629 features, %.1f KB\n", path, file.size(path) / 1024))
