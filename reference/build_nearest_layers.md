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
[`layer_id_col()`](https://lennon-li.github.io/ONgeoR/reference/layer_id_col.md),
[`render_postal_reproducer_script()`](https://lennon-li.github.io/ONgeoR/reference/render_postal_reproducer_script.md),
[`render_reproducer_script()`](https://lennon-li.github.io/ONgeoR/reference/render_reproducer_script.md)

## Examples

``` r
stations <- retrieve_monitoring_stations_bundled()
build_nearest_layers(stations[1:3, ], stations[4:10, ])
#> $source
#> Simple feature collection with 3 features and 5 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -83.388 ymin: 44.80829 xmax: -77.59257 ymax: 46.71642
#> Geodetic CRS:  WGS 84
#>      OGF_ID STATION_NAME STATION_IDENT                          NETWORK_NAME
#> 1 294927289      GILMOUR        967695 NRF Snow Network for Ontario Wildlife
#> 2 294928880        WELLS        967828 NRF Snow Network for Ontario Wildlife
#> 3 294926885 CAPREOL PARK        138073                      NRF Snow Surveys
#>   DATA_COLLECTION_METHOD                   geometry
#> 1                 Manual POINT (-77.59257 44.80829)
#> 2                 Manual   POINT (-83.388 46.39601)
#> 3                 Manual    POINT (-80.95 46.71642)
#> 
#> $matched_target
#> Simple feature collection with 2 features and 5 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -81.97189 ymin: 44.72976 xmax: -78.81889 ymax: 46.18375
#> Geodetic CRS:  WGS 84
#>      OGF_ID          STATION_NAME STATION_IDENT
#> 8 294927360 Gull River at Norland        149349
#> 7 294927832                MASSEY        967756
#>                              NETWORK_NAME DATA_COLLECTION_METHOD
#> 8 Federal Provincial Cost Share Agreement                   Auto
#> 7   NRF Snow Network for Ontario Wildlife                 Manual
#>                     geometry
#> 8 POINT (-78.81889 44.72976)
#> 7 POINT (-81.97189 46.18375)
#> 
#> $connectors
#> Simple feature collection with 3 features and 1 field
#> Geometry type: LINESTRING
#> Dimension:     XY
#> Bounding box:  xmin: -83.388 ymin: 44.72976 xmax: -77.59257 ymax: 46.71642
#> Geodetic CRS:  WGS 84
#>   distance_km                       geometry
#> 1    97.20207 LINESTRING (-77.59257 44.80...
#> 2   111.33845 LINESTRING (-83.388 46.3960...
#> 3    98.16897 LINESTRING (-80.95 46.71642...
#> 
#> $table
#> # A tibble: 3 × 17
#>      OGF_ID STATION_NAME STATION_IDENT NETWORK_NAME       DATA_COLLECTION_METHOD
#>       <int> <chr>        <chr>         <chr>              <chr>                 
#> 1 294927289 GILMOUR      967695        NRF Snow Network … Manual                
#> 2 294928880 WELLS        967828        NRF Snow Network … Manual                
#> 3 294926885 CAPREOL PARK 138073        NRF Snow Surveys   Manual                
#> # ℹ 12 more variables: .ongeor_source_row <int>, rank <int>, OGF_ID.1 <int>,
#> #   STATION_NAME.1 <chr>, STATION_IDENT.1 <chr>, NETWORK_NAME.1 <chr>,
#> #   DATA_COLLECTION_METHOD.1 <chr>, .ongeor_target_row <int>,
#> #   distance_km <dbl>, source_url <chr>, target_url <chr>, retrieved_at <dttm>
#> 
```
