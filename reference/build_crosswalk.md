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
    corrected join.

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

## See also

The "What linking does, by layer types" section of
[`vignette("building-crosswalks", package = "ONgeoR")`](https://lennon-li.github.io/ONgeoR/articles/building-crosswalks.md)
tabulates which operation each pair of layer geometries selects
(polygon/point/raster), including where the `coverage` column comes
from.

## Examples

``` r
if (interactive()) {
  upper_tier <- retrieve_municipal("upper")
  phu <- retrieve_phu()
  crosswalk <- build_crosswalk(upper_tier, phu, method = "within")
}
```
