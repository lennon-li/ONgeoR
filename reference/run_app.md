# Launch the ONgeoR Shiny app

Launches a thin Shiny UI over the package: pick a source and a target
layer, and the geometry pair alone decides the link (intersection,
nearest, containment, or raster sampling). View the map and table and
download `mapping.csv`, `pairs.csv`, `map.html`, and `reproduce.R`.

## Usage

``` r
run_app(...)
```

## Arguments

- ...:

  Passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

Called for its side effect (launches the Shiny app). Invisibly returns
`NULL`.

## Examples

``` r
if (interactive()) {
  run_app()
}
```
