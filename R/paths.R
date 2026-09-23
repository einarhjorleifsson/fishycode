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

  # R reads .Renviron from the working directory at STARTUP, and this repo keeps
  # its own at the root. Anything started from a subdirectory therefore never sees
  # FISHYDATA - which is why docs/ could not read curated/ despite AGENTS.md saying
  # it does: quarto runs each .qmd with docs/ as the working directory, so no page
  # that opened a dataset could render. Walk up to the repo root and read it.
  if (is.na(root) || !nzchar(root)) {
    d <- normalizePath(getwd(), mustWork = FALSE)
    for (i in 1:5) {
      if (file.exists(file.path(d, ".Renviron")) &&
          file.exists(file.path(d, "AGENTS.md"))) {
        readRenviron(file.path(d, ".Renviron"))
        root <- Sys.getenv("FISHYDATA", unset = NA_character_)
        break
      }
      up <- dirname(d)
      if (identical(up, d)) break
      d <- up
    }
  }

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

fd_path <- function(...) file.path(fishydata_root(), ...)

# Ensure the containing directory exists, then return the path.
# Applied to the layers we write to, so a script never fails merely because a
# parent directory has not been created yet. NOT applied to raw/, which is
# read-only input: silently creating a directory there would mask a typo in a
# source path rather than surfacing it.
.fd_writable <- function(layer, ...) {
  p <- fd_path(layer, ...)
  d <- if (grepl("[.][A-Za-z0-9]+$", basename(p))) dirname(p) else p
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  p
}

fd_raw       <- function(...) fd_path("raw", ...)
fd_staging   <- function(...) .fd_writable("staging", ...)
fd_curated   <- function(...) .fd_writable("curated", ...)
fd_published <- function(...) .fd_writable("published", ...)
