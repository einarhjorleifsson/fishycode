# place_name_proposal_accounting.R — the proposals' bookkeeping (plan 081, decision 337): every name of the step's class in
# one proposal, every one of ÍSOR's troughs in one outcome (taken by a name, or a proposal of its own; a shared trough's
# parts never overlapping, decision 338), every proposal's
# witnesses counted from its evidence, its thing inside its extent, every verdict on a proposal that exists.
# Side: preprocessing (sea-chart names). Standalone, run by hand after reference/names/place_name_proposal.R.
#
# Input:  curated/reference/place_name_proposal{,_evidence,_shape}.parquet, marine_name.parquet, seabed_feature.parquet,
#         overrides/marine_name_edits.csv
# Output: curated/check/place_name_proposal_accounting.parquet - one row per check: the check, its verdict, n
#
# Bookkeeping (decision 155): the script stops, after writing, unless every check holds.
# Run from the repo root: Rscript curate/checks/place_name_proposal_accounting.R. Written by Claude (AI), 2026-11-20.

suppressPackageStartupMessages({ library(dplyr); library(sf) })
sf_use_s2(FALSE)
for (f in c("R/paths.R", "R/write_curated.R")) source(f)                     # standalone: not targets'
REF <- function(f) fd_curated("reference", f)
pr <- read_curated_sf(REF("place_name_proposal.parquet")); p <- st_drop_geometry(pr)
ev <- as.data.frame(nanoparquet::read_parquet(REF("place_name_proposal_evidence.parquet")))
sh <- read_curated_sf(REF("place_name_proposal_shape.parquet"))
nm <- as.data.frame(nanoparquet::read_parquet(REF("marine_name.parquet")))
sfx <- st_drop_geometry(read_curated_sf(REF("seabed_feature.parquet")))
ed <- read.csv("overrides/marine_name_edits.csv", encoding = "UTF-8"); if (!"link_to" %in% names(ed)) ed$link_to <- NA_character_
low <- function(x) gsub("[^a-zþæöðáéíóúý]", "", tolower(x))

acc <- data.frame(check = character(), verdict = character(), n = integer())
ok <- function(what, cond, n = NA_integer_) { cond <- isTRUE(all(cond))
  acc[nrow(acc) + 1, ] <<- list(what, if (cond) "ok" else "FAILED", as.integer(n)) }

over_trough <- nm$src == "maintainer" & grepl("^isor:landform:trough:[0-9]+$", ifelse(is.na(nm$seabed_members), "", nm$seabed_members))
rs <- ed[ed$action %in% c("rest", "unrest"), ]; rs <- rs[order(rs$at), ]
rs <- rs[!duplicated(rs$feature, fromLast = TRUE) & rs$action == "rest", ]          # a name he gives the rest of a trough
deeps <- nm$id[(grepl("(djúp|djúpið|dýpi|dýpið|áll|állinn|renna|rennan)$", low(nm$name)) | over_trough | nm$id %in% rs$feature) & !is.na(nm$lon)]
ok("every deep of ours (a name ending -djúp, -dýpi, -áll, -renna, his own over a trough, or one he gives a trough's rest) in one proposal", setequal(p$name_id[p$class == "deep" & !is.na(p$name_id)], deeps) &&
   !anyDuplicated(p$name_id[!is.na(p$name_id)]), length(deeps))
troughs <- sub("isor:landform:trough:", "", sfx$seabed_id[sfx$kind == "trough"])
ok(sprintf("every one of ÍSOR's %d troughs in one outcome: taken by a deep, or a proposal of its own (a shared trough's part no name takes, one each)", length(troughs)),
   setequal(unique(p$trough[p$trough != "none"]), troughs) && all(!duplicated(paste(p$trough, p$part)[is.na(p$name_id)])), length(troughs))
ok("keys unique; every evidence row and shape on a proposal", !anyDuplicated(p$key) && all(ev$key %in% p$key) && all(sh$key %in% p$key), nrow(p))
on <- p[p$trough != "none", ]
ok("every proposal on a trough has its extent, and its element the trough", all(on$key %in% sh$key[sh$what == "extent"]) &&
   all(on$element == paste0("isor:landform:trough:", on$trough)), nrow(on))
ex <- sh[sh$what == "extent", ]; pp <- pr[match(ex$key, pr$key), ]
inside <- vapply(seq_len(nrow(ex)), function(i) st_intersects(st_geometry(pp)[i], st_buffer(st_make_valid(st_geometry(ex)[i]), 1e-3), sparse = FALSE)[1, 1], logical(1))
ok("a proposal's thing inside its extent (within 0.001 degrees)", inside, nrow(ex))
cnt <- ev |> filter(grepl("^agrees", outcome)) |> distinct(key, trough, part, group) |> count(key, trough, part, name = "n")
chk <- on |> left_join(cnt, by = c("key", "trough", "part")) |> mutate(n = coalesce(n, 0L))
ok("a proposal's witnesses agreeing counted from its evidence, on its part where its trough is shared (a copy with its source)", chk$n == chk$n_agree, nrow(chk))
# a shared trough's parts: the names' and the unnamed ones' extents never overlap (more than the width of a cell's edge)
spl <- unique(p$trough[!is.na(p$part)]); ov <- 0
for (tt in spl) { e <- st_transform(ex[ex$key %in% p$key[p$trough == tt & !is.na(p$part)], ], 3057); e$nm <- coalesce(p$name[match(e$key, p$key)], e$key)
  e <- e[!duplicated(e$nm), ]                                                           # a name's rows of two sources share one part
  if (nrow(e) > 1) for (i in 1:(nrow(e) - 1)) for (j in (i + 1):nrow(e)) ov <- ov + sum(as.numeric(st_area(st_intersection(st_buffer(st_geometry(e)[i], -100), st_buffer(st_geometry(e)[j], -100))))) }
ok(sprintf("a shared trough's parts never overlap, a name's rows of two sources sharing one (%d shared troughs)", length(spl)), ov == 0, length(spl))
ok("every proposal placed, with a basis", !is.na(p$lon) & !is.na(p$lat) & !is.na(p$place_basis), nrow(p))
vd <- ed[ed$action %in% c("accept proposal", "reject proposal"), ]
ok("every verdict on a proposal that exists", all(vd$link_to %in% p$key), nrow(vd))
ok("every text valid UTF-8", all(validUTF8(na.omit(c(p$name, p$flags, p$place_basis, ev$member, ev$detail, ev$value, sh$basis)))), nrow(p))

write_curated(acc, fd_curated("check", "place_name_proposal_accounting.parquet"), script = "curate/checks/place_name_proposal_accounting.R",
              inputs = c(REF("place_name_proposal.parquet"), REF("place_name_proposal_evidence.parquet"), REF("place_name_proposal_shape.parquet"),
                         REF("marine_name.parquet"), REF("seabed_feature.parquet"), "overrides/marine_name_edits.csv"))
print(knitr::kable(acc))
fails <- acc$check[acc$verdict != "ok"]
message(sprintf("place_name_proposal_accounting: %d checks, %d failed", nrow(acc), length(fails)))
if (length(fails)) stop("place_name_proposal_accounting: ", paste(fails, collapse = "; "))
