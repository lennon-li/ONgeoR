# Retrieve MOH service locations

Retrieves Ministry of Health service location points (hospitals,
clinics, and other health service facilities) from the LIO Open Data
REST service (`LIO_Open09/26`), optionally filtered by service type.

## Usage

``` r
retrieve_moh_service_locations(
  service_type = NULL,
  refresh = FALSE,
  max_age = NULL
)
```

## Arguments

- service_type:

  Character or `NULL`. If supplied, filters results to rows where
  `SERVICE_TYPE` equals this value. If `NULL` (the default), no filter
  is applied.

- refresh:

  Logical. If `TRUE`, bypasses any cached copy and re-fetches from the
  live API. Defaults to `FALSE`.

- max_age:

  Numeric or `NULL`. Maximum acceptable cache age in days; older entries
  are re-fetched. Defaults to `NULL`.

## Value

An `sf` object of MOH service location points, with `source_url`,
`source_name`, and `retrieved_at` attributes attached.

## Examples

``` r
if (FALSE) { # \dontrun{
# Retrieves from the Ontario LIO REST service and caches the result.
hospitals <- retrieve_moh_service_locations(service_type = "Hospital")
} # }
```
