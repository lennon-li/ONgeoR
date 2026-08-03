# List available data sources

Prints and returns the sources registered in ONgeoR's bundled source
registry (`inst/extdata/sources.yaml`).

## Usage

``` r
list_sources()
```

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with columns `source_id`, `name`, `geography_type`, and `feature_count`.

## Examples

``` r
list_sources()
#> # A tibble: 29 × 4
#>    source_id              name                      geography_type feature_count
#>    <chr>                  <chr>                     <chr>                  <int>
#>  1 phu_boundaries         MOH Public Health Unit B… boundary                  34
#>  2 ontario_health_regions Ontario Health Region     boundary                   6
#>  3 municipal_upper        Municipal Bnd Upper And … boundary                  98
#>  4 municipal_lower        Municipal Bnd Lower And … boundary                 685
#>  5 airport_official       Airport Official          boundary                 403
#>  6 waste_management_site  Waste Management Site     boundary                 813
#>  7 moh_service_locations  MOH Service Location      facility               11625
#>  8 conservation_authority Conservation Authority A… boundary                  36
#>  9 orwn_station           ORWN Station              facility                 671
#> 10 monitoring_stations    Monitoring Station Point  facility                2588
#> # ℹ 19 more rows
```
