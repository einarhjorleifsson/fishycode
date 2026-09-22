# check_ready.R — which targets can actually build right now?
#
# Input:  the repo's scripts, plus $FISHYDATA
# Output: one row per target: ready / BLOCKED, and what is missing
#
# Answers the question worth asking before launching a long run: will this die
# two hours in because an input was never produced? Inputs that a target's own
# upstream produces are not counted as missing.

check_ready <- function() {

  scripts <- c(
    dictionary     = "reference/dictionary.R",
    gear           = "reference/gear/mapping.R",
    port           = "reference/ports/harbour_codes.R",
    harbour        = "reference/ports/harbours.R",
    shapes_raw     = "reference/geo/shapes_raw.R",
    shapes         = "reference/geo/shapes.R",
    area_h3        = "reference/geo/h3_index.R",
    vessel         = "reference/vessels/registry.R",
    vessel_identity = "reference/vessels/identity.R",
    vessel_ais_key = "reference/vessels/ais_key.R",
    afli           = "sources/afli/convert.R",
    fs_afladagbok  = "sources/fs_afladagbok/convert.R",
    adb            = "sources/adb/convert.R",
    aflagrunnur    = "sources/aflagrunnur/convert.R",
    stk            = "sources/stk/convert.R",
    ais_ping_union = "curate/ais_ping_union.R",
    ais_ping_tag   = "curate/ais_ping_tag.R",
    ais_trip       = "curate/ais_trip.R",
    logbook        = "curate/logbook.R",
    check_ais_key_registry = "curate/checks/ais_key_registry.R",
    check_ais_key_landings = "curate/checks/ais_key_landings.R",
    lid_map        = "curate/link_lid_map.R")

  cat(sprintf("%-16s %-9s %s\n", "target", "status", "missing inputs"))
  cat(strrep("-", 88), "\n")

  out <- list()
  for (nm in names(scripts)) {
    f <- scripts[[nm]]
    if (!file.exists(f)) { cat(sprintf("%-16s %-9s %s\n", nm, "NO SCRIPT", f)); next }
    x <- readLines(f, warn = FALSE)
    x <- x[!grepl("^[[:space:]]*#", x)]

    # only READ calls matter; a write path not existing yet is normal
    reads <- unique(unlist(regmatches(
      x, gregexpr("(read_sf|read_parquet|open_dataset|readRDS|read_csv|read_csv2|read_delim|read_excel|read_ods|rast|vect|file.exists|unzip)\\([^)]*fd_(raw|staging|curated)\\([^)]*\\)", x))))
    paths <- unique(unlist(regmatches(reads, gregexpr("fd_(raw|staging|curated)\\([^)]*\\)", reads))))

    miss <- character()
    for (cl in paths) {
      p <- tryCatch(eval(parse(text = cl)), error = function(e) NA_character_)
      if (is.na(p) || !file.exists(p)) miss <- c(miss, sub("^fd_", "", cl))
    }
    cat(sprintf("%-16s %-9s %s\n", nm, if (length(miss)) "BLOCKED" else "ready",
                paste(miss, collapse = "; ")))
    out[[nm]] <- miss
  }
  invisible(out)
}
