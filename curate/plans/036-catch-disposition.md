# 036 — The catch's disposition: at home, exported, or landed abroad, carried from the landings to the trip

**status:** proposal — measured 2026-10-21 (read-only); nothing built; seven asks open (TODO 112) · **2026-10-21** ·
**see:** TODO 112, TODO 81 and plan 027 (a trip landed in two pieces), TODO 74 and plans 007, 023 and 025 (the
landings), TODO 92 (ports abroad), decision 031 (the agf/LODS merge), `sources/aflagrunnur/convert.R`,
`sources/lods/convert.R`, `curate/landing.R`, `reference/ports/port_code.R`, `curate/link_lid_map.R`,
`curate/catch_by_species_trip.R`, `curate/ais_catch.R`

Drafted with AI assistance (Claude) on 2026-10-21, at the maintainer's request that code 159 'Gámur/Sigling' be kept
downstream. The definition of 159 is the maintainer's. The measurements and the proposal are Claude's. The numbers were
measured by Claude (AI), and a person has not yet checked them. The scripts are in
`$FISHYDATA/archive/2026-10-landing-disposition/` (read-only, rerunnable). Its README answers whether the 159 landings
are counted twice; they are not (§1).

**Measured:** every number in §1 and §2. **Assumed:**
- that LODS's 159 rows with an Icelandic origin port are container exports rather than landings abroad (ask's EE
  container notes witness this for 2007-09 to 2013 only);
- that agf's `afdrif` U means the same thing as LODS's 159 (the two never overlap in time, so this is not checked);
- that the foreign codes in the landings are landings abroad (sigling).

## 1. What the study found

The maintainer (2026-10-21): 159 is not a port. *Gámur*: the catch went straight into a container and was exported
unprocessed. *Sigling*: the vessel sailed and landed abroad. Both are "important to have/keep in potential downstream
processing".

- **LODS keeps the exported part as a landing of its own at 159**, to 2013-08-30: 38,112 vessel-days, 717,119 t (live
  weight) over 1992-2013, 6,282 (151,229 t) of them from 2007-09.
- **agf lacks that part until 2013-08, by design.** ask's agf feed leaves out its container notes (type EE), and on the
  vessel-days with both, agf equals LODS's home-port landing on 4,439 of 4,447. agf equals the home landing plus 159
  on none.
- **It is not double counting.** The logbook confirms it: on 4,037 trips the logged catch is 1.004 times home + 159
  and 2.30 times the home landing alone.
- **From 2013-09 agf records the same thing per row**, as `afdrif` U 'Útflutningur', inside a landing at a real port:
  8,017 landings, 221,663 t, a median 30 % of the landing; 54 are export only. The handover is clean: LODS's last 159
  is 2013-08-30, agf's first U 2013-09-05, and no vessel-day holds both.

## 2. What fishycode does now

- **agf's `afdrif` is dropped** by `sources/aflagrunnur/convert.R`. Every agf row has one (5,392,528 rows, none
  empty): V to processing, C regional quota to processing, H VS catch, S coastal-fishing fund, A to reduction, B
  damaged, I to farming, F to freezing, U export.
- **LODS's 159 is a landing at a code that is no port.** `port.parquet` has no row for 159, so its pid is empty;
  `port_code.parquet` (from agf's view, which never uses 159) has no name for it. The origin port, `upprunahofn`, is
  only in `kvoti.lods_slaegt` (same rows as `lods_oslaegt`, 230 t apart in total), which the adapter does not read.
  - Origin port, from 2007-09: Icelandic on 6,273 of 6,282.
  - Origin port, before: Icelandic on 13,264 of 31,830; none on 18,329 (all of 1992-1995, most of 1996-2000).
- **The trip loses the exported part.** `lid_map` gives a trip one landing (TODO 81). It claims 610 of the 6,282
  landings at 159 from 2007-09 (13,479 t). On 4,073 vessel-days it claims the home landing and leaves the 159 one
  unclaimed: 107,592 t, so those trips' landed catch is half what they caught. `ais_catch.R` shares an unclaimed
  landing over the voyages it links, so the kg may still reach fixes, but the trip's raising factor (landed over
  logged) is about half.
- **The logbook's own 159.** afli has 821 trips ending at 159 (`trip.parquet` hid2; 546 in 1973-1991, 163 in 1994-2003,
  112 in 2008-2010), and 129 landing confirmations name 159 (2008-2010). Where LODS exists, the skipper's 159 sits
  within 3 days of a LODS 159 landing:
  - on 144 of 163 trips in 1992-2007;
  - on 107 of 112 trips from 2007-09;
  - on 122 of 129 confirmations.

  But skippers seldom use it. Of LODS's 4,779 landings at 159 in 2008-2010, an afli trip ends within 3 days on 4,595,
  and only 98 of those trips end at 159.
- **Other codes with no pid** (`results/codes_without_pid.csv`):
  - **abroad:** Færeyjar 167 (1,344 landings, 814 kt), Noregur 163 (641, 356 kt), Kanada 172, Danmörk 165, Grænland
    166, Skotland 160, Írland 208, Holland 175, 161, 168;
  - **sigling, in ask's list:** 196 'Erlendis / Aðrar siglingar' and 198 'Siglingar frystitogara', 22 LODS landings in
    1993-1995;
  - **transfers:** 155 (Icelandic vessel to Icelandic vessel), 301 and 302 (between Icelandic and foreign vessels),
    300 'Flutningaskip';
  - **placeholders:** 150 'Ýmsir staðir' (6,288 landings), 197 'Leiðréttingar', 999, 900;
  - **unexplained:** 41 and 71, and 200 Gjögur, a place in Iceland with no pid.

