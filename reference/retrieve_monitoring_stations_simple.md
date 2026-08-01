# Retrieve bundled monitoring station points

Returns the built-in monitoring station point layer shipped in
`inst/extdata/monitoring_stations.rds`. This layer is intended for
examples and tests that need a real point-in-polygon join with no
network access. It is NOT a substitute for
[`retrieve_monitoring_stations()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_monitoring_stations.md):
use
[`retrieve_monitoring_stations()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_monitoring_stations.md)
when you need up-to-date, authoritative monitoring station locations.

## Usage

``` r
retrieve_monitoring_stations_simple()
```

## Value

An `sf` object of monitoring station points (`OGF_ID`, `STATION_NAME`,
`STATION_IDENT`, `NETWORK_NAME`, `DATA_COLLECTION_METHOD`, `geometry`
columns) in EPSG:4326.

## Details

The built-in file was downloaded from the Esri Hub export endpoint for
LIO layer `LIO_Open08/30` and subset to six columns to fit the CRAN
package size budget. The source data are published by the Ontario
Ministry of Natural Resources and Forestry under the Open Government
Licence - Ontario.

## Examples

``` r
stations <- retrieve_monitoring_stations_simple()
nrow(stations)
#> [1] 2407
```
