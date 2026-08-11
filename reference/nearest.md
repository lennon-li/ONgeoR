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
stations <- retrieve_monitoring_stations_simple()[1:5, ]
nearest(stations, retrieve_hive()[1:50, ], k = 3)
#> # A tibble: 15 × 13
#>      OGF_ID STATION_NAME STATION_IDENT NETWORK_NAME DATA_COLLECTION_METHOD  rank
#>       <int> <chr>        <chr>         <chr>        <chr>                  <int>
#>  1   2.95e8 GILMOUR      967695        NRF Snow Ne… Manual                     1
#>  2   2.95e8 GILMOUR      967695        NRF Snow Ne… Manual                     2
#>  3   2.95e8 GILMOUR      967695        NRF Snow Ne… Manual                     3
#>  4   2.95e8 WELLS        967828        NRF Snow Ne… Manual                     1
#>  5   2.95e8 WELLS        967828        NRF Snow Ne… Manual                     2
#>  6   2.95e8 WELLS        967828        NRF Snow Ne… Manual                     3
#>  7   2.95e8 CAPREOL PARK 138073        NRF Snow Su… Manual                     1
#>  8   2.95e8 CAPREOL PARK 138073        NRF Snow Su… Manual                     2
#>  9   2.95e8 CAPREOL PARK 138073        NRF Snow Su… Manual                     3
#> 10   2.95e8 STEPHEN'S G… 137993        NRF Snow Su… Manual                     1
#> 11   2.95e8 STEPHEN'S G… 137993        NRF Snow Su… Manual                     2
#> 12   2.95e8 STEPHEN'S G… 137993        NRF Snow Su… Manual                     3
#> 13   2.95e8 BEARPAW      121220        NRF Fire We… Auto                       1
#> 14   2.95e8 BEARPAW      121220        NRF Fire We… Auto                       2
#> 15   2.95e8 BEARPAW      121220        NRF Fire We… Auto                       3
#> # ℹ 7 more variables: GRID_ID <chr>, Level <chr>, HIVE_ID <int>,
#> #   distance_km <dbl>, source_url <chr>, target_url <chr>, retrieved_at <dttm>
```
