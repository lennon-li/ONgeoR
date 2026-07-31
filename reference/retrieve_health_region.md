# Retrieve Ontario Health Region boundaries

Retrieves Ontario Health Region boundaries from the LIO Open Data REST
service (`LIO_Open09/52`).

## Usage

``` r
retrieve_health_region(simplify = TRUE, refresh = FALSE, max_age = NULL)
```

## Arguments

- simplify:

  Logical. If `TRUE` (the default), requests generalized geometry from
  the service. Unlike
  [`retrieve_phu()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_phu.md),
  this layer's full-precision geometry is unreliable to fetch: these 6
  regions are province-scale with much more complex boundaries than the
  34 PHUs, and the LIO ArcGIS service intermittently fails ("Could not
  access any server machines") on the unsimplified request for this
  specific layer. Set to `FALSE` if you need full precision and are
  prepared to retry on failure.

- refresh:

  Logical. If `TRUE`, bypasses any cached copy and re-fetches from the
  live API. Defaults to `FALSE`.

- max_age:

  Numeric or `NULL`. Maximum acceptable cache age in days; older entries
  are re-fetched. Defaults to `NULL`.

## Value

An `sf` object of Ontario Health Region boundary polygons, with
`source_url`, `source_name`, and `retrieved_at` attributes attached.

## Examples

``` r
if (FALSE) { # \dontrun{
# Retrieves from the Ontario LIO REST service and caches the result.
health_regions <- retrieve_health_region()
} # }
```
