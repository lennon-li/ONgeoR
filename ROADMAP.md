# ONgeoR Roadmap

## Current Status: API Validation Phase

**Goal:** Prove that we can retrieve Ontario geospatial data from the LIO REST API, perform spatial joins, and build auditable crosswalk tables.

### What We Know
- ✅ LIO REST API is accessible (no auth required)
- ✅ PHU boundaries retrievable via `resultRecordCount=2000` parameter
- ✅ GeoJSON format works with httr2 + jsonlite
- ✅ Layer metadata: `maxRecordCount: 2000`, pagination supported
- ⚠️ Geometry data is truncated in GeoJSON responses (simplification needed)
- ⚠️ Need to test: sf conversion, spatial joins, CRS handling

### What We Need to Validate
- Can we convert ArcGIS GeoJSON to sf objects?
- Does `sf::st_join()` work on the retrieved geometries?
- Can we build a crosswalk table with full provenance?

---

## Phase 1: Spatial Join Proof-of-Concept (Current)

**Deliverable:** R script that demonstrates end-to-end workflow

```
retrieve PHU boundaries → convert to sf → 
create test points → spatial join → 
output table with provenance
```

**Test scenario:**
- 3 synthetic points (Toronto, Ottawa, Thunder Bay)
- Retrieve all 34 PHU boundaries
- Join points to PHUs
- Output: point_id, point_name, lon, lat, phu_id, phu_name_en, retrieved_at

**Success criteria:**
- [ ] Script runs in < 10 seconds
- [ ] All 3 points correctly assigned to their PHUs
- [ ] Output includes full provenance (source_url, retrieved_at)
- [ ] No CRS errors or geometry conversion failures

**Files:**
- `test_spatial_join.R` — main script
- `test_lio_api.R` — API connectivity test
- `test_lio_count.R` — pagination/count validation

---

## Phase 2: Package Skeleton (After Phase 1 Validates)

**Goal:** Minimal R package structure with working examples

### Deliverables
- [ ] `DESCRIPTION`, `NAMESPACE`, `LICENSE`, `README.md`
- [ ] `R/retrieve.R` — `retrieve_phu()` and per-source retrieval functions
- [ ] `R/link.R` — `link()` (topological join) and `nearest()` (proximity)
- [ ] `R/resolve.R` — `resolve()` (attribute lookup by id/name)
- [ ] `R/crosswalk.R` — `build_crosswalk()` function
- [ ] `inst/extdata/` — example data (3 test points as CSV)
- [ ] `tests/testthat/` — unit tests for each function
- [ ] `man/` — roxygen2 documentation

### Dependencies
```
Imports: sf, httr2, jsonlite, dplyr
Suggests: testthat, knitr, rmarkdown
```

### Functions
```r
retrieve_phu() -> sf object
link(source, target, predicate) -> joined tibble       # point/polygon by geometry type
nearest(source, target, k, max_dist_km) -> ranked tibble
resolve(layer, query, by) -> matched records
build_crosswalk(from_sf, to_sf) -> provenance tibble
```

Linking dispatches on geometry type, not named source: facility-to-PHU,
municipality-to-region, and point-to-health-region are all expressed as
`link()`; proximity as `nearest()`. There are no per-source linking functions.

---

## Phase 3: Expand Source Coverage

**Goal:** Add more Ontario datasets to the source registry

### Target Layers
- [ ] Health Unit boundaries (done in Phase 1)
- [ ] Municipal boundaries (LIO_Open03)
- [ ] Postal code boundaries (if available)
- [ ] Hospitals/health facilities (if available)

### Source Registry
- `inst/extdata/sources.yaml` — metadata for each source
- Each entry: name, url, description, license, last_updated, retrieval_function

---

## Phase 4: User Interface

**Goal:** Make the package user-friendly

### Deliverables
- [ ] Vignettes: quickstart, examples, troubleshooting
- [ ] Error messages with actionable guidance
- [ ] Progress indicators for long retrievals
- [ ] Caching strategy (avoid re-downloading)

---

## Future (Post-MVP)

### Additional Features
- Interactive maps: `map_layers()` (generic, by geometry type) and
  `map_crosswalk()` shipped; `map_nearest()` (points + connector lines +
  nearest facilities, on `map_layers()`) still planned
- Batch processing for large datasets
- Custom CRS support
- Export to multiple formats (CSV, GeoJSON, Shapefile)

### Additional Data Sources
- Ontario Health regions
- Census subdivisions (Statistics Canada)
- Transit routes (if public API available)
- Environmental data (air quality, water quality)

---

## Known Issues / Open Questions

1. **Geometry truncation:** LIO API returns simplified geometries. Need to verify this is acceptable for spatial joins.

2. **CRS handling:** ArcGIS uses WKID 102100 (Web Mercator). Need to confirm sf can reproject to WGS84 (EPSG:4326).

3. **Pagination:** maxRecordCount is 2000. Need to test if any layer exceeds this and implement pagination.

4. **Rate limiting:** Unknown if LIO API has rate limits. Need to test with multiple concurrent requests.

5. **Data freshness:** Unknown how often LIO updates these layers. Need to add `last_updated` field to source registry.
