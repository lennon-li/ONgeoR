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
# The GeoHub catalogue advertises 2588 records, but the export actually
# yields 2407. The number written to sources.yaml is the count actually
# obtained, not the advertised one.
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
