# Resolve Ontario postal codes to point coordinates

Downloads and verifies the immutable OPCC M1 postal-code centroid
release, then caches the parsed table locally. Postal codes are matched
after uppercasing and normalizing whitespace.

## Usage

``` r
resolve_postal_points(x, as_sf = FALSE)
```

## Arguments

- x:

  Character vector of Ontario postal codes.

- as_sf:

  Logical scalar. If `FALSE` (default), return a tibble. If `TRUE`,
  return an `sf` POINT layer in EPSG:4326.

## Value

With `as_sf = FALSE`, a
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with one row per input element, in input order: postal code,
coordinates, point provenance, source URL, and retrieval time. With
`as_sf = TRUE`, an `sf` POINT layer in EPSG:4326 containing only the
rows with coordinates. An unmatched postal code, or a matched code whose
`point_source` is `"none"`, yields one row with `NA` coordinates; a
single combined warning lists all unmatched postal codes.

## Coverage

The release covers 299,796 Ontario postal codes: 282,409 matched by
`nar_centroid` (address-derived coordinates), 17,373 by `geonames`
(place-level coordinates, coarser), and 14 reported as `none`, which
have no coordinates and are returned as `NA`.

## Examples

``` r
if (FALSE) { # \dontrun{
resolve_postal_points(c("K1A0B1", "M5V 3A8"))
resolve_postal_points("M5V 3A8", as_sf = TRUE)
} # }
```
