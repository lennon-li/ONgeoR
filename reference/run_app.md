# Launch the ONgeoR Shiny app

Launches a thin Shiny UI over the package: pick sources, build a
crosswalk, view the map and table, and download `crosswalk.csv`,
`map.html`, and `reproduce.R`. A second tab finds the nearest targets to
an uploaded set of points.

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
