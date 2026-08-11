# Retrieve the pre-2025 simplified Public Health Unit boundaries

Returns the built-in pre-2025 Ontario Public Health Unit (PHU) boundary
layer shipped in `inst/extdata/phu_simple_pre2025.rds`. This 250 m
simplified snapshot preserves the 34-boundary PHU vintage that pre-dates
the 2025 boundary changes.

## Usage

``` r
retrieve_phu_pre2025()
```

## Value

An `sf` object of 34 simplified pre-2025 PHU boundary `MULTIPOLYGON`s in
WGS 84.

## Details

LIO no longer serves this vintage, so the snapshot cannot be refreshed.
Use
[`retrieve_phu_simple()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_phu_simple.md)
for the current bundled PHU boundaries, or
[`retrieve_phu()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_phu.md)
for the current live LIO layer.

## Examples

``` r
phu_pre2025 <- retrieve_phu_pre2025()
nrow(phu_pre2025)
#> [1] 34
```
