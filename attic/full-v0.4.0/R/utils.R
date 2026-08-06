#' @importFrom rlang .data
NULL

lio_base_url <- "https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA"

lio_now <- function() Sys.time()

inform_lio_progress <- function(message) {
  rlang::inform(message, class = "ongeor_retrieval_progress")
}

abort_lio_retrieval <- function(message, parent = NULL) {
  rlang::abort(
    message,
    class = "ongeor_retrieval_error",
    parent = parent
  )
}

lio_response_truncated <- function(geojson_string) {
  grepl(
    "\"exceededTransferLimit\"[[:space:]]*:[[:space:]]*true",
    geojson_string
  )
}

validate_lio_feature_count <- function(n, registry_entry) {
  if (is.null(registry_entry) || !is.numeric(registry_entry$feature_count) ||
      length(registry_entry$feature_count) != 1 ||
      is.na(registry_entry$feature_count)) {
    return(invisible(NULL))
  }

  expected <- registry_entry$feature_count
  deviation <- if (expected == 0) n != 0 else abs(n - expected) / expected > 0.2
  if (deviation) {
    rlang::warn(
      sprintf(
        paste(
          "Retrieved %d features but the registry expects %d for '%s';",
          "the registry may be stale or retrieval may be incomplete."
        ),
        n,
        expected,
        registry_entry$name %||% "this source"
      ),
      class = "ongeor_feature_count_mismatch"
    )
  }

  invisible(NULL)
}

# The maxAllowableOffset (in degrees, since the service returns EPSG:4326)
# applied when simplify = TRUE. Shared between lio_query_url() (which sends
# it) and fetch_lio_sf() (which records it as provenance), so the two can
# never drift apart. See the measurement note in lio_query_url() for why
# this value was chosen.
lio_simplify_offset_deg <- 1e-04

lio_simplify_guidance <- function(simplify) {
  if (simplify) {
    "Generalized geometry is already requested (simplify = TRUE)."
  } else {
    paste(
      "If generalized geometry is acceptable and supported for this layer,",
      "try simplify = TRUE."
    )
  }
}

#' Build a LIO ArcGIS REST query URL
#'
#' @param service_layer Character. Service and layer path, e.g. `"LIO_Open09/44"`.
#' @param where Character. SQL-style filter expression. Defaults to `"1=1"`.
#' @param simplify Logical. Whether to request generalized geometry via
#'   `maxAllowableOffset`.
#' @param result_record_count Integer. Maximum number of records to request.
#' @param result_offset Integer. Record offset for paginated requests.
#'
#' @return A character scalar: the full query URL.
#' @keywords internal
#' @noRd
lio_query_url <- function(service_layer, where = "1=1", simplify = TRUE,
                          result_record_count = 2000, result_offset = 0) {
  params <- list(
    where = where,
    outFields = "*",
    f = "geojson",
    resultRecordCount = result_record_count
  )
  if (result_offset > 0) {
    params$resultOffset <- result_offset
  }
  if (simplify) {
    # The service returns EPSG:4326, so maxAllowableOffset is in DEGREES. The
    # previous value of 10 meant a ~1,100 km tolerance, which made the server
    # collapse every small or urban polygon to zero area. Measured live on
    # 2026-07-29 for LIO_Open09/44 (PHU boundaries), raw response, no
    # client-side repair: at offset 10, Toronto, Peel, Halton, Hamilton,
    # Windsor-Essex, Niagara, York, Ottawa and Middlesex-London all came back
    # with area 0, Waterloo was inflated 3.3x and Durham 1.7x, and the layer
    # totalled 646,394 km2 against 983,322 km2 at offset 1e-04 - a third of
    # Ontario silently missing, with the survivors misshapen.
    #
    # 1e-04 degrees is ~11 m: fine enough that 28 of 29 boundaries stay
    # polygonal and areas match full resolution, while still generalizing
    # (12.8 MB versus a full-resolution request the service will not serve).
    params$maxAllowableOffset <- lio_simplify_offset_deg
  }

  parts <- strsplit(service_layer, "/", fixed = TRUE)[[1]]
  service <- parts[1]
  layer <- parts[2]

  paste0(lio_base_url, "/", service, "/MapServer/", layer, "/query") |>
    httr2::url_parse() |>
    httr2::url_modify_query(!!!params) |>
    httr2::url_build()
}

