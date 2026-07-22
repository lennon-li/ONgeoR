# Retrieve Ontario Railway Network (ORWN) station points

Retrieves railway station point locations from the Ontario Railway
Network (ORWN) via the LIO Open Data REST service (`LIO_Open04/15`).

## Usage

``` r
retrieve_orwn_station(refresh = FALSE, max_age = NULL)
```

## Arguments

- refresh:

  Logical. If `TRUE`, bypasses any cached copy and re-fetches from the
  live API. Defaults to `FALSE`.

- max_age:

  Numeric or `NULL`. Maximum acceptable cache age in days; older entries
  are re-fetched. Defaults to `NULL`.

## Value

An `sf` object of ORWN station points, with `source_url`, `source_name`,
and `retrieved_at` attributes attached for provenance.

## Examples

``` r
if (interactive()) {
  stations <- retrieve_orwn_station()
}
```
