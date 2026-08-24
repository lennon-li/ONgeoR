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
#> # A tibble: 45 × 4
#>    source_id              name                      geography_type feature_count
#>    <chr>                  <chr>                     <chr>                  <int>
#>  1 phu_boundaries         MOH Public Health Unit B… boundary                  29
#>  2 phu_boundaries_pre2025 MOH Public Health Unit B… boundary                  34
#>  3 ontario_health_regions Ontario Health Region     boundary                   6
#>  4 municipal_upper        Municipal Bnd Upper And … boundary                  98
#>  5 municipal_lower        Municipal Bnd Lower And … boundary                 685
#>  6 airport_official       Airport Official          boundary                 403
#>  7 waste_management_site  Waste Management Site     boundary                 813
#>  8 moh_service_locations  MOH Service Location      facility               11625
#>  9 conservation_authority Conservation Authority A… boundary                  36
#> 10 orwn_station           ORWN Station              facility                 671
#> # ℹ 35 more rows
```
