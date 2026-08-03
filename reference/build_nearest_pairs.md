# Build a point-to-point nearest-match table

Matches each target point to its single nearest source point. Returns
the same column schema as
[`build_intersection()`](https://lennon-li.github.io/ONgeoR/reference/build_intersection.md)
so the two are row-bindable.

## Usage

``` r
build_nearest_pairs(source, target)
```

## Arguments

- source:

  An `sf` point layer (the candidate matches).

- target:

  An `sf` point layer (the units to be matched).

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with one row per target feature. Fixed columns match
[`build_intersection()`](https://lennon-li.github.io/ONgeoR/reference/build_intersection.md);
`relation` is `"nearest"`, `match_distance_km` is populated, and
`overlap_area_m2`, `share_of_target`, `share_of_source` are `NA`.

## Examples

``` r
stations <- retrieve_monitoring_stations_simple()
build_nearest_pairs(stations[1:20, ], stations[21:25, ])
#> # A tibble: 5 × 26
#>   interaction_id target_id target_name       target_source source_id source_name
#>   <chr>          <chr>     <chr>             <lgl>         <chr>     <chr>      
#> 1 136532__121220 136532    LAKE 304 NEAR KE… NA            121220    BEARPAW    
#> 2 134699__138073 134699    CONISTON CREEK N… NA            138073    CAPREOL PA…
#> 3 134867__149349 134867    HAWKROCK RIVER A… NA            149349    Gull River…
#> 4 145058__967695 145058    Little Cataraqui… NA            967695    GILMOUR    
#> 5 967714__121220 967714    IGNACE            NA            121220    BEARPAW    
#> # ℹ 20 more variables: source_source <lgl>, relation <chr>,
#> #   overlap_area_m2 <dbl>, share_of_target <dbl>, share_of_source <dbl>,
#> #   match_distance_km <dbl>, src_OGF_ID <int>, src_STATION_NAME <chr>,
#> #   src_STATION_IDENT <chr>, src_NETWORK_NAME <chr>,
#> #   src_DATA_COLLECTION_METHOD <chr>, tgt_OGF_ID <int>, tgt_STATION_NAME <chr>,
#> #   tgt_STATION_IDENT <chr>, tgt_NETWORK_NAME <chr>,
#> #   tgt_DATA_COLLECTION_METHOD <chr>, source_url_source <lgl>, …
```
