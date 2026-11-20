# place_name_proposal_accounting.R — the proposals' bookkeeping (plan 081, decision 337): every name of the step's class in
# one proposal, every one of ÍSOR's troughs in one outcome (taken by a name, or a proposal of its own; a shared trough's
# parts never overlapping, decision 338), every proposal's
# witnesses counted from its evidence, its thing inside its extent, every verdict on a proposal that exists. Step 2: every
# water name of ours of the grammar's ridge, edge, toe and tip endings in one proposal, each on one of ÍSOR's moraines or
# none, none off the shelf on one. Step 3: every bank of the east on its piece (a piece one bank's, or shared and flagged),
# every part's whole a bank, every witness counted.
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
   !anyDuplicated(p$name_id[p$class == "deep" & !is.na(p$name_id)]), length(deeps))
troughs <- sub("isor:landform:trough:", "", sfx$seabed_id[sfx$kind == "trough"])
d1 <- p[p$class == "deep", ]
ok(sprintf("every one of ÍSOR's %d troughs in one outcome: taken by a deep, or a proposal of its own (a shared trough's part no name takes, one each)", length(troughs)),
   setequal(unique(d1$trough[d1$trough != "none"]), troughs) && all(!duplicated(paste(d1$trough, d1$part)[is.na(d1$name_id)])), length(troughs))
ok("keys unique; every evidence row and shape on a proposal", !anyDuplicated(p$key) && all(ev$key %in% p$key) && all(sh$key %in% p$key), nrow(p))
on <- d1[d1$trough != "none", ]
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
# step 2: the moraines and the ridge, edge, toe and tip names
G2 <- c("hryggur", "hryggurinn", "hrygg", "hryggnum", "hryggjar", "hryggir", "hryggirnir", "hryggjum", "kambur", "kamburinn", "kamb", "kambi", "kambinum",
  "kantur", "kanturinn", "kant", "kanti", "kantinum", "kantinn", "kantar", "kantarnir", "köntum", "brún", "brúnin", "brúnina", "brúninni", "brúnir",
  "tá", "táin", "tána", "tánni", "tær", "tota", "totan", "totu", "totunni", "horn", "hornið", "horni", "horninu", "hornin", "hæll", "hællinn", "hæl", "hælnum",
  "hali", "halinn", "hala", "halanum", "halli", "hallinn", "halla", "hallanum", "rani", "raninn", "rana", "haft", "haftið", "hafti", "fótur", "fóturinn", "fót", "fæti", "fætinum")
gram <- vapply(strsplit(gsub("[^a-zþæöðáéíóúý ]", " ", tolower(nm$name)), " +"), function(w) any(grepl(paste0("(", paste(G2, collapse = "|"), ")$"), w[nzchar(w)])), TRUE)
st2 <- nm$id[nm$kind == "water" & !is.na(nm$lon) & gram & !nm$id %in% deeps]
p2 <- p[p$class == "moraine", ]
ok("every water name of ours of step 2's endings (not a deep) in one proposal; the skippers' own keyed by their spelling", setequal(p2$name_id[!is.na(p2$name_id)], st2) &&
   all(grepl("^moraine:skippers:", p2$key[is.na(p2$name_id)])), length(st2))
moraines <- sub("isor:landform:moraine:", "", sfx$seabed_id[sfx$kind == "moraine"])
on2 <- p2[p2$moraine != "none", ]
ok("every step 2 proposal on one of ÍSOR's moraines or none; on one, its element the moraine and its extent drawn",
   all(p2$moraine %in% c(moraines, "none")) && all(on2$element == paste0("isor:landform:moraine:", on2$moraine)) && all(on2$key %in% sh$key[sh$what == "extent"]), nrow(p2))
cnt2 <- ev |> filter(grepl("^agrees", outcome), !is.na(moraine)) |> distinct(key, moraine, group) |> count(key, moraine, name = "n")
chk2 <- on2 |> left_join(cnt2, by = c("key", "moraine")) |> mutate(n = coalesce(n, 0L))
ok("a step 2 proposal's witnesses agreeing counted from its evidence on its moraine (a copy with its source)", chk2$n == chk2$n_agree, nrow(chk2))
shelf <- st_make_valid(read_curated_sf(REF("seabed_feature.parquet"))[sfx$kind == "shelf break", ])
o2 <- on2[!is.na(on2$name_id), ]; q2 <- nm[match(o2$name_id, nm$id), ]
off <- lengths(st_intersects(st_as_sf(q2, coords = c("lon", "lat"), crs = 4326), shelf)) == 0
ok("no name of ours off the shelf (beyond ÍSOR's shelf break) on a moraine", !off, nrow(o2))
# step 3: the banks (the east first)
p3 <- p[p$class == "bank", ]; b3 <- p3[p3$kind == "bank", ]; s3 <- p3[p3$kind != "bank", ]
ok("a name in one proposal of each class (a step 2 name off the moraines may be a step 3 part)", !anyDuplicated(paste(p$class, p$name_id)[!is.na(p$name_id)]), sum(!is.na(p$name_id)))
ok("every step 3 bank has its piece as its extent and element; a piece taken by one bank, or by several each flagged as sharing it",
   all(b3$key %in% sh$key[sh$what == "extent"]) && all(b3$element == paste0("bank:east:piece:", b3$piece)) &&
   all(vapply(split(b3, b3$piece), function(x) nrow(x) == 1 || all(!is.na(x$shared_with)), TRUE)), nrow(b3))
ok("every step 3 part or shoal's whole a step 3 bank taking a piece, or none (flagged)", all(s3$whole_id[!is.na(s3$whole_id)] %in% b3$name_id) &&
   all(grepl("no whole found", s3$flags[is.na(s3$whole_id)])), nrow(s3))
cnt3 <- ev |> filter(grepl("^agrees", outcome), !is.na(candidate)) |> distinct(key, candidate, group) |> count(key, candidate, name = "n")
chk3 <- p3 |> left_join(cnt3, by = c("key", "candidate")) |> mutate(n = coalesce(n, 0L))
ok("a step 3 proposal's witnesses agreeing counted from its evidence on its candidate (a piece, or its whole)", chk3$n == chk3$n_agree, nrow(chk3))
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
