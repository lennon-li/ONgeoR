# Data-Source Expansion Proposal

_Generated: 2026-07-17_

This document describes the candidates evaluated for adding to ONgeoR as
retrievable data sources, organized by priority and implementation status.

---

## 1. Implemented in This Branch

Both sources below are freely available from the LIO Open Data ArcGIS REST
service under the Open Government Licence - Ontario, follow exactly the same
URL pattern as existing sources, and require no additional package dependencies.

### 1.1 Conservation Authority Admin Area

- **Source:** LIO_Open03/11
- **URL:** `https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open03/MapServer/11`
- **Features:** 36 boundary polygons
- **Key fields:** `CA_ID`, `LEGAL_NAME`, `COMMON_NAME`
- **License:** Open Government Licence - Ontario
- **Retrieval function:** `retrieve_conservation_authority()`
- **Rationale:** Conservation authority boundaries are a standard Ontario
  administrative geography used in watershed management, land-use planning, and
  environmental health analysis. They sit between municipal and provincial scale.
  At only 36 features the layer is small and fast to retrieve. Crosswalk to PHU,
  municipal, or HIVE boundaries is immediate.

### 1.2 ORWN Railway Station Points

- **Source:** LIO_Open04/15
- **URL:** `https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open04/MapServer/15`
- **Features:** 671 facility points
- **Key fields:** `STENNAME`, `STNTYPE`, `TRACKNAME`
- **License:** Open Government Licence - Ontario
- **Retrieval function:** `retrieve_orwn_station()`
- **Rationale:** Ontario Railway Network (ORWN) station points support
  transportation-access analyses such as commute-shed health profiles and
  service-area mapping for transit-accessible populations. Point geometry, so
  `simplify` is forced `FALSE`. 671 features fit in a single non-paginated
  request.

---

## 2. Remaining CSV Candidates - Propose Only

These five rows have `include=FALSE` in `geohub-inventory.csv` but were not
implemented because their relevance is too low to justify the surface-area
cost, or there are open questions about utility.

### 2.1 Province (LIO_Open03/0) - Low priority

- **Features:** 1 boundary polygon (the Ontario provincial outline)
- **Recommendation:** Do not implement as a dedicated function. A single
  province polygon has no crosswalk utility inside ONgeoR - every existing
  layer already covers the province. If needed, a caller can load the HIVE
  grid and take its convex hull, or use `retrieve_municipal()` and dissolve.
  If the province outline becomes needed (e.g., for a basemap clip), add a
  `retrieve_province()` function as a trivial wrapper with a prominent note
  that the layer is province-wide and has no analytic children.

### 2.2 Monitoring Station Point (LIO_Open08/30) - Low priority

- **Features:** 2588 facility points
- **Key fields:** `STATION_NAME`, `STATION_NO`, `NETWORK_NAME`
- **Recommendation:** Propose only. Environmental monitoring stations are
  relevant to air/water quality analysis but the layer carries no health
  context on its own. If a monitoring station crosswalk is needed, implement
  alongside a matching monitoring-data source (not currently in scope). The
  synthetic air-quality raster already provides a stand-in.

### 2.3 Fire Aviation and Emergency Facility Point (LIO_Open05/21) - Low priority

- **Features:** 70 facility points
- **Key fields:** `FACILITY_NAME`, `FACILITY_TYPE`
- **Recommendation:** Propose only. Coverage is sparse (70 air-and-remote
  facilities) and the layer does not represent municipal fire stations. If
  emergency facility coverage is needed, prefer a Statistics Canada or
  municipal open-data source that includes all fire stations, not just remote
  aviation bases.

---

## 3. Additional Candidates - Research and Proposal

The following candidates go beyond the `geohub-inventory.csv` include=FALSE
rows. Each is evaluated for fit with the retrieve -> link -> crosswalk
architecture, licensing, and source accessibility.

### 3.1 Long-Term Care Homes (IMPLEMENT WHEN SOURCE CONFIRMED)

- **Candidate source:** Ontario Ministry of Long-Term Care via the Ontario
  Data Catalogue (`data.ontario.ca`). The published dataset "Long-Term Care
  Home Locations" provides geocoded facility points under the Open Government
  Licence - Ontario.
- **Why it fits:** Long-term care homes are a core public-health facility type.
  Linking them to PHU or health-region boundaries is an immediate, high-value
  crosswalk.
- **Blocker:** The Ontario Data Catalogue uses a CKAN-style download URL, not
  an ArcGIS REST service. Implementing this source requires either (a) adding
  an HTTP CSV/GeoJSON download path to `fetch_lio_sf()`, or (b) writing a
  separate `fetch_ontario_catalogue_sf()` helper. Neither is in scope for this
  branch but should be the first addition in a follow-on branch.
- **Action:** Open a tracking issue. Prototype the download path. No license
  barrier once the CKAN URL is confirmed stable.

### 3.2 School Locations (IMPLEMENT WHEN SOURCE CONFIRMED)

- **Candidate source:** Ontario school board boundary and facility data is
  available from the Ontario GeoHub but the point-location layer has not been
  confirmed in the current LIO Open Data ArcGIS catalog.
- **Why it fits:** School catchment areas and facility points are used in
  pediatric health, equity, and social-determinants analysis.
- **Blocker:** The LIO Open Data catalog examined for this branch does not
  include a confirmed school-point layer. If the layer exists in a different
  LIO_OpenXX service group it can be added with a trivial wrapper once the
  service number is confirmed. Alternatively the Ministry of Education publishes
  a school-list dataset on `data.ontario.ca`; that path has the same CKAN
  blocker as long-term care homes (3.1 above).
