# Build layers for a nearest-neighbour map

Finds the nearest target features for each source feature, retains only
matched targets, and constructs one connector line per match. This
supports custom map renderers that need the same layers as
[`map_nearest()`](https://lennon-li.github.io/ONgeoR/reference/map_nearest.md).

## Usage

``` r
build_nearest_layers(source, target, k = 1, max_dist_km = NULL)
```

## Arguments

- source:

  An `sf` object of source point geometries.

- target:

  An `sf` object of candidate point or polygon geometries.

- k:

  Integer. Number of nearest targets per source. Defaults to `1`; `Inf`
  may be used with `max_dist_km` for a radius search.

- max_dist_km:

  Numeric or `NULL`. If set, omit targets farther than this distance in
  kilometres.

## Value

A named list with four elements: `source`, the original source layer;
`matched_target`, the target features present in the matches;
`connectors`, an `sf` layer of connector lines or `NULL` when there are
no matches; and `table`, the tibble returned by
[`nearest()`](https://lennon-li.github.io/ONgeoR/reference/nearest.md).

## See also

Other app support interfaces:
[`extract_polygon_collection()`](https://lennon-li.github.io/ONgeoR/reference/extract_polygon_collection.md),
[`guess_name_col()`](https://lennon-li.github.io/ONgeoR/reference/guess_name_col.md),
[`render_reproducer_script()`](https://lennon-li.github.io/ONgeoR/reference/render_reproducer_script.md)

## Examples

``` r
source <- sf::st_as_sf(
  data.frame(id = "A", lon = -79, lat = 43),
  coords = c("lon", "lat"), crs = 4326
)
target <- sf::st_as_sf(
  data.frame(id = c("B", "C"), lon = c(-79.1, -79.2), lat = c(43, 43)),
  coords = c("lon", "lat"), crs = 4326
)
build_nearest_layers(source, target)
#> $source
#> Simple feature collection with 1 feature and 1 field
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -79 ymin: 43 xmax: -79 ymax: 43
#> Geodetic CRS:  WGS 84
#>   id       geometry
#> 1  A POINT (-79 43)
#> 
#> $matched_target
#> Simple feature collection with 1 feature and 1 field
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -79.1 ymin: 43 xmax: -79.1 ymax: 43
#> Geodetic CRS:  WGS 84
#>   id         geometry
#> 1  B POINT (-79.1 43)
#> 
#> $connectors
#> Simple feature collection with 1 feature and 1 field
#> Geometry type: LINESTRING
#> Dimension:     XY
#> Bounding box:  xmin: -79.1 ymin: 43 xmax: -79 ymax: 43
#> Geodetic CRS:  WGS 84
#>   distance_km                      geometry
#> 1    8.132294 LINESTRING (-79 43, -79.1 43)
#> 
#> $table
#> # A tibble: 1 × 9
#>   id    .ongeor_source_row  rank id.1  .ongeor_target_row distance_km source_url
#>   <chr>              <int> <int> <chr>              <int>       <dbl> <lgl>     
#> 1 A                      1     1 B                      1        8.13 NA        
#> # ℹ 2 more variables: target_url <lgl>, retrieved_at <lgl>
#> 
```
