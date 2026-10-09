# What a hull was called, and when.
# Side: preprocessing (vessels). See plan 014.
#
# Input:  curated/vessel/vessel.parquet
# Output: curated/vessel/vessel_identity.parquet - one row per (vid, period)
#
# The vid is assigned to the keel: a vessel may change name, call sign, local sign
# and MMSI, but the vid stays with the hull from cradle to grave, like an IMO
# number (maintainer, 2026-09-22). So vid is the stable identity and everything
# else is an attribute of it *at a time*, which is the distinction this table
# exists to make and which vessel_ais_key.parquet does not make.
#
# Two defects follow from not making it, both measured 2026-09-22:
#
#   1. ais_key.R:650 attaches MMSI by joining v_mmsi_no_dupes - one arbitrary row
#      per MMSI, picked by arrange(mmsi, desc(mmsi_t2), desc(vid)) |> slice(1). The
#      registry reissues 21 MMSIs from one hull to the next, so for each of those
#      the EARLIER holder is erased and the later one inherits its whole history.
#   2. curate/ais_ping_union.R:45 and :60 resolve the ASTD and ASTDB feeds with
#      `vid |> select(mmsi, vid) |> distinct()` - no time at all. Every commercial
#      ping on a reissued MMSI therefore lands on the later hull. OLAFUR's 2007-08
#      pings become HOFFELL's, and OLAFUR shows up in curated/check/
#      ais_key_landings.parquet as a vessel that lands fish and has no AIS track.
#
# This table is the fix for both: join through it on (mmsi, time), not on mmsi.

library(dplyr)
library(nanoparquet)

AIS_T1   <- as.Date("2007-06-01")   # STK begins; nothing earlier is resolvable
SENTINEL <- as.Date("2028-12-24")   # the registry's own open-ended marker

reg <- read_parquet(fd_curated("vessel", "vessel.parquet"))

