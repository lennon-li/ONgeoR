# Retrieve Ontario Marginalization Index (ON-Marg) values

Fetches one geography's worth of the 2021 Ontario Marginalization Index
from Public Health Ontario. ON-Marg summarises four dimensions of
marginalization derived from the 2021 Census: households and dwellings
(formerly residential instability), material resources (formerly
material deprivation), age and labour force (formerly dependency), and
racialized and newcomer populations (formerly ethnic concentration).

## Usage

``` r
retrieve_onmarg(geography, refresh = FALSE)
```

## Arguments

- geography:

  Character scalar naming the geography, e.g. `"da"` or `"phu"`. See
  [`onmarg_geographies()`](https://lennon-li.github.io/ONgeoR/reference/onmarg_geographies.md)
  for the full set.

- refresh:

  Logical. `TRUE` re-downloads the workbook instead of reusing the copy
  held for this session. Default `FALSE`.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with one row per feature of that geography: the key column under its
published name (character), the `onmarg_*` measure columns (numeric),
and the geography's own name column where the workbook publishes one.
Carries `source_name`, `source_url`, `retrieved_at`, and `citation`
attributes for provenance.

## Details

The workbook is downloaded at runtime, verified against a pinned
SHA-256, and held in memory for the life of the R process. Unlike
ONgeoR's spatial retrievals it is never written to the ONgeoR cache
directory: its licence permits non-commercial use with attribution and
forbids modifying the content, so ONgeoR neither redistributes nor
stores it. Values are returned exactly as published; only column names
are normalised, because the published names carry a per-sheet geography
suffix:

- `Pop2021` / `pop2021` becomes `onmarg_pop2021`

- `households_dwellings_*` becomes `onmarg_households_dwellings`

- `material_resources_*` becomes `onmarg_material_resources`

- `age_labourforce_*` becomes `onmarg_age_labourforce`

- `racialized_NC_pop_*` becomes `onmarg_racialized_nc_pop`

- the matching `*_q_*` columns take the same names with a `_q` suffix

Higher factor scores mean more marginalization on that dimension.
Quintiles run 1 (least marginalized) to 5 (most), and are published for
some geographies only - see
[`onmarg_geographies()`](https://lennon-li.github.io/ONgeoR/reference/onmarg_geographies.md).

Cite ON-Marg as: Matheson FI (Unity Health Toronto), Moloney G (Unity
Health Toronto), van Ingen T (Public Health Ontario). 2021 Ontario
marginalization index. Toronto, ON: St. Michael's Hospital (Unity Health
Toronto); 2023.

## See also

[`add_onmarg()`](https://lennon-li.github.io/ONgeoR/reference/add_onmarg.md)
to attach these values to a boundary layer,
[`onmarg_geographies()`](https://lennon-li.github.io/ONgeoR/reference/onmarg_geographies.md)
for the available geographies.

## Examples

``` r
if (FALSE) { # interactive()
retrieve_onmarg("phu")
}
```
