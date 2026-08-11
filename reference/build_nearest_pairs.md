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
#>   interaction_id       target_id target_name target_source source_id source_name
#>   <chr>                <chr>     <chr>       <chr>         <chr>     <chr>      
#> 1 LAKE 304 NEAR KENOR… LAKE 304… LAKE 304 N… Monitoring S… BEARPAW   BEARPAW    
#> 2 CONISTON CREEK NEAR… CONISTON… CONISTON C… Monitoring S… CAPREOL … CAPREOL PA…
#> 3 HAWKROCK RIVER AT G… HAWKROCK… HAWKROCK R… Monitoring S… Gull Riv… Gull River…
#> 4 Little Cataraqui Ri… Little C… Little Cat… Monitoring S… GILMOUR   GILMOUR    
#> 5 IGNACE__BEARPAW      IGNACE    IGNACE      Monitoring S… BEARPAW   BEARPAW    
#> # ℹ 20 more variables: source_source <chr>, relation <chr>,
#> #   overlap_area_m2 <dbl>, share_of_target <dbl>, share_of_source <dbl>,
#> #   match_distance_km <dbl>, src_OGF_ID <int>, src_STATION_NAME <chr>,
#> #   src_STATION_IDENT <chr>, src_NETWORK_NAME <chr>,
#> #   src_DATA_COLLECTION_METHOD <chr>, tgt_OGF_ID <int>, tgt_STATION_NAME <chr>,
#> #   tgt_STATION_IDENT <chr>, tgt_NETWORK_NAME <chr>,
#> #   tgt_DATA_COLLECTION_METHOD <chr>, source_url_source <chr>, …
```
