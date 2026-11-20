# freeze_version.R — a version of the place names frozen: its files copied, as written, into a folder of their own that is
# never rewritten, with a manifest (plan 080 ask b, decision 333: "Stamp, column, frozen").
# Side: preprocessing (sea-chart names). Standalone, run by hand when a version is reviewed and done, outside the targets flow.
#
# Input:  curated/reference/{marine_name,marine_name_source,marine_name_record,marine_name_extent,marine_name_pair,
#         marine_feature,marine_feature_link}.parquet (those present) and products/marine_feature/names.parquet, the
#         version they hold: their `version` column (version 1, built before the column, has none and is version 1)
#         and the proposals the version was reviewed on, curated/reference/place_name_proposal{,_evidence,_shape}.parquet
#         (plan 081, decision 338; those present), copied beside them with their own version ("081.1", a step of plan 081)
# Output: curated/reference/place_names/v<N>/ - the files, byte for byte, and manifest.csv (file, bytes, md5, the file's
#         fd.built, fd.commit and fd.dirty), README.md (the version, when frozen, by which commit)
#
# It stops if the folder exists (a version is frozen once), if the files hold more than one version, or if a file's version
# differs from the others'. Run from the repo root: Rscript reference/names/freeze_version.R
# Written by Claude (AI), 2026-11-19.

for (f in c("R/paths.R", "R/write_curated.R")) source(f)   # standalone: not targets'
REF <- function(f) fd_curated("reference", f)
FILES <- c(file.path(fd_curated("reference"), paste0(c("marine_name", "marine_name_source", "marine_name_record", "marine_name_extent", "marine_name_pair",
                        "marine_feature", "marine_feature_link"), ".parquet")),
           fd_path("products", "marine_feature", "names.parquet"))
FILES <- FILES[file.exists(FILES)]
PROP <- file.path(fd_curated("reference"), paste0(c("place_name_proposal", "place_name_proposal_evidence", "place_name_proposal_shape"), ".parquet"))
PROP <- PROP[file.exists(PROP)]

con <- DBI::dbConnect(duckdb::duckdb()); on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
q <- function(x) DBI::dbQuoteString(con, x)
ver_of <- function(f) {
  cols <- DBI::dbGetQuery(con, sprintf("DESCRIBE SELECT * FROM read_parquet(%s)", q(f)))$column_name
  if (!"version" %in% cols) return(1L)
  v <- DBI::dbGetQuery(con, sprintf("SELECT DISTINCT version FROM read_parquet(%s)", q(f)))$version
  if (length(v) != 1) stop(f, " holds more than one version: ", paste(v, collapse = ", "))
  as.integer(v)
}
kv_of <- function(f) {
  k <- DBI::dbGetQuery(con, sprintf("SELECT decode(key) AS key, decode(value) AS value FROM parquet_kv_metadata(%s)", q(f)))
  function(key) { v <- k$value[k$key == key]; if (length(v)) v[1] else NA_character_ }
}
v <- vapply(FILES, ver_of, 0L)
# a table that carries no rows of its own version (the links, the record) takes the names' version
main <- v[basename(FILES) == "marine_name.parquet"]
if (length(unique(v[v != 1L | basename(FILES) == "marine_name.parquet"])) > 1) stop("the files hold different versions: ",
  paste(sprintf("%s %d", basename(FILES), v), collapse = "; "))
N <- main
dir <- fd_path("curated", "reference", "place_names", paste0("v", N))   # fd_path: fd_curated() would create it
if (dir.exists(dir)) stop("version ", N, " is frozen already: ", dir)
dir.create(dir, recursive = TRUE)
pver <- function(f) { cols <- DBI::dbGetQuery(con, sprintf("DESCRIBE SELECT * FROM read_parquet(%s)", q(f)))$column_name
  if ("version" %in% cols) paste(DBI::dbGetQuery(con, sprintf("SELECT DISTINCT version FROM read_parquet(%s)", q(f)))$version, collapse = ",") else NA_character_ }
ALL <- c(FILES, PROP)
man <- do.call(rbind, lapply(ALL, function(f) { kv <- kv_of(f)
  data.frame(file = basename(f), from = sub(paste0("^", fd_path(), "/?"), "", f), bytes = file.size(f), md5 = unname(tools::md5sum(f)),
             version = if (f %in% PROP) pver(f) else as.character(v[[f]]),
             built = kv("fd.built"), commit = kv("fd.commit"), dirty = kv("fd.dirty")) }))
stopifnot(file.copy(ALL, file.path(dir, basename(ALL)), copy.date = TRUE))
stopifnot(identical(unname(tools::md5sum(file.path(dir, man$file))), man$md5))
write.csv(man, file.path(dir, "manifest.csv"), row.names = FALSE, fileEncoding = "UTF-8")
g <- .git_info()
writeLines(c(sprintf("# Place names, version %d", N), "",
             sprintf("Frozen %s by fishycode's reference/names/freeze_version.R at %s%s (plan 080 ask b, decision 333).",
                     format(Sys.time(), "%Y-%m-%d %H:%M UTC", tz = "UTC"), substr(g$commit, 1, 7), if (isTRUE(g$dirty)) ", the tree dirty" else ""),
             "The files as they were written, byte for byte; manifest.csv holds each file's md5 and its own build stamps.",
             if (length(PROP)) "With them the proposals it was reviewed on (place_name_proposal*, their own version a step of plan 081).",
             "Never rewritten: a fix enters the next version."), file.path(dir, "README.md"))
cat(sprintf("version %d frozen in %s: %d files, %.1f MB\n", N, dir, nrow(man), sum(man$bytes) / 1e6))
print(man[c("file", "bytes", "version", "built", "commit")])
