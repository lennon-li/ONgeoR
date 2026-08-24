# Retrieve Ontario postal code points as a layer

Returns every Ontario postal-code centroid in the OPCC M1 release as an
`sf` POINT layer, so postal codes can be used as a crosswalk or map
layer without supplying a list of codes. The release is downloaded,
checksum-verified, and cached by the same machinery
[`resolve_postal_points()`](https://lennon-li.github.io/ONgeoR/reference/resolve_postal_points.md)
uses.

## Usage

``` r
retrieve_postal_points(bbox = NULL, refresh = FALSE)
```

## Arguments

- bbox:

  Optional `sf` bbox or numeric `xmin, ymin, xmax, ymax` vector in
  EPSG:4326. When supplied, only points inside the envelope are
  returned. The full province is 299,782 points, which is more than most
  maps or spatial joins can carry, so window the layer whenever the use
  case allows.

- refresh:

  Logical. If `TRUE`, discards the cached release and re-downloads it.
  Defaults to `FALSE`.

## Value

An `sf` POINT layer in EPSG:4326 with `postal_code`, `point_source`, and
`point_method` columns, and `source_name`, `source_url`, and
`retrieved_at` attributes attached for provenance. Postal codes without
coordinates (the 14 codes whose `point_source` is `"none"`) are dropped
silently, so the layer has one row per postal code that can be placed.

## See also

[`resolve_postal_points()`](https://lennon-li.github.io/ONgeoR/reference/resolve_postal_points.md)
to look up a known list of postal codes.

## Examples

``` r
if (FALSE) { # \dontrun{
# Whole province: 299,782 points.
postal_points <- retrieve_postal_points()

# A downtown Toronto window, which is what an interactive map should ask
# for.
toronto <- retrieve_postal_points(
  bbox = c(xmin = -79.42, ymin = 43.63, xmax = -79.36, ymax = 43.68)
)
nrow(toronto)
} # }
```
