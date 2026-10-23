# 182 — A species reference from every list: one row per code, each value from the first list that means the code's taxon

*2026-10-23. Closes TODO 10. Written by Claude (AI) in a session started from another Claude session; the script, the
rule that matches the lists and every count below are Claude's and have not been checked by a person. **Built in
the store the same day** on the maintainer's go, at d73b4e3 (below).*

## Found

**The codes are one numbering, kept in several lists that do not always agree.** The logbooks and landings carry one
species code (`sid`). The Directorate's list (`ufs.fisktegundir`, 331 codes) and orri's (`orri.fisktegundir`, 686)
share 328 codes; orri's and MFRI's register (`taxon.species`, 1,312) share 645. Most shared codes are named alike or as
variants (Grálúða and "Grálúða / Svarta spraka"; Laxsíld ógr. and Laxsíldaætt). A few mean another species:

- 278: ufs and adb Bretahveðnir - 1, orri and taxon Brandháfur (a sixgill shark); agf uses it on 10 rows, 0 kg;
- 953: ufs Langhali, orri and lods Skötuselur 2; fs_afladagbok on 14 rows, 0.8 t;
- 165: ufs Litli loðháfur, orri "do not use this number, use 125";
- 613 (Svartmjóri, a fish, against Kolusmokkur, a squid) and 556 (Leðjuláki against Marglytta), between orri and taxon;
- 445 in afli: its own list says Slitinn humar (Norway lobster, broken), every other list Sækönguló (a sea spider).
  afli logs it on 563 stations in 2019-2021, 554 of them Nephrops trawl (gear 7), 28.7 t, and on none of them code 40
  (Norway lobster): afli's meaning holds there.

**adb's codes are MFRI's numbers.** `adb.species` maps the Directorate's code (`id`) to MFRI's (`species_no`, "BIOTA
species number" in Oracle's comment), several to one (950 and 951 to 48, 278 to 512, 953 to 122, 901 to 55), and adb's
catch carries `species_no`. All 98 codes adb's catch uses are in `taxon.species`, and none falls on a code where taxon
and ufs mean different species, but for the catch-alls 29, 55 and 184, where adb's own names agree with ufs's.

**Views replaced by their tables.** `taxon.tegund_v` is `species` joined to `taxon` (the WoRMS id where the unit's
source is WORMS) and to `asfis.asfis` (the 3-alpha code by `taxocode`); `kvoti.stadall_fisktegundir_v` is 74 rows of
`orri.fisktegundir` chosen by a list in the view's text; `kvoti.lods_fteg_v` is `lods_fteg` where `birting_vefur = 1`.
The script reads the tables and does the joins. `fs_ufs.landing_species` has two halves, 120 rows keyed by orri's code
(`fteg`) and 49 by ufs's (`fisktegund`); 115 rows carry both and they are always equal, 4 codes are in both halves with
the same values; its WoRMS ids equal taxon's on all 141 rows where both have one. `fs_ufs.fisktegundir` is a copy of
ufs's list that differs on 31 rows: ufs has an FAO code it lacks on most, and on some it has another value (45
Beitukóngur: Eutrigla gurnardus, a gurnard, where ufs has Buccinum undatum, a whelk). `taxon.vernacular` holds several
English names per taxon unit with none marked preferred (`taxon.species.eng_name` is among them for 31 of 286), so it is
not read.

## Chosen

`reference/species/species.R` (target `species`, preprocessing) writes `curated/reference/species.parquet`: one row per
code that any list holds, and the declared ones.

- **The anchor.** A code's identity is that of its first list in the name order: ufs, orri, taxon, lods, afli, adb,
  fs_ufs's copy. ufs first because the landings (agf) code by it and agf and fs_afladagbok use codes only it holds (1128,
  954): where ufs and orri name a code differently, the sweep's rows are the Directorate's.
- **Which lists mean the anchor's taxon.** A list's record of the code is taken when it shares an Icelandic name with
  the anchor or a list already taken (case, accents, rank words and "A / B" ignored, two letters apart, or an
  abbreviation), or a scientific name at the same rank (genus and epithet; `Sebastes sp.` is not `Sebastes
  norvegicus`), or one's name is the other's scientific name, repeated until no list is added. A list whose record
  names no taxon (landing_species without a taxon number) contradicts none. The others are listed in
  `lists_unmatched`, and their values are kept in the `_other` columns, never taken.
- **One value per field**, from the first matched list in the field's declared order (`layer_order` in the script; the
  grammar's layer), with `<field>_layer` and `<field>_basis`: `recorded` where the list holds the value for the code,
  `derived` where it comes through the record's own key (the FAO code by taxon's `taxocode` in ASFIS, the WoRMS id by
  its taxon unit), `none`. Scientific names from taxon first (checked against WoRMS); FAO codes from ufs, then orri's
  map where it is one to one (20, 55 and 305 take several), then ASFIS by taxocode, then fs_ufs; a code not in ASFIS is
  never taken (QGF, PO, MIX, VAP, 48), and is kept in `fao_3a_other` marked so. The WoRMS id from landing_species, then
  taxon.
