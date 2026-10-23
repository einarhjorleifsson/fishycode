# 115 — The feeds' claims, the crosswalk and the vid ledger are code (plan 021 steps 2-4)

*2026-10-17. Written by Claude (AI-assisted), from a session the maintainer's session started ("carry plan 021 on
from step 1 through steps 2-4"). Built and checked in scratch only: nothing was written under `$FISHYDATA`, and the
first allocation of vids is the maintainer's. The choices marked **Claude's reading** are for the maintainer to confirm
before that allocation, since a vid given cannot be taken back. Revised the same day on the maintainer's direction:
clean handovers are cut at the ping boundary and only overlaps held (§6 c amended), and what a vid does when a hull's
key changes is put to the maintainer as an open ask (§6 i), not decided here.*

*Confirmed 2026-10-23 by the maintainer, in a status review run by Claude: Claude's readings 1-6 and 8 below stand as
the crosswalk's rules. Also answered: in an overlapping `two_imos` segment, an IMO with 99 % or more of the segment's
IMO pings takes it by rule (176 of the 636), the rest stay held. Before the first allocation the crosswalk is fixed for
the 27 MMSIs that carry the IMO of a hull already linked to a foreign vid (reading 4 extended to the reviewed foreign
links) and for TODO 129's open STK end, rebuilt, and dry-run again (TODO 65). The Directorate of Fisheries and PAME had
not answered.*

*The fixes are code since 2026-10-23, checked in scratch only (decision 190): the dominant IMO, the reviewed links' IMOs,
the STK open end, and the trail's SKB bound. The rebuild and the first allocation are the maintainer's.*

## What was built

| step | code | output | time on the data |
|---|---|---|---|
| 2 | `sources/astd/identity.R` | `staging/astd/identity.parquet`: pings, hours, box hours, first and last ping by MMSI, year, IMO, name, flag, `astd_cat` and size group | 30 s; 831,881 rows, 547,888 MMSIs, 2,908 M pings |
| 2 | `sources/astd_b/identity.R` | `staging/astd_b/identity.parquet`: by MMSI, year, `cc_iso3`, AIS class, length, breadth | 6 s; 140,629 rows, 68,663 MMSIs |
| 2 | `sources/emodnet/identity.R` | `staging/emodnet/identity.parquet`: by MMSI, year, IMO, call sign, name, flag, ship type | 2 s; 1,642 rows, 1,375 MMSIs |
| 3-4 | `curate/vessel_ais_link.R` | `curated/vessel/vessel_ais_link.parquet` (§4.3) and `curated/check/vessel_ais_link_review.parquet` | 3.4 min; 655,187 rows |
| 4 | `R/allocate_vids.R` | `read_vid_ledger()`, `allocate_vids()`: the ledger `curated/vessel/vid_ledger/`, a stamped file per allocation | seconds |
| §7 | `curate/checks/vessel_ais_link_routes.R` | `curated/check/vessel_ais_link_routes.parquet`: §2.2 by year, route and flag | < 1 s |

Also `R/vessel_keys.R` (`is_valid_imo()`, `mmsi_kind()`), an empty `overrides/vessel_ais_link.csv` (its header is the
format), and eight targets in `_targets.R`: `astd_identity`, `astd_b_identity`, `emodnet_identity`, `stk_mobile_raw`,
`vessel_ais_link_overrides`, `vid_ledger` (listed at the top, like the feeds, and empty until the first allocation:
an empty file target builds, scratch test), `vessel_ais_link` and `check_vessel_ais_link_routes`. Nothing in the flow
reads the crosswalk yet; its reader is the union (step 6).

## How it links

- **One row per feed id and period.** `feed` is `stk` (mobile-id) or `mmsi`: an MMSI names one transmitter in ASTD,
  astdB and EMODnet alike, so it is linked once, and `feeds` says which carried it (§4.3 had a row per feed).
- **Icelandic MMSIs** (any MMSI in `vessel_identity`) are linked exactly as `curate/ais_ping_union.R` reads them, and
  nothing else touches them: 2,197 rows, equal row for row to the union's windows for the MMSIs heard. Six no-hull
  periods (`isl_unregistered`, the placeholders of `mmsi_broadcast_unregistered.yml`) and one gap between holders
  (`isl_gap`) have no vid, as today.
