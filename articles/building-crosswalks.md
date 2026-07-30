# Building geographic crosswalks

A crosswalk records how features in one polygon layer relate to features
in another.
[`build_crosswalk()`](https://lennon-li.github.io/ONgeoR/reference/build_crosswalk.md)
standardizes the result and includes provenance needed to audit it
later. This vignette uses synthetic polygons and requires no network
connection.

## A reproducible polygon example

``` r

library(ONgeoR)

square <- function(xmin, ymin, xmax, ymax) {
  sf::st_polygon(list(rbind(
    c(xmin, ymin), c(xmax, ymin), c(xmax, ymax),
    c(xmin, ymax), c(xmin, ymin)
  )))
}

phu <- sf::st_sf(
  PHU_ID = c("P1", "P2"),
  PHU_NAME_ENG = c("West PHU", "East PHU"),
  geometry = sf::st_sfc(
    square(0, 0, 1, 1), square(1, 0, 2, 1), crs = 3857
  )
)
municipal <- sf::st_sf(
  MUNID = c("M1", "M2"),
  MUNICIPAL_NAME = c("West municipality", "East municipality"),
  geometry = sf::st_sfc(
    square(0.1, 0.1, 0.9, 0.9), square(1.1, 0.1, 1.9, 0.9), crs = 3857
  )
)

attr(phu, "source_name") <- "Synthetic PHU boundaries"
attr(phu, "source_url") <- "https://example.invalid/phu"
attr(phu, "retrieved_at") <- as.POSIXct("2026-01-01", tz = "UTC")
attr(municipal, "source_name") <- "Synthetic municipal boundaries"
attr(municipal, "source_url") <- "https://example.invalid/municipal"

crosswalk <- build_crosswalk(municipal, phu, method = "within")
crosswalk
#> # A tibble: 2 × 14
#>   from_id from_name         from_source     to_id to_name to_source match_method
#>   <chr>   <chr>             <chr>           <chr> <chr>   <chr>     <chr>       
#> 1 M1      West municipality Synthetic muni… P1    West P… Syntheti… within      
#> 2 M2      East municipality Synthetic muni… P2    East P… Syntheti… within      
#> # ℹ 7 more variables: match_distance_km <dbl>, coverage <dbl>,
#> #   from_id_col <chr>, to_id_col <chr>, source_url_from <chr>,
#> #   source_url_to <chr>, retrieved_at <dttm>
```

The default path for polygon-to-polygon linking is now
[`build_link()`](https://lennon-li.github.io/ONgeoR/reference/build_link.md),
which calls
[`build_intersection()`](https://lennon-li.github.io/ONgeoR/reference/build_intersection.md)
and returns every overlapping pair with area shares in a single pass.
This removes the need to choose a predicate for most workflows.
[`build_crosswalk()`](https://lennon-li.github.io/ONgeoR/reference/build_crosswalk.md)
and its five methods (`within`, `intersects`, `point_on_surface`,
`largest_overlap`, `weighted`) remain available for direct callers who
need a specific rule, such as when a workflow depends on the one-to-one
assignment that `largest_overlap` provides.

Real municipal layers are simplified by default. Generalizing each layer
can move nominally shared borders enough that a municipal polygon is no
longer strictly within a PHU polygon. For those layers, the intersection
path handles the overlap naturally: every positive-area overlap is
reported, and the `share_of_target` and `share_of_source` columns let
you filter or weight the result after the fact.

## What linking does, by layer types

[`build_link()`](https://lennon-li.github.io/ONgeoR/reference/build_link.md)
inspects the geometry types of the two layers and dispatches to the
appropriate operation. The table below is rendered from the same matrix
that drives the Shiny app and the package internals.

| source_kind | target_kind | mode | what_it_does | output |
|:---|:---|:---|:---|:---|
| point | point | Nearest | Each target point is matched to its single nearest source point. | nearest table |
| point | polygon | Containment | Each point is matched to the boundary it falls inside. | crosswalk |
| point | raster | Sampling | Each point takes the value of the cell containing it. | linked values table |
| polygon | point | Containment | Direction is auto-corrected internally. | crosswalk |
| polygon | polygon | Intersection | Every overlapping pair, with the share of each target covered and the share of each source falling inside. | intersection table |
| polygon | raster | Sampling | Each polygon samples the raster values it overlaps. | linked values table |
| raster | point | Sampling | Raster reduced to cell centroids. | linked values table |
| raster | polygon | Cell sampling into boundaries | Each cell centroid is matched to the boundary it falls inside. | linked values table |
| raster | raster | Not supported | Not supported; align/resample with terra first. | none |

Linking never creates or emits geometry: the output is always an
assignment or values table, and overlap areas are used only as internal
arithmetic.

Two area-share columns are returned for polygon-to-polygon linking. They
are not interchangeable, and getting the distinction wrong is silent:

- `share_of_target` is the fraction of the TARGET polygon covered by the
  source. It characterizes how much of the target is accounted for by
  each overlapping source.
- `share_of_source` is the fraction of the SOURCE polygon falling inside
  the target. It is the apportionment weight to use when moving an
  extensive variable such as population or case counts from the source
  to the target.

[`build_intersection()`](https://lennon-li.github.io/ONgeoR/reference/build_intersection.md)
returns every overlapping pair with both area shares in one pass, which
covers the same ground as the `weighted` method of
[`build_crosswalk()`](https://lennon-li.github.io/ONgeoR/reference/build_crosswalk.md)
without requiring a method choice.

## Weighted crosswalks

Use `weighted` when one source polygon should be apportioned across
every target it overlaps, such as many-to-many allocation. Use
`largest_overlap` when each source needs one target assignment. Weighted
coverage values for a source sum to at most 1; `largest_overlap` selects
the largest weighted row.
[`build_intersection()`](https://lennon-li.github.io/ONgeoR/reference/build_intersection.md)
now returns every overlapping pair with both area shares in one pass,
which covers the same ground without a method choice.

``` r

weighted_from <- sf::st_sf(
  from_id = c("F1", "F2"),
  geometry = sf::st_sfc(
    square(0, 0, 1, 1), square(1, 0, 2, 1), crs = 3857
  )
)
weighted_to <- sf::st_sf(
  to_id = c("T1", "T2"),
  geometry = sf::st_sfc(
    square(0, 0, 1.25, 1), square(1.25, 0, 2, 1), crs = 3857
  )
)
weighted <- build_crosswalk(weighted_from, weighted_to, method = "weighted")
weighted[, c("from_id", "to_id", "coverage")]
```

## Inspect the audit fields

The canonical output contains source and target identifiers and names,
the registry-style source labels, the matching method, reserved distance
field, source URLs, and the target retrieval time.

``` r

names(crosswalk)
#>  [1] "from_id"           "from_name"         "from_source"      
#>  [4] "to_id"             "to_name"           "to_source"        
#>  [7] "match_method"      "match_distance_km" "coverage"         
#> [10] "from_id_col"       "to_id_col"         "source_url_from"  
#> [13] "source_url_to"     "retrieved_at"
crosswalk[, c(
  "from_id", "from_name", "to_id", "to_name", "match_method",
  "source_url_from", "source_url_to", "retrieved_at"
)]
#> # A tibble: 2 × 8
#>   from_id from_name     to_id to_name match_method source_url_from source_url_to
#>   <chr>   <chr>         <chr> <chr>   <chr>        <chr>           <chr>        
#> 1 M1      West municip… P1    West P… within       https://exampl… https://exam…
#> 2 M2      East municip… P2    East P… within       https://exampl… https://exam…
#> # ℹ 1 more variable: retrieved_at <dttm>
```

`match_distance_km` is currently `NA` because
[`build_crosswalk()`](https://lennon-li.github.io/ONgeoR/reference/build_crosswalk.md)
implements topological polygon matching, not nearest-neighbour matching.

Export only after checking unmatched or duplicated source identifiers
and the provenance fields. This write is deliberately not run during the
vignette build:

``` r

write.csv(crosswalk, "municipal-to-phu.csv", row.names = FALSE)
```

## Live Ontario example

The following example requires network access or populated ONgeoR caches
and is not executed while this vignette builds.

``` r

municipal <- retrieve_municipal("upper")
phu <- retrieve_phu()

municipal_to_phu <- build_crosswalk(
  municipal,
  phu,
  method = "intersects"
)

map_layers(Municipalities = municipal, PHUs = phu)
```
