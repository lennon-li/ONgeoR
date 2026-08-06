# ONgeoR 0.4.0

- Add `retrieve_phu_pre2025()` for the retained 34-boundary, 250 m simplified
  PHU snapshot that LIO no longer serves.

- Export `layer_id_col()`, which resolves a retrieved layer's id column from
  the source registry's declared key fields. This is the supported way to join
  `build_crosswalk()` / `build_intersection()` output back onto the layer
  geometry it came from; downstream callers previously had to reach for the
  internal.

- Add `resolve_postal_points()` for checksum-verified OPCC M1 postal-code to
  latitude/longitude resolution (282,409 address-derived `nar_centroid`
  matches, 17,373 coarser `geonames` matches, 14 codes with no coordinates),
  with optional `as_sf = TRUE` output as an EPSG:4326 POINT layer.

- Add `resolve_postal()` for checksum-verified OPCC M5 postal-code to
  dissemination-area resolution, plus `render_postal_reproducer_script()`.
  `normalize_postal_code()` is exported; joins use a normalized, de-duplicated
  postal-code key, and `render_postal_reproducer_script()` gains `all_links`.

- Add `retrieve_monitoring_stations()` for Ontario water and weather
  monitoring stations (LIO_Open08/30), with live retrieval automatically
  paginated across pages of 2,000 features, and a bundled offline subset
  `retrieve_monitoring_stations_simple()` (2,407 stations, a frozen
  2023-06-23 GeoHub snapshot). The bundled layer is the first bundled point
  layer, so point-in-polygon examples now run offline.

- Fix the bundled HIVE grid: eight cells were invalid under planar GEOS while
  passing `st_is_valid()` on geographic coordinates (s2), so
  `build_intersection()` on HIVE Level 1/2 grids aborted with a
  TopologyException. The repaired cells now validate under GEOS and s2; all
  other cells are unchanged.

- Point-in-polygon examples for `link()`, `nearest()`, `map_nearest()`,
  `build_nearest_layers()`, and `build_nearest_pairs()` now use the bundled
  station layer and execute during `R CMD check`.

- The Shiny app moves to its own package,
  [ONgeoRapp](https://github.com/lennon-li/ONgeoRapp). `run_app()` is no longer
  exported from ONgeoR; install ONgeoRapp and call `ONgeoRapp::run_app()`.
  Nothing else changed — the app only ever used exported functions, so no
  linking, retrieval, or crosswalk behaviour is affected.
- `Suggests` drops `shiny`, `bslib`, `DT`, `shinytest2`, `chromote`, `future`,
  `later`, and `promises`, which moved with the app. This also removes the
  standing "detritus in the temp directory" `R CMD check` NOTE, which came from
  the browser smoke test.

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
- Add `build_intersection()` for polygon-to-polygon linking: returns every
  overlapping pair with `share_of_target` (fraction of the target covered by
  the source) and `share_of_source` (fraction of the source falling inside the
  target, the apportionment weight for extensive variables). All source and
  target attributes are carried through with `src_` and `tgt_` prefixes.
- Add `build_nearest_pairs()` for point-to-point linking: each target point is
  matched to its single nearest source point, with the same column schema as
  `build_intersection()` so the two are row-bindable.
- Add `summarise_by_target()` to collapse a pairs table to one row per distinct
  target, with multi-valued fields as `"; "`-delimited strings and the dominant
  source identified by `share_of_target`.
- Add `build_link()` as the no-choice entry point: it inspects the geometry
  types of the two layers and dispatches to `build_nearest_pairs()` for
  point-point, `build_intersection()` for polygon-polygon, or `link()` /
  `build_crosswalk()` for mixed types.
- Duplicate id values in either layer now abort early in `build_intersection()`
  and `build_nearest_pairs()`, because `summarise_by_target()` keys on
  `target_id` and two distinct features sharing an id would silently collapse.
- All changes are additive: `build_crosswalk()` and its five methods
  (`within`, `intersects`, `point_on_surface`, `largest_overlap`, `weighted`)
  are unchanged and remain available for direct callers.