- **Action:** Audit LIO services 01-10 for a school or education layer. If
  found on LIO, implement immediately (same pattern as 1.1 and 1.2). If only
  on CKAN, defer to the CKAN-fetch branch.

### 3.3 Pharmacies and Drug Stores (PROPOSE ONLY)

- **Candidate source:** No confirmed LIO layer. The Ontario College of
  Pharmacists publishes a registrant list but it is a CSV without stable
  geocoding, not a geospatial service.
- **Blocker:** No open geospatial source with province-wide coverage and a
  stable machine-readable URL is known. Do not implement until a canonical
  source is identified. A CKAN or Health Canada open-data path may exist;
  research required.

### 3.4 Fire Stations (PROPOSE ONLY - not yet on LIO)

- **Candidate source:** Ontario municipal fire stations are not available as a
  single province-wide LIO layer. Individual municipalities publish their own
  fire station datasets; there is no consolidated Ontario Open Government
  source.
- **Blocker:** Fragmented source. Would require either aggregating municipal
  open-data files (out of scope for this package) or waiting for a provincial
  consolidation. The LIO_Open05/21 "Fire Aviation and Emergency Facility" layer
  (2.3 above) covers only remote air bases, not municipal fire halls.
- **Action:** Monitor the Ontario GeoHub for a future consolidated layer.

### 3.5 Walk-In Clinics and Community Health Centres (PROPOSE - already partial)

- **Current coverage:** `retrieve_moh_service_locations()` with
  `service_type = "Community Health Centre"` already returns CHC locations from
  the MOH Service Location layer (LIO_Open09/26, 11625 features). Walk-in
  clinics may also appear under a `SERVICE_TYPE` value in that layer.
- **Recommendation:** Expose convenience wrappers:
  `retrieve_moh_service_locations(service_type = "Community Health Centre")`
  and `retrieve_moh_service_locations(service_type = "Walk-In Clinic")`. No
  new source is needed - just document the `service_type` filter values in a
  vignette or helper that returns the set of valid SERVICE_TYPE strings.

### 3.6 Census Tract and Dissemination Area Boundaries (PROPOSE)

- **Source:** Statistics Canada via the Census boundary file download service.
  `https://www12.statcan.gc.ca/census-recensement/2021/geo/shr-fsa/boundary-limites/files-fichiers/...`
  (Shapefile or GeoJSON downloads by province).
- **Why it fits:** Census geography (census tracts, dissemination areas) is the
  primary unit for linking health outcomes to socioeconomic data from the
  National Household Survey and Canadian Community Health Survey. This is
  high-priority for any social-determinants workflow.
- **Blocker:** Statistics Canada uses bulk shapefile/GeoJSON downloads, not
  ArcGIS REST. The download URLs are stable but large (~200 MB for the full
  Canada DA boundary file). Implementing this source requires a new download
  helper that handles large file downloads, optional provincial subsetting,
  and shapefile unzipping - a meaningful engineering addition.
- **License:** Statistics Canada Open Licence (not the Ontario OGL, but also
  free and open for any use).
- **Action:** High-priority follow-on. Implement in a dedicated
  `feat/statscan-boundaries` branch with a `fetch_statscan_boundary()` helper.

### 3.7 Ontario Electoral Districts (PROPOSE)

- **Candidate source:** Elections Ontario publishes electoral district
  boundaries. The Ontario GeoHub may carry them as an LIO layer; if so,
  implementation is trivial. If only available from Elections Ontario directly,
  the download format needs to be confirmed.
- **Why it fits:** Riding boundaries are commonly needed for policy mapping and
  health equity analysis by political geography.
- **Action:** Confirm the LIO service number (check LIO_Open03 group). If
  present, add in a follow-on PR.

### 3.8 First Nations and Indigenous Community Boundaries (PROPOSE - licensing)

- **Candidate source:** Crown-Indigenous Relations and Northern Affairs Canada
  (CIRNAC) publishes First Nations reserve boundaries. The layer appears in
  Statistics Canada geographic files and also in the Ontario GeoHub. However,
  some Indigenous boundary datasets carry restrictions on commercial or
  analytical use beyond simple display; the specific OGL variant must be
  confirmed before retrieval is implemented.
- **Why it fits:** Indigenous community boundaries are important for health
  equity analysis and for ensuring reporting respects First Nations
  jurisdictions.
- **Action:** Confirm the exact licence on the LIO or StatCan version of this
  layer before implementing. Do not implement under assumptions about OGL
  coverage. Engage with the data steward.

---

## 4. Priority Order for Future Implementation

| Priority | Source | Est. effort | Blocker |
|----------|--------|-------------|---------|
| 1 | Long-term care homes (Ontario Data Catalogue) | Medium - needs CKAN fetch path | New fetch helper |
| 2 | Census DA / CT boundaries (Statistics Canada) | High - large file download | New download helper |
| 3 | School locations (LIO if confirmed, else CKAN) | Low if on LIO | Confirm layer number |
| 4 | Ontario electoral districts (LIO if confirmed) | Low if on LIO | Confirm layer number |
| 5 | Walk-in / CHC convenience wrappers | Low - no new source | Documentation only |
| 6 | First Nations boundaries | Low once confirmed | Licence confirmation |
| 7 | Pharmacies | High | No confirmed source |
| 8 | Fire stations | High | No consolidated source |

---

## 5. Sources Deliberately Excluded

- **Postal Code Conversion File (PCCF):** Licensed from Statistics Canada.
  Not open. Do not implement.
- **Any layer requiring non-OGL licence agreement:** Not in scope.
- **Commercial geocoding APIs (Google Maps, Here, etc.):** Not in scope.
