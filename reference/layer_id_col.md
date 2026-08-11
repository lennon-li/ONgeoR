# Resolve the id column of a retrieved layer

Returns the column that identifies each feature of `layer`. When the
layer carries retrieval provenance, the answer comes from the source
registry's declared key fields, so it matches the `from_id_col` /
`to_id_col` values recorded in
[`build_crosswalk()`](https://lennon-li.github.io/ONgeoR/reference/build_crosswalk.md)
and
[`build_intersection()`](https://lennon-li.github.io/ONgeoR/reference/build_intersection.md)
output. Layers without provenance fall back to a name-pattern guess.

## Usage

``` r
layer_id_col(layer)
```

## Arguments

- layer:

  An `sf` object or `data.frame`.

## Value

Character scalar: the id column name.

## Details

This is the supported way for a downstream caller to join a crosswalk or
linked table back onto the layer geometry it came from.

## See also

Other app support interfaces:
[`build_nearest_layers()`](https://lennon-li.github.io/ONgeoR/reference/build_nearest_layers.md),
[`extract_polygon_collection()`](https://lennon-li.github.io/ONgeoR/reference/extract_polygon_collection.md),
[`guess_name_col()`](https://lennon-li.github.io/ONgeoR/reference/guess_name_col.md),
[`render_postal_reproducer_script()`](https://lennon-li.github.io/ONgeoR/reference/render_postal_reproducer_script.md),
[`render_reproducer_script()`](https://lennon-li.github.io/ONgeoR/reference/render_reproducer_script.md)

## Examples

``` r
layer_id_col(data.frame(PHU_ID = 2253, PHU_NAME_ENG = "Example"))
#> [1] "PHU_ID"
```
