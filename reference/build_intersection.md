# Build a polygon-to-polygon intersection table

Computes every overlapping pair between a source polygon layer and a
target polygon layer using a single vectorized
[`sf::st_intersection()`](https://r-spatial.github.io/sf/reference/geos_binary_ops.html)
call, and returns one row per pair with area shares. Targets with no
overlap at all receive one explicit all-NA-match row so every target
feature is represented.

## Usage

``` r
build_intersection(source, target, min_overlap = 0)
```

## Arguments

- source:

  An `sf` polygon layer (the matched unit).

- target:

  An `sf` polygon layer (the index unit).

- min_overlap:

  Numeric. Minimum intersection area in square metres for a pair to be
  retained. Defaults to `0`, meaning strictly greater than zero
  (boundary-touching polygons that share only an edge are excluded).

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with one row per overlapping pair (plus all-NA-match rows for unmatched
targets). Fixed columns: `interaction_id`, `target_id`, `target_name`,
`target_source`, `source_id`, `source_name`, `source_source`,
`relation`, `overlap_area_m2`, `share_of_target`, `share_of_source`,
`match_distance_km`, then every source attribute prefixed `src_`, every
target attribute prefixed `tgt_`, then `source_url_source`,
`source_url_target`, `retrieved_at`, `simplify_used`. No geometry column
is ever emitted.

## Examples

``` r
hive <- retrieve_hive()
cells <- hive[hive$Level == "Level 3", ][1:50, ]
build_intersection(cells, retrieve_phu_simple())
#> # A tibble: 86 × 27
#>    interaction_id target_id target_name      target_source source_id source_name
#>    <chr>          <chr>     <chr>            <chr>         <chr>     <chr>      
#>  1 2240__ND-457   2240      Chatham-Kent He… MOH Public H… ND-457    ND-457     
#>  2 2240__NE-457   2240      Chatham-Kent He… MOH Public H… NE-457    NE-457     
#>  3 2240__ND-456   2240      Chatham-Kent He… MOH Public H… ND-456    ND-456     
#>  4 2240__NE-456   2240      Chatham-Kent He… MOH Public H… NE-456    NE-456     
#>  5 2268__MU-461   2268      Windsor-Essex C… MOH Public H… MU-461    MU-461     
#>  6 2268__MV-461   2268      Windsor-Essex C… MOH Public H… MV-461    MV-461     
#>  7 2268__MV-460   2268      Windsor-Essex C… MOH Public H… MV-460    MV-460     
#>  8 2268__MW-460   2268      Windsor-Essex C… MOH Public H… MW-460    MW-460     
#>  9 2268__MX-460   2268      Windsor-Essex C… MOH Public H… MX-460    MX-460     
#> 10 2268__ML-459   2268      Windsor-Essex C… MOH Public H… ML-459    ML-459     
#> # ℹ 76 more rows
#> # ℹ 21 more variables: source_source <chr>, relation <chr>,
#> #   overlap_area_m2 <dbl>, share_of_target <dbl>, share_of_source <dbl>,
#> #   match_distance_km <dbl>, src_GRID_ID <chr>, src_Level <chr>,
#> #   src_HIVE_ID <int>, tgt_OGF_ID <int>, tgt_PHU_ID <int>,
#> #   tgt_PHU_NAME_ENG <chr>, tgt_PHU_NAME_FR <chr>,
#> #   tgt_GEOMETRY_UPDATE_DATETIME <dbl>, tgt_EFFECTIVE_DATETIME <dbl>, …
```
