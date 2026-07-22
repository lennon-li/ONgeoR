# Map one or more layers on an interactive leaflet map

Draws each `sf` layer on a single leaflet map, dispatching on geometry
type: polygons are drawn as filled outlines, points as circle markers. A
`SpatRaster` layer is drawn as a coloured raster image with a legend.
Layers get a toggle in a layers-control.

## Usage

``` r
map_layers(..., colors = NULL)
```

## Arguments

- ...:

  One or more `sf` objects (points or polygons) or `SpatRaster` objects.
  Arguments may be named; a name sets that layer's group label.

- colors:

  Optional character vector of colors, one per layer (recycled if
  shorter). If `NULL` (default), distinct colors are assigned from a
  built-in qualitative palette.

## Value

A `leaflet` htmlwidget.

## Examples

``` r
if (interactive()) {
  map_layers(retrieve_phu(), retrieve_moh_service_locations(service_type = "Hospital"))
}
```