#' Repair geometry validity without silently deleting features
#'
#' `sf::st_make_valid()` dispatches to the s2 backend for geographic
#' coordinates, and s2 rejects the degenerate rings (duplicate vertices) that
#' LIO's server-side generalization emits: instead of repairing them it returns
#' EMPTY geometry. Measured live on 2026-07-29 for LIO_Open09/44 (PHU
#' boundaries) at `maxAllowableOffset = 10`: 11 of 29 boundaries -- Toronto,
#' Peel, Niagara, Middlesex-London among them -- came back as empty
#' GEOMETRYCOLLECTIONs, so the map drew 18 units and silently omitted the rest.
#' The same call with s2 disabled repairs all 29 and empties none.
#'
#' So do validity repair on the planar GEOS path, then verify: if any feature
#' that arrived with geometry leaves without it, that is data loss and must
#' abort rather than reach a map.
#'
#' @param x An sf object straight from `sf::st_read()`.
#' @return `x` with valid geometry and the same number of non-empty features.
#' @keywords internal
#' @noRd
lio_make_valid <- function(x) {
  if (!inherits(x, "sf") || nrow(x) == 0) {
    return(x)
  }
  had_geometry <- !sf::st_is_empty(x)
  was_areal <- as.character(sf::st_geometry_type(x)) %in%
    c("POLYGON", "MULTIPOLYGON")

  # GEOS repairs invalid rings with the "linework" method, which is allowed to
  # hand back a GEOMETRYCOLLECTION of polygons plus dangling lines. Keep only
  # the polygonal part of any feature that arrived areal, so a boundary layer
  # can never reach a map or a spatial join as LINESTRING.
  keep_areal <- function(obj) {
    if (!any(was_areal)) {
      return(obj)
    }
    geometry <- sf::st_geometry(obj)
    mixed <- was_areal & as.character(sf::st_geometry_type(geometry)) %in%
      c("GEOMETRYCOLLECTION", "LINESTRING", "MULTILINESTRING", "POINT",
        "MULTIPOINT")
    if (!any(mixed)) {
      return(obj)
    }
    geometry[mixed] <- lapply(geometry[mixed], function(geom) {
      parts <- try(
        sf::st_collection_extract(sf::st_sfc(geom), "POLYGON"),
        silent = TRUE
      )
      if (inherits(parts, "try-error") || length(parts) == 0) {
        sf::st_polygon()
      } else {
        sf::st_combine(parts)[[1]]
      }
    })
    sf::st_geometry(obj) <- sf::st_sfc(geometry, crs = sf::st_crs(obj))
    obj
  }

  # Pass 1, planar GEOS: fixes self-intersecting rings without s2's habit of
  # discarding whatever it cannot interpret.
  previous_s2 <- sf::sf_use_s2()
  suppressMessages(sf::sf_use_s2(FALSE))
  repaired <- keep_areal(sf::st_make_valid(x))
  suppressMessages(sf::sf_use_s2(previous_s2))

  # Pass 2, under the caller's setting. GEOS validity is not s2 validity: a
  # ring GEOS accepts can still have crossing loops, and every downstream
  # predicate (st_intersects in link()/build_crosswalk()) goes through s2 by
  # default, where that aborts with "Loop N edge M crosses loop ...". Rebuild
  # under s2 so the layer is usable by the operations it exists to feed.
  if (isTRUE(previous_s2)) {
    rebuilt <- try(keep_areal(sf::st_make_valid(repaired)), silent = TRUE)
    if (!inherits(rebuilt, "try-error")) {
      repaired <- rebuilt
    }
  }

  lost <- had_geometry & sf::st_is_empty(repaired)
  if (any(lost)) {
    abort_lio_retrieval(sprintf(
      paste(
        "Geometry repair left %d of %d features with no usable geometry.",
        "Refusing to return a layer with silently missing shapes."
      ),
      sum(lost),
      nrow(x)
    ))
  }
  repaired
}

