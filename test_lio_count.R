#!/usr/bin/env Rscript
# Check feature count and pagination for LIO PHU boundaries

library(httr2)
library(jsonlite)

base <- "https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open09/MapServer/44"

# 1. Check total count
cat("=== Query 1: Count only ===\n")
count_url <- paste0(base, "/query?where=1%3D1&returnCountOnly=true&f=json")
resp <- request(count_url) %>% req_perform()
cat(resp_body_string(resp), "\n\n")

# 2. Check max record count from layer metadata
cat("=== Query 2: Layer metadata (maxRecordCount) ===\n")
meta_url <- paste0(base, "?f=json")
resp <- request(meta_url) %>% req_perform()
meta <- fromJSON(resp_body_string(resp))
cat("maxRecordCount:", meta$maxRecordCount, "\n")
cat("supportsPagination:", meta$supportsPagination, "\n\n")

# 3. Try fetching with explicit resultRecordCount
cat("=== Query 3: Fetch with resultRecordCount=100 ===\n")
fetch_url <- paste0(base, "/query?where=1%3D1&outFields=PHU_ID,PHU_NAME_ENG&resultRecordCount=100&f=geojson")
resp <- request(fetch_url) %>% req_perform()
geojson <- fromJSON(resp_body_string(resp))
cat("Features returned:", length(geojson$features), "\n")
cat("exceededTransferLimit:", geojson$exceededTransferLimit %||% "not present", "\n\n")

# 4. List all PHUs
cat("=== All PHU names ===\n")
if (length(geojson$features) > 0) {
  props <- geojson$features$properties
  print(data.frame(PHU_ID = props$PHU_ID, Name = props$PHU_NAME_ENG))
}
