# Retrieve Public Health Unit boundaries

Retrieves Ontario Public Health Unit (PHU) boundaries from the LIO Open
Data REST service (`LIO_Open09/44`).

## Usage

``` r
retrieve_phu(simplify = TRUE, refresh = FALSE, max_age = NULL)
```

## Arguments

- simplify:

  Logical. If `TRUE` (the default), requests generalized geometry from
  the service (`maxAllowableOffset = 1e-04`, i.e. 0.0001 degrees, since
  the service returns EPSG:4326 – roughly 11 m on the ground) to reduce
  payload size. Set to `FALSE` if you need full-precision geometry, but
  be aware that the LIO service may fail to serve the full-resolution
  layer intermittently; if that occurs, retry with `simplify = TRUE` or
  set `refresh = TRUE`.

- refresh:

  Logical. If `TRUE`, bypasses any cached copy and re-fetches from the
  live API. Defaults to `FALSE`.

- max_age:

  Numeric or `NULL`. Maximum acceptable cache age in days; older entries
  are re-fetched. Defaults to `NULL`.

## Value

An `sf` object of PHU boundary polygons, with `source_url`,
`source_name`, and `retrieved_at` attributes attached for provenance.

## Examples

``` r
if (interactive()) {
  phu <- retrieve_phu()
}
```
