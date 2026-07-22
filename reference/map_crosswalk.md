# Map crosswalk source layers

Builds an interactive Leaflet map with one toggleable group for each
distinct source id used in a crosswalk workflow. Polygon layers are
rendered as polygons and point layers are rendered as circle markers.
Popups show the layer's guessed name field.

## Usage

``` r
map_crosswalk(layers, from_ids, to_ids)
```

## Arguments

- layers:

  A named list of `sf` objects keyed by source id.

- from_ids:

  Character vector of source ids used as crosswalk sources.

- to_ids:

  Character vector of source ids used as crosswalk targets.

## Value

A `leaflet` htmlwidget.

## Examples

``` r
if (interactive()) {
  from_ids <- "municipal_upper"
  to_ids <- "phu_boundaries"
  layers <- retrieve_layers(c(from_ids, to_ids))
  map_crosswalk(layers, from_ids, to_ids)
}
```
