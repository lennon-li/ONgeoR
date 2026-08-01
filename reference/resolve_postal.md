# Resolve Ontario postal codes to dissemination areas

Downloads and verifies the immutable OPCC M5 postal-code to
dissemination area correspondence, then caches the parsed table locally.
Postal codes are matched after uppercasing and normalizing whitespace.

## Usage

``` r
resolve_postal(x, all_links = FALSE)
```

## Arguments

- x:

  Character vector of Ontario postal codes.

- all_links:

  Logical scalar. If `FALSE` (default), return the one best link for
  each postal code. If `TRUE`, return every dissemination-area link.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with postal-code links, source URL, and retrieval time. An unmatched
postal code yields one row with `NA` data columns; a single combined
warning lists all unmatched postal codes.

## Coverage

The correspondence covers 282,409 Ontario postal codes across 529
forward sortation areas, and is derived by rolling dissemination blocks
up to dissemination areas (2021 census vintage). Postal codes with no
residential dissemination block behind them are therefore absent -
notably large-volume receiver codes assigned to a single building, such
as much of the federal `K1A` range. An absent code is reported as an
unmatched value, not an error.

About 7.8 percent of postal codes span more than one dissemination area.
For those, the default single row is the highest-weight link, and
`allocation_weight` is returned so the caller can see how much of the
postal code it represents; that share is below one half for roughly
1,850 codes. Use `all_links = TRUE` when apportioning a quantity rather
than labelling a record.

## Examples

``` r
if (FALSE) { # \dontrun{
resolve_postal(c("K1A0B1", "M5V 3A8"))
} # }
```