- **Disagreement kept and flagged.** Every other list's value that does not agree with the one taken is in
  `<field>_other` ("schema.table: value"), with `<field>_differs`.
- **Declared codes.** `note` says why for the codes no list names (0), afli's own (-30, -31, -34: herring, capelin and
  blue whiting let go; 999; 445), the codes the lists mean differently (278, 953, 165, 901) and the codes TODO 10 found
  unnamed (665, 533, 269, 1128, 954).
- **The check** runs before the write: every `sid` of `curated/logbook/catch` and `curated/landing/catch` must have a
  name or a note, or the script stops. The catch tables are read for the check only, not as inputs.

The overlay lines for every table read are in `dump/oracle/meta/` (plan 040, phase 2): new `taxon.yml`, `orri.yml`,
`ufs.yml`, `fs_ufs.yml` and `asfis.yml`, and the lists added to `afli.yml`, `adb.yml` and `kvoti.yml`, with keys,
labels, the codes' meanings and two asserts (an FAO code has three letters: expected false on 1 row in ufs, PO, and on
2 in fs_ufs, 48 and PO). `docs/data-dict.yaml` has `reference_species` and its joins from both catch tables.

## Measured (scratch store, dumps of 2026-10-16, -17 and -22)

- 1,367 codes: an Icelandic name on 1,366 (all but 0), English 374, scientific 1,298, FAO 466 (360 derived), WoRMS
  1,194 (1,054 derived), rank 1,275, target assemblage 159. Names from ufs 331, orri 358, taxon 667, adb 6, afli 4.
- The check: all 518 (table, schema, code) of the two catch tables resolve. Share of each source's kg with a name, a
  scientific name, an FAO code and a WoRMS id:

  | table | schema | codes | kt | name | scientific | FAO | WoRMS |
  |---|---|---|---|---|---|---|---|
  | logbook | afli | 79 | 45,985 | 99.994 % | 99.24 % | 99.24 % | 99.23 % |
  | logbook | fs_afladagbok | 122 | 3,927 | 100 % | 99.65 % | 99.65 % | 99.33 % |
  | logbook | adb | 98 | 837 | 100 % | 99.93 % | 99.93 % | 99.92 % |
  | logbook | aflaskeyti | 24 | 283 | 100 % | 100 % | 100 % | 100 % |
  | landing | agf | 112 | 25,815 | 100 % | 100 % | 100 % | 99.45 % |
  | landing | lods | 83 | 29,113 | 100 % | 99.93 % | 99.93 % | 99.93 % |

  The kg without a scientific name are the catch-alls 55 'Annað' (166.6 kt) and 29 (12.6 kt), afli's 999 (143.6 kt),
  -30 and -31 (54.8 kt), and 0 (2.8 kt).
- TODO 10's codes: 999 is afli's (74,706 rows, 143,586 t, 1973-1990, bottom trawl but 12 rows, the station's only
  species on 34,303 of them), named only by taxon ("Ógreinanlegt", unidentifiable): most likely catch not split by
  species, not established. 0: afli 41 rows (2,808 t, purse seine, 2011-2022) and lods 8 (0 kg), named by no list.
  665, 533 and 269 are named by ufs, orri and taxon, 1128 and 954 by ufs alone; 278 and 901 as above.
- `lists_unmatched` on 30 codes. In the catch tables: the catch-alls 20, 29, 55 and 184 (taxon's broader or narrower
  group, or "other" in other words), 271 (Ögn: Mysidacea against Mysida), 278, 445, 901 and 953. The other 21 (50,
  147, 162, 165, 185, 190, 213, 236, 316, 324, 409, 410, 556, 613, 641, 645, 658, 732, 738, 905, 1035) no catch uses.
  Some are spellings the rule does not reach (185 Vængjasnigill and Vængjasniglar; 1035 Grámi and "Risso's dolphin"):
  a value lost, not a wrong one.
- The overlays on clones of the eight dumps: `rewrite_data_dict()` and `check_data_dict()` give 0 spec errors, the
  asserts false on 1 and 2 rows as described, the enums pass, the keys unique. The real dictionaries are not rewritten.
  `docs/data-dict.yaml`: 223 spec errors before and after (TODO 51), none in the new entry; its data check passes on the
  scratch file.

## Built

2026-10-23, on the maintainer's go: `tar_make_isolated(names = "species")` at d73b4e3, a clean tree, built
`species_raw` and `species` (9 s). The only file written is `curated/reference/species.parquet` (`fd.dirty` false),
identical to the scratch build; the check gave 1,367 codes and all 518 (table, schema, code) resolved; `species` is not
outdated since.

## Open

- Nothing reads `species.parquet` yet.
- A person to read the 30 `lists_unmatched` codes and the notes, above all 278, 953, 445 and 999.
- Rewriting the eight real dictionaries with the new overlays (`rewrite_data_dict()`), as decision 176's were.
