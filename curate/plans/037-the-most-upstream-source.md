# 037 — The most upstream source, value by value: layers from raw to curated, in the grammar's terms

**status:** proposal — written 2026-10-21, scoped the same evening; nothing built in the store; the sent layer's
adapter written the same night and run on a scratch store only (§2.1); TODO 113 and 114 paused for it;
asks in §7 (a, b, c and e answered 2026-10-21), the TODO items it touches in §8 · **2026-10-21** · **see:** `docs/grammar.qmd` (the grammar of sea-going observational data), TODO 108,
110, 113, 114, decisions 157, 158 and 160, plans 023, 025, 028, 029 and 036, `curate/corrections/afli_end_longitude.yml`,
`curate/corrections/afli_coords.yml`, `$FISHYDATA/archive/2026-10-xml-oracle-map/`, `2026-10-xml-inventory/`,
`2026-10-xml-positions/`, `2026-10-time-offsets/`, `2026-10-time-offsets-towed/`, `2026-10-landing-confirmations/`,
`2026-10-landing-disposition/`, `2026-10-plan037/` (the paused TODO 113 and 114 sessions' notes and scripts)

Drafted with AI assistance (Claude) on 2026-10-21. The principle is the maintainer's, stated that day as the premise of
decision 160: take "the most upstream source possible when curating (or even staging) the data if different, if
having more clarity on units or if they have higher precision or known precision". The maintainer asked for the plan to
cover the logbooks, the landings and every other element with a version as sent; to take into account that some
tables were not dumped, and say which seem to warrant it; to tell resends from in-house manual corrections, which the
maintainer suspects are common in `afli`; and to think the design from raw to staged to curated through the grammar.
The inventory, the measurements and the design are Claude's.

**Measured** (by Claude, read-only, not yet checked by a person): §2 and §3, from Oracle's catalogue
(`raw/oracle/_catalogue/objects.parquet`, 112 schemas), the column types of every dumped table, the side studies cited,
and the TODO 113 and 114 sessions' notes. **Assumed:** that a value an app sent is what the skipper entered unless a
defect is measured; that a value changed in-house after loading was changed on purpose; that the schemas of §3.3 not
yet read hold what their table names and Oracle's comments say (six were dumped on 2026-10-21, decision 162; none is
read yet).

## 1. The principle, sharpened by the scoping

Each value is taken from the most upstream layer that holds it **when that layer states its unit and keeps more, or a
known, precision**; a downstream layer is a witness. Two things qualify it:

- **A later deliberate change wins over an earlier value.** A resend by the app (a new version of a record) and a
  correction made in-house after loading are both later than the first value sent. The latest version sent is the
  app's own correction; an in-house edit is a person's, made with evidence (a landing, a call to the vessel). Where
  the layers differ and the record is marked edited, the edited value is taken, and the difference is a finding, not
  a defect.
- **Upstream is not the same as clearer.** The sent record has its own defects: the app's placeholder set times
  (decision 157), the logger's misdecoded positions (`afli_coords.yml`), and depths sent in fathoms by some vessels in
  some periods, in every year of Fishing Log 2.6 and 2.7 (TODO 113 notes). These are flagged or tested, as on any
  layer.

So the choice is made per value, by the field group the value belongs to, and every chosen value says which layer it
came from.

