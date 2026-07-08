#!/usr/bin/env Rscript
# Test LIO REST API retrieval for PHU boundaries using httr2 + jsonlite
# Layer: LIO_Open09/44 (MOH Public Health Unit Boundary)

library(httr2)
library(jsonlite)

# ArcGIS REST API query endpoint for GeoJSON
phu_url <- "https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open09/MapServer/44/query?where=1%3D1&outFields=*&f=geojson"

cat("Testing LIO API retrieval...\n")
cat("URL:", phu_url, "\n\n")

# Attempt to fetch and parse
result <- tryCatch({
  resp <- request(phu_url) %>%
    req_perform()
  
  json_text <- resp_body_string(resp)
  geojson <- fromJSON(json_text)
  
  cat("Response received\n")
  cat("Number of features:", length(geojson$features), "\n")
  
  if (length(geojson$features) > 0) {
    cat("\n=== SUCCESS ===\n")
    cat("First feature properties:\n")
    print(geojson$features$properties[1, ])
    
    cat("\nGeometry type:", geojson$features$geometry$type[1], "\n")
    
    # Return first 5 features
    list(
      success = TRUE,
      n_features = length(geojson$features),
      sample = geojson$features$properties[1:5, ],
      geometry_type = geojson$features$geometry$type[1]
    )
  } else {
    cat("\n=== EMPTY RESPONSE ===\n")
    list(success = FALSE, reason = "No features returned")
  }
}, error = function(e) {
  cat("\n=== ERROR ===\n")
  cat(conditionMessage(e), "\n")
  list(success = FALSE, reason = conditionMessage(e))
})

if (is.list(result) && isTRUE(result$success)) {
  cat("\n=== TEST PASSED ===\n")
  cat("LIO REST API is retrievable via httr2 + jsonlite\n")
  cat("Next step: convert GeoJSON to sf object for spatial operations\n")
} else {
  cat("\n=== TEST FAILED ===\n")
}
