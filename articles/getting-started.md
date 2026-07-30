# Getting started with ONgeoR

ONgeoR helps a public-health analyst connect locations and boundaries to
Ontario health geography while retaining source provenance. This
vignette uses small synthetic layers so that it builds without a network
connection. The equivalent live calls are shown separately and are not
run.

## Discover and retrieve sources

The package registry describes the available authoritative layers.

``` r

library(ONgeoR)

head(list_sources())
#> # A tibble: 6 × 4
#>   source_id              name                       geography_type feature_count
#>   <chr>                  <chr>                      <chr>                  <int>
#> 1 phu_boundaries         MOH Public Health Unit Bo… boundary                  34
#> 2 ontario_health_regions Ontario Health Region      boundary                   6
#> 3 municipal_upper        Municipal Bnd Upper And D… boundary                  98
#> 4 municipal_lower        Municipal Bnd Lower And S… boundary                 685
#> 5 airport_official       Airport Official           boundary                 403
#> 6 waste_management_site  Waste Management Site      boundary                 813
get_source("phu_boundaries")
#> $name
#> [1] "MOH Public Health Unit Boundary"
#> 
#> $service_layer
#> [1] "LIO_Open09/44"
#> 
#> $geography_type
#> [1] "boundary"
#> 
#> $feature_count
#> [1] 34
#> 
#> $update_frequency
#> [1] "unknown"
#> 
#> $key_fields
#> [1] "PHU_ID"       "PHU_NAME_ENG" "PHU_NAME_FR" 
#> 
#> $license
#> [1] "Open Government Licence - Ontario"
#> 
#> $source_url
#> [1] "https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open09/MapServer/44"
```

Retrieval functions download an `sf` layer, attach `source_url`,
`source_name`, and `retrieved_at` attributes, and save it in the ONgeoR
cache. A normal call reuses the cached result. Use `refresh = TRUE` when
you deliberately want a new copy from the source. Record the provenance
attributes alongside exported analysis results because the upstream
layer can change.

The following calls require network access or an existing cache and
therefore are not executed while this vignette builds.

``` r

phu <- retrieve_phu()
hospitals <- retrieve_moh_service_locations(service_type = "Hospital")

# Deliberately bypass the cache and retrieve a new copy.
phu_fresh <- retrieve_phu(refresh = TRUE)

attr(phu, "source_url")
attr(phu, "source_name")
attr(phu, "retrieved_at")
```

## Link locations to boundaries

Here are two synthetic health-unit polygons, two analyst locations, and
three facilities. The column names resemble the registered LIO schemas
so that the same code structure transfers to live data.

``` r

square <- function(xmin, ymin, xmax, ymax) {
  sf::st_polygon(list(rbind(
    c(xmin, ymin), c(xmax, ymin), c(xmax, ymax),
    c(xmin, ymax), c(xmin, ymin)
  )))
}

phu_demo <- sf::st_sf(
  PHU_ID = c("A", "B"),
  PHU_NAME_ENG = c("West Demo PHU", "East Demo PHU"),
  geometry = sf::st_sfc(
    square(-80.0, 43.0, -79.5, 43.5),
    square(-79.5, 43.0, -79.0, 43.5),
    crs = 4326
  )
)
attr(phu_demo, "source_name") <- "Synthetic PHU boundaries"
attr(phu_demo, "source_url") <- "https://example.invalid/phu"
attr(phu_demo, "retrieved_at") <- as.POSIXct("2026-01-01", tz = "UTC")

locations <- data.frame(
  location = c("Clinic request 1", "Clinic request 2"),
  lon = c(-79.75, -79.25),
  lat = c(43.25, 43.25)
)

linked <- link(locations, phu_demo)
linked[, c("location", "PHU_ID", "PHU_NAME_ENG", "target_url")]
#> # A tibble: 2 × 4
#>   location         PHU_ID PHU_NAME_ENG  target_url                 
#>   <chr>            <chr>  <chr>         <chr>                      
#> 1 Clinic request 1 A      West Demo PHU https://example.invalid/phu
#> 2 Clinic request 2 B      East Demo PHU https://example.invalid/phu
```

