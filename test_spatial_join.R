# Test spatial join: points to PHU boundaries
# Validates: retrieve boundaries, convert to sf, join points, output table

library(httr2)
library(jsonlite)
library(sf)

# Step 1: Retrieve PHU boundaries
cat("=== Step 1: Retrieve PHU boundaries ===\n")
phu_url <- "https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open09/MapServer/44/query?where=1%3D1&outFields=*&resultRecordCount=2000&f=geojson"

resp <- request(phu_url) %>% req_perform()
geojson <- resp %>% resp_body_string() %>% fromJSON()

cat("Retrieved", length(geojson$features), "PHU boundaries\n\n")

# Step 2: Convert to sf object
cat("=== Step 2: Convert to sf ===\n")
phu_sf <- st_read(geojson, quiet = TRUE)
cat("sf object created with", nrow(phu_sf), "features\n")
cat("CRS:", st_crs(phu_sf)$input, "\n\n")

# Step 3: Create test points (Toronto, Ottawa, Thunder Bay)
cat("=== Step 3: Create test points ===\n")
test_points <- data.frame(
  point_id = 1:3,
  point_name = c("Toronto", "Ottawa", "Thunder Bay"),
  lon = c(-79.3832, -75.6972, -89.6306),
  lat = c(43.6532, 45.4215, 48.3822)
)

points_sf <- st_as_sf(test_points, coords = c("lon", "lat"), crs = 4326)
cat("Created", nrow(points_sf), "test points\n\n")

# Step 4: Spatial join
cat("=== Step 4: Spatial join ===\n")
joined <- st_join(points_sf, phu_sf)
cat("Join completed\n\n")

# Step 5: Output table
cat("=== Step 5: Output table ===\n")
result <- data.frame(
  point_id = joined$point_id,
  point_name = joined$point_name,
  lon = st_coordinates(joined)[,1],
  lat = st_coordinates(joined)[,2],
  phu_id = joined$PHU_ID,
  phu_name_en = joined$PHU_NAME_ENG,
  retrieved_at = Sys.time()
)

print(result)

cat("\n=== SUCCESS ===\n")
cat("All", nrow(result), "points successfully joined to PHU boundaries\n")
