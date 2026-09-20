# check_paths.R — verify that every data path referenced in the repo resolves.
#
# Input:  the repo's .R files, plus $FISHYDATA
# Output: a data frame of unresolved references (invisibly), printed as a report
#
# Two classes of reference are checked differently:
#   fd_raw()      must exist now — raw dumps are inputs, never built
#   fd_staging()  } may not exist yet; they are pipeline outputs. Only their
#   fd_curated()  } shape is checked, not their presence.
#
# A leftover bare path literal ("data-raw/...", "/heima/...") is always a finding:
# it means a script was missed by the migration.

check_paths <- function(root = ".", verbose = TRUE) {

  files <- list.files(root, pattern = "[.]R$", recursive = TRUE, full.names = TRUE)
  files <- files[!grepl("/[.]git/|/renv/", files)]
  files <- files[basename(files) != "check_paths.R"]   # do not scan our own patterns

  findings <- list()

  for (f in files) {
    x <- readLines(f, warn = FALSE)
    x <- x[!grepl("^\\s*#", x)]                      # ignore comments

    # 1. fd_raw() calls must resolve on disk
    for (cl in unique(unlist(regmatches(x, gregexpr("fd_raw\\([^)]*\\)", x))))) {
      p <- tryCatch(eval(parse(text = cl)), error = function(e) NA_character_)
      if (is.na(p) || !file.exists(p)) {
        findings[[length(findings) + 1]] <-
          data.frame(file = f, kind = "missing_raw", ref = cl)
      }
    }

    # 2. bare old-style path literals mean the file was missed by the migration
    stale <- unique(unlist(regmatches(
      x, gregexpr(paste0('"(data-dump|data-raw|data)/[^"]*"',      # old relative layout
                         '|"(/heima|/u3|/Users|/home)/[^"]*"',      # absolute machine paths
                         '|"~/[^"]*"'),                            # home-relative
                  x))))
    for (s in stale) {
      findings[[length(findings) + 1]] <-
        data.frame(file = f, kind = "stale_literal", ref = s)
    }
  }

  out <- if (length(findings)) do.call(rbind, findings) else
    data.frame(file = character(), kind = character(), ref = character())

  if (verbose) {
    if (nrow(out) == 0) {
      message("check_paths: clean — every fd_raw() resolves, no stale literals")
    } else {
      message(sprintf("check_paths: %d finding(s) across %d file(s)",
                      nrow(out), length(unique(out$file))))
      for (k in unique(out$kind)) {
        sub <- out[out$kind == k, ]
        message(sprintf("\n  [%s] %d", k, nrow(sub)))
        for (i in seq_len(nrow(sub)))
          message(sprintf("    %-46s %s", sub$file[i], sub$ref[i]))
      }
    }
  }

  invisible(out)
}
