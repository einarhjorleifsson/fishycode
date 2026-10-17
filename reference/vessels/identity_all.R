# The single vessel-identity table an analyst opens — Icelandic and foreign
# together, one row per (source, external_id, period).
# Side: preprocessing (vessels). See plan 014.
#
# Input:  curated/vessel/vessel_identity.parquet (Icelandic, vid-keyed),
#         curated/vessel/vessel_identity_foreign.parquet (foreign, external_id-keyed)
# Output: curated/vessel/vessel_identity_all.parquet
#
# vessel_identity.parquet and vessel_identity_foreign.parquet stay exactly as
# they are - vid is a real primary key other scripts (ais_key.R, mmsi.R) rely
# on, and faking a vid for a vessel that never had one would break that. But
# AGENTS.md's whole premise is a sweep an analyst opens with no pipeline
# knowledge required, and two vessel tables an analyst has to know exist and
# combine themselves is exactly the knowledge that is supposed to be hidden.
# This table is the union, built fresh each run from the two specialized
# ones - it is a product, not a third source of truth. `vid` survives as a
# column (populated for the Icelandic rows, source "ISL" and the "SKB" pleasure
# craft, NA otherwise); `external_id` is
# populated for every row, IMO-first, so a lookup by IMO works regardless of
# which side of the union a vessel came from.

library(dplyr)
library(nanoparquet)

is_valid_imo <- function(x) {
  ok <- !is.na(x) & grepl("^[0-9]{7}$", x)
  digs <- matrix(NA_integer_, length(x), 7)
  digs[ok, ] <- do.call(rbind, lapply(x[ok], function(s) as.integer(strsplit(s, "")[[1]])))
  checksum <- digs[, 1] * 7 + digs[, 2] * 6 + digs[, 3] * 5 +
              digs[, 4] * 4 + digs[, 5] * 3 + digs[, 6] * 2
  ok & (checksum %% 10) == digs[, 7]
}

# A period with no vid is an MMSI broadcast with no known hull (curate/corrections/mmsi_broadcast_unregistered.yml,
# 25 rows on 2026-10-17): it identifies no vessel, and paste0("isl_", NA) would have made them all one, "isl_NA".
isl <- read_parquet(fd_curated("vessel", "vessel_identity.parquet")) |>
  filter(!is.na(vid)) |>
  mutate(external_id = if_else(is_valid_imo(imo), imo, paste0("isl_", vid))) |>
  rename(name = vessel)

foreign <- read_parquet(fd_curated("vessel", "vessel_identity_foreign.parquet")) |>
  mutate(vid = NA_integer_)

identity_all <- bind_rows(isl, foreign) |>
  select(source, external_id, vid, everything())

cat("rows:", nrow(identity_all), "\n")
print(identity_all |> count(source, name = "rows"))
cat("distinct external_id:", n_distinct(identity_all$external_id), "\n")
cat("distinct vid (Icelandic):", n_distinct(identity_all$vid[!is.na(identity_all$vid)]), "\n")

write_curated(
  identity_all,
  fd_curated("vessel", "vessel_identity_all.parquet"),
  inputs = c(
    vessel_identity         = fd_curated("vessel", "vessel_identity.parquet"),
    vessel_identity_foreign = fd_curated("vessel", "vessel_identity_foreign.parquet")
  )
)
