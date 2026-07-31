# Retrieve simplified Public Health Unit boundaries

Returns the built-in simplified Ontario Public Health Unit (PHU)
boundary layer shipped in `inst/extdata/phu_simple.rds`. This layer is
intended as a lightweight, always-on reference outline for the Shiny app
and other mapping code. It is NOT a substitute for
[`retrieve_phu()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_phu.md):
use
[`retrieve_phu()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_phu.md)
when you need full-resolution, authoritative PHU boundaries or
up-to-date provenance.

## Usage

``` r
retrieve_phu_simple()
```

## Value

An `sf` object of 34 simplified PHU boundary `MULTIPOLYGON`s, with
`source_url`, `source_name`, and `retrieved_at` attributes inherited
from the full-resolution source.

## Details

The built-in file was produced by fetching full-resolution PHU
boundaries from the LIO Open Data REST service, reprojecting to
EPSG:3161 (Ontario MNR Lambert), simplifying with
`sf::st_simplify(dTolerance = 250, preserveTopology = TRUE)`,
reprojecting back to the source CRS, and casting to `MULTIPOLYGON`. The
source data are distributed under the Open Government Licence - Ontario.

## Examples

``` r
phu_simple <- retrieve_phu_simple()
nrow(phu_simple)
#> [1] 34
```
