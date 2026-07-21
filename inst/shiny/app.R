# Thin launcher for the ONgeoR Shiny app.
#
# Keep the large implementation file byte-for-byte intact and apply the startup
# lifecycle correction before evaluating it. This avoids source-time worker
# creation while preserving the existing app implementation and test fixtures.

.app_file <- tryCatch(
  normalizePath(sys.frame(1)$ofile, mustWork = TRUE),
  error = function(cnd) normalizePath(file.path(getwd(), "app.R"), mustWork = TRUE)
)
.app_impl <- file.path(dirname(.app_file), "app_impl.R")
.app_source <- paste(readLines(.app_impl, warn = FALSE), collapse = "\n")

.old_startup <- paste(
  "# plan() returns the previous plan; restore it when the app stops so a",
  "# multisession plan does not leak into the caller's R session.",
  ".previous_future_plan <- future::plan(future::multisession)",
  "shiny::onStop(function() future::plan(.previous_future_plan))",
  sep = "\n"
)

.new_startup <- paste(
  "# Keep app sourcing side-effect free. Capture the caller's plan now, but",
  "# initialize a bounded worker pool only when a user invokes async work.",
  ".previous_future_plan <- future::plan()",
  ".async_plan_initialized <- FALSE",
  "ensure_async_plan <- function() {",
  "  if (!isTRUE(.async_plan_initialized)) {",
  "    future::plan(future::multisession, workers = 2L)",
  "    .async_plan_initialized <<- TRUE",
  "  }",
  "  invisible(NULL)",
  "}",
  "shiny::onStop(function() {",
  "  if (isTRUE(.async_plan_initialized)) {",
  "    future::plan(.previous_future_plan)",
  "  }",
  "})",
  sep = "\n"
)

if (length(gregexpr(.old_startup, .app_source, fixed = TRUE)[[1]]) != 1L ||
    gregexpr(.old_startup, .app_source, fixed = TRUE)[[1]][1] < 0L) {
  stop("ONgeoR Shiny launcher could not locate the expected future-plan startup block.")
}
.app_source <- sub(.old_startup, .new_startup, .app_source, fixed = TRUE)

for (.task in c(
  "preview_task$invoke(",
  "build_task$invoke(",
  "nearest_preview_task$invoke(",
  "nearest_task$invoke("
)) {
  .hits <- gregexpr(.task, .app_source, fixed = TRUE)[[1]]
  if (length(.hits) != 1L || .hits[1] < 0L) {
    stop(sprintf("ONgeoR Shiny launcher expected exactly one '%s'.", .task))
  }
  .app_source <- sub(
    .task,
    paste0("ensure_async_plan()\n    ", .task),
    .app_source,
    fixed = TRUE
  )
}

eval(parse(text = .app_source, keep.source = TRUE), envir = environment())
rm(.app_file, .app_impl, .app_source, .old_startup, .new_startup, .task, .hits)
