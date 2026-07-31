# Find the nearest targets to each source geometry

For each source geometry, returns the `k` nearest targets in ascending
distance, optionally capped at `max_dist_km`. Use `k = Inf` with
`max_dist_km` for a pure radius search.

## Usage

``` r
nearest(source, target, k = 1, max_dist_km = NULL)
```

## Arguments

- source:

  An `sf` object of points, or a `data.frame` with `lon`/`lat` columns
  (assumed CRS 4326 / WGS 84).

- target:

  An `sf` object of candidate geometries.

- k:

  Integer. Number of nearest targets to return per source. Defaults to
  `1`. If a source has fewer than `k` targets available, all are
  returned.

- max_dist_km:

  Numeric or `NULL`. If set, drop targets farther than this distance
  (km). Defaults to `NULL` (no cap). A source with no target in range
  contributes zero rows.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with the source columns, `rank` (1 = nearest), the matched target
columns, `distance_km`, and `source_url` / `target_url` / `retrieved_at`
provenance columns. Uses a full source-by-target distance matrix (not
spatial-indexed); requests over 10 million distances abort as unsuitable
at this scale. See the nearest-neighbour performance item in
`ROADMAP.md`.

## Examples

``` r
points <- data.frame(lon = -79.3832, lat = 43.6532)
nearest(points, retrieve_hive()[1:50, ], k = 3)
#> # A tibble: 3 × 9
#>   point_id  rank GRID_ID Level   HIVE_ID distance_km source_url target_url      
#>      <int> <int> <chr>   <chr>     <int>       <dbl> <lgl>      <chr>           
#> 1        1     1 G-6     Level 1       7        173. NA         builtin://ongeo…
#> 2        1     2 BE-62   Level 2      56        183. NA         builtin://ongeo…
#> 3        1     3 BD-62   Level 2      55        188. NA         builtin://ongeo…
#> # ℹ 1 more variable: retrieved_at <dttm>
```
