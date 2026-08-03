# data-raw/monitoring_stations.R
#
# Reproducible prep script for the bundled monitoring station point layer
# (inst/extdata/monitoring_stations.rds).
#
# Source: Monitoring Station Point, LIO layer LIO_Open08/30.
# Published by the Ontario Ministry of Natural Resources and Forestry.
# Licensed under the Open Government Licence - Ontario.
#
# The download uses the Esri Hub export endpoint rather than the LIO REST
# service, because Hub serves the whole layer in one request while the REST
# service caps at 2000 records per page (which would require paginated
# fetching for a layer of this size).
#
# Count discrepancy, resolved 2026-08-03 by querying both ends:
#
# - The origin MapServer (LIO_Open08/MapServer/30) reports 2588 records
#   (returnCountOnly, where=1=1).
# - The GeoHub export used here yields 2407 records, all carrying
#   SYSTEM_DATETIME 2023-06-23T10:55:20Z: the Hub item is a frozen
#   2023-06-23 snapshot (item created that day), not a live mirror.
# - Joined on STATION_IDENT (OGF_ID values are system-generated and
#   disjoint between the two): 195 stations present at the origin are
#   absent from the snapshot - mostly federal/US Great Lakes stations
#   bulk-loaded on 2026-02-23 (NOAA/ECCC buoys, NOAA Great Lakes
#   stations, Parks Canada) - and 14 snapshot records are no longer in
#   the origin layer. 2588 - 195 + 14 = 2407 exactly.
#
# The bundled layer therefore intentionally carries the snapshot count.
# sources.yaml records 2588 for the live source and 2407 for this
# bundled snapshot. Re-running this script against today's Hub export
# still yields the snapshot, not the live layer.
#
# Only six columns are kept (OGF_ID, STATION_NAME, STATION_IDENT,
# NETWORK_NAME, DATA_COLLECTION_METHOD, geometry) to hold the file well
# inside the CRAN size budget.
#
# Run from the package root: source("data-raw/monitoring_stations.R")

url <- paste0(
  "https://geohub.lio.gov.on.ca/api/download/v1/items/",
  "53fafcb5f3b04d0ebaa99dd16634b7c5/geojson?layers=30"
)
dest <- tempfile(fileext = ".geojson")
utils::download.file(url, dest, mode = "wb", quiet = TRUE)

stations <- sf::st_read(dest, quiet = TRUE)
keep <- c(
  "OGF_ID", "STATION_NAME", "STATION_IDENT",
  "NETWORK_NAME", "DATA_COLLECTION_METHOD", "geometry"
)
stations <- stations[, keep]

stopifnot(
  inherits(stations, "sf"),
  all(sf::st_geometry_type(stations) == "POINT"),
  sf::st_crs(stations)$epsg == 4326
)
message("features retrieved: ", nrow(stations))

saveRDS(
  stations,
  file.path("inst", "extdata", "monitoring_stations.rds"),
  compress = "xz"
)

message(sprintf(
  "Wrote inst/extdata/monitoring_stations.rds: %d features, %.2f KB",
  nrow(stations),
  file.size("inst/extdata/monitoring_stations.rds") / 1024
))
