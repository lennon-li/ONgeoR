# Render a postal-code reproducer script

Render a postal-code reproducer script

## Usage

``` r
render_postal_reproducer_script(
  input_file,
  postal_col,
  output_dir,
  all_links = TRUE
)
```

## Arguments

- input_file:

  Character scalar path to the user's input file.

- postal_col:

  Character scalar naming the postal-code column in the input file.

- output_dir:

  Character scalar output directory.

- all_links:

  Logical scalar passed through to
  [`resolve_postal()`](https://lennon-li.github.io/ONgeoR/reference/resolve_postal.md).
  The default `TRUE` writes every dissemination-area link, which can
  give a record more than one output row; `FALSE` keeps one best link
  per postal code so the row count of the input is preserved.

## Value

A character scalar containing valid R code.

## See also

Other app support interfaces:
[`build_nearest_layers()`](https://lennon-li.github.io/ONgeoR/reference/build_nearest_layers.md),
[`extract_polygon_collection()`](https://lennon-li.github.io/ONgeoR/reference/extract_polygon_collection.md),
[`guess_name_col()`](https://lennon-li.github.io/ONgeoR/reference/guess_name_col.md),
[`render_reproducer_script()`](https://lennon-li.github.io/ONgeoR/reference/render_reproducer_script.md)

## Examples

``` r
render_postal_reproducer_script("records.csv", "postal_code", tempdir())
#> [1] "library(ONgeoR)\n\n# Point this at your own input file.\ninput_file <- \"records.csv\"\npostal_col <- \"postal_code\"\noutput_dir <- \"/tmp/RtmpHmyDnE\"\n\nrecords <- utils::read.csv(input_file, stringsAsFactors = FALSE, check.names = FALSE)\n\n# resolve_postal() reports codes in the correspondence's own format, so\n# the join key has to be normalized on this side too. Joining on the raw\n# column silently drops every code that was not already typed as \"A1A 1A1\".\n# resolve_postal() returns a row per input, so it is asked for each\n# distinct code once. Passing the column as-is would put duplicate keys\n# on both sides of the merge and multiply the rows.\nrecords[[\".postal_key\"]] <- normalize_postal_code(records[[postal_col]])\npostal_links <- resolve_postal(unique(records[[\".postal_key\"]]), all_links = TRUE)\njoined <- merge(\n  records, postal_links,\n  by.x = \".postal_key\", by.y = \"postal_code\",\n  all.x = TRUE, sort = FALSE\n)\njoined[[\".postal_key\"]] <- NULL\n\ndir.create(output_dir, recursive = TRUE, showWarnings = FALSE)\nutils::write.csv(joined, file.path(output_dir, \"postal_da.csv\"), row.names = FALSE)\n"
```
