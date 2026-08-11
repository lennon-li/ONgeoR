# Render a reproducible R script for a CLI run

Render a reproducible R script for a CLI run

## Usage

``` r
render_reproducer_script(from_ids, to_ids, output_dir, method = "intersects")
```

## Arguments

- from_ids:

  Character vector of source ids used as crosswalk sources.

- to_ids:

  Character vector of source ids used as crosswalk targets.

- output_dir:

  Character scalar output directory.

- method:

  Character. Crosswalk assignment rule recorded in the script and passed
  to
  [`build_crosswalk()`](https://lennon-li.github.io/ONgeoR/reference/build_crosswalk.md)
  for every pair, so the script rebuilds the crosswalk with the same
  rule as the run it documents. Defaults to `"intersects"`.

## Value

A character vector containing valid R code.

## See also

Other app support interfaces:
[`build_nearest_layers()`](https://lennon-li.github.io/ONgeoR/reference/build_nearest_layers.md),
[`extract_polygon_collection()`](https://lennon-li.github.io/ONgeoR/reference/extract_polygon_collection.md),
[`guess_name_col()`](https://lennon-li.github.io/ONgeoR/reference/guess_name_col.md),
[`layer_id_col()`](https://lennon-li.github.io/ONgeoR/reference/layer_id_col.md),
[`render_postal_reproducer_script()`](https://lennon-li.github.io/ONgeoR/reference/render_postal_reproducer_script.md)

## Examples

``` r
render_reproducer_script("airport_official", "phu_boundaries", "output")
#> [1] "library(ONgeoR)\n\nfrom_ids <- \"airport_official\"\nto_ids <- \"phu_boundaries\"\nmethod <- \"intersects\"\noutput_dir <- \"output\"\n\nlayers <- list(\n  airport_official = retrieve_airport(),\n  phu_boundaries = retrieve_phu()\n)\n\ncw <- build_crosswalk(layers[[from_ids]], layers[[to_ids]], method = method)\nmap <- map_crosswalk(layers, from_ids, to_ids)\n\ndir.create(output_dir, recursive = TRUE, showWarnings = FALSE)\nwrite.csv(cw, file.path(output_dir, \"mapping.csv\"), row.names = FALSE)\nhtmlwidgets::saveWidget(map, file.path(output_dir, \"map.html\"), selfcontained = TRUE)\nwriteLines(\n  ONgeoR:::render_reproducer_script(from_ids, to_ids, output_dir, method = method),\n  file.path(output_dir, \"reproduce.R\")\n)\n"
```
