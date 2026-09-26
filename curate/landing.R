# Merge agf and lods into unified landing tables.
# Input:  staging/landing/{agf,lods}/{landings,catch}.parquet
# Output: curated/landing/{landings,catch}.parquet
#
# Decision rule (curate/plans/007 §2): agf wins wherever a (vid, date, hid)
# trip exists in agf, on both presence and value - lods contributes only the
# trips agf has nothing at all for. This is deliberately not a date cutoff:
# agf and lods run in parallel to the present, and a hard cutoff would
# misrepresent or silently drop both sides' exceptions to it (curate/plans/007
# §1-2). Real figures: see curate/plans/007's own measured section, re-run
# after the lods key fix below rather than duplicated here to avoid drift.
#
# .tid_land -> .lid (curate/plans/007 §3): agf's own staging catch table
# still carries the per-delivery raw id (.lid) it was built from (sources/
# aflagrunnur/convert.R); this collapses it away, grouping by (.tid_land,
# schema, sid, gid, stid, kfteg) and summing catch - species, gear and stock
# all vary within a real multi-delivery trip and are kept; only the raw
# per-delivery record id is dropped (curate/plans/007 §5). lods no longer has
# a per-delivery id to collapse (sources/lods/convert.R mints .tid_land
# directly from (vid, date, hid) - komunr turned out to be a recycled
# loading-batch code, not a stable per-delivery id), so this step is a no-op
# for it, just naming. The surviving trip-level key is renamed .tid_land ->
# .lid.
#
# The composite key is (.lid, schema), not .lid alone (curate/plans/007 §4):
# agf's and lods' own id domains can still coincide by chance even now that
# lods' own id is a hash, not a recycled raw field - the merge below keys
# uniqueness on (vid, date, hid) for the precedence decision, which is safe,
# but a consumer joining landing_catch on .lid alone (not .lid + schema) can
# still collide across schemas.
#
# The hid -> pid port join happens once here, not duplicated in each source
# adapter.

library(tidyverse)
library(duckdbfs)

agf_landings  <- duckdbfs::open_dataset(fd_staging("landing", "agf",  "landings.parquet")) |> collect()
agf_catch     <- duckdbfs::open_dataset(fd_staging("landing", "agf",  "catch.parquet")) |> collect()
lods_landings <- duckdbfs::open_dataset(fd_staging("landing", "lods", "landings.parquet")) |> collect()
lods_catch    <- duckdbfs::open_dataset(fd_staging("landing", "lods", "catch.parquet")) |> collect()

ports <- duckdbfs::open_dataset(fd_curated("reference", "port.parquet")) |> collect()

# .tid_land -> .lid, collapsing the per-delivery .lid out (agf only; a no-op
# regrouping for lods, which arrives already at this grain) -------------------
collapse_catch <- function(catch) {
  if (!"kfteg" %in% names(catch)) catch <- catch |> mutate(kfteg = NA_integer_)
  if (!"komunr" %in% names(catch)) catch <- catch |> mutate(komunr = NA_integer_)
  catch |>
    group_by(.tid_land, schema, sid, gid, stid, kfteg) |>
    summarise(catch = sum(catch, na.rm = TRUE), komunr = first(komunr), .groups = "drop") |>
    rename(.lid = .tid_land)
}

agf_catch  <- collapse_catch(agf_catch)
lods_catch <- collapse_catch(lods_catch)

agf_landings  <- agf_landings  |> rename(.lid = .tid_land)
lods_landings <- lods_landings |> rename(.lid = .tid_land)

# Precedence: agf wherever present ---------------------------------------------
agf_vid_date_hid <- agf_landings |> distinct(vid, date, hid)

lods_only_landings <- lods_landings |> anti_join(agf_vid_date_hid, by = c("vid", "date", "hid"))
lods_only_lids      <- lods_only_landings |> distinct(.lid)
lods_only_catch     <- lods_catch |> semi_join(lods_only_lids, by = ".lid")

merged_landings <- bind_rows(agf_landings, lods_only_landings)
merged_catch    <- bind_rows(agf_catch, lods_only_catch)

# Summary ------------------------------------------------------------------
cat(sprintf("agf trips:        %d\n", nrow(agf_landings)))
cat(sprintf("lods-only trips:  %d\n", nrow(lods_only_landings)))
cat(sprintf("merged trips:     %d\n", nrow(merged_landings)))
cat(sprintf("merged catch:     %d\n", nrow(merged_catch)))

# Port join ------------------------------------------------------------------
# hid is Fiskistofa's hafnarnumer; pid is the standard port key, so landings
# join to the same port identity as the logbooks and the AIS trail.
merged_landings <- merged_landings |>
  left_join(ports |> select(hid, höfn = port, pid), by = "hid")

# Export -----------------------------------------------------------------------
dir.create(fd_curated("landing"), showWarnings = FALSE, recursive = TRUE)
merged_landings |> duckdbfs::write_dataset(fd_curated("landing", "landings.parquet"))
merged_catch    |> duckdbfs::write_dataset(fd_curated("landing", "catch.parquet"))
