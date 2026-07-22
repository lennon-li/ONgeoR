# Map nearest targets and their connections to source points

Combines
[`nearest()`](https://lennon-li.github.io/ONgeoR/reference/nearest.md)
with
[`map_layers()`](https://lennon-li.github.io/ONgeoR/reference/map_layers.md)
to show source points, the targets matched to them, and a connector line
for every match. Only matched targets are drawn. If no target is within
`max_dist_km`, the returned map contains the source points without
target or connector layers.

## Usage

``` r
map_nearest(source, target, k = 1, max_dist_km = NULL)
```

## Arguments

- source:

  An `sf` object of points, or a `data.frame` with `lon` and `lat`
  columns (assumed CRS 4326 / WGS 84).

- target:

  An `sf` object of candidate point or polygon geometries.

- k:

  Integer. Number of nearest targets to map per source. Defaults to `1`;
  `Inf` may be used with `max_dist_km` for a radius search.

- max_dist_km:

  Numeric or `NULL`. If set, omit targets farther than this distance in
  kilometres.

## Value

A `leaflet` htmlwidget.

## Examples

``` r
if (interactive()) {
  points <- data.frame(lon = -79.3832, lat = 43.6532)
  map_nearest(points, retrieve_moh_service_locations(), k = 3)
}
```
