#' Get the ONgeoR cache directory
#'
#' @return Character scalar cache directory path.
#' @keywords internal
#' @noRd
ongeor_cache_dir <- function() {
  cache_dir <- tools::R_user_dir("ONgeoR", which = "cache")
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  cache_dir
}

#' Build a cache key for a LIO request
#'
#' @return Character scalar cache key without a file extension.
#' @keywords internal
#' @noRd
cache_key <- function(source_name, service_layer, where, simplify,
                      result_record_count, paginate = FALSE) {
  slug <- tolower(source_name)
  slug <- gsub("[^[:alnum:]]+", "-", slug)
  slug <- gsub("^-+|-+$", "", slug)
  hash <- substr(
    rlang::hash(list(service_layer, where, simplify, result_record_count, paginate)),
    1,
    8
  )

  paste0(slug, "__", hash)
}

#' Read a cached sf object
#'
#' @return An `sf` object, or `NULL` if no cache file exists.
#' @keywords internal
#' @noRd
cache_read <- function(key) {
  rds_path <- file.path(ongeor_cache_dir(), paste0(key, ".rds"))
  if (!file.exists(rds_path)) {
    return(NULL)
  }

  readRDS(rds_path)
}

cache_read_meta <- function(key) {
  yaml_path <- file.path(ongeor_cache_dir(), paste0(key, ".yaml"))
  if (!file.exists(yaml_path)) {
    return(NULL)
  }

  tryCatch(yaml::read_yaml(yaml_path), error = function(cnd) NULL)
}

cache_age_days <- function(meta, now = Sys.time()) {
  retrieved_at <- tryCatch(
    as.POSIXct(meta$retrieved_at, tz = "UTC"),
    warning = function(cnd) NA,
    error = function(cnd) NA
  )
  if (length(retrieved_at) == 0 || is.na(retrieved_at)) {
    return(NA_real_)
  }

  as.numeric(difftime(now, retrieved_at, units = "days"))
}

cache_is_stale <- function(age_days, max_age) {
  if (is.null(max_age)) {
    return(FALSE)
  }
  if (!is.numeric(max_age) || length(max_age) != 1 || is.na(max_age) ||
      max_age < 0) {
    rlang::abort("max_age must be a non-negative numeric scalar.")
  }

  is.na(age_days) || age_days > max_age
}

#' Write an sf object and sidecar metadata to cache
#'
#' @return Invisibly, `NULL`.
#' @keywords internal
#' @noRd
cache_write <- function(key, sf_obj, meta) {
  cache_dir <- ongeor_cache_dir()
  saveRDS(sf_obj, file.path(cache_dir, paste0(key, ".rds")))
  yaml::write_yaml(meta, file.path(cache_dir, paste0(key, ".yaml")))

  invisible(NULL)
}

#' Clear Cached ONgeoR Data
#'
#' @description
#' Removes cached source data from ONgeoR's on-disk cache. By default, all
#' cached entries are removed. Supplying a source id removes only entries whose
#' cached metadata matches that source in the bundled source registry.
#'
#' @param source_id Character scalar or NULL. If supplied, clears only cache
#'   entries for this source registry id; if NULL (default), clears the entire
#'   cache.
#'
#' @return Invisibly, the number of files removed.
#'
#' @examples
#' if (interactive()) {
#'   clear_cache()
#'   clear_cache("phu_boundaries")
#' }
#'
#' @export
clear_cache <- function(source_id = NULL) {
  cache_dir <- ongeor_cache_dir()
  sidecars <- list.files(cache_dir, pattern = "\\.yaml$", full.names = TRUE)

  if (is.null(source_id)) {
    files <- list.files(
      cache_dir,
      pattern = "\\.(rds|yaml)$",
      full.names = TRUE
    )
  } else {
    target_name <- get_source(source_id)$name
    sidecars <- sidecars[vapply(sidecars, function(sidecar) {
      meta <- yaml::read_yaml(sidecar)
      identical(meta$source_name, target_name)
    }, logical(1))]
    keys <- sub("\\.yaml$", "", basename(sidecars))
    files <- as.vector(rbind(
      file.path(cache_dir, paste0(keys, ".rds")),
      file.path(cache_dir, paste0(keys, ".yaml"))
    ))
    files <- files[file.exists(files)]
  }

  existing_files <- files[file.exists(files)]
  if (length(existing_files) > 0) {
    unlink(existing_files)
  }
  deleted_files <- existing_files[!file.exists(existing_files)]
  entries_removed <- sum(grepl("\\.rds$", deleted_files))
  message(sprintf("Removed %d cached entr%s.", entries_removed,
    if (entries_removed == 1) "y" else "ies"
  ))

  invisible(length(deleted_files))
}

#' List Cached ONgeoR Data
#'
#' @description
#' Lists the source metadata currently stored in ONgeoR's on-disk cache.
#'
#' @return A tibble::tibble() with columns source_name, retrieved_at,
#'   age_days, file_size_kb -- one row per cached entry.
#'
#' @examples
#' if (interactive()) {
#'   list_cache()
#' }
#'
#' @export
list_cache <- function() {
  cache_dir <- ongeor_cache_dir()
  sidecars <- list.files(cache_dir, pattern = "\\.yaml$", full.names = TRUE)

  if (length(sidecars) == 0) {
    return(tibble::tibble(
      source_name = character(),
      retrieved_at = character(),
      age_days = numeric(),
      file_size_kb = numeric()
    ))
  }

  rows <- lapply(sidecars, function(sidecar) {
    meta <- yaml::read_yaml(sidecar)
    key <- sub("\\.yaml$", "", basename(sidecar))
    rds_path <- file.path(cache_dir, paste0(key, ".rds"))

    tibble::tibble(
      source_name = meta$source_name %||% NA_character_,
      retrieved_at = meta$retrieved_at %||% NA_character_,
      age_days = round(cache_age_days(meta), 1),
      file_size_kb = round(file.size(rds_path) / 1024, 1)
    )
  })

  do.call(rbind, rows)
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
