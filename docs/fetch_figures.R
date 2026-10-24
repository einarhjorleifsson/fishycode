# The book's images from $FISHYDATA, copied in before every render (quarto's pre-render): images live under
# $FISHYDATA, never in this repo (maintainer, 2026-10-24). A missing image or store is reported, and the render
# goes on without it.
#
# Input:  $FISHYDATA/<path> for each entry of `figs`
# Output: docs/figures/fd/<name> (gitignored)

figs <- c(gagnakvorn.png = "exports/gagnakvorn/gagnakvorn.png")

dir.create("figures/fd", showWarnings = FALSE)
root <- tryCatch({ source("../R/paths.R"); fishydata_root() }, error = function(e) NA_character_)
for (n in names(figs)) {
  from <- if (is.na(root)) NA_character_ else file.path(root, figs[[n]])
  if (!is.na(from) && file.exists(from)) {
    file.copy(from, file.path("figures/fd", n), overwrite = TRUE)
  } else {
    message("fetch_figures.R: not found, so not in the book: $FISHYDATA/", figs[[n]])
  }
}
