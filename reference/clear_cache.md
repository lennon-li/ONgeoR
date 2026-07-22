# Clear Cached ONgeoR Data

Removes cached source data from ONgeoR's on-disk cache. By default, all
cached entries are removed. Supplying a source id removes only entries
whose cached metadata matches that source in the bundled source
registry.

## Usage

``` r
clear_cache(source_id = NULL)
```

## Arguments

- source_id:

  Character scalar or NULL. If supplied, clears only cache entries for
  this source registry id; if NULL (default), clears the entire cache.

## Value

Invisibly, the number of files removed.

## Examples

``` r
if (interactive()) {
  clear_cache()
  clear_cache("phu_boundaries")
}
```
