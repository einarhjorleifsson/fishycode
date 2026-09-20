# paths.R — the single place that resolves data locations.
#
# Input:  environment variable FISHYDATA
# Output: path helpers used by every script in this repo
#
# No script anywhere in this repo hardcodes an absolute path, and nothing writes
# into the repo tree. The previous pipelines hardcoded /heima/einarhj/... and
# /u3/geo/... in 17 places, none of which resolve on a laptop; that is the
# failure this file exists to remove.
#
# Layout under $FISHYDATA:
#   raw/        immutable source dumps      never modified, never versioned
#   staging/    source-shaped parquet       one directory per source system
#   curated/    merged-shaped parquet       the sweep — the product
#   published/  versioned releases          tiers A+B only, mirrored to the web

fishydata_root <- function() {
  root <- Sys.getenv("FISHYDATA", unset = NA_character_)
  if (is.na(root) || !nzchar(root)) {
    stop(
      "FISHYDATA is not set.\n",
      "  Add to ~/.Renviron:  FISHYDATA=/path/to/fishydata-store\n",
      "  then restart R.",
      call. = FALSE
    )
  }
  if (!dir.exists(root)) {
    stop("FISHYDATA points at a directory that does not exist: ", root, call. = FALSE)
  }
  normalizePath(root, mustWork = TRUE)
}

fd_path      <- function(...) file.path(fishydata_root(), ...)
fd_raw       <- function(...) fd_path("raw", ...)
fd_staging   <- function(...) fd_path("staging", ...)
fd_curated   <- function(...) fd_path("curated", ...)
fd_published <- function(...) fd_path("published", ...)
