# Guess a name column in an sf/data.frame layer

Guess a name column in an sf/data.frame layer

## Usage

``` r
guess_name_col(x)
```

## Arguments

- x:

  An `sf` object or `data.frame`.

## Value

Character scalar: the guessed name column name. Prefers an English name
column, then any `*NAME*` column, then falls back to the first
non-geometry column.

## See also

Other app support interfaces:
[`build_nearest_layers()`](https://lennon-li.github.io/ONgeoR/reference/build_nearest_layers.md),
[`extract_polygon_collection()`](https://lennon-li.github.io/ONgeoR/reference/extract_polygon_collection.md),
[`render_postal_reproducer_script()`](https://lennon-li.github.io/ONgeoR/reference/render_postal_reproducer_script.md),
[`render_reproducer_script()`](https://lennon-li.github.io/ONgeoR/reference/render_reproducer_script.md)

## Examples

``` r
guess_name_col(data.frame(feature_id = 1, feature_name_eng = "Example"))
#> [1] "feature_name_eng"
```
