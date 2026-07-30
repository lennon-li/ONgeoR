# Launching and using the ONgeoR Shiny app

ONgeoR ships a browser-based Shiny application that lets you build
spatial crosswalks and run nearest-match searches without writing any R
code. This vignette describes how to launch the app and use its two main
tabs.

## Launching the app

Open a browser-based session with a single call:

``` r

ONgeoR::run_app()
```

[`run_app()`](https://lennon-li.github.io/ONgeoR/reference/run_app.md)
calls [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html) on
the bundled app directory (`inst/shiny`). By default Shiny opens a
browser tab automatically. You can pass additional arguments to control
the port or host:

``` r

ONgeoR::run_app(port = 4321, launch.browser = FALSE)
```

The app requires the `shiny` and `bslib` packages;
[`run_app()`](https://lennon-li.github.io/ONgeoR/reference/run_app.md)
checks for them at startup and prompts you to install them if they are
missing.

## The two tabs

### Link tab

The **Link** tab retrieves two registered Ontario GeoHub or LIO layers
and joins them spatially.

Workflow:

1.  **Source layer** – Select a source from the “Source layer” dropdown.
    This is the layer whose identifying attributes get attached to the
    result (e.g. Public Health Unit boundaries).
2.  **Target layer** – Select a second source from the “Target layer”
    dropdown (e.g. MOH Service Locations). The result is shaped like
    this layer: one row per target feature.
3.  **Preview on map** – Click **Preview on map** to retrieve both
    layers and draw them on an interactive Leaflet map. Inspect the map
    to confirm the layers align as expected before joining. **Join stays
    greyed out until a preview succeeds** for the currently selected
    pair, and re-greys if you change either dropdown.
4.  **Join** – Click **Join** to open a confirmation that names both
    layers with their dimensions and states the expected result shape,
    e.g. “11,625 rows x 14 columns – one row per target feature”.
    Nothing is retrieved or computed until you confirm. For the “Any
    overlap” and “Apportion across overlaps” rules the result can be
    longer than the target layer, because both keep every overlap; the
    confirmation says so.

The direction is fixed: every row assigns a target feature to the source
feature that contains it, so the source layer is always the one whose
`to_id`/`to_name` columns appear in the result.

### Find Nearest tab

The **Find Nearest** tab performs a nearest-match search and draws
connector lines between each source point and its nearest target.

Workflow:

1.  **Source points** – Upload a CSV of your own starting points using
    the “Source points (CSV with lon/lat columns)” file input (e.g. a
    set of clinic locations).
2.  **Target source** – Select the registered candidate layer to search
    within (e.g. MOH Service Locations).
3.  **k** – Set the number of nearest targets to return per source point
    (default 1).
4.  **max_dist_km** – Cap results to targets within this radius.
5.  **Preview on map / Find nearest** – Preview draws the uploaded
    points and target layer; Find nearest runs the search. The map shows
    connector lines from each source to its nearest target(s), and the
    result table lists the distances.

## Download buttons

Each tab has its own download buttons, which become available after the
corresponding operation completes.

Link tab:

| Button | Output |
|----|----|
| **Download map** | `map.html` – the Leaflet map as a standalone HTML file |
| **Download results** | `mapping.csv` (or `linked.csv` for raster linking) |
| **Download script** | `reproduce.R` – an R script that reproduces the result from scratch |

Find Nearest tab:

| Button | Output |
|----|----|
| **Download map** | `map.html` – the Leaflet map as a standalone HTML file |
| **Download results** | `nearest.csv` – the nearest-match table |

The `map.html` file embeds the widget’s JavaScript and data, so it opens
without R installed; note the basemap tiles are still fetched from the
tile provider, so viewing it requires network access.

## A note on automated testing

The source picker dropdowns use selectize.js, a JavaScript-enhanced
widget that wraps a standard HTML select element. When writing automated
tests with `shinytest2`, the underlying input value can be set
programmatically:

``` r

# Works: sets the underlying Shiny input value
app$set_inputs(base_layer = "phu_boundaries")
```

However, the visible selectize dropdown does not update its displayed
text until the JavaScript layer processes the change. Tests that rely on
the widget visually showing the selected value must follow the
`set_inputs()` call with either `app$click()` on a trigger element or
direct JavaScript injection via `app$execute_script()`.

Because of this constraint, the ONgeoR test suite covers the
**server-side logic** (retrieval, linking, nearest-match computation,
and download generation) in isolation rather than driving the full UI
flow through a headless browser. This is intentional: the spatial and
data correctness properties are best tested at the function level, while
UI integration tests would add fragility without exercising new logic
paths.

If you want to add UI-level coverage,
[`shinytest2::AppDriver`](https://rstudio.github.io/shinytest2/reference/AppDriver.html)
is the recommended approach. See
[`vignette("shinytest2", package = "shinytest2")`](https://rstudio.github.io/shinytest2/articles/shinytest2.html)
for details on recording and replaying interactions with selectize
widgets.