**It is bookkeeping, not modelling** (the maintainer, 2026-10-21: "an accountant exercise, not a random forest
model"). Every record and every kilogram is accounted for: placed in one outcome, and every difference between layers
explained (unit, precision, defect, resend, in-house edit). An agreement rate is not a pass, however high: 99.9 % that
matches says nothing of the 0.1 % that does not, which is listed record by record, explained or marked unexplained.
Statistics only test in the background (a unit test on depths against GEBCO, the track against a time); they never
replace the account.

## 2. The layers, measured for afli's electronic logbook

afli's electronic logbook passes through three layers, each of which adds or loses something:

| Layer | Where | Adds | Loses or alters |
|---|---|---|---|
| **sent** | `fs_afli.afladagb_xml_mottaka` (565,192 messages, 1.44 M records; a superset of `afli`'s copy by 81,454 messages after 2020-07-28) | everything the app sent: positions to the arc-second, the end position (`POS_END`), depths, catch as logged with its state (`SLAEGT`), soak hours and nights, tow time, hooks and baiting, when the record was closed, the landing confirmation, the app and its version | the app's own defects (above) |
| **loaded** | `rafr_stofn`, `rafr_lineha`, `rafr_toga`, `rafr_afli`, `rafr_sjalfvirkir_maelar` | the record id, the load | positions to the minute, the end position never loaded, the start depth converted to fathoms and the end left in metres, the end longitude overwritten by the latitude (2010-2012), the soak rounded up, the catch's logged weight and state on only part of the rows |
| **edited / moved** | `afli.stofn`, `lineha`, `toga`, `afli` | in-house corrections: another gear on 30,026 records, another landing date or port on 101,087; in all, a value differing from both the sent and the loaded one on 178,778 fields of 152,555 stations (12 %), records of 2003-2018; the flag `breytt_eftir_lokun` marks the move into afli from 2020-09 on, not an edit; `fs_afli.afladagbok_sidast_breytt` times each record's last change; the statistical rectangle computed where missing | the Danish seine's tow time dropped (105,879), the depth divided by 1.8288 a second time (11,956), the soak rounded a second time (13,637 and 6,104), the catch's logged weight and state not moved |

**Who edited.** afli keeps no editor. `rafr_stofn` names the account that last changed each loaded record (`sbg`,
`sbt`): the move into afli, a later confirmation or an edit in `rafr_`, so an account is the row's last changer, not
the author of an afli edit. The flag `breytt_eftir_lokun` is not an edit mark either: it is set on all 166,214 stations
moved into afli from 2020-09 on, by any account, and on 324 moved before (recounted on the dump, 2026-10-22). This
plan first read the flag as edits after closing, three quarters of them by one account; those were that account's
moves, equal to the loaded values but 47 ports. The in-house corrections are found by comparing the layers: 178,778
fields of 152,555 stations, records of 2003-2018 (landing date mostly from the registry, gear from the catch, nephrops
weights; `$FISHYDATA/archive/2026-10-afli-layers/`, measured by Claude, not checked by a person). The maintainer
(2026-10-21): the person behind the corrections had a deep knowledge of the fishery and checked the data the old way,
by comparing sources and asking the captains. So the in-house edits are an expert's corrections with evidence behind
them: they win where they apply, and they are labels, a set of records an expert judged wrong and put right, against
which an automatic check (gear from the landing, the trip-to-landing match on dates and ports, the station's place) can
be scored. Accounts are counted, not named.

Resends are rare and in-house edits common. Of the 1.44 M sent records, 91.3 % were loaded as sent; 4,598 (0.3 %)
are older versions of a record sent again; 107,189 the same version sent again in another message; 14,267 never
loaded (most with no readable record id); 257 test messages. A record is found in its message by three forms of its
id (as sent, negated, and −(1,000,000 + id)); the end-longitude correction of decision 158 knows only the first, and
its pattern misses records spanning lines.

### 2.1 The sent layer staged (2026-10-21)

*Written and measured by Claude (AI) on a scratch store; not checked by a person. The full account, cell by cell,
is in `$FISHYDATA/archive/2026-10-plan037/afli-sent/` and `visir-reuse/` (notes and scripts of 2026-10-21).*
`sources/afli_sent/convert.R` (target `afli_sent`) stages every record of the messages onto the grammar's tables, the
latest version of each, keyed to `rafr_stofn.visir` so that `.sid` is the edited layer's; nothing in `curate/` reads
it yet. Three findings set what a record is:

- **The apps' record number (VISIR) is one running count per vessel and app installation, and it restarts:** 11,763
  (vessel, VISIR) pairs hold two or more records, mostly years apart, 9,478 of the 11,106 restarts at a change of
  app family and 1,545 under one app and version. The number holds neither the vessel, the year nor the haul within
  a trip, and no account the message names (software key, skipper) makes it unique. A copy is a version of a record
  only with the same vessel, VISIR and a fishing date within 31 days.
- **Oracle loads some versions as rows of their own** (mostly two versions in one message, the older deleted):
  14,370 records hold 30,286 rows. A vessel's loaded rows of one VISIR within 31 days are one record, staged once; its
  `.sid` is the row loaded from its highest version.
- **The apps resend a haul under a new number:** 7,911 unloaded copies have the vessel, date, gear section and a sent
  time of a loaded record, mostly its position and depth too. They are kept with it, never staged.

Every sent copy (1,444,695) in one outcome: loaded and staged 1,302,401; loaded, a newer version staged 14,978;
loaded, the same version staged from another message 909; the same version in another message 98,973; never loaded
14,759 (staged with `loaded` false: 13,990 have no loaded record of the vessel that day); the same haul under another
VISIR 7,911; older version 4,213; test message 454; repeated in its message 92; newer than the loaded one (staged) 5.
The 1,318,288 loaded copies and the key forms equal the map's; 23,404 copies are classed otherwise than in the map,
each for a listed reason (number reuse, resends under another number, the receipt's missing vessel, the map's
per-copy counting of unloaded records). `rafr_stofn`'s 1,318,780 rows: 1,302,406 are a staged record's `.sid`, 15,916
another row of one, 458 (2010-2011) are not found in their message. The edited layer's 1,275,274 electronic stations:
1,273,587 are a staged record's `.sid`; 549 another row of one (on 434 of them the edited layer holds the record's
`.sid` too, a duplicate there; on 115 it kept an older row than the latest version's); 692 have no `rafr_stofn` row;
446 a row whose message holds no record with its keys. Of the 1,302,406 staged records Oracle loaded, 28,704 have no
row in the edited layer: 26,695 in afli's `rafr_stofn` never moved to afli.stofn (3,182 deleted, 23,513 not, the
latter unexplained here) and 2,009 in fs_afli's `rafr_stofn` only.

The paper logbook has one layer only (`afli.*`, with `afli.mottaka`, 509,774 rows, a register of when the paper books
came in), and its in-house edits are unmarked.

## 3. The other elements

### 3.1 Elements with a sent version, dumped

| Element (grammar) | Sent layer | Later layers | Read today |
|---|---|---|---|
| fs_afladagbok 2020-2025 (trip, station, sample, observation) | its forms by the Taktikal route (`takt_json_form`, 6,912, JSON and a file); Trackwell's own messages are not in Oracle | `ws_*` (the system of record) and its change tables (`ws_*_breytingar`), then adb, derived in part: of the 368 adb trips decision 160 removed, 27 are copies of afli or fs_afladagbok trips, but 340 are adb's own (321 app trips, 320 of them with no catch; 19 with catch: Trackwell books, vendor trials, one paper logbook), from an entry route not dumped (decision 160, traced) | `ws_*` |
| Foreign ERS reports 2014-2018 | `dw.dw_aflaskeyti` | none dumped | yes (plan 026) |
| Landing confirmations (declarations ashore) | in the logbook messages (`LONDUN`) | none | no |
| Landings (declarations ashore) | the weighings: `ask` (weighing notes, 2007/08 to 2020-07-22), `agf` continuing its ids; `LODS` before 2007 | the landing totals, kvoti's and dw's copies | the landings (plans 007, 023, 025; plan 036 on the disposition) |
| The track (stream) | STK reports and the AIS feeds; the logger's NMEA sentences (`GPS_DATA`) | stk's views of the whole trail; the logger track as the app decoded it | the trail |
| Vessels | Samgöngustofa's register (PDFs), the live register | `ufs`/`vessel` tables, owners (decision 159) | plan 028 |
| Real-time closures | the scientists' XML documents, `uv.skyndilokanir_xml_input` (1,694) | `uv.veidisvaedi` (5,948) and `hnit` | no |
| Licences | the letters' text, `kvoti.veidileyfi_textar` | kvoti's licence tables | plan 029 |

The e-mails (`ra_email_skeyti`, 137,391 and 168,725) hold no logbook XML in their bodies; their attachments are not
examined.

### 3.2 Dumped but failed or left out

- Four views fail with `ORA-01843: not a valid month`: `afli.urv_raekja` (a shrimp fishery view with per-species
  catch), `afli.rafr_mottaka_view` (the messages as a CLOB; its table is dumped), `kvoti.hld1` (quota holdings) and
  `kvoti.umframafli_eftirl` (excess-catch control). The likely cause is a date the views parse in the session's
  language; a dump session with Icelandic date settings may read them (TODO 110).
- `fs_afladagbok.takt_json_form`: a CLOB with NUL characters (TODO 110).
- Deliberate skips: ask's guarded `*_sec_v` views, dw's landings copies, Oracle's own tables.

### 3.3 Dumped for this plan, and the rest

Twenty-eight of 112 schemas are dumped, six of them on 2026-10-21 (decision 162); none of the six is read yet. The
rest are judged by table names, Oracle's row estimates and comments (columns not read):

| Schema | What it holds | Warrants a dump? |
|---|---|---|
| `kvotix` | **dumped** (29 objects, 22,101,309 rows): the landings' before-images indexed by `log_lods` (2.6 M), the line-incentive history (1.7 M, its recomputation only, decision 163), the catch error checks (90,739 and 272,883), the register's change log (708,703); ends 2020-07 | yes: the in-house edits of the landings and the checks behind them, the layers above the landings that fishycode lacks |
| `vor` | **dumped** (97 objects, 176,889,601 rows): weighings, the catch's disposition (plan 036), market reports, files received, auction XML; 1982 to 2020-07, but `samantekt_a_lods` to 2026-10-19 from a source not yet known | yes: a second record of the weighings and the disposition, and the value |
| `dwstg` | **dumped** (20 tables, 69,922 rows): ERS messages as staged, 2014-01 to 2018-06, with deletes and rejected rows | yes: the layer upstream of the ERS reports fishycode reads |
| `fiskifelagid` | **dumped** (3 tables, 2,265,200 rows): registers of 1966-1981, landed catch 1982-1993 | for the history only |
| `fiskist` | **dumped** (1 table, 1,803,610 rows): `ttrail`, 731 mobile ids over 22 hours of 2008-09-22/23 | a one-off extract |
| `simalinu` | **dumped**, through RJDBC (7 tables, 275,378 rows): the line vessels' phone notifications, `tilk_linu_sokn` (263,326, 2004-2014) | the phone times of the line-incentive check (decision 163) |
| `siritar` (5 tables, 4.6 M) | temperature and Scanmar sensors, station documents: survey sensors | only for the survey tows (TODO 105) |
| `channel_log`, `biota_log`, `fresh_log` | change logs of the survey schemas | only if the surveys' edits matter |
| `veidibok`, the `ops$` schemas, the science schemas | freshwater angling, personal work, biology | no |

## 4. The design: raw, staged, curated, in the grammar's terms

- **raw/** keeps every layer as its source holds it, unchanged: the sent messages, the loaded tables, the edited
  tables, the logs.
- **staging/** gets one adapter per layer, mapping that layer alone onto the grammar: trip, station, sample and
  observation, and the streams (the track, the declarations ashore), with the grammar's names and metric units, each
  field in its field group, `station_type` for its resolution, and basis `recorded` (`derived` where computed within
  the record). An adapter reads one layer; it never chooses between layers. So `sources/afli/` stays the edited layer,
  a new `sources/afli_sent/` stages the sent layer (the latest version of each record, with the app, its version, the
  record's closing time and its key forms), and the loaded layer is staged only where it holds what neither of the
  others does. Each staged row says its layer.
- **curate/** chooses, per field group, which layer answers, by a declared precedence (a table, read by the code, not
  rules buried in it):

  | Field group (grammar) | Precedence, as measured | Evidence |
  |---|---|---|
  | Identification | the loaded ids (they key every link) | §2 |
  | Design (gear, target) | edited, then sent | gear corrected in-house on 30,026 |
  | Temporal envelope | sent = loaded (equal to the second); edited where marked; placeholders flagged on any layer | decisions 157, 158; time-offset studies |
  | Spatial envelope | sent (arc-second, the end position), unless edited | map; xml-positions draft |
  | Configuration (hooks, nets, mesh, baiting) | sent (some never loaded) | map |
  | Execution (soak, tow time) | sent (unrounded, not dropped) | map; TODO 108 |
  | Environment (water depth) | sent, after a per-vessel-period unit test on the sent value | TODO 113 notes |
  | Outcome (edited, closed, deleted) | every layer contributes: the edit flag and last change (edited), the closing time (sent) | §2 |
  | Observation (catch) | sent as logged with its state; the whole weight derived from it, basis `derived` | TODO 114 notes |
  | Declarations ashore (landings) | the weighing, then the landing total; in-house edits from the logs once dumped | plans 023, 025, 036; §3.3 |

  Each curated value records the layer that answered beside its basis. Basis keeps the grammar's five words; the
  layer is a column of its own (`*_layer`, or one provenance table keyed on station and field: §7 b).
- **The consumers' meaning is fixed in the grammar, not left to each source.** The TODO 114 notes found that `catch`
  means the whole weight for afli and the weight as logged for the other three sources, and that every consumer sums
  it. In the grammar the observation is the catch as logged with its state, and the whole weight is a derived
  measure beside it; every consumer reads the whole weight by name. Oracle's whole weight on gutted items in
  fs_afladagbok and adb is the same round(gutted × 1.25), so this applies to all three e-logbooks.

## 5. The phases

0. **Dump what is missing and warranted:** `kvotix`, `vor` and `dwstg` (with their persons' columns kept as decision
   159 says); the four failing views with Icelandic date settings; `takt_json_form` (TODO 110). Look at
   `fiskist.ttrail` before deciding. The five, `dump/oracle/{kvotix,vor,dwstg,fiskist,fiskifelagid}.R`, were
   run on the server on 2026-10-21 and adopted, with simalinu (decision 162); they are also the baseline of omar2's pilot (its plan 001, *Next*), after which the next full refresh
   may go through omar2.
1. **The grammar's precedence table and provenance column,** and the consumers reading the whole weight by name, on the
   current sources (no new layer yet): the change that makes later phases additive.
2. **afli's sent layer** (`sources/afli_sent/`), and the curated choice per field group for afli's electronic records;
   `afli_end_longitude` retires; TODO 108, 113 and 114 close here, with the TODO 113 and 114 notes' findings (decimal
   commas, the three key forms, the per-vessel unit test, the catch semantics). The in-house edits are scored as
   labels against the automatic checks that would have caught them.
3. **The landings' layers:** the weighings over the totals where they differ, the in-house edits from `kvotix`, the
   disposition from `vor` and plan 036.
4. **fs_afladagbok's forms and change tables, the ERS staging, the closures, the licences** (plans 028, 029 for the
   last two).

## 6. What is measured before each phase is built

The pass is that everything is accounted for (§1), not a rate.

- The new staged layer against the layer below, field by field, every record in one outcome, each difference
  classed: unit, precision, defect, resend, in-house edit.
- A scratch build of the merge against the built tables: which columns change, on which rows. The flow reads times
  and catch, not positions or depth, so the effort and catch on the fixes move only where a time or a catch moves.
- The rebuild, fingerprinted before and after, as for decisions 158 and 160, and **the catch accounted for kilogram
  by kilogram**: the catch shared onto the fixes, per catch unit and approach, before and after, every unit in one
  outcome (unchanged, moved, new, gone) and the total's change decomposed into them. Decision 160's rebuild moved
  253 t no prediction had foreseen; its trace (`$FISHYDATA/archive/2026-10-catch-253t/`, a scratch store rebuilt as
  before, the rise reproduced to the kilogram) is the method.
- **Where a removed or replaced source's records came from:** when a layer is dropped or demoted (as adb before
  2025-11-19 was, decision 160), its records are traced to the upstream layer they were derived from, one outcome
  each (found, and how they differ there; or found in no dumped schema). Records found nowhere mean the layer has an
  upstream not yet dumped.

## 7. Asks

Answered by the maintainer on 2026-10-21: a (the principle, taken as stated), b (a column per field group), c (below)
and e (`catch` as logged everywhere). d by the run of 2026-10-21 (decision 162; the failing views and `takt_json_form`
stay with TODO 110). Open: f, g, h, i.

**c, in the maintainer's words:** where the expert edited, the expert wins; "but we want also to learn how / why he
won (landings data, ...) ... because if we know, we have added to our own domain knowledge. and that is important to
know, because once [he] retired, it got lost." So the edits are not only taken: each is explained from the evidence
that most likely led to it (the landing's date, port and gear; the track; the vessel's other records), the reasons
classed and counted, and each class turned into a check of fishycode's own, scored on how many of the expert's edits
it would have made. The years after the corrections end (records of 2018) are the years nobody corrected: those checks are
what stands in for him there.

The domain-expert group is one account, which the maintainer knows and Claude is not to know (2026-10-21: "only
ops$XXX counts - i know, but you are not allowed to know"). The scripts read it from `FISHYDATA_EXPERT_ACCOUNT`, set by
the maintainer in the project's git-ignored `.Renviron`, and never print it. Since afli keeps no editor, its edits are
found only on the rows that account last changed: a lower bound. The other accounts' edits are not presumed an
expert's: they are classed and judged by their evidence like any other difference between the layers.

a. The principle of §1, with its two qualifications, as AGENTS.md's rule.
b. The layer recorded as a column per field group, or as one provenance table (station, field, layer, basis, reason).
c. The precedence table of §4 as a starting point, field group by field group; in particular whether an in-house edit
   always wins, or only where its evidence is known.
d. Phase 0: dump `kvotix`, `vor` and `dwstg`; look at `fiskist.ttrail`; leave the rest.
e. `catch` as the weight as logged in every source, the whole weight by name for every consumer (phase 1).
f. The latest version of each sent record, and the 14,267 never loaded left out or staged with a flag.
g. The paused TODO 113 and 114 work folded into phase 2, those items closed by it.
h. The TODO items of §8 linked to the plan's phases as they stand, or folded into it (closed when their phase is).
i. The sent layer's key where Oracle loaded one record as several rows (the adapter on branch
   `claude/plan037-afli-sent-1f2f63`, not merged): on 115 edited stations the edited layer holds another row than the
   staged one, 99 the same version loaded again from a later message (Oracle deleted the staged row on 87) and 16 an
   older version Oracle deleted but moved. Keep the latest version's row, the 115 reached through `record.parquet`'s
   `.sid_loaded`; or key on the one undeleted row where there is exactly one (90 keys change, 87 of the 115 then meet
   by `.sid`, none lost, 28 left to the join). Measured by Claude, not checked by a person.

## 8. The TODO items this plan touches

Not folded (each keeps its own check); listed so that a phase is built with them in view:

| Phase | Items |
|---|---|
| 0, the dumps | 110 (the dumper's open ends: `--resume`, `takt_json_form`) |
| 1, the grammar's names and dictionary | 111 (`output-schema.md`'s column tables), 51 (`data-dict.yaml` against the spec) |
| 2, afli's layers | 108, 113, 114 (folded); 70 (afli.afli's malformed stored numbers); 75 (trips and rows lost between the layers, decision 098); 79 (every source station accounted for, plan 024); 98 and 100 (the logger and the sensor readings, layers of afli too); 103 and 107 (the app-made values, whose flags the precedence reads) |
| 3, the landings | 74 (each period's source, plans 023 and 025), 81 (a catch landed over two days), 112 (plan 036, the disposition) |
| 4, the rest | 62 (foreign logbooks, through `dwstg`), 68 and 87 (stk's other tables; the reports reloaded by hand, an in-house layer of the track), 73 (fs_afladagbok's tables, plans 019 and 020), 83 and 84 (the vessels and the licences, plans 028 and 029) |
