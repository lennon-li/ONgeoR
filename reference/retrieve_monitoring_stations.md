# Retrieve monitoring station points

Retrieves Ontario water and weather monitoring station point locations
from the LIO Open Data REST service (`LIO_Open08/30`).

## Usage

``` r
retrieve_monitoring_stations(simplify = TRUE, refresh = FALSE, max_age = NULL)
```

## Arguments

- simplify:

  Logical. If `TRUE` (the default), requests generalized geometry from
  the service. Monitoring stations are point features, so simplification
  has no visible effect but is kept for consistency with the other LIO
  retrievers.

- refresh:

  Logical. If `TRUE`, bypasses any cached copy and re-fetches from the
  live API. Defaults to `FALSE`.

- max_age:

  Numeric or `NULL`. Maximum acceptable cache age in days; older entries
  are re-fetched. Defaults to `NULL`.

## Value

An `sf` object of monitoring station points, with `source_url`,
`source_name`, and `retrieved_at` attributes attached for provenance.

## Examples

``` r
if (FALSE) { # \dontrun{
stations <- retrieve_monitoring_stations()
} # }
```