#' Retrieve a LIO layer and convert it to an sf object with provenance
#'
#' @param service_layer Character. Service and layer path, e.g. `"LIO_Open09/44"`.
#' @param source_name Character. Human-readable source name for provenance.
#' @param where Character. SQL-style filter expression.
#' @param simplify Logical. Whether to request generalized geometry.
#' @param result_record_count Integer. Maximum number of records to request.
#' @param refresh Logical. If `TRUE`, bypasses any cached copy and re-fetches
#'   from the live API, overwriting the cache entry. Defaults to `FALSE`.
#' @param paginate Logical. If `TRUE`, retrieve pages with `resultOffset`
#'   until the service reports that the response is not truncated. Pages
#'   request 2000 features by default; pagination has a 20-page hard cap,
#'   allowing at most 40,000 features. Truncation is detected through the
#'   ArcGIS `exceededTransferLimit` response flag.
#' @param max_age Numeric or `NULL`. Maximum acceptable cache age in days;
#'   older entries are re-fetched. Defaults to `NULL`.
#'
#' @return An `sf` object with `source_url`, `source_name`, `retrieved_at`,
#'   and `simplify` attributes attached. `simplify` records the
#'   `maxAllowableOffset` (in degrees) actually applied to the retrieval: `0`
#'   if `simplify = FALSE` (no generalization), or the offset value if
#'   `simplify = TRUE`. This lets downstream area-ratio outputs (e.g.
#'   `share_of_target`/`share_of_source` in [build_intersection()]) be traced
#'   back to whether the geometry behind them was generalized.
#' @keywords internal
#' @noRd
fetch_lio_sf <- function(service_layer, source_name, where = "1=1",
                         simplify = TRUE, result_record_count = 2000,
                         refresh = FALSE, paginate = FALSE, max_age = NULL) {
  key <- cache_key(
    source_name = source_name,
    service_layer = service_layer,
    where = where,
    simplify = simplify,
    result_record_count = result_record_count,
    paginate = paginate
  )
  if (!refresh) {
    cache_meta <- cache_read_meta(key)
    cache_age <- cache_age_days(cache_meta %||% list())
    cached <- tryCatch(
      cache_read(key),
      error = function(cnd) {
        abort_lio_retrieval(
          sprintf(
            paste(
              "Could not read cached data for source '%s' (layer '%s').",
              "Use refresh = TRUE to bypass and replace this cache entry."
            ),
            source_name,
            service_layer
          ),
          parent = cnd
        )
      }
    )
    if (!is.null(cached)) {
      inform_lio_progress(sprintf(
        "Cache hit for source '%s' (cache age: %s).",
        source_name,
        if (is.na(cache_age)) "unknown age" else sprintf("%.1f days", cache_age)
      ))
      if (!cache_is_stale(cache_age, max_age)) {
        return(cached)
      }
      refresh <- TRUE
    }
  }

  started_at <- lio_now()
  inform_lio_progress(sprintf(
    "Retrieving source '%s' (layer '%s').",
    source_name,
    service_layer
  ))

  read_lio_page <- function(result_offset = 0) {
    url <- lio_query_url(
      service_layer = service_layer,
      where = where,
      simplify = simplify,
      result_record_count = result_record_count,
      result_offset = result_offset
    )

    sf_obj <- tryCatch(
      {
        resp <- httr2::request(url) |>
          httr2::req_retry(
            max_tries = 3,
            retry_on_failure = TRUE,
            is_transient = function(resp) {
              status <- httr2::resp_status(resp)
              status == 429 || (status >= 500 && status <= 599)
            }
          ) |>
          httr2::req_perform()
        geojson <- httr2::resp_body_string(resp)
        truncated <- lio_response_truncated(geojson)

        temp_file <- tempfile(fileext = ".geojson")
        on.exit(unlink(temp_file), add = TRUE)
        writeLines(geojson, temp_file)
        sf_obj <- sf::st_read(temp_file, quiet = TRUE)
        lio_make_valid(sf_obj)
      },
      error = function(cnd) {
        abort_lio_retrieval(
          sprintf(
            paste(
              "Could not retrieve source '%s' (layer '%s').",
              "Retry later; transient requests are limited to three attempts.",
              "%s"
            ),
            source_name,
            service_layer,
            lio_simplify_guidance(simplify)
          ),
          parent = cnd
        )
      }
    )

    list(url = url, sf_obj = sf_obj, truncated = truncated)
  }

  first_url <- lio_query_url(
    service_layer = service_layer,
    where = where,
    simplify = simplify,
    result_record_count = result_record_count
  )

  if (paginate) {
    max_pages <- 20
    pages <- list()
    result_offset <- 0
    page_number <- 1

    repeat {
      if (length(pages) >= max_pages) {
        abort_lio_retrieval(sprintf(
          paste(
            "Stopped retrieving source '%s' (layer '%s') at the %d-page",
            "pagination hard cap to avoid an unbounded request loop.",
            paste(
              "Narrow the query and retry; if the layer legitimately exceeds",
              "the safety cap, report it so the package limit can be reviewed",
              "deliberately."
            )
          ),
          source_name,
          service_layer,
          max_pages
        ))
      }

      if (page_number > 1) {
        inform_lio_progress(sprintf(
          "Retrieving page %d for source '%s' (layer '%s').",
          page_number,
          source_name,
          service_layer
        ))
      }

      page <- read_lio_page(result_offset)
      n <- nrow(page$sf_obj)

      if (n > 0) {
        pages[[length(pages) + 1]] <- page$sf_obj
      }
      if (!page$truncated) {
        break
      }
      if (n == 0) {
        abort_lio_retrieval(sprintf(
          paste(
            "Server returned an empty truncated page for source '%s'",
            "(layer '%s'); cannot advance pagination safely. Retry later."
          ),
          source_name,
          service_layer
        ))
      }

      # Advance by the rows actually returned, not the requested page size:
      # the server may cap pages below result_record_count, and skipping the
      # difference would silently drop features.
      result_offset <- result_offset + n
      page_number <- page_number + 1
    }

    sf_obj <- if (length(pages) == 0) {
      page$sf_obj
    } else if (length(pages) == 1) {
      pages[[1]]
    } else {
      do.call(rbind, pages)
    }
    url <- first_url
  } else {
    page <- read_lio_page()
    if (page$truncated) {
      abort_lio_retrieval(sprintf(
        paste(
          "Source '%s' (layer '%s') exceeds one page;",
          "retrieve it with paginate = TRUE."
        ),
        source_name,
        service_layer
      ))
    }
    sf_obj <- page$sf_obj
    url <- page$url
  }

  attr(sf_obj, "source_url") <- url
  attr(sf_obj, "source_name") <- source_name
  attr(sf_obj, "retrieved_at") <- Sys.time()
  # Record what was actually applied, not just the flag: the offset itself is
  # what determines how much area error simplification could have introduced.
  # 0 is unambiguous here because lio_query_url() never sends an offset of
  # exactly 0 when simplify = TRUE (it sends lio_simplify_offset_deg), so 0
  # can only mean "no simplification requested".
  attr(sf_obj, "simplify") <- if (simplify) lio_simplify_offset_deg else 0

  registry <- load_source_registry()
  matching_entries <- which(vapply(
    registry,
    function(entry) identical(entry$name, source_name),
    logical(1)
  ))
  registry_entry <- if (length(matching_entries) == 0) {
    NULL
  } else {
    registry[[matching_entries[[1]]]]
  }
  validate_lio_feature_count(nrow(sf_obj), registry_entry)

  cache_write(
    key,
    sf_obj,
    meta = list(
      source_name = source_name,
      source_url = url,
      where = where,
      simplify = simplify,
      retrieved_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC")
    )
  )

  elapsed <- as.numeric(difftime(lio_now(), started_at, units = "secs"))
  if (elapsed >= 2) {
    inform_lio_progress(sprintf(
      "Retrieved source '%s': %d rows in %.1f seconds.",
      source_name,
      nrow(sf_obj),
      elapsed
    ))
  }

  sf_obj
}