## 3. The design (proposal)

1. **A class for every code that is not a harbour**, in `reference/ports/port_code.R`. It reads its names from
   `kvoti.stadur`, which names 159, rather than from agf's view, which does not. It adds `class`:
   - `disposition` for 159;
   - `abroad` for the country codes, 196 and 198;
   - `transfer` for 155, 300, 301 and 302;
   - `placeholder` for 150, 197, 900 and 999.

   The classes are a small declared table beside the script, reviewed by hand (ask e). 159 never gets a pid or a
   geometry.
2. **Preprocessing keeps the originals.**
   - `sources/aflagrunnur/convert.R` keeps `afdrif` on its catch rows.
   - `sources/lods/convert.R` keeps the origin port as `hid_origin` (from `lods_slaegt`; ask g).
3. **`curated/landing/catch.parquet` gets `disposition` and `disposition_basis`**, and `disposition` joins the key
   `curate/landing.R` collapses by, so a landing's rows split by disposition. agf's `afdrif` stays beside it,
   recorded.

   | disposition | from | basis |
   |---|---|---|
   | `home`: landed in Iceland for use there | agf rows not U (2007-09 on); LODS at an Icelandic harbour | recorded (agf); derived (LODS: the ledger kept exports at 159) |
   | `export`: landed in Iceland, exported unprocessed | agf U (2013-09 on); LODS 159 with an Icelandic origin port | recorded (agf); derived (LODS) |
   | `abroad`: landed abroad | a code of class `abroad` | derived |
   | `export_or_abroad`: one or the other, not told apart | LODS 159 with no Icelandic origin port | derived |
   | `transfer` / `unknown` | codes of class `transfer` / `placeholder` | derived |

   `curated/landing/landings.parquet` gets `hid_origin` and `pid_origin`, the origin port of a landing at 159.
4. **The exported part joins its trip.** A landing at 159 joins the trip that claims a landing of the same vessel at
   its origin port, on the same day or the day before. ask's container weighing (EE) falls mostly on the day before
   LODS's date, and on that day agf equals LODS's home landing on 1,310 of the 1,835 rows with no home landing on
   LODS's own day. The rule reads no track, so it can sit in preprocessing beside `lid_map` (ask c). It is what plan
   027's `trip_landing` does for other further landings, with a basis `export`. Folding the 159 rows into the home
   landing instead is ask b.
5. **The trip carries it.**
   - `catch_by_species_trip.parquet` splits `catch_landings` by disposition.
   - `trip.parquet` gets `disposition`: `home`, `export`, `abroad` or `mixed`. It comes from the trip's landings, basis
     theirs; where no landing is linked, from the skipper's own 159 (`export_or_abroad`, basis recorded, from the
     logbook). That is the only source for afli's 546 trips of 1973-1991.
   - The skipper's 159 is kept as recorded: `hid2` stays 159, its pid empty.
6. **Docs:** the columns in `docs/data-dict.yaml`, and a section on disposition where the landings are described,
   with the period convention (159 to 2013-08, U from 2013-09) and the surcharge rows (ask d).

## 4. Checks (done when)

1. Landed kg by year and source are unchanged: disposition only splits rows.
2. Every catch row has a disposition and a basis.
3. Export is continuous across the handover: LODS's 159 by fishing year to 2012/13, agf's U from 2013/14.
4. On the 4,037 trips with an unclaimed 159 the same day, logged over landed moves from 2.30 to about 1.0 (the control
   is 0.982). No trip without a 159 landing near it changes its landing.
5. `check_bookkeeping()` clean; the rebuild runs from `landing` through `ais_catch` (by name, fingerprints first).

## 5. Asks

a. **The vocabulary.** The five values of §3.3, with agf's `afdrif` kept raw beside them; or agf's nine codes as the
   column itself, with 159 and the codes abroad mapped onto them.
b. **The 159 landing: apart or folded in?** *Apart* (recommended): it stays its own landing at 159, with its origin
   port, and joins its trip by rule (§3.4). Keys stay, and `lid_map` is untouched. *Folded*: its rows move into the
   home landing at the origin port, which is agf's shape from 2013-09. But the merge's precedence would then have to
   key on disposition, one landing would hold rows of two schemas, and the `.lid` of about 6,300 landings from
   2007-09 (and up to 31,830 before) would change.
c. **Where the trip rule lives.** In preprocessing beside `lid_map` (it reads no track), or in plan 027's flow table
   `trip_landing`.
d. **The export surcharge rows (`gerd` A, -66,884 t, all at 159).** Today they are summed into the catch. The study
   leans to the sum being the weight, since K is grossed up by the surcharge, but it is not settled. Keep the sum, or
   carry A in its own column so that either reading stays possible.
e. **The classes of §3.1**, and what 41, 71, 197 and 200 Gjögur are.
f. **The fixes.** Should `ais_catch.R`'s catch on the fixes carry disposition (kg exported per fix), or should it stop
   at the trip?
g. **The LODS input.** Read `lods_slaegt`, the only table with the origin port and LODS's landed weight, in place of
   `lods_oslaegt`, after checking the 230 t between them; or join it in for `upprunahofn` alone.
