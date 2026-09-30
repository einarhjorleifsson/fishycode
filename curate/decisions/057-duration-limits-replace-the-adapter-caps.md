# 057 - Duration limits replace the caps in the logbook adapters

**Status:** done 2026-09-30. Closes `TODO.md` item 28. Plan: `curate/plans/010-ping-activity-link.md` §12, §12b.

`sources/afli/convert.R` and `sources/fs_afladagbok/convert.R` each capped a long `duration_m` at a hand-set maximum per gear and kept only the capped value (afli: 30,120
stations across the two adapters). For mobile gear the end time was then derived from the capped duration, so a Danish-seine tow logged as 9 h became exactly 3 h long. The two
cap tables had drifted (Danish seine 180 vs 240 min, finfish trawl 600 vs 720, plough 240 vs 1200). Two AGENTS.md rules were broken: corrections live in `curate/`,
and the original is never destroyed.

**Measured** (plan §12b, from the raw tables, before any cap): the excess over each cap sat *just above* it for most gears (Danish seine has a second mode of 6-12 h records; finfish
trawl 91 % within 1.5x; longline 86-88 %), and *far above* it for Nephrops and shrimp trawl (70 % and 54 % over 4x the cap: errors). Capping an error at the cap invents a
precise-looking duration.

**Chosen (maintainer, 2026-09-30):** one plausible maximum per gear in `reference/gear/windows.R` (`gear_window.dur_max_min`): Danish seine 960 min, finfish trawl 900, Nephrops
720, shrimp 1440, midwater 2160, longline and jigs 2880, gillnet 7 d (Greenland-halibut nets 21 d); dredge, drift net and trap keep the larger old value. The rule is
`R/duration_limit.R`, shared by both adapters: `duration_m_raw` is always kept, a duration above the limit is NA with `.duration_source = "implausible"`, and in
`fs_afladagbok` the end time behind it is NA too.

**Result (rebuilt from the raw logbook data):** capped stations 30,120 -> 0; `implausible` 3,943 (afli 3,421, fs 522). Danish-seine tows over 180 min 1,605 -> 4,624, 99th percentile
180 -> 533 min, none over 960. The 2019 Danish-seine gap against the old trail (old pings no window claimed) fell from 78,256 pings / 550 windows to 5,913 / 21.
`station_window` moved by a few hundred stations per row type. The STK key's headline figures are unchanged (720,336 trips for 2,763 vids, against 720,330 and 2,763; the coverage
invariant closes). AIS rows per year changed by at most 0.016 % (2021: -5,153), cause not isolated.

**Not done:** the overlap check in `afli` that sets `t2`/`t3` to NA for overlapping operations (183,516 bottom-trawl stations, 4.3 %) - the same kind of correction, `TODO.md` item 29.