#' Guess an identifier column in an sf/data.frame layer
#'
#' @param x An `sf` object or `data.frame`.
#'
#' @return Character scalar: the guessed id column name. Falls back to the
#'   first non-geometry column if no `*ID`/`*IDENT` column is found.
#' @keywords internal
#' @noRd
generic_lio_fields <- c("OGF_ID", "OBJECTID")

# Matches identifier columns ending in "ID" (e.g. PHU_ID, MUNID) or "IDENT"
# (e.g. AIRPORT_IDENT, MOH_SERVICE_PROVIDER_IDENT). The "IDENT" case matters:
# several LIO layers name their domain identifier `*_IDENT`, which a bare
# `ID$` pattern misses -- leaving only the generic `OGF_ID` to match, which is
# the wrong column to resolve against.
id_col_pattern <- "ID(ENT)?$"

guess_id_col <- function(x) {
  cols <- setdiff(colnames(x), attr(x, "sf_column"))
  candidates <- setdiff(cols, generic_lio_fields)
  id_cols <- candidates[grepl(id_col_pattern, candidates, ignore.case = TRUE)]
  if (length(id_cols) > 0) {
    return(id_cols[1])
  }
  id_cols <- cols[grepl(id_col_pattern, cols, ignore.case = TRUE)]
  if (length(id_cols) > 0) {
    return(id_cols[1])
  }
  cols[1]
}

