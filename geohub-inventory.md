# Ontario LIO Data Inventory & Recommendations

## 1. Prioritized Recommendations

### Tier 1 (MVP)

- **MOH Public Health Unit Boundary** (`LIO_Open09/44`)
  - Category: Administrative Boundaries
  - Type: boundary, Features: 34
  - Key Fields: PHU_ID, PHU_NAME_ENG, PHU_NAME_FR, EFFECTIVE_DATETIME
  - **Endpoint:**
    `https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open09/MapServer/44`
  - **R Retrieval:**
    `sf::st_read("https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open09/MapServer/44/query?where=1=1&outFields=*&f=geojson&maxAllowableOffset=10")`
- **Ontario Health Region** (`LIO_Open09/52`)
  - Category: Administrative Boundaries
  - Type: boundary, Features: 6
  - Key Fields: OH_REGION_ID, ENGLISH_NAME, FRENCH_NAME,
    EFFECTIVE_DATETIME
  - **Endpoint:**
    `https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open09/MapServer/52`
  - **R Retrieval:**
    `sf::st_read("https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open09/MapServer/52/query?where=1=1&outFields=*&f=geojson&maxAllowableOffset=10")`
- **Municipal Bnd Upper And Dist** (`LIO_Open03/13`)
  - Category: Administrative Boundaries
  - Type: boundary, Features: 98
  - Key Fields: MUNID, MUNICIPAL_NAME, MUNICIPAL_TYPE
  - **Endpoint:**
    `https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open03/MapServer/13`
  - **R Retrieval:**
    `sf::st_read("https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open03/MapServer/13/query?where=1=1&outFields=*&f=geojson&maxAllowableOffset=10")`
- **Municipal Bnd Lower And Single** (`LIO_Open03/14`)
  - Category: Administrative Boundaries
  - Type: boundary, Features: 685
  - Key Fields: MUNID, MUNICIPAL_NAME, MUNICIPAL_TYPE,
    UPPER_TIER_MUNICIPALITY
  - **Endpoint:**
    `https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open03/MapServer/14`
  - **R Retrieval:**
    `sf::st_read("https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open03/MapServer/14/query?where=1=1&outFields=*&f=geojson&maxAllowableOffset=10")`
- **MOH Service Location** (`LIO_Open09/26`)
  - Category: Health Facilities
  - Type: facility, Features: 11625
  - Key Fields: MOH_SERVICE_PROVIDER_IDENT, SERVICE_TYPE, ENGLISH_NAME,
    POSTAL_CODE
  - **Endpoint:**
    `https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open09/MapServer/26`
  - **R Retrieval:**
    `sf::st_read("https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open09/MapServer/26/query?where=1=1&outFields=*&f=geojson&maxAllowableOffset=10")`

### Tier 2 (v0.2)

- **Conservation Authority Admin Area** (`LIO_Open03/11`)
  - Category: Administrative Boundaries
  - Type: boundary, Features: 36
  - Key Fields: CA_ID, LEGAL_NAME, COMMON_NAME
- **Airport Official** (`LIO_Open05/0`)
  - Category: Transportation Infrastructure
  - Type: boundary, Features: 403
  - Key Fields: AIRPORT_IDENT, NAME, AIRPORT_TYPE
- **ORWN Station** (`LIO_Open04/15`)
  - Category: Transportation Infrastructure
  - Type: facility, Features: 671
  - Key Fields: STENNAME, STNTYPE, TRACKNAME
- **Waste Management Site** (`LIO_Open08/9`)
  - Category: Environmental Health
  - Type: boundary, Features: 813
  - Key Fields: SITE_NAME, PRIMARY_CLASSIFICATION, STATUS

### Tier 3 (future)

- **Province** (`LIO_Open03/0`)
  - Category: Administrative Boundaries
  - Type: boundary, Features: 1
  - Key Fields: OFFICIAL_NAME
- **Monitoring Station Point** (`LIO_Open08/30`)
  - Category: Environmental Health
  - Type: facility, Features: 2588
  - Key Fields: STATION_NAME, STATION_NO, NETWORK_NAME
- **Fire Aviation and Emergency Facility Point** (`LIO_Open05/21`)
  - Category: Community Services
  - Type: facility, Features: 70
  - Key Fields: FACILITY_NAME, FACILITY_TYPE

## 2. API Query Assessment

All Tier 1 datasets were tested against the REST API. The results show
that: - **GeoJSON support:** Confirmed working using `f=geojson`. -
**Filtering:** Confirmed working using `where=1=1`. - **Geometry
Simplification:** Confirmed working using `maxAllowableOffset=10`
(useful for large polygon boundaries like PHUs and Municipalities). -
**Rate Limits:** None observed during scanning, but
`returnCountOnly=true` was used for initial inspection to be polite.

## 3. Data Quality Notes

- **Licenses:** All datasets are covered by the Open Government Licence
  – Ontario. Some descriptions include specific ‘subject to terms of
  use’ text, but the general LIO portal defaults to open government.
- **Updates:** Use the `EFFECTIVE_DATETIME` field to ascertain the
  freshness of the data.
- **Size Considerations:** Municipal Boundaries Lower/Single (685
  features) and MOH Service Locations (11,625 features) are relatively
  large. Consider using pagination or spatial filters if downloading
  frequently, or simplifying geometries using `maxAllowableOffset`.

## 4. Gap Analysis (Not available on LIO)

- **Postal Codes:** PCCF (Postal Code Conversion File) is not open data
  and not on LIO. Need alternative approaches (e.g. Statistics Canada or
  license via academic institution).
- **Education:** No clear province-wide layers for schools, child care
  centers, or universities were found on the open API.
- **Hospitals / Specific Facilities:** While `MOH Service Location` is
  comprehensive, specific sub-categories like Acute Care Hospitals or
  Long-Term Care might need explicit filtering or sourcing directly from
  CIHI or other specific Ministry datasets.
- **Transportation:** LIO provides Air and Rail stations, but major
  highways and roads are only available via the massive
  `ORN Road Net Element` layer which may be too heavy. GTFS feeds from
  transit agencies might be better for transit routes.
