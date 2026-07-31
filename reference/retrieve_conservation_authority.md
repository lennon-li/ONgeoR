# Retrieve Conservation Authority administrative areas

Retrieves Conservation Authority administrative area boundaries from the
LIO Open Data REST service (`LIO_Open03/11`).

## Usage

``` r
retrieve_conservation_authority(
  simplify = TRUE,
  refresh = FALSE,
  max_age = NULL
)
```

## Arguments

- simplify:

  Logical. If `TRUE` (the default), requests generalized geometry from
  the service. Conservation Authority boundaries are province-scale
  watersheds; simplification keeps the payload small without losing
  analytic utility for most crosswalk use-cases.

- refresh:

  Logical. If `TRUE`, bypasses any cached copy and re-fetches from the
  live API. Defaults to `FALSE`.

- max_age:

  Numeric or `NULL`. Maximum acceptable cache age in days; older entries
  are re-fetched. Defaults to `NULL`.

## Value

An `sf` object of Conservation Authority boundary polygons, with
`source_url`, `source_name`, and `retrieved_at` attributes attached for
provenance.

## Examples

``` r
if (FALSE) { # \dontrun{
# Retrieves from the Ontario LIO REST service and caches the result.
ca_areas <- retrieve_conservation_authority()
} # }
```
