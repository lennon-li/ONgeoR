#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
refresh <- "--refresh" %in% args
args <- setdiff(args, "--refresh")

if (!length(args) %in% c(2, 3)) {
  cat(
    "Usage: Rscript inst/cli/ongeor.R <from_ids> <to_ids> [output_dir] [--refresh]\n",
    file = stderr()
  )
  quit(status = 1)
}

from_ids <- strsplit(args[1], ",", fixed = TRUE)[[1]]
to_ids <- strsplit(args[2], ",", fixed = TRUE)[[1]]

if (requireNamespace("ONgeoR", quietly = TRUE)) {
  library(ONgeoR)
  if (!exists("retrieve_layers", envir = asNamespace("ONgeoR"), inherits = FALSE)) {
    devtools::load_all(".")
  }
} else {
  devtools::load_all(".")
}

retrieve_layers <- get("retrieve_layers", asNamespace("ONgeoR"))
cross_crosswalk <- get("cross_crosswalk", asNamespace("ONgeoR"))
render_reproducer_script <- get("render_reproducer_script", asNamespace("ONgeoR"))

valid_ids <- list_sources()$source_id
unknown_ids <- setdiff(unique(c(from_ids, to_ids)), valid_ids)
if (length(unknown_ids) > 0) {
  cat(
    sprintf(
      "Unknown source id(s): %s. Valid source ids are: %s.\n",
      paste(unknown_ids, collapse = ", "),
      paste(valid_ids, collapse = ", ")
    ),
    file = stderr()
  )
  quit(status = 1)
}

output_dir <- if (length(args) >= 3) {
  args[3]
} else {
  file.path("ongeor_output", format(Sys.time(), "%Y%m%d_%H%M%S"))
}
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

layers <- retrieve_layers(unique(c(from_ids, to_ids)), refresh = refresh)
cw <- cross_crosswalk(from_ids, to_ids, refresh = refresh)
map <- map_crosswalk(layers, from_ids, to_ids)

crosswalk_path <- file.path(output_dir, "crosswalk.csv")
map_path <- file.path(output_dir, "map.html")
reproduce_path <- file.path(output_dir, "reproduce.R")

write.csv(cw, crosswalk_path, row.names = FALSE)
htmlwidgets::saveWidget(map, map_path, selfcontained = TRUE)
writeLines(render_reproducer_script(from_ids, to_ids, output_dir), reproduce_path)

cat(sprintf("from-to pairs: %d\n", length(from_ids) * length(to_ids)))
cat(sprintf("crosswalk rows: %d\n", nrow(cw)))
cat(sprintf("cache: %s\n", if (refresh) "bypassed (--refresh)" else "used if available"))
cat(sprintf("crosswalk: %s\n", crosswalk_path))
cat(sprintf("map: %s\n", map_path))
cat(sprintf("reproducer: %s\n", reproduce_path))
