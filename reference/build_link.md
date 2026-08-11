# Link two layers with no method choice

Infers the linking mode from the geometry types of the two layers and
dispatches to the appropriate implementation. Point-to-point uses
nearest matching; polygon-to-polygon uses intersection; all other
combinations delegate to the existing
[`build_crosswalk()`](https://lennon-li.github.io/ONgeoR/reference/build_crosswalk.md)
or [`link()`](https://lennon-li.github.io/ONgeoR/reference/link.md)
unchanged.

## Usage

``` r
build_link(source, target)
```

## Arguments

- source:

  An `sf` object or `SpatRaster`.

- target:

  An `sf` object or `SpatRaster`.

## Value

A tibble whose schema depends on the dispatched implementation.

## Geometry combination matrix

What an operation does is determined by the geometry types of the two
layers, not by a match-rule argument:

- point to point:

  Nearest. Each target point is matched to its single nearest source
  point. Output: nearest table.

- point to polygon:

  Containment. Each point is matched to the boundary it falls inside.
  Output: crosswalk.

- point to raster:

  Sampling. Each point takes the value of the cell containing it.
  Output: linked values table.

- polygon to point:

  Containment. Direction is auto-corrected internally. Output:
  crosswalk.

- polygon to polygon:

  Intersection. Every overlapping pair, with the share of each target
  covered and the share of each source falling inside. Output:
  intersection table.

- polygon to raster:

  Sampling. Each polygon samples the raster values it overlaps. Output:
  linked values table.

- raster to point:

  Sampling. Raster reduced to cell centroids. Output: linked values
  table.

- raster to polygon:

  Cell sampling into boundaries. Each cell centroid is matched to the
  boundary it falls inside. Output: linked values table.

- raster to raster:

  Not supported. Not supported; align/resample with terra first. Output:
  none.

## Examples

``` r
hive <- retrieve_hive()
cells <- hive[hive$Level == "Level 3", ][1:50, ]
build_link(cells, retrieve_phu_simple())
#> # A tibble: 81 × 27
#>    interaction_id target_id target_name      target_source source_id source_name
#>    <chr>          <chr>     <chr>            <chr>         <chr>     <chr>      
#>  1 2240__ND-457   2240      Chatham-Kent Pu… MOH Public H… ND-457    ND-457     
#>  2 2240__NE-457   2240      Chatham-Kent Pu… MOH Public H… NE-457    NE-457     
#>  3 2240__ND-456   2240      Chatham-Kent Pu… MOH Public H… ND-456    ND-456     
#>  4 2240__NE-456   2240      Chatham-Kent Pu… MOH Public H… NE-456    NE-456     
#>  5 2268__MU-461   2268      Windsor-Essex C… MOH Public H… MU-461    MU-461     
#>  6 2268__MV-461   2268      Windsor-Essex C… MOH Public H… MV-461    MV-461     
#>  7 2268__MV-460   2268      Windsor-Essex C… MOH Public H… MV-460    MV-460     
#>  8 2268__MW-460   2268      Windsor-Essex C… MOH Public H… MW-460    MW-460     
#>  9 2268__MX-460   2268      Windsor-Essex C… MOH Public H… MX-460    MX-460     
#> 10 2268__ML-459   2268      Windsor-Essex C… MOH Public H… ML-459    ML-459     
#> # ℹ 71 more rows
#> # ℹ 21 more variables: source_source <chr>, relation <chr>,
#> #   overlap_area_m2 <dbl>, share_of_target <dbl>, share_of_source <dbl>,
#> #   match_distance_km <dbl>, src_GRID_ID <chr>, src_Level <chr>,
#> #   src_HIVE_ID <int>, tgt_OGF_ID <int>, tgt_PHU_ID <int>,
#> #   tgt_PHU_NAME_ENG <chr>, tgt_PHU_NAME_FR <chr>,
#> #   tgt_GEOMETRY_UPDATE_DATETIME <dbl>, tgt_EFFECTIVE_DATETIME <dbl>, …
```
