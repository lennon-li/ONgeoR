# Get metadata for one data source

Get metadata for one data source

## Usage

``` r
get_source(source_id)
```

## Arguments

- source_id:

  Character. The source identifier, e.g. `"phu_boundaries"`. See
  [`list_sources()`](https://lennon-li.github.io/ONgeoR/reference/list_sources.md)
  for available ids.

## Value

A named list of metadata for the requested source: `name`,
`service_layer`, `geography_type`, `feature_count`, `key_fields`,
`license`, and `source_url`.

## Examples

``` r
get_source("phu_boundaries")
#> $name
#> [1] "MOH Public Health Unit Boundary (post-2025, 29 PHUs)"
#> 
#> $service_layer
#> [1] "LIO_Open09/44"
#> 
#> $geography_type
#> [1] "boundary"
#> 
#> $feature_count
#> [1] 29
#> 
#> $update_frequency
#> [1] "unknown"
#> 
#> $key_fields
#> [1] "PHU_ID"       "PHU_NAME_ENG" "PHU_NAME_FR" 
#> 
#> $license
#> [1] "Open Government Licence - Ontario"
#> 
#> $source_url
#> [1] "https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open09/MapServer/44"
#> 
```