- **Every other MMSI, by segment,** by §4's rule: a register's IMO (EU, Faroese, by MMSI at the time), else the
  feed's own IMO (basis `broadcast`, §6 c), else the register's own id, else the MMSI itself. An IMO that is a registry
  vid's is that vid. A segment is a year, cut where its claims hand over without overlapping in time (§6 c as amended):
  - `imo_handover`: two or more IMOs in a year, each one's last ping before the next one's first; cut at the first
    ping of each later IMO. Of the 900 non-Icelandic MMSI-years with two or more valid IMOs, **261 are clean** (250
    MMSIs, 1.2 M pings) and **639 overlap** (507 MMSIs, 5.3 M pings); only the overlapping are held (`two_imos`);
  - `name_handover`: pings with no IMO, under a name unlike every name the year's IMO pings carry, all before the first
    IMO ping or all after the last; cut there (19 segments). Such pings inside the IMO's span cut nothing.
- **Periods are half-open UTC timestamps** `[t1, t2)`, NA open, in every row: a registry's date period runs to the end
  of its last day, a handover starts at the new holder's first ping.
- **STK** is the frozen key as it is (3,062 rows with a vid), plus a reason for each of the rest: the key's entity class
  (`navaid`, `net_relay`, ...), `unkeyed` or `awaiting_review`, and `not_in_key` for 15,419 mobile-ids in STK's mobile
  table that the key never saw (14,355 of them in the trail: 0.56 M pings, 0.48 M in 2026, median one ping).
- **Hull keys:** `vid_<n>` (a registry vid, not in the ledger), `imo_<n>`, `eu_<cfr>`, `fro_<id>`, `mmsi_<n>`, and
  `mmsi_<n>_<yyyymmdd>` for a hull split off an MMSI by name (below). On the data: 329,433 broadcast hulls, 125 split
  ones, 49,759 IMO hulls, 3,009 registry vids, 426 Faroese and 191 EU register ids.

## Claude's reading, to confirm

1. **A valid MMSI is nine digits whose first three are an assigned MID** (`staging/aux/maritime_identification_digits.parquet`);
   `mmsi_kind` names the rest (`craft_associated` 98…, `aid_to_navigation` 99…, `handheld` 8…, `unassigned_mid`, ...).
   It calls 180,191 ASTD MMSIs invalid where §2 had 99,978, but they carry 8.1 M pings against §2's 7.3 M: the extra
   80,000 are one-ping MMSIs on unassigned MIDs (537…, 539…: 13,774 and 13,331 MMSIs, 14 k pings each).
2. **Segments with no evidence take the hull of the segments before them, else after** (§4: "one hull until the
   feed's own IMO history splits it"), basis `reconstructed`, **unless their name is unlike the names carried**: then
   they are another vessel and start a broadcast hull of their own (`split_by_name`, 125 segments on 113 MMSIs, 0.42 M
   pings; MEKHANIK MAKLAKOV after MUMRINSKIY, ENDRE DYROY after ALEXANDER L. KIELLAND). This is case 2 of the
   maintainer's direction, and it rests on the name alone, which §4 never lets match: here it only splits. So "unlike"
   is generous: two sets of names are the same vessel's if any word of one is like any word of the other (equal, one
   inside the other, or a typo apart), because a wrong "same" only carries a hull over as before, while a wrong
   "different" splits one vessel in two. A first, stricter test (whole names, prefixes) split 245 segments, among them
   the Danish HDMS HVIDBJORNEN from HVIDBJOERNEN. One split in the sample is still one ship (USWARSHIP 25, US GOV
   VESSEL25): every split is in the review table, with the names it was compared to. An MMSI with no evidence at all
   is one broadcast hull whatever its names: a name alone splits nothing. Carried over in all: about 6,200
   segments with 60 M pings, most with no static data at all.
