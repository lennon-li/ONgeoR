# Retrieve HIVE Grid boundaries

Returns the built-in HIVE Grid dataset, a custom hierarchical polygon
grid (Levels 1-3, 1629 features) maintained by the package author.
Unlike the other `retrieve_*()` functions, this does not call a live web
service: the data ships with the package as a static, pre-simplified
`sf` object (see `data-raw/hive.R` for the reproducible prep pipeline
that generated it from the author's source shapefile).

## Usage

``` r
retrieve_hive(refresh = FALSE)
```

## Arguments

- refresh:

  Logical. Accepted for signature uniformity with the other
  `retrieve_*()` functions but unused: HIVE is a static built-in dataset
  with no live source to re-fetch from. Defaults to `FALSE`.

## Value

An `sf` object of HIVE Grid polygons (`GRID_ID`, `Level`, `HIVE_ID`
columns) in EPSG:4326, with `source_url`, `source_name`, and
`retrieved_at` attributes attached for provenance.

## Examples

``` r
hive <- retrieve_hive()
nrow(hive)
#> [1] 1629
```
