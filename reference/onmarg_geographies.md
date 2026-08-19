# ON-Marg geographies and the boundary layers they attach to

Lists the geographies published in the 2021 Ontario Marginalization
Index (ON-Marg), the key column each one is published under, and the
ONgeoR boundary source whose features that key identifies. This is a
static correspondence table: it performs no download.

## Usage

``` r
onmarg_geographies()
```

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with columns `geography` (the token accepted by
[`retrieve_onmarg()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_onmarg.md)),
`label`, `sheet` (the workbook sheet it is read from), `uid` (the key
column as published), `target_key` (the column that key appears under in
the boundary layer), `source_id` (the ONgeoR source, or `NA`), and
`quintiles` (whether quintile columns are published for that geography
as well as factor scores).

## Details

Two geographies (`"lhin"`, `"lhin_sr"`) have no `source_id`, because
ONgeoR does not currently provide Local Health Integration Network
boundaries. Their marginalization values are still retrievable with
[`retrieve_onmarg()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_onmarg.md);
they simply cannot be attached to a layer.

ON-Marg 2021 reports Public Health Units on the pre-2025, 34-unit
geography (`phu_boundaries_pre2025`). There is no correspondence for the
post-2025, 29-unit geography returned by
[`retrieve_phu()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_phu.md).

## See also

[`retrieve_onmarg()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_onmarg.md)
to fetch the values,
[`add_onmarg()`](https://lennon-li.github.io/ONgeoR/reference/add_onmarg.md)
to attach them to a layer.

## Examples

``` r
onmarg_geographies()
#> # A tibble: 10 × 7
#>    geography label                    sheet uid   target_key source_id quintiles
#>    <chr>     <chr>                    <chr> <chr> <chr>      <chr>     <lgl>    
#>  1 da        Dissemination Area       DA_2… DAUID DAUID      census_d… TRUE     
#>  2 ct        Census Tract             2021… CTUID CTUID      census_c… TRUE     
#>  3 ada       Aggregate Dissemination… 2021… ADAU… ADAUID     census_a… TRUE     
#>  4 csd       Census Subdivision       2021… CSDU… CSDUID     census_c… TRUE     
#>  5 ccs       Census Consolidated Sub… 2021… CCSU… CCSUID     census_c… TRUE     
#>  6 cd        Census Division          2021… CDUID CDUID      census_c… FALSE    
#>  7 cma       Census Metropolitan Area 2021… CMAU… CMAUID     census_c… FALSE    
#>  8 phu       Public Health Unit       2021… HUID  PHU_ID     phu_boun… FALSE    
#>  9 lhin      Local Health Integratio… 2021… LHIN… LHINUID    NA        FALSE    
#> 10 lhin_sr   Local Health Integratio… 2021… LHIN… LHINSRUID  NA        TRUE     
```
