# Retrieve a synthetic coarse air-quality raster

Generates a deterministic synthetic `SpatRaster` of ground-level PM2.5
(micrograms per cubic metre) covering Ontario. No raster source exists
in the Ontario GeoHub registry (every registered source is vector), so
this function provides a reproducible raster surface to exercise the
package's raster linking and mapping paths end-to-end.

## Usage

``` r
retrieve_synthetic_raster(refresh = FALSE)
```

## Arguments

- refresh:

  Logical. Accepted for signature uniformity with the other
  `retrieve_*()` functions but unused: synthetic data is computed on
  demand and needs no cache or network access. Defaults to `FALSE`.

## Value

A single-layer `SpatRaster` (layer `"pm25"`) in EPSG:4326 spanning the
Ontario bounding box, with `source_name`, `source_url`, and
`retrieved_at` R attributes attached for provenance. Note that terra
operations may drop these attributes; downstream code reads them through
an NA-safe fallback.

## Details

Values are a pure, deterministic function of each cell's centroid
coordinates: a smooth north-to-south gradient (higher over the populated
south) plus two fixed Gaussian hotspots near Toronto and Ottawa. There
is no random component, so two calls return identical rasters.

## Examples

``` r
# \donttest{
# first call bears the one-time terra/GDAL startup cost
r <- retrieve_synthetic_raster()
# }
```
