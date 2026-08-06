library(ONgeoR)

source_ids <- c("phu_boundaries", "airport_official")

for (source_id in source_ids) {
  result <- retrieve_source(source_id, refresh = TRUE)

  if (!inherits(result, "sf") || nrow(result) <= 0) {
    stop(source_id, " did not return a non-empty sf object")
  }

  cat(source_id, "OK:", nrow(result), "rows\n")
}

cat("live smoke passed\n")
