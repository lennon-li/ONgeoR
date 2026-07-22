# Resolve records from a layer by an identifier or name

Attribute lookup (not a spatial operation): given one or more query
values, return the matching record(s) from a layer. By default matches
an id column exactly or a name column by substring; either can be
overridden.

## Usage

``` r
resolve(layer, query, by = c("ident", "name"), column = NULL, match = NULL)
```

## Arguments

- layer:

  An `sf` object or `data.frame` with attribute columns.

- query:

  A character vector of one or more values to look up.

- by:

  Character. `"ident"` (default) uses the layer's id column with exact
  matching; `"name"` uses the name column with substring matching. The
  columns are auto-detected. Ignored when `column` is supplied.

- column:

  Character or `NULL`. Overrides the column to match against.

- match:

  Character or `NULL`. `"exact"` or `"substring"`. If `NULL` (default),
  derived from `by` (`ident` -\> exact, `name` -\> substring).

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with a `query` column, the layer's non-geometry columns for matches, and
`source_url` / `retrieved_at` provenance. A query with no match yields
one row with `NA` data columns; a single combined warning lists all
unmatched query values.

## Examples

``` r
if (interactive()) {
  airports <- retrieve_airport()
  resolve(airports, "CYYZ")
  resolve(airports, "toronto", by = "name")
}
```
