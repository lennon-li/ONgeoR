# List Cached ONgeoR Data

Lists the source metadata currently stored in ONgeoR's on-disk cache.

## Usage

``` r
list_cache()
```

## Value

A tibble::tibble() with columns source_name, retrieved_at, age_days,
file_size_kb – one row per cached entry.

## Examples

``` r
if (interactive()) {
  list_cache()
}
```
