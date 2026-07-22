# Link geometries to a target layer by spatial relationship

Joins a source layer to a target layer using a spatial predicate. Covers
point-in-polygon and polygon-to-polygon joins, plus raster sources and
targets via the package's raster linking model (rasters are reduced to
vector geometries and delegated to the vector join path).

## Usage

``` r
link(source, target, predicate = c("within", "intersects", "contains"))
```

## Arguments

- source:

  An `sf` object (points or polygons), or a `data.frame` with `lon` and
  `lat` columns (assumed CRS 4326 / WGS 84). A `SpatRaster` `source` is
  reduced to its cell-centroid points (carrying the raster's value
  column(s), NA cells dropped) before the join.

- target:

  An `sf` object, typically polygons. A `SpatRaster` `target` is reduced
  to per-cell bounding-box polygons (carrying the raster's value
  column(s)) before the join, so each source point lands in the polygon
  of the cell that contains it (equivalent to raster sampling).

- predicate:

  Character. Spatial join predicate: `"within"` (default),
  `"intersects"`, or `"contains"`. Note: simplified boundary data (e.g.
  municipal boundaries retrieved with `simplify = TRUE`) often needs
  `"intersects"`, because `"within"` misses matches against generalized
  borders. For very complex geometry, simplify first (retrieve with
  `simplify = TRUE`, or
  [`sf::st_simplify()`](https://r-spatial.github.io/sf/reference/geos_unary.html))
  then link. `predicate = "within"` with a polygon `source` and point
  `target` is geometrically degenerate (a polygon is never "within" a
  point): every row will be unmatched (NA), and `link()` emits a warning
  before running the join. The join still runs and the return shape is
  unchanged.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with the source's non-geometry columns, the matched target columns, and
`source_url` / `target_url` / `retrieved_at` provenance columns.
Column-name collisions between source and target follow
[`sf::st_join()`](https://r-spatial.github.io/sf/reference/st_join.html)'s
default `.x`/`.y` suffixing.

## See also

The "What linking does, by layer types" section of
[`vignette("building-crosswalks", package = "ONgeoR")`](https://lennon-li.github.io/ONgeoR/articles/building-crosswalks.md)
tabulates which operation each pair of layer geometries selects
(polygon/point/raster), including the raster sampling paths this
function delegates to.

## Examples

``` r
if (interactive()) {
  points <- data.frame(lon = -79.3832, lat = 43.6532)
  result <- link(points, retrieve_phu())
}
```
