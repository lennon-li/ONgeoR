# Retrieve municipal boundaries

Retrieves Ontario municipal boundaries from the LIO Open Data REST
service, either the upper/district tier (`LIO_Open03/13`) or the
lower/single tier (`LIO_Open03/14`).

## Usage

``` r
retrieve_municipal(
  tier = c("upper", "lower"),
  simplify = TRUE,
  refresh = FALSE,
  max_age = NULL
)
```

## Arguments

- tier:

  Character. Either `"upper"` (upper-tier and district municipalities)
  or `"lower"` (lower-tier and single-tier municipalities). Defaults to
  `"upper"`.

- simplify:

  Logical. If `TRUE` (the default), requests generalized geometry from
  the service.

- refresh:

  Logical. If `TRUE`, bypasses any cached copy and re-fetches from the
  live API. Defaults to `FALSE`.

- max_age:

  Numeric or `NULL`. Maximum acceptable cache age in days; older entries
  are re-fetched. Defaults to `NULL`.

## Value

An `sf` object of municipal boundary polygons, with `source_url`,
`source_name`, and `retrieved_at` attributes attached.

## Examples

``` r
if (interactive()) {
  upper_tier <- retrieve_municipal("upper")
}
```
