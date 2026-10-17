# allocate_vids.R — the vid ledger: which vid each hull has, given once and never moved (plan 021 §6 b, f).
#
# Input:  curated/vessel/vid_ledger/ (the ledger, one stamped parquet per allocation),
#         curated/vessel/vessel_ais_link.parquet (the crosswalk, curate/vessel_ais_link.R)
# Output: read_vid_ledger() the ledger as one table; allocate_vids() a new batch file in the ledger
#
# A hull is a key the crosswalk derives from the evidence: `imo_<n>`, `eu_<cfr>`, `fro_<id>` or `mmsi_<n>`. A hull
# that is a registry vid (`vid_<n>`: Icelandic, SKB 100000 + n, or a foreign vid 3699-4999) is not in the ledger: its
# number is the registry's. Every other hull gets 200000 + n here.
#
# Which hull an MMSI period is follows from the inputs and is rebuilt with each delivery. Which vid a hull has depends on
# earlier builds, and a target cannot read its own output, so the numbering lives outside the graph: the crosswalk reads
# the ledger as an input, like overrides/, and allocate_vids() - run by hand, as a dump is - extends it. Until then a new
# hull's links carry vid NA with the reason `unallocated`, and nothing stops.
#
# Append-only, at the file level: each allocation writes a new file and no file is ever rewritten, so no rebuild and no
# allocation can move a vid. The ledger is under $FISHYDATA, not in overrides/: it lists every MMSI the feeds carry,
# about 370,000 from ASTD alone, and this repository is public.
#
# Evidence improves, and a hull's key changes with it: a broadcast hull `mmsi_<n>` becomes `imo_<n>` once a register or
# GFW's Vessels API gives its IMO, and one MMSI's history may split into two hulls. What the vid does then is plan 021
# §6 i, answered by the maintainer on 2026-10-17: it keeps its vid, so it changes only where it really was two vessels.
#   - inherit = TRUE (the default, the answer): a new hull whose other keys (`alt_keys` in the crosswalk) hold exactly
#     one vid that no current link holds takes that vid, as a row with basis `inherited` and the old key in `from_hull`.
#     A vid is inherited once; in a split the hull seen first keeps it and the later one gets the next number;
#   - inherit = FALSE: every new hull gets a new number, and the old vid is retired with its links. Kept for checks.
# A vid whose hull no longer has a link is retired, never reused.

# The ledger as one table. Stops if the files contradict each other: a hull on two vids, or a vid allocated twice.
read_vid_ledger <- function(dir = fd_path("curated", "vessel", "vid_ledger")) {
  files <- sort(list.files(dir, "^batch_.*[.]parquet$", full.names = TRUE), method = "radix")
  empty <- data.frame(vid = integer(), hull = character(), basis = character(), from_hull = character(),
                      allocated = as.Date(character()), batch = character())
  if (!length(files)) return(empty)
  led <- do.call(rbind, lapply(files, function(f) {
    d <- as.data.frame(nanoparquet::read_parquet(f))[names(empty)]
    d$allocated <- as.Date(d$allocated)
    d
  }))
  if (anyDuplicated(led$hull)) stop("vid ledger: a hull on two rows: ", paste(head(led$hull[duplicated(led$hull)]), collapse = ", "))
  new <- led[led$basis == "new", ]
  if (anyDuplicated(new$vid)) stop("vid ledger: a vid allocated twice: ", paste(head(new$vid[duplicated(new$vid)]), collapse = ", "))
  orphan <- setdiff(led$vid[led$basis == "inherited"], new$vid)
  if (length(orphan)) stop("vid ledger: inherited vids never allocated: ", paste(head(orphan), collapse = ", "))
  led
}

