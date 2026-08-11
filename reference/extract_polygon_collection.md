# Reduce GEOMETRYCOLLECTION geometries to their polygon parts

Reduce GEOMETRYCOLLECTION geometries to their polygon parts

## Usage

``` r
extract_polygon_collection(layer)
```

## Arguments

- layer:

  An `sf` object that may contain `GEOMETRYCOLLECTION` geometries.

## Value

The `sf` object with each `GEOMETRYCOLLECTION` replaced by its combined
polygon parts (empty polygon if it has none).

## See also

Other app support interfaces:
[`build_nearest_layers()`](https://lennon-li.github.io/ONgeoR/reference/build_nearest_layers.md),
[`guess_name_col()`](https://lennon-li.github.io/ONgeoR/reference/guess_name_col.md),
[`layer_id_col()`](https://lennon-li.github.io/ONgeoR/reference/layer_id_col.md),
[`render_postal_reproducer_script()`](https://lennon-li.github.io/ONgeoR/reference/render_postal_reproducer_script.md),
[`render_reproducer_script()`](https://lennon-li.github.io/ONgeoR/reference/render_reproducer_script.md)

## Examples

``` r
polygon <- sf::st_polygon(list(rbind(
  c(0, 0), c(1, 0), c(1, 1), c(0, 0)
)))
collection <- sf::st_geometrycollection(list(polygon))
layer <- sf::st_sf(
  name = "Example",
  geometry = sf::st_sfc(collection, crs = 4326)
)
extract_polygon_collection(layer)
#> Simple feature collection with 1 feature and 1 field
#> Geometry type: MULTIPOLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 0 ymin: 0 xmax: 1 ymax: 1
#> Geodetic CRS:  WGS 84
#>      name                       geometry
#> 1 Example MULTIPOLYGON (((0 0, 1 0, 1...
```