# yh2 is CENSORED, not an event. It never exceeds 2021 anywhere in the registry:
# 2,264 of the 4,714 hulls that carry a yh2 carry 2021, and 1,244 of those landed
# fish after 2022, the most recent on 2026-04-14. So yh2 == the horizon means "still
# there when the snapshot was taken", not "struck that year", and treating it as a
# closing date shuts the window on most of the active fleet. Measured 2026-09-22
# after a first version did exactly that and discarded 99.9 M astd pings across 755
# hulls. curate/corrections/vessel_registry_stale_lifetime.yml.
YH_HORIZON <- max(reg$yh2, na.rm = TRUE)
cat("registry yh2 horizon:", YH_HORIZON, "- hulls reaching it are treated as open
")

# The registry times exactly one attribute - the MMSI, via mmsi_t1/mmsi_t2 and
# zombie_no. Call sign, local sign and name carry no dates at all, so their window
# is the hull's own lifetime, and `window_basis` says which of the two a row got.
# That distinction matters: an mmsi_window is evidence, a hull_lifetime is an
# inference, and a row with neither is a guess that spans the whole era.
identity <-
  reg |>
  transmute(
    vid, vessel, cs, uid, imo, mmsi, flag, source, mclass,
    zombie_no = coalesce(zombie_no, 1L),
    .hull_t1 = if_else(is.na(yh1), as.Date(NA), as.Date(paste0(yh1, "-01-01"))),
    .hull_t2 = case_when(is.na(yh2)          ~ as.Date(NA),
                         yh2 >= YH_HORIZON   ~ SENTINEL,
                         .default = as.Date(paste0(yh2, "-12-31"))),
    window_basis = case_when(
      (!is.na(mmsi_t1) | !is.na(mmsi_t2)) & (!is.na(yh1) | !is.na(yh2)) ~ "both",
      !is.na(mmsi_t1) | !is.na(mmsi_t2) ~ "mmsi_window",
      !is.na(yh1) | !is.na(yh2)         ~ "hull_lifetime",
      .default = "unbounded"),
    # INTERSECTION, not preference. mmsi.R writes 2007-06-01 and 2028-12-24 as
    # DEFAULTS for every vessel that has never had its MMSI reissued, so an
    # mmsi_t1/mmsi_t2 pair is usually a placeholder rather than evidence. Taking
    # it in preference to the hull lifetime reopens windows that ought to be shut:
    # vid 1473 HOLMBERG was struck in 2006 and its default MMSI window ran to 2028,
    # which is how call sign TFBR went on matching for fifteen years after the hull
    # was gone (curate/corrections/ais_key_callsign_reuse.yml). Both bounds must
    # hold, so both are applied.
    t1 = pmax(coalesce(mmsi_t1, AIS_T1), coalesce(.hull_t1, AIS_T1), AIS_T1),
    t2 = pmin(coalesce(mmsi_t2, SENTINEL), coalesce(.hull_t2, SENTINEL)),
    # The MMSI window UNINTERSECTED, because the two answer different questions and
    # only one of them is "who was transmitting under this number". The registry can
    # say an MMSI transferred in 2011 while the receiving hull's yh1 is 2020 - vid
    # 7839 BYLGJA on 251146240 is exactly that - and intersecting leaves 2011-2019
    # belonging to nobody. curate/ais_ping_union.R resolves the MMSI-keyed feeds on
    # these two; t1/t2 above are for asking whether a hull was registered at all.
    mmsi_t1 = coalesce(mmsi_t1, AIS_T1),
    mmsi_t2 = coalesce(mmsi_t2, SENTINEL)) |>
  select(-c(.hull_t1, .hull_t2)) |>
  # A hull struck before STK began has no resolvable window; keeping it would put
  # a t1 after its t2 and break every between-join downstream. Dropping it is also
  # the point: an AIS assignment to a vid with no identity period is then visible
  # as such rather than being quietly plausible.
  #
  # A vessel that leaves the registry and keeps transmitting - "afmadur", decision
  # 013 - is correctly outside its own window here. The identity table answers
  # "who held this call sign, in the Icelandic registry, at time t", and after
  # deregistration the honest answer is nobody. The key's own afmadur step carries
  # the keel forward; this table does not have to.
  filter(t2 >= t1) |>
  arrange(vid, t1)

## Assertions --------------------------------------------------------------------
# The whole point of the table is that (mmsi, time) resolves to ONE vid. If two
# rows with the same MMSI overlap in time, it does not, and a between-join will
# silently duplicate every ping on that MMSI.
overlaps <-
  identity |>
  filter(!is.na(mmsi)) |>
  arrange(mmsi, mmsi_t1) |>
  group_by(mmsi) |>
  mutate(.next_t1 = lead(mmsi_t1), .next_vid = lead(vid)) |>
  ungroup() |>
  filter(!is.na(.next_t1), mmsi_t2 >= .next_t1)
print(overlaps |>
        select(mmsi, vid, mmsi_t1, mmsi_t2, .next_vid, .next_t1) |>
        knitr::kable(caption = "MMSI resolving to two hulls at once (expect none)"))

# The mirror image, and the one that silently loses pings rather than duplicating
# them: successive holders of an MMSI with a hole between them.
gaps <-
  identity |>
  filter(!is.na(mmsi)) |>
  arrange(mmsi, mmsi_t1) |>
  group_by(mmsi) |>
  mutate(.next_t1 = lead(mmsi_t1), .next_vid = lead(vid)) |>
  ungroup() |>
  filter(!is.na(.next_t1), as.numeric(.next_t1 - mmsi_t2) > 1)
print(gaps |>
        select(mmsi, vid, mmsi_t2, .next_vid, .next_t1) |>
        knitr::kable(caption = "MMSI unclaimed between two holders (expect none)"))
if (nrow(overlaps))
  warning("vessel_identity: ", nrow(overlaps),
          " MMSI periods overlap; a (mmsi, time) join will duplicate pings")

print(identity |> count(window_basis, name = "rows") |>
        knitr::kable(caption = "vessel_identity"))
print(identity |> filter(!is.na(mmsi)) |> count(mmsi) |> filter(n > 1) |> nrow() |>
        (\(n) knitr::kable(data.frame(reissued_mmsi = n)))())

write_curated(identity, fd_curated("vessel", "vessel_identity.parquet"),
              inputs = c(vessel = fd_curated("vessel", "vessel.parquet")))
