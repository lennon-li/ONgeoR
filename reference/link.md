# Link geometries to a target layer by spatial relationship

Joins a source layer to a target layer using a spatial predicate. Covers
point-in-polygon and polygon-to-polygon joins, plus raster sources and
targets via the package's raster linking model (rasters are reduced to
vector geometries and delegated to the vector join path).

## Usage

``` r
link(source, target, predicate = c("within", "intersects", "contains"))
```

## Arguments

- source:

  An `sf` object (points or polygons), or a `data.frame` with `lon` and
  `lat` columns (assumed CRS 4326 / WGS 84). A `SpatRaster` `source` is
  reduced to its cell-centroid points (carrying the raster's value
  column(s), NA cells dropped) before the join.

- target:

  An `sf` object, typically polygons. A `SpatRaster` `target` is reduced
  to per-cell bounding-box polygons (carrying the raster's value
  column(s)) before the join, so each source point lands in the polygon
  of the cell that contains it (equivalent to raster sampling).

- predicate:

  Character. Spatial join predicate: `"within"` (default),
  `"intersects"`, or `"contains"`. Note: simplified boundary data (e.g.
  municipal boundaries retrieved with `simplify = TRUE`) often needs
  `"intersects"`, because `"within"` misses matches against generalized
  borders. For very complex geometry, simplify first (retrieve with
  `simplify = TRUE`, or
  [`sf::st_simplify()`](https://r-spatial.github.io/sf/reference/geos_unary.html))
  then link. `predicate = "within"` with a polygon `source` and point
  `target` is geometrically degenerate (a polygon is never "within" a
  point): every row will be unmatched (NA), and `link()` emits a warning
  before running the join. The join still runs and the return shape is
  unchanged. `predicate = "contains"` with a point `source` and polygon
  `target` is the mirror case (a point never "contains" a polygon) and
  warns the same way.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with the source's non-geometry columns, the matched target columns, and
`source_url` / `target_url` / `retrieved_at` provenance columns.
Column-name collisions between source and target follow
[`sf::st_join()`](https://r-spatial.github.io/sf/reference/st_join.html)'s
default `.x`/`.y` suffixing.

## See also

The "What linking does, by layer types" section of
[`vignette("building-crosswalks", package = "ONgeoR")`](https://lennon-li.github.io/ONgeoR/articles/building-crosswalks.md)
tabulates which operation each pair of layer geometries selects
(polygon/point/raster), including the raster sampling paths this
function delegates to.

## Examples

``` r
stations <- retrieve_monitoring_stations_simple()[1:20, ]
link(stations, retrieve_phu_simple())
#> # A tibble: 20 × 16
#>     OGF_ID.x STATION_NAME      STATION_IDENT NETWORK_NAME DATA_COLLECTION_METHOD
#>        <int> <chr>             <chr>         <chr>        <chr>                 
#>  1 294927289 GILMOUR           967695        NRF Snow Ne… Manual                
#>  2 294928880 WELLS             967828        NRF Snow Ne… Manual                
#>  3 294926885 CAPREOL PARK      138073        NRF Snow Su… Manual                
#>  4 294928636 STEPHEN'S GULCH   137993        NRF Snow Su… Manual                
#>  5 294926700 BEARPAW           121220        NRF Fire We… Auto                  
#>  6 294926579 ABITIBI RIVER AT… 136308        Federal Pro… Auto                  
#>  7 294927832 MASSEY            967756        NRF Snow Ne… Manual                
#>  8 294927360 Gull River at No… 149349        Federal Pro… Auto                  
#>  9 294928861 Wawa Creek near … 140204        Federal Pro… Auto                  
#> 10 294928124 OBA SNOW          148188        OPG Snow Su… Manual                
#> 11 294928696 Teeswater River … 141956        Federal Pro… Auto                  
#> 12 294928816 VICTORIA BEACH    127757        MSC Monitor… Auto                  
#> 13 294928295 PROTON            137749        NRF Snow Su… Manual                
#> 14 294928430 SCHNEIDER CREEK … 135171        Federal Pro… Auto                  
#> 15 294926995 CORBETTON         137389        NRF Snow Su… Manual                
#> 16 294927499 Kaministiquia Ri… 139983        Federal Pro… Auto                  
#> 17 294928357 Rigaud River nea… 145837        Federal Pro… Auto                  
#> 18 294927108 EARLTON A         133491        MSC Monitor… Auto                  
#> 19 294926915 Centreville Cree… 1252503       Federal Pro… Auto                  
#> 20 294927655 LAKE OF THE WOOD… 136496        Federal Pro… Auto                  
#> # ℹ 11 more variables: OGF_ID.y <int>, PHU_ID <int>, PHU_NAME_ENG <chr>,
#> #   PHU_NAME_FR <chr>, GEOMETRY_UPDATE_DATETIME <dbl>,
#> #   EFFECTIVE_DATETIME <dbl>, SYSTEM_DATETIME <dbl>, OBJECTID <int>,
#> #   source_url <lgl>, target_url <chr>, retrieved_at <dttm>
```
