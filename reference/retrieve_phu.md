# Retrieve Public Health Unit boundaries

Retrieves Ontario Public Health Unit (PHU) boundaries from the LIO Open
Data REST service (`LIO_Open09/44`).

## Usage

``` r
retrieve_phu(simplify = FALSE, refresh = FALSE, max_age = NULL)
```

## Arguments

- simplify:

  Logical. If `TRUE`, requests generalized geometry from the service
  (`maxAllowableOffset = 10`) to reduce payload size. Defaults to
  `FALSE`: independently simplifying each PHU polygon distorts shared
  borders between adjacent units, which can misassign points near a
  boundary. This layer is small (34 features) and fast to fetch at full
  precision, so simplification is opt-in rather than default.

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
