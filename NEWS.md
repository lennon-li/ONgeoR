# ONgeoR 0.3.0.9000

- Add registry-driven LIO retrieval and 17 verified Ontario geography sources.
- Fix generalized geometry silently dropping small polygons. `maxAllowableOffset`
  was 10, but the service returns EPSG:4326, making that a ~1,100 km tolerance:
  Toronto, Peel, Halton, Hamilton, Windsor-Essex, Niagara, York, Ottawa and
  Middlesex-London all came back with zero area, and PHU boundaries totalled
  646,394 km2 instead of 983,322 km2. Now 1e-04 degrees (~11 m).
- Repair geometry validity without deleting features. `sf::st_make_valid()`
  dispatches to s2 on geographic coordinates, which answered the degenerate rings
  by returning EMPTY, so 11 of 29 PHU boundaries arrived as empty
  GEOMETRYCOLLECTIONs and maps drew 18 units with no error. Retrieval now repairs
  on the planar GEOS path, rebuilds under s2 (a ring GEOS accepts can still abort
  `st_intersects`), keeps only polygonal parts of areal input, and errors rather
  than returning a layer with missing shapes.
- Add a geometry-schema component to the cache key, so caches written before the
  above are not served afterwards.
- `retrieve_phu()` now defaults to `simplify = TRUE`; full-resolution requests for
  that layer fail against the service.
- Shiny app: rename the pickers to **Source layer** / **Target layer**, rename
  **Link** to **Join**, and move the pairing explanation from Preview to a Join
  confirmation that names both layers with their dimensions and the expected
  result shape. Join stays disabled until a preview of the current pair succeeds,
  and is now visibly greyed out in that state. The results download is
  `mapping.csv`.
- Fix `reproduce.R` so it reproduces what the app produces: it used the CLI's
  multi-pair path, which re-downloaded every layer and wrote 16 columns where the
  app writes 14.
