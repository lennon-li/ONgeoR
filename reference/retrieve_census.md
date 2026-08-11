# Retrieve an Ontario 2021 census boundary layer

Retrieves one of the registered StatCan 2021 census cartographic
boundary layers. Requests always apply the Ontario `PRUID = '35'` filter
on the server, so Canada-wide features are never downloaded.

## Usage

``` r
retrieve_census(
  source_id,
  bbox = NULL,
  simplify = TRUE,
  refresh = FALSE,
  max_age = NULL
)
```

## Arguments

- source_id:

  Character scalar naming a registered `census_*` source.

- bbox:

  An `sf` bbox or numeric `xmin, ymin, xmax, ymax` vector in EPSG:4326.
  When supplied, requests only features intersecting the envelope.

- simplify:

  Logical. Whether to request generalized geometry.

- refresh:

  Logical. Whether to bypass the local cache.

- max_age:

  Numeric or `NULL`. Maximum acceptable cache age in days.

## Value

An `sf` object in EPSG:4326 with retrieval provenance attributes.

## Examples

``` r
if (FALSE) { # \dontrun{
census_divisions <- retrieve_census("census_cd_2021")
} # }
```
