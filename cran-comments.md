# cran-comments.md

## Test environments

- local Ubuntu 24.04, R 4.5.x — `R CMD check --as-cran --run-donttest`
- GitHub Actions: ubuntu-latest, macos-latest, windows-latest (R release)

## R CMD check results

0 errors | 0 warnings | 1 note

```
* checking CRAN incoming feasibility ... NOTE
Maintainer: 'Lennon Li <lennon.yeli@gmail.com>'
New submission
```

Expected; this is the package's first submission to CRAN.

## Notes for the reviewer

- The package retrieves most data at run time from public Ontario government
  REST endpoints (Land Information Ontario). It bundles three small offline
  layers used for documentation and tests, so no example requires network
  access and the full example set completes in about 19 seconds.
- No example writes to the user's filesystem. Nothing touches
  `tools::R_user_dir()`; the run-time cache is created only when a user calls a
  retrieval function themselves.
- The `\dontrun{}` blocks are the nine functions that retrieve from the LIO
  service, plus `clear_cache()` and `list_cache()`. The retrieval functions
  cannot run without the external service; `clear_cache()` deletes the user's
  cached layers and `list_cache()` creates the cache directory as a side
  effect, so neither should execute unattended. Every other example runs.
- Retrieval failures raise a classed `ongeor_retrieval_error` condition with an
  informative message, so the package fails gracefully when the service is
  unavailable.
- Four strings in the vignettes point at `https://example.invalid/...`. These
  are placeholder values assigned to a `source_url` attribute inside code
  chunks, not links. `.invalid` is reserved by RFC 2606 precisely so that it
  never resolves, which is why it was chosen; `urlchecker::url_check()` reports
  them because it scans text without distinguishing a string literal from a
  hyperlink.

## Downstream dependencies

None. A companion package, ONgeoRapp, provides the Shiny interface and is not
yet on CRAN; it depends on this package rather than the reverse.
