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
if (interactive()) {
  municipal <- retrieve_municipal("upper")
  phu <- retrieve_phu()
  result <- build_link(municipal, phu)
}
```
