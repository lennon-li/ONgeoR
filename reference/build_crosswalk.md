# Build an auditable crosswalk table between two geographic layers

Joins two `sf` layers (e.g. municipalities to Public Health Units) and
returns a tidy crosswalk table with full source provenance.

## Usage

``` r
build_crosswalk(
  from,
  to,
  method = c("within", "intersects", "point_on_surface", "largest_overlap", "weighted")
)
```

## Arguments

- from:

  An `sf` object: the source layer (e.g. municipal boundaries).

- to:

  An `sf` object: the target layer (e.g. PHU boundaries).

- method:

  Character. Assignment rule for the crosswalk:

  - `"within"` (default) / `"intersects"`: spatial-join predicate. If
    `method = "within"` and `from` is polygonal while `to` is
    point-type, the join direction is geometrically degenerate (a
    polygon is never "within" a point). In that case `build_crosswalk()`
    auto-corrects by joining `to` within `from` instead, emits an
    informative message, and builds the same output schema from the
    corrected join. If `from` and `to` are both point layers,
    containment has no meaningful direction to auto-correct (a point is
    only within/intersects another point when exactly coincident), so
    `build_crosswalk()` instead emits a warning and proceeds with the
    join as-is; use
    [`nearest()`](https://lennon-li.github.io/ONgeoR/reference/nearest.md)
    or
    [`build_link()`](https://lennon-li.github.io/ONgeoR/reference/build_link.md)
    for point-to-point matching.

  - `"point_on_surface"`: representative-point assignment for point-like
    `from` polygons. Each `from` polygon is reduced to a single
    guaranteed-interior point
    ([`sf::st_point_on_surface()`](https://r-spatial.github.io/sf/reference/geos_unary.html),
    not the centroid, which can fall outside a concave polygon) and
    joined `"within"` the `to` boundaries. `to` must be a polygon layer.

  - `"largest_overlap"`: same-scale polygon-to-polygon assignment. Each
    `from` polygon is assigned to the single `to` polygon it shares the
    largest intersection area with, and the `coverage` column reports
    that winner's share of the `from` polygon's area. Both layers must
    be polygonal.

  - `"weighted"`: polygon-to-polygon apportionment. Every intersecting
    `to` polygon is retained, with `coverage` reporting its share of the
    `from` polygon's area. Coverage values for a `from` polygon sum to
    at most 1, and equal 1 only when the `to` layer fully covers it. The
    `largest_overlap` result is the argmax row of the weighted result.

  `build_crosswalk()` returns an assignment table only: it never emits
  or contains geometry. `"largest_overlap"` uses intersection internally
  as area arithmetic only.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with columns `from_id`, `from_name`, `from_source`, `to_id`, `to_name`,
`to_source`, `match_method`, `match_distance_km` (always `NA`, reserved
for nearest-neighbour matching in a future version), `coverage` (the
winner's area share for `"largest_overlap"`, each intersecting pair's
area share for `"weighted"`, otherwise `NA`), `from_id_col`,
`to_id_col`, `source_url_from`, `source_url_to`, and `retrieved_at`.

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

## See also

[`build_link()`](https://lennon-li.github.io/ONgeoR/reference/build_link.md)
picks the operation from the geometry pair with no `method` argument.
The "What linking does, by layer types" section of
[`vignette("building-crosswalks", package = "ONgeoR")`](https://lennon-li.github.io/ONgeoR/articles/building-crosswalks.md)
tabulates the same matrix, including where the `coverage` column comes
from.

## Examples

``` r
hive <- retrieve_hive()
cells <- hive[hive$Level == "Level 3", ][1:50, ]
build_crosswalk(cells, retrieve_phu_simple(), method = "within")
#> # A tibble: 50 × 14
#>    from_id from_name from_source            to_id to_name to_source match_method
#>    <chr>   <chr>     <chr>                  <chr> <chr>   <chr>     <chr>       
#>  1 MU-461  MU-461    HIVE Grid (Levels 1-3) NA    NA      MOH Publ… within      
#>  2 MV-461  MV-461    HIVE Grid (Levels 1-3) NA    NA      MOH Publ… within      
#>  3 MV-460  MV-460    HIVE Grid (Levels 1-3) NA    NA      MOH Publ… within      
#>  4 MW-460  MW-460    HIVE Grid (Levels 1-3) NA    NA      MOH Publ… within      
#>  5 MX-460  MX-460    HIVE Grid (Levels 1-3) NA    NA      MOH Publ… within      
#>  6 ML-459  ML-459    HIVE Grid (Levels 1-3) NA    NA      MOH Publ… within      
#>  7 MW-459  MW-459    HIVE Grid (Levels 1-3) NA    NA      MOH Publ… within      
#>  8 MX-459  MX-459    HIVE Grid (Levels 1-3) 2268  Windso… MOH Publ… within      
#>  9 MY-459  MY-459    HIVE Grid (Levels 1-3) NA    NA      MOH Publ… within      
#> 10 MZ-459  MZ-459    HIVE Grid (Levels 1-3) NA    NA      MOH Publ… within      
#> # ℹ 40 more rows
#> # ℹ 7 more variables: match_distance_km <dbl>, coverage <dbl>,
#> #   from_id_col <chr>, to_id_col <chr>, source_url_from <chr>,
#> #   source_url_to <chr>, retrieved_at <dttm>
```