For live Ontario boundaries, the corresponding operation is:

``` r

phu <- retrieve_phu()
linked <- link(locations, phu)
```

## Find or resolve facilities

[`nearest()`](https://lennon-li.github.io/ONgeoR/reference/nearest.md)
performs a spatial proximity search.
[`resolve()`](https://lennon-li.github.io/ONgeoR/reference/resolve.md)
instead looks up attributes by an identifier or name; it is not a
spatial operation.

``` r

facilities_demo <- sf::st_as_sf(
  data.frame(
    MOH_SERVICE_PROVIDER_IDENT = c("F001", "F002", "F003"),
    ENGLISH_NAME = c("West Hospital", "Central Clinic", "East Hospital"),
    lon = c(-79.78, -79.52, -79.22),
    lat = c(43.24, 43.27, 43.24)
  ),
  coords = c("lon", "lat"), crs = 4326
)
attr(facilities_demo, "source_name") <- "Synthetic facilities"
attr(facilities_demo, "source_url") <- "https://example.invalid/facilities"
attr(facilities_demo, "retrieved_at") <- as.POSIXct("2026-01-01", tz = "UTC")

nearby <- nearest(locations, facilities_demo, k = 2)
nearby[, c("location", "rank", "ENGLISH_NAME", "distance_km")]
#> # A tibble: 4 × 4
#>   location          rank ENGLISH_NAME   distance_km
#>   <chr>            <int> <chr>                <dbl>
#> 1 Clinic request 1     1 West Hospital         2.67
#> 2 Clinic request 1     2 Central Clinic       18.8 
#> 3 Clinic request 2     1 East Hospital         2.67
#> 4 Clinic request 2     2 Central Clinic       22.0

resolve(facilities_demo, "F002")
#> # A tibble: 1 × 5
#>   query MOH_SERVICE_PROVIDER_IDENT ENGLISH_NAME   source_url retrieved_at       
#>   <chr> <chr>                      <chr>          <chr>      <dttm>             
#> 1 F002  F002                       Central Clinic https://e… 2026-01-01 00:00:00
resolve(facilities_demo, "hospital", by = "name")
#> # A tibble: 2 × 5
#>   query    MOH_SERVICE_PROVIDER_ID…¹ ENGLISH_NAME source_url retrieved_at       
#>   <chr>    <chr>                     <chr>        <chr>      <dttm>             
#> 1 hospital F001                      West Hospit… https://e… 2026-01-01 00:00:00
#> 2 hospital F003                      East Hospit… https://e… 2026-01-01 00:00:00
#> # ℹ abbreviated name: ¹​MOH_SERVICE_PROVIDER_IDENT
```

The live versions use the retrieved facility layer:

``` r

hospitals <- retrieve_moh_service_locations(service_type = "Hospital")
nearby <- nearest(locations, hospitals, k = 3, max_dist_km = 25)
facility <- resolve(hospitals, "12345")
named_facilities <- resolve(hospitals, "general", by = "name")
```

[`build_link()`](https://lennon-li.github.io/ONgeoR/reference/build_link.md)
is the no-choice entry point: it inspects the geometry types of the two
layers and dispatches to the appropriate operation (nearest matching for
point-point, intersection for polygon-polygon, containment or sampling
for mixed types). Use it when you do not need to override the default
behaviour.

## Audit and map the result

Returned tables carry provenance columns such as `source_url`,
`target_url`, and `retrieved_at`. Inspect them before exporting,
particularly after a cache refresh. Interactive maps are useful for
checking surprising assignments and nearest matches.

``` r

map_layers(PHUs = phu, Hospitals = hospitals)
map_nearest(locations, hospitals, k = 3, max_dist_km = 25)
```

These maps are review aids, not substitutes for checking source
metadata, geometry precision, unmatched records, and the provenance
columns in the analysis output.
