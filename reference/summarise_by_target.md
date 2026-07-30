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
if (interactive()) {
  pairs <- build_intersection(retrieve_municipal("upper"), retrieve_phu())
  summary_tbl <- summarise_by_target(pairs)
}
```
