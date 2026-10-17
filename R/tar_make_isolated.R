# tar_make_isolated.R — build every outdated target in its own R session, in dependency order.
#
# Input:  the targets graph (_targets.R, _targets/)
# Output: what tar_make() would build; one line per step on stdout
#
# The workaround of TODO 37. tar_make() runs every target in one R session, and produces()
# sources each script into its global environment, so objects pile up: on 2026-10-07 area_h3 and
# check_ais_key_segments both hit R's 24 GB limit that way, and both ran in their own session.
# A fresh `Rscript` per target costs a few seconds and cannot accumulate. It stops at the first
# failure; run it again to resume, since completed targets are no longer outdated.
#
#   Rscript -e 'source("R/tar_make_isolated.R"); tar_make_isolated()'
#
# `names` builds only those targets and their outdated ancestors (tar_outdated(names = )), and leaves
# the rest outdated: the logbook half of a build waits for nothing downstream of a key not yet redone.
#
# It follows TAR_PROJECT (_targets.yaml): set TAR_PROJECT=once for the one-time fixes (plan 014). The
# Rscript per target inherits the variable.

tar_make_isolated <- function(names = NULL) {
  # names is inlined into the call: tar_outdated() evaluates it in a callr process, where the variable does not exist
  o <- if (is.null(names)) targets::tar_outdated() else
    eval(bquote(targets::tar_outdated(names = tidyselect::all_of(.(names)))))
  if (!length(o)) return(invisible(cat("nothing outdated\n")))
  e <- targets::tar_network(targets_only = TRUE, outdated = FALSE)$edges
  e <- e[e$from %in% o & e$to %in% o, ]
  ord <- character(0)
  while (length(ord) < length(o)) {
    ready <- setdiff(o[!o %in% e$to[!e$from %in% ord]], ord)
    if (!length(ready)) stop("cycle among: ", paste(setdiff(o, ord), collapse = ", "))
    ord <- c(ord, ready[1])
  }
  cat("ORDER", length(ord), "targets:", paste(ord, collapse = ", "), "\n")
  for (i in seq_along(ord)) {
    cmd <- sprintf('targets::tar_make(names = %s, reporter = "timestamp")', ord[i])
    st  <- system2("Rscript", c("-e", shQuote(cmd)))
    if (st != 0) stop(sprintf("stopped at %s (%d of %d), exit %d", ord[i], i, length(ord), st))
    cat(sprintf("STEP %d/%d done: %s\n", i, length(ord), ord[i]))
  }
  cat("ALL DONE\n")
}
