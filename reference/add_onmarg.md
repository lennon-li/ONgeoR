# Attach ON-Marg columns to an administrative boundary layer

Adds the 2021 Ontario Marginalization Index measures to a layer whose
features are one of the geographies ON-Marg publishes, matching on the
layer's own key column. The layer is returned unchanged apart from the
added `onmarg_*` columns, so an `sf` object stays an `sf` object with
its geometry intact.

## Usage

``` r
add_onmarg(
  x,
  geography = NULL,
  scores = TRUE,
  quintiles = TRUE,
  population = FALSE,
  dimensions = names(onmarg_measure_stems()),
  refresh = FALSE
)
```

## Arguments

- x:

  A data frame or `sf` object carrying the geography's key column - for
  example the output of
  [`retrieve_census()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_census.md)
  or
  [`retrieve_phu()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_phu.md).

- geography:

  Character scalar naming the ON-Marg geography, as in
  [`retrieve_onmarg()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_onmarg.md).
  `NULL` (the default) detects it from the key columns present in `x`,
  and errors if that is ambiguous or absent.

- scores:

  Logical. Attach the four factor-score columns. Default `TRUE`.

- quintiles:

  Logical. Attach the four quintile columns, where the geography
  publishes them. Default `TRUE`.

- population:

  Logical. Attach ON-Marg's own 2021 population count. Default `FALSE`,
  since boundary layers usually carry their own.

- dimensions:

  Character vector naming which of the four dimensions to attach: any of
  `"households_dwellings"`, `"material_resources"`, `"age_labourforce"`,
  `"racialized_nc_pop"`. Defaults to all four.

- refresh:

  Logical, passed to
  [`retrieve_onmarg()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_onmarg.md).

## Value

`x` with the requested `onmarg_*` columns added. Features with no
ON-Marg row get `NA`; how many that was is reported in a message,
because a key mismatch otherwise looks exactly like a successful join.

## Details

The ON-Marg name columns (`CSDNAME`, `HU_NAME`, and similar) are
deliberately not attached: they restate a name the boundary layer
already carries, under a name that would collide with it.

## See also

[`retrieve_onmarg()`](https://lennon-li.github.io/ONgeoR/reference/retrieve_onmarg.md),
[`onmarg_geographies()`](https://lennon-li.github.io/ONgeoR/reference/onmarg_geographies.md).

## Examples

``` r
if (FALSE) { # interactive()
phu <- retrieve_phu_pre2025()
add_onmarg(phu, "phu")
}
```
