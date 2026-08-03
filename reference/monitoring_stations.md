# Monitoring Station Point (bundled snapshot)

A bundled snapshot of Ontario water and weather monitoring station point
locations from LIO layer `LIO_Open08/30`, shipped as
`inst/extdata/monitoring_stations.rds` and accessed via
[`retrieve_monitoring_stations_simple()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_monitoring_stations_simple.md).
For up-to-date retrieval from the live LIO service, use
[`retrieve_monitoring_stations()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_monitoring_stations.md)
instead.

## Details

Columns:

- OGF_ID:

  Ontario Geo Fabric identifier.

- STATION_NAME:

  Station name.

- STATION_IDENT:

  Station identifier.

- NETWORK_NAME:

  Name of the monitoring network the station belongs to.

- DATA_COLLECTION_METHOD:

  Data collection method.

- geometry:

  `POINT` geometry, EPSG:4326.

The dataset contains 2407 features. The live origin layer is larger
(2588 stations as of 2026-08-03): the bundled file is a frozen
2023-06-23 GeoHub snapshot, and the gap is explained in
`data-raw/monitoring_stations.R`. See `data-raw/monitoring_stations.R`
for the reproducible preparation pipeline (download, column selection)
used to generate `inst/extdata/monitoring_stations.rds`.

## Provenance

Published by the Ontario Ministry of Natural Resources and Forestry.

## Licence

Open Government Licence - Ontario.

## See also

[`retrieve_monitoring_stations_simple()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_monitoring_stations_simple.md)
