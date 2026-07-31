# Retrieve airport boundaries

Retrieves official airport boundaries from the LIO Open Data REST
service (`LIO_Open05/0`).

## Usage

``` r
retrieve_airport(simplify = FALSE, refresh = FALSE, max_age = NULL)
```

## Arguments

- simplify:

  Logical. If `TRUE`, requests generalized geometry from the service
  (`maxAllowableOffset = 1e-04`, i.e. 0.0001 degrees, since the service
  returns EPSG:4326 – roughly 11 m on the ground). Defaults to `FALSE`:
  confirmed live that the simplified request returns corrupted geometry
  for this layer (`GEOMETRYCOLLECTION` instead of polygons, for all 403
  features) rather than valid generalized boundaries – the same class of
  distortion documented for
  [`retrieve_phu()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_phu.md),
  caught here by live-testing rather than assumed from feature count. Do
  not flip this default without re-testing live.

- refresh:

  Logical. If `TRUE`, bypasses any cached copy and re-fetches from the
  live API. Defaults to `FALSE`.

- max_age:

  Numeric or `NULL`. Maximum acceptable cache age in days; older entries
  are re-fetched. Defaults to `NULL`.

## Value

An `sf` object of airport boundary polygons, with `source_url`,
`source_name`, and `retrieved_at` attributes attached.

## Examples

``` r
if (interactive()) {
  airports <- retrieve_airport()
}
```