# Give every unallocated hull in the crosswalk a vid, and write them as one new batch. dry_run = TRUE (the default)
# writes nothing and returns the rows it would add. Writing is the maintainer's step: run it after the crosswalk is
# rebuilt, then rebuild the crosswalk (tar_outdated() shows it, since the ledger is a declared input).
allocate_vids <- function(link = fd_curated("vessel", "vessel_ais_link.parquet"),
                          dir = fd_path("curated", "vessel", "vid_ledger"),
                          first = 200001L, dry_run = TRUE, inherit = TRUE) {
  led <- read_vid_ledger(dir)
  lk  <- as.data.frame(nanoparquet::read_parquet(link))
  if (!all(c("hull", "vid_reason", "alt_keys", "t1") %in% names(lk))) stop("not a crosswalk: ", link)
  lk$t1s <- dplyr::coalesce(as.numeric(lk$t1), -Inf)

  # The hulls to number, in the order they were first seen, so a given crosswalk always numbers the same way
  todo <- lk[lk$vid_reason %in% "unallocated" & !is.na(lk$hull) & !startsWith(lk$hull, "vid_") & !lk$hull %in% led$hull, ]
  if (!nrow(todo)) { message("allocate_vids: nothing unallocated"); return(invisible(led[0, ])) }
  first_seen <- tapply(todo$t1s, todo$hull, min)
  hulls <- names(first_seen)[order(first_seen, names(first_seen), method = "radix")]

  # Inheritance: the vids that a new hull's other keys hold, where no current hull holds that key any longer
  current <- unique(lk$hull[!is.na(lk$hull)])
  ak <- todo[!is.na(todo$alt_keys), c("hull", "alt_keys")]
  ak <- data.frame(hull = rep(ak$hull, lengths(strsplit(ak$alt_keys, ";"))), key = unlist(strsplit(ak$alt_keys, ";")))
  ak <- unique(merge(ak[!ak$key %in% current, ], led[, c("hull", "vid")], by.x = "key", by.y = "hull"))
  one <- tapply(ak$vid, ak$hull, function(v) if (length(unique(v)) == 1) v[1] else NA_integer_)
  taken <- integer()
  inh     <- setNames(rep(NA_integer_, length(hulls)), hulls)
  from    <- setNames(rep(NA_character_, length(hulls)), hulls)
  cand <- intersect(hulls, names(one)[!is.na(one)])
  if (length(cand) && is.na(inherit))
    stop("allocate_vids: ", length(cand), " new hulls could keep an old key's vid (e.g. ", cand[1], "); say inherit = ",
         "TRUE (plan 021 §6 i) or FALSE", call. = FALSE)
  if (isFALSE(inherit)) cand <- character()
  for (h in cand) {
    v <- one[[h]]
    if (!is.na(v) && !v %in% taken && !v %in% lk$vid) {
      inh[h] <- v; taken <- c(taken, v)
      from[h] <- paste(sort(ak$key[ak$hull == h & ak$vid == v]), collapse = ";")
    }
  }

  nxt <- max(c(first - 1L, led$vid[led$basis == "new"]))
  vid <- inh
  k <- which(is.na(vid))
  vid[k] <- nxt + seq_along(k)
  stamp <- format(Sys.time(), "%Y%m%dT%H%M%S", tz = "UTC")
  add <- data.frame(vid = as.integer(vid), hull = hulls, basis = ifelse(is.na(inh), "new", "inherited"),
                    from_hull = unname(from), allocated = Sys.Date(), batch = stamp)
  nv <- add$vid[add$basis == "new"]
  message(sprintf("allocate_vids: %s hulls, %s new vids (%s), %s inherited%s",
                  format(nrow(add), big.mark = ","), format(length(nv), big.mark = ","),
                  if (length(nv)) paste(range(nv), collapse = "-") else "none", sum(add$basis == "inherited"),
                  if (dry_run) " - dry run, nothing written" else ""))
  if (dry_run) return(invisible(add))

  f <- file.path(dir, paste0("batch_", stamp, ".parquet"))
  if (file.exists(f)) stop("ledger batch exists already: ", f)
  write_curated(add, f, inputs = c(vessel_ais_link = link), script = "R/allocate_vids.R")
  # read it back as one ledger, which checks the new file against the old ones
  read_vid_ledger(dir)
  invisible(add)
}
