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
if (interactive()) {
  municipal <- retrieve_municipal("upper")
  phu <- retrieve_phu()
  pairs <- build_intersection(municipal, phu)
}
```
