# Summarise an intersection or nearest table by target

Collapses a pairs table (from
[`build_intersection()`](https://lennon-li.github.io/ONgeoR/reference/build_intersection.md)
or
[`build_nearest_pairs()`](https://lennon-li.github.io/ONgeoR/reference/build_nearest_pairs.md))
to exactly one row per distinct target, with multi-valued fields as
`"; "`-delimited strings.

## Usage

``` r
summarise_by_target(pairs)
```

## Arguments

- pairs:

  A tibble produced by
  [`build_intersection()`](https://lennon-li.github.io/ONgeoR/reference/build_intersection.md)
  or
  [`build_nearest_pairs()`](https://lennon-li.github.io/ONgeoR/reference/build_nearest_pairs.md).

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with exactly one row per distinct target. Columns: `target_id`,
`target_name`, `target_source`, `n_source`, `source_ids`,
`source_names`, `shares_of_target`, `shares_of_source`,
`dominant_source_id`, `dominant_source_name`,
`dominant_share_of_target`, `covered_share`, `match_distance_km`, all
`tgt_*` attributes, and provenance columns.

## Examples

``` r
hive <- retrieve_hive()
cells <- hive[hive$Level == "Level 3", ][1:50, ]
pairs <- build_intersection(cells, retrieve_phu_simple())
summarise_by_target(pairs)
#> # A tibble: 29 × 28
#>    target_id target_name          target_source n_source source_ids source_names
#>    <chr>     <chr>                <chr>            <int> <chr>      <chr>       
#>  1 2240      Chatham-Kent Public… MOH Public H…        4 ND-457; N… ND-457; NE-…
#>  2 2268      Windsor-Essex Count… MOH Public H…       50 MU-461; M… MU-461; MV-…
#>  3 2253      Peel Public Health   MOH Public H…        0 NA         NA          
#>  4 7653      Lakelands Public He… MOH Public H…        0 NA         NA          
#>  5 4913      Southwestern Public… MOH Public H…        0 NA         NA          
#>  6 7652      Grand Erie Public H… MOH Public H…        0 NA         NA          
#>  7 2246      Niagara Region Publ… MOH Public H…        0 NA         NA          
#>  8 5183      Huron Perth Public … MOH Public H…        0 NA         NA          
#>  9 2260      Simcoe Muskoka Dist… MOH Public H…        0 NA         NA          
#> 10 3895      Toronto Public Heal… MOH Public H…        0 NA         NA          
#> # ℹ 19 more rows
#> # ℹ 22 more variables: shares_of_target <chr>, shares_of_source <chr>,
#> #   dominant_source_id <chr>, dominant_source_name <chr>,
#> #   dominant_share_of_target <dbl>, covered_share <dbl>,
#> #   match_distance_km <dbl>, src_GRID_ID <chr>, src_Level <chr>,
#> #   src_HIVE_ID <chr>, tgt_OGF_ID <chr>, tgt_PHU_ID <chr>,
#> #   tgt_PHU_NAME_ENG <chr>, tgt_PHU_NAME_FR <chr>, …
```