#' Guess a name column in an sf/data.frame layer
#'
#' @param x An `sf` object or `data.frame`.
#'
#' @return Character scalar: the guessed name column name. Prefers an
#'   English name column, then any `*NAME*` column, then falls back to the
#'   first non-geometry column.
#'
#' @examples
#' guess_name_col(data.frame(feature_id = 1, feature_name_eng = "Example"))
#'
#' @family app support interfaces
#' @export
guess_name_col <- function(x) {
  cols <- setdiff(colnames(x), attr(x, "sf_column"))
  name_cols <- cols[grepl("NAME", cols, ignore.case = TRUE)]
  if (length(name_cols) == 0) {
    return(cols[1])
  }
  eng_cols <- name_cols[grepl("ENG", name_cols, ignore.case = TRUE)]
  if (length(eng_cols) > 0) {
    return(eng_cols[1])
  }
  name_cols[1]
}

registry_entry_for <- function(layer) {
  source_name <- provenance_attr(layer, "source_name")
  if (length(source_name) != 1 || is.na(source_name)) {
    return(NULL)
  }

  registry <- load_source_registry()
  matches <- vapply(
    registry,
    function(entry) identical(entry$name, source_name),
    logical(1)
  )
  if (!any(matches)) NULL else registry[[which(matches)[1]]]
}

#' Resolve the id column of a retrieved layer
#'
#' Returns the column that identifies each feature of `layer`. When the layer
#' carries retrieval provenance, the answer comes from the source registry's
#' declared key fields, so it matches the `from_id_col` / `to_id_col` values
#' recorded in [build_crosswalk()] and [build_intersection()] output. Layers
#' without provenance fall back to a name-pattern guess.
#'
#' This is the supported way for a downstream caller to join a crosswalk or
#' linked table back onto the layer geometry it came from.
#'
#' @param layer An `sf` object or `data.frame`.
#'
#' @return Character scalar: the id column name.
#'
#' @examples
#' layer_id_col(data.frame(PHU_ID = 2253, PHU_NAME_ENG = "Example"))
#'
#' @family app support interfaces
#' @export
layer_id_col <- function(layer) {
  entry <- registry_entry_for(layer)
  key_fields <- entry$key_fields %||% character()
  present <- key_fields[key_fields %in% colnames(layer)]
  if (length(present) > 0) present[1] else guess_id_col(layer)
}

layer_name_col <- function(layer) {
  entry <- registry_entry_for(layer)
  key_fields <- entry$key_fields %||% character()
  name_fields <- key_fields[
    grepl("NAME", key_fields, ignore.case = TRUE) &
      key_fields %in% colnames(layer)
  ]
  eng_fields <- name_fields[grepl("ENG", name_fields, ignore.case = TRUE)]
  if (length(eng_fields) > 0) return(eng_fields[1])
  if (length(name_fields) > 0) return(name_fields[1])
  guess_name_col(layer)
}

#' Check whether a layer's geometry is entirely points
#'
#' @param x An `sf` object.
#'
#' @return Logical scalar. `FALSE` for an empty layer.
#' @keywords internal
#' @noRd
is_point_geom <- function(x) {
  if (!inherits(x, "sf") || nrow(x) == 0) {
    return(FALSE)
  }
  all(as.character(sf::st_geometry_type(x)) %in% c("POINT", "MULTIPOINT"))
}

#' Check whether a layer's geometry is entirely polygons
#'
#' @param x An `sf` object.
#'
#' @return Logical scalar. `FALSE` for an empty layer.
#' @keywords internal
#' @noRd
is_polygon_geom <- function(x) {
  if (!inherits(x, "sf") || nrow(x) == 0) {
    return(FALSE)
  }
  all(as.character(sf::st_geometry_type(x)) %in% c("POLYGON", "MULTIPOLYGON"))
}

#' Read a provenance attribute, falling back to NA
#'
#' @param x An object with provenance attributes (`source_url`,
#'   `source_name`, `retrieved_at`).
#' @param which Character. Attribute name to read.
#'
#' @return The attribute value, or `NA` if not present.
#' @keywords internal
#' @noRd
provenance_attr <- function(x, which) {
  val <- attr(x, which)
  if (is.null(val)) NA else val
}

#' Load the bundled source registry
#'
#' @return A named list of source metadata, keyed by source id.
#' @keywords internal
#' @noRd
load_source_registry <- function() {
  registry_path <- system.file("extdata", "sources.yaml", package = "ONgeoR")
  if (!nzchar(registry_path)) {
    rlang::abort("Could not locate inst/extdata/sources.yaml in the ONgeoR package.")
  }
  yaml::read_yaml(registry_path)$sources
}
