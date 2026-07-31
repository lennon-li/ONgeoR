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
source <- sf::st_as_sf(
  data.frame(id = c("s1", "s2"), lon = c(-79.4, -79.5), lat = c(43.6, 43.7)),
  coords = c("lon", "lat"), crs = 4326
)
target <- sf::st_as_sf(
  data.frame(id = c("t1", "t2"), lon = c(-79.41, -79.6), lat = c(43.61, 43.8)),
  coords = c("lon", "lat"), crs = 4326
)
build_nearest_pairs(source, target)
#> # A tibble: 2 × 18
#>   interaction_id target_id target_name target_source source_id source_name
#>   <chr>          <chr>     <chr>       <lgl>         <chr>     <chr>      
#> 1 t1__s1         t1        t1          NA            s1        s1         
#> 2 t2__s2         t2        t2          NA            s2        s2         
#> # ℹ 12 more variables: source_source <lgl>, relation <chr>,
#> #   overlap_area_m2 <dbl>, share_of_target <dbl>, share_of_source <dbl>,
#> #   match_distance_km <dbl>, src_id <chr>, tgt_id <chr>,
#> #   source_url_source <lgl>, source_url_target <lgl>, retrieved_at <lgl>,
#> #   simplify_used <lgl>
```
