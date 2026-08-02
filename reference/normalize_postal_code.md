# Normalize postal codes to the correspondence's own format

Uppercases, strips whitespace, and re-inserts a single space in the
middle of a six-character code, producing the `"A1A 1A1"` form that
[`resolve_postal()`](https://lennon-li.github.io/ONgeoR/reference/resolve_postal.md)
reports in its `postal_code` column. Use it to build a join key on your
own records: joining on the column as typed silently drops every code
that was not already in that exact form.

## Usage

``` r
normalize_postal_code(x)
```

## Arguments

- x:

  Character vector of postal codes.

## Value

A character vector the same length as `x`.

## Examples

``` r
normalize_postal_code(c("m5v3a8", "M5V 3A8", " m5v 3a8 "))
#> [1] "M5V 3A8" "M5V 3A8" "M5V 3A8"
```
