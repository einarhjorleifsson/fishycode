# source_script() — source a pipeline script, then leave the R session as the script found it.
#
# Input:  the path of a script (curate/, reference/, sources/, ...), as produces() in _targets.R passes it
# Output: none; the files the script writes are the point
#
# tar_make() runs every target in one R session, and produces() used to source() each script straight into
# the global environment, so a script's objects outlived its target. On 2026-10-07 area_h3 hit R's 24 GB
# limit right after shapes had left its 2.1 M-polygon EUSM object behind (TODO item 37). Settings leaked the
# same way: shapes.R's sf_use_s2(FALSE) held for every later target, and a package a script attaches stays
# attached and masks later scripts' functions (terra masks tidyr::extract, igraph masks dplyr::union).
#
# On exit - also when the script fails - this removes what the script added to the global environment, puts
# back what it overwrote or removed, restores options() (sf_use_s2 is one) and detaches the packages it
# attached (their namespaces stay loaded). A script that relied on another's leftovers now fails loudly
# instead of depending on build order.
source_script <- function(script) {
  g      <- globalenv()
  before <- mget(ls(g, all.names = TRUE), envir = g)   # references, not copies
  opts   <- options()
  pkgs   <- search()
  on.exit({
    rm(list = setdiff(ls(g, all.names = TRUE), names(before)), envir = g)
    for (n in names(before))
      if (!exists(n, envir = g, inherits = FALSE) || !identical(get(n, envir = g), before[[n]]))
        assign(n, before[[n]], envir = g)
    added <- setdiff(names(options()), names(opts))
    options(c(opts, setNames(vector("list", length(added)), added)))
    # newest first, so a package is detached before the ones it was attached on top of
    for (p in setdiff(search(), pkgs)) try(detach(p, character.only = TRUE), silent = TRUE)
    gc(FALSE)
  }, add = TRUE)
  source(script, encoding = "UTF-8")
  invisible(NULL)
}