3. **An IMO on two MMSIs at the same time** is an overlap of a day or more between the first and last ping of that IMO
   on each (pairs touching within a day are a reflag: 493 pairs). It includes an IMO that reaches a registry vid while
   that vid holds its own Icelandic MMSI (by the archive's dates), whether or not the Icelandic MMSI broadcasts it.
4. **A foreign MMSI with an Icelandic vid's IMO is that vid** (the vid is the keel): 290 rows, 227 MMSIs on 174 vids,
   mostly vessels sold abroad (*Afmáð*: FAXABORG under Vanuatu's flag, FREYJA as SERMILIK in Greenland). These are new
   links on Icelandic vids (§7 check 4 allows them), and they make a vid's flag a matter of period: step 5 must take
   the flag from the link, not from `vessel.parquet`.
5. **A register MMSI whose call sign a foreign vid (3699-4999) holds is held out** (`foreign_vid_candidate`), not
   linked: of 76 unique Faroese call-sign matches, 71 differ in name (Fram VN 3090 vs SKORABERG), and call signs are
   reused in the Faroes (decision 041). These 59 MMSIs carry 2.63 M of the 3.16 M held-out box hours; a review puts
   each on its foreign vid or lets it be numbered.
6. **The ledger is under `$FISHYDATA`, not in `overrides/`:** it lists about 380,000 hulls keyed by MMSI and IMO, the
   feeds' identities, and this repository is public. A file per allocation, never rewritten; `read_vid_ledger()` stops on
   a hull on two rows or a vid given twice.
7. **Not decided here: what a vid does when better evidence changes a hull's key** (`mmsi_<n>` → `imo_<n>` once GFW's
   API or a register gives the IMO, or one MMSI's history splitting in two). It is plan 021 §6 i, put to the
   maintainer as an open ask. The ledger carries either answer without rewriting a row: each link lists its other keys
   (`alt_keys`), and `allocate_vids(inherit = TRUE)` gives a new key the vid of an old key no current link holds (basis
   `inherited`, `from_hull`; in a split the earlier hull keeps it), while `inherit = FALSE` numbers every new key afresh.
   Until §6 i is answered it stops when the choice matters and numbers freely when it does not, as at the first
   allocation.
   *Answered by the maintainer later the same day: the vid is kept (`inherit = TRUE`, now the default; plan 021 §6 i).*
8. **Side.** §6 f put the crosswalk "in the flow", against `once`. It is in the main project, rebuilt with each
   delivery; by plan 014's line it is preprocessing, since it reads the feeds' static claims and never the track.

## Measured (scratch, ASTD to 2026-06)

Held out, linked only through `overrides/` (§6 c), 1,185 MMSIs, 52.8 M pings, 3.15 M box hours:

| reason | segments | MMSIs | pings (M) | box hours (k) |
|---|---|---|---|---|
| `foreign_vid_candidate` | 543 | 59 | 23.3 | 2,632 |
| `imo_two_mmsis` | 1,040 | 626 | 15.4 | 271 |
| `register_two_ids` | 73 | 12 | 2.4 | 167 |
| `two_imos` (overlapping) | 636 | 506 | 5.2 | 78 |
| `continued_conflict` (no evidence, carried from a held segment) | 268 | 81 | 6.3 | 5 |
| `imo_registry_conflict` (8817540 on vids 1352 and 2220, or a vid with two IMOs) | 14 | 2 | 0.2 | 0.1 |

Of the 636 `two_imos` segments, 176 have one IMO with 99 % or more of the IMO pings (52 k of the 78 k box hours).
Listed and linked (`held_out` FALSE): 251 `imo_handover` and 19 `name_handover` cuts, 125 `split_by_name`, and 54
segments where the register's IMO differs from the feed's (the register's is taken).

**§2.2 from the product** (`check_vessel_ais_link_routes`, ASTD 2013-01 to 2026-06, MMSI-years, each takes the first
route that reaches it):

| route | % of pings | % of box hours | §2.2 (pings, box hours) |
|---|---|---|---|
| 1 Icelandic lists | 12.3 | 64.0 | 12.4, 64.1 |
| 2 EU register (by MMSI) | 1.0 | 0.4 | 1.2, 0.5 |
| 3 Faroese register (by MMSI) | 3.0 | 19.3 | 3.0, 19.2 |
| 4 IMO in a register | 1.9 | 3.6 | 1.6, 4.0 |
| 5 GFW only | 22.6 | 2.6 | 22.3, 2.4 |
| 6 the feed's own IMO only | 38.9 | 7.6 | 38.2, 7.4 |
| 7 nothing but the broadcast | 19.5 | 1.4 | 21.0, 1.3 |
| 8 held out, no register | 0.6 | 0.2 | — |
| 9 invalid MMSI | 0.3 | 1.0 | 0.3, 1.0 |

By year, registers (routes 1-4) reach 8.6-28.6 % of the pings and 82-90 % of the box hours; the broadcast-only share
grows from 13-15 % (2013-2018) to 29-31 % (2024-2025), and 2026 (IMO-only deliveries from February) is 60 % own IMO.
By flag: Norway 1.2 % register, 37 % GFW, 37 % own IMO, 24 % broadcast; Faroes 97.7 % register; Iceland 99.7 %.

## Checked (plan 021 §7, scratch)

- **Check 1:** every MMSI in the pings of ASTD (547,888), astdB (68,663) and EMODnet (1,375), read again from the pings,
  and every mobile-id in the STK trail (33,516), has a row; every row has a vid or a reason.
- **Check 2:** after a scratch allocation (379,934 hulls, vids 200001-579934), no feed id has two overlapping rows, no
  IMO is on two vids, no vid has two IMOs or two hulls, and wherever `vessel.parquet` holds an IMO the link's vid is
  that vid. The script asserts the same and stops if any fails.
- **Icelandic links** equal the union's MMSI windows row for row (2,197).
- **Huginn (MMSI 251439000, the parent session's test case).** Both its MMSIs are in the Icelandic archive on vid 2411
  (251439000 from 2007, 251139000 from 2021-02-28), so rule 1 links both to 2411 and the IMO rule never reaches them.
  That reverses decision 067's outcome (the maintainer's "no override", 2026-10-07: the 2017 EMODnet pings on 251439000
  without a vid), but not here: today's union already puts 173,242 of 251439000's 2017 pings (ASTD and EMODnet) on
  2411, through plan 016's archive (decision 112). The crosswalk reproduces it; whether it stands is the maintainer's.
- **Check 5, simulated:** build A on ASTD to 2026-05, allocate (379,823 vids); build B with 2026-06 on A's ledger.
  Allocating B with §6 i open stops, as it should: 7 new hulls could keep an old key's vid. Then under each answer:

  | B allocated with | new vids | inherited | A's ledger rows moved | A's MMSI-years: same vid | changed | lost |
  |---|---|---|---|---|---|---|
  | `inherit = TRUE` | 111 | 7 | 0 | 576,843 | 0 | 2 |
  | `inherit = FALSE` | 118 | 0 | 0 | 576,810 | 33 | 2 |

  190,386 MMSI-years have no vid in either (invalid MMSIs). The 33 are §6 i's upgrade case, 7 MMSIs whose IMO first
  came in June. June's IMO-only month gave 369970411 the IMO 4684517, which moves its broadcast hull of 2013-2025 to
  an IMO hull. The 2 lost are a new conflict: in June IMO 9187409 came to be on two MMSIs at once (316003980,
  538090716), so both 2026 segments are held out. No vid moved under either answer, but a new month can withdraw a
  link into the review table. The STK rows are identical.

## Left

**Waiting on the maintainer:**
- the go to build the five new targets on `$FISHYDATA`, then the first `allocate_vids(dry_run = FALSE)` and a rebuild of
  `vessel_ais_link`. In order, after the commit: `tar_invalidate()` and rebuild `vessel_identity_foreign` and
  `vessel_identity_all` (built from a dirty tree, decision 114), then `tar_make(names = c("vessel_ais_link",
  "check_vessel_ais_link_routes"))`, which builds the claims and declared inputs above them and nothing of the AIS chain
  that decision 113 left outdated; then allocate, and rebuild `vessel_ais_link` (the ledger is its input);
- items 1-6 and 8 above, before that allocation (item 7, plan 021 §6 i, is answered); and whether a dominant
  IMO (99 % of the IMO pings: 176 of the 636 overlapping `two_imos` segments) may be linked by rule rather than one
  override each;
- *(done 2026-10-17)* the review of the 59 `foreign_vid_candidate` MMSIs: 52 links for 50 of them in
  `overrides/vessel_ais_link.csv`, confirmed by the maintainer; 9 stay held (what the review left is in TODO 65);
- the Directorate of Fisheries' answer on MMSI. GFW's Vessels API pass (§6 d) no longer waits on the token, which is
  in fishycode's `.Renviron` since 2026-10-17; it is not built. Its place is marked in `curate/vessel_ais_link.R`: the
  API's IMO and call sign by MMSI and period join the registers there;
- PAME's answer on ASTD's coverage by year and the IMO-only months from 2026-02 (asked 2026-10-17, §6 h). Full months
  would add MMSIs without an IMO, so broadcast hulls, and change no vid already given.

**Not done here:** the STK key's 15,419 mobile-ids it never saw wait for its redo (step 7, by decision); the four
other copies of the IMO check could use `R/vessel_keys.R`; `AGENTS.md` names neither the ledger nor the crosswalk yet;
`docs/data-dict.yaml` has no entry for the new tables.
