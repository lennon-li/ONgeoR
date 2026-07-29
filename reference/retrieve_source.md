# Retrieve a layer by source registry id

Dispatches to the appropriate `retrieve_*()` function for a given source
id, so callers can retrieve any registered layer without knowing which
underlying retrieval function backs it.

## Usage

``` r
retrieve_source(source_id, refresh = FALSE, max_age = NULL)
```

## Arguments

- source_id:

  Character scalar. A source id from
  [`list_sources()`](https://lennon-li.github.io/ONgeoR/reference/list_sources.md).

- refresh:

  Logical. If `TRUE`, bypasses any cached copy and re-fetches from the
  live API. Defaults to `FALSE`.

- max_age:

  Maximum cache age in days for registry-backed LIO sources. Defaults to
  `NULL`, which accepts any cached copy.

## Value

An `sf` object, or a `SpatRaster` for raster sources (e.g.
`"synthetic_air_quality"`).

## Examples

``` r
if (interactive()) {
  phu <- retrieve_source("phu_boundaries")
}
```
