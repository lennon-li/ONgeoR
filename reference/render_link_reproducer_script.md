# Render a reproducible R script for a raster `link()` run

Reproduces the linked-values table a raster source or target run
produces through
[`link()`](https://lennon-li.github.io/ONgeoR/reference/link.md). Unlike
[`render_reproducer_script()`](https://lennon-li.github.io/ONgeoR/reference/render_reproducer_script.md),
there is no crosswalk to rebuild: a raster pairing has no per-target
summary, only the row-per-cell (or row-per-point) table
[`link()`](https://lennon-li.github.io/ONgeoR/reference/link.md) returns
directly.

## Usage

``` r
render_link_reproducer_script(from_id, to_id, output_dir, predicate = "within")
```

## Arguments

- from_id:

  Character scalar source id passed as
  [`link()`](https://lennon-li.github.io/ONgeoR/reference/link.md)'s
  `source`.

- to_id:

  Character scalar source id passed as
  [`link()`](https://lennon-li.github.io/ONgeoR/reference/link.md)'s
  `target`.

- output_dir:

  Character scalar output directory.

- predicate:

  Character. Spatial predicate passed to
  [`link()`](https://lennon-li.github.io/ONgeoR/reference/link.md).
  Defaults to `"within"`, matching the app's raster-pairing behavior.

## Value

A character vector containing valid R code.

## See also

Other app support interfaces:
[`build_nearest_layers()`](https://lennon-li.github.io/ONgeoR/reference/build_nearest_layers.md),
[`extract_polygon_collection()`](https://lennon-li.github.io/ONgeoR/reference/extract_polygon_collection.md),
[`guess_name_col()`](https://lennon-li.github.io/ONgeoR/reference/guess_name_col.md),
[`layer_id_col()`](https://lennon-li.github.io/ONgeoR/reference/layer_id_col.md),
[`render_postal_reproducer_script()`](https://lennon-li.github.io/ONgeoR/reference/render_postal_reproducer_script.md),
[`render_reproducer_script()`](https://lennon-li.github.io/ONgeoR/reference/render_reproducer_script.md)

## Examples

``` r
render_link_reproducer_script("synthetic_air_quality", "hive", "output")
#> [1] "library(ONgeoR)\n\nfrom_id <- \"synthetic_air_quality\"\nto_id <- \"hive\"\npredicate <- \"within\"\noutput_dir <- \"output\"\n\nfrom_layer <- retrieve_synthetic_raster()\nto_layer <- retrieve_hive()\n\nlinked <- link(from_layer, to_layer, predicate = predicate)\n\ndir.create(output_dir, recursive = TRUE, showWarnings = FALSE)\nwrite.csv(linked, file.path(output_dir, \"linked.csv\"), row.names = FALSE)\nwriteLines(\n  ONgeoR:::render_link_reproducer_script(from_id, to_id, output_dir, predicate = predicate),\n  file.path(output_dir, \"reproduce.R\")\n)\n"
```
