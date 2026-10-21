# 037 — The most upstream source, value by value: layers from raw to curated, in the grammar's terms

**status:** proposal — written 2026-10-21, scoped the same evening; nothing built; TODO 113 and 114 paused for it;
asks in §7, the TODO items it touches in §8 · **2026-10-21** · **see:** `docs/grammar.qmd` (the grammar of sea-going observational data), TODO 108,
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
defect is measured; that a value changed in-house after loading was changed on purpose; that the undumped schemas of
§3.3 hold what their table names and Oracle's comments say (their columns were not read: Oracle did not answer on the
evening of 2026-10-21).

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

## 2. The layers, measured for afli's electronic logbook

afli's electronic logbook passes through three layers, each of which adds or loses something:

| Layer | Where | Adds | Loses or alters |
|---|---|---|---|
| **sent** | `fs_afli.afladagb_xml_mottaka` (565,192 messages, 1.44 M records; a superset of `afli`'s copy by 81,454 messages after 2020-07-28) | everything the app sent: positions to the arc-second, the end position (`POS_END`), depths, catch as logged with its state (`SLAEGT`), soak hours and nights, tow time, hooks and baiting, when the record was closed, the landing confirmation, the app and its version | the app's own defects (above) |
| **loaded** | `rafr_stofn`, `rafr_lineha`, `rafr_toga`, `rafr_afli`, `rafr_sjalfvirkir_maelar` | the record id, the load | positions to the minute, the end position never loaded, the start depth converted to fathoms and the end left in metres, the end longitude overwritten by the latitude (2010-2012), the soak rounded up, the catch's logged weight and state on only part of the rows |
| **edited / moved** | `afli.stofn`, `lineha`, `toga`, `afli` | in-house corrections: another gear on 30,026 records, another landing date or port on 101,087; the flag `breytt_eftir_lokun` on 166,538 of 1,275,274 electronic stations (13 %); `fs_afli.afladagbok_sidast_breytt` times each record's last change; the statistical rectangle computed where missing | the Danish seine's tow time dropped (105,879), the depth divided by 1.8288 a second time (11,956), the soak rounded a second time (13,637 and 6,104), the catch's logged weight and state not moved |

**Who edited.** `rafr_stofn` names the account that last changed each record (`sbg`, `sbt`). Of the 166,538 records
marked edited after closing, one account made 125,381 (75 %), 2008-2023, and three accounts nearly all the rest; the two
busiest accounts overall made no marked edit (most likely the loading). The maintainer (2026-10-21): the person behind
it had a deep knowledge of the fishery and checked the data the old way, by comparing sources and asking the captains.
So the in-house edits are an expert's corrections with evidence behind them: they win where they apply, and they are
labels, a set of records an expert judged wrong and put right, against which an automatic check (gear from the
landing, the trip-to-landing match on dates and ports, the station's place) can be scored. Accounts were counted, not
named.

Resends are rare and in-house edits common. Of the 1.44 M sent records, 91.3 % were loaded as sent; 4,598 (0.3 %)
are older versions of a record sent again; 107,189 the same version sent again in another message; 14,267 never
loaded (most with no readable record id); 257 test messages. A record is found in its message by three forms of its
id (as sent, negated, and −(1,000,000 + id)); the end-longitude correction of decision 158 knows only the first, and
its pattern misses records spanning lines.

The paper logbook has one layer only (`afli.*`, with `afli.mottaka`, 509,774 rows, a register of when the paper books
came in), and its in-house edits are unmarked.

## 3. The other elements

### 3.1 Elements with a sent version, dumped

| Element (grammar) | Sent layer | Later layers | Read today |
|---|---|---|---|
| fs_afladagbok 2020-2025 (trip, station, sample, observation) | its forms by the Taktikal route (`takt_json_form`, 6,912, JSON and a file); Trackwell's own messages are not in Oracle | `ws_*` (the system of record) and its change tables (`ws_*_breytingar`), then adb (derived, decision 160) | `ws_*` |
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

### 3.3 Not dumped, and whether it seems to warrant it

Twenty-two of 112 schemas are dumped. Of the rest, by table names, Oracle's row estimates and comments (columns not
read):

| Schema | What it seems to hold | Warrants a dump? |
|---|---|---|
| `kvotix` (28 tables, 22 M rows) | logs of the landings' changes (`log_lods`, 2.6 M, master of `log_lods2_londun` and others), landing notifications (`log_ivln_tilkynning_londun`, 1.7 M), the catch error checks (`kvoti_afli_villutekk`, 90,739, and detail 272,883), quota-status history (13.9 M), vessel-history log (708,703) | **yes**: the in-house edits of the landings, the error checks behind them and the notifications are the layers above the landings that fishycode lacks |
| `vor` (46 tables, 24.6 M) | weighings (`vigt` 4.0 M, `vigt_linur` 12.9 M), the catch's disposition (`radstafanir` 143,798, lines 1.4 M), resale, market reports (`mark_skyrslur` 5.7 M), fish-market auction data (`rsf_markadur`, `rsf_markadur_xml`), LODS summaries | **yes**: a second record of the weighings and the disposition (plan 036), and the value |
| `dwstg` (20 tables, 70 k) | the staging behind `dw_aflaskeyti`: ERS hauls, logs and species, their error tables, port notifications | **yes**: the layer upstream of the ERS reports fishycode reads, with what was rejected |
| `fiskifelagid` (3 tables, 2.3 M) | the weighing and disposition registers of 1966-1981, landed catch before 1994 | for the history only (before the AIS) |
| `fiskist` (1 table, 1.8 M) | `ttrail`: a track of some kind | look first |
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
  | Design (gear, target) | edited, then sent | gear corrected in-house on 30,026, three quarters of the edits by one expert |
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
   `fiskist.ttrail` before deciding. The scripts are prepared (2026-10-21, not run): `dump/oracle/{kvotix,vor,dwstg,
   fiskist,fiskifelagid}.R`, in the run order of `R/run_dump.R`.
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

- The new staged layer against the layer below, field by field, every record in one outcome, each difference
  classed: unit, precision, defect, resend, in-house edit.
- A scratch build of the merge against the built tables: which columns change, on which rows. The flow reads times
  and catch, not positions or depth, so the effort and catch on the fixes move only where a time or a catch moves.
- The rebuild, fingerprinted before and after, as for decisions 158 and 160.

## 7. Asks

a. The principle of §1, with its two qualifications, as AGENTS.md's rule.
b. The layer recorded as a column per field group, or as one provenance table (station, field, layer, basis, reason).
c. The precedence table of §4 as a starting point, field group by field group; in particular whether an in-house edit
   always wins, or only where its evidence is known.
d. Phase 0: dump `kvotix`, `vor` and `dwstg`; look at `fiskist.ttrail`; leave the rest.
e. `catch` as the weight as logged in every source, the whole weight by name for every consumer (phase 1).
f. The latest version of each sent record, and the 14,267 never loaded left out or staged with a flag.
g. The paused TODO 113 and 114 work folded into phase 2, those items closed by it.
h. The TODO items of §8 linked to the plan's phases as they stand, or folded into it (closed when their phase is).

## 8. The TODO items this plan touches

Not folded (each keeps its own check); listed so that a phase is built with them in view:

| Phase | Items |
|---|---|
| 0, the dumps | 110 (the dumper's open ends: `--resume`, `takt_json_form`) |
| 1, the grammar's names and dictionary | 111 (`output-schema.md`'s column tables), 51 (`data-dict.yaml` against the spec) |
| 2, afli's layers | 108, 113, 114 (folded); 70 (afli.afli's malformed stored numbers); 75 (trips and rows lost between the layers, decision 098); 79 (every source station accounted for, plan 024); 98 and 100 (the logger and the sensor readings, layers of afli too); 103 and 107 (the app-made values, whose flags the precedence reads) |
| 3, the landings | 74 (each period's source, plans 023 and 025), 81 (a catch landed over two days), 112 (plan 036, the disposition) |
| 4, the rest | 62 (foreign logbooks, through `dwstg`), 68 and 87 (stk's other tables; the reports reloaded by hand, an in-house layer of the track), 73 (fs_afladagbok's tables, plans 019 and 020), 83 and 84 (the vessels and the licences, plans 028 and 029) |
