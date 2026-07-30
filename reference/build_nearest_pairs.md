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
if (interactive()) {
  stations <- retrieve_orwn_station()
  airports <- retrieve_airport()
  pairs <- build_nearest_pairs(stations, airports)
}
```
