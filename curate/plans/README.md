# Plans — index

Forward-looking design. A plan is written **before** the work, describes something
that does not exist yet, and states plainly what is proposal and what is measured.

This slot exists because the alternative is worse: a multi-page design living inside
a `TODO.md` item, which is how that file reached 600 lines. `TODO.md` holds *what is
open*, one item to a few paragraphs. When an item needs sections, tables and its own
evidence, it is a plan and belongs here, with a one-line stub in `TODO.md` pointing at
it. The convention is borrowed from `~/R/Pakkar/obus`, whose `PLAN-qc-checks.md` is
the worked example.

**A plan is not a decision record.** It describes what is *intended*; a record in
`../decisions/` describes what was *chosen or found*, after the fact. When a plan is
executed it does not migrate — it stays here as the design, and the decision record
says what actually happened. When a plan is abandoned, say so in its header and keep
it; the reasoning is the value.

**Header contract.** Every plan opens with a status line naming its state
(`proposal` / `partly built` / `executed` / `abandoned`), the date, and — this is the
part that matters — which claims are **measured** and which are **assumed**. A plan
that does not separate those is a wish.

**Invariant:** every `.md` in this directory has a row here. Checked by
`check_bookkeeping()`.

| # | plan | status | what it proposes |
|---|---|---|---|
| 001 | [three-repo publication boundary](001-three-repo-publication-boundary.md) | proposal — nothing built | what `fishycode`, `fishydata` and `fishyweb` each publish, and the disclosure rule the split forces |
| 002 | [the last mile](002-the-last-mile.md) | proposal — nothing built | the enrichment and consumer-shaped tables that stand between the curated pings and a sweep an analyst can filter; discharges the code half of `TODO.md` item 16 |
| 003 | [STK vessel identity](003-stk-vessel-identity.md) | partly built — steps 1–4 done, 5 partly | why the STK match assigns a vid to 62% of pings and an MMSI to 60%, the six defects behind that, and the identity model that would fix them; carries `TODO.md` item 17 |
| 004 | [behavioural fishing windows](004-behavioural-fishing-windows.md) | proposal — nothing built | infer each station's fishing window from the logger's own speed and heading — measurements independent of the AIS match — instead of from logbook times that 7,336 stations a year do not record at all |
| 005 | [recover the dropped afli stations](005-recover-the-dropped-afli-stations.md) | **parked** — step 1 measured, nothing queued | recover 23,570 lost logbook stations on AIS corroboration rather than on an explanation that will never come; 98.3% of them place the vessel at sea against a 99.6% control |
| 006 | [trip identity across systems, and splitting catch onto AIS pings](006-trip-identity-and-catch-to-ais-pings.md) | proposal — nothing built | `.tid` → `.tid_land` for landings (mirrors 028); names the three trip-identifier shapes (logbook/landings synthetic columns, AIS's composite `(vid,year,trip)`); flags a design disagreement between `grammar.qmd`'s `w1`/`w2` and plan 002's raw-`t1`..`t4`-plus-speed-filter approach to joining catch onto pings, and that no document specifies the actual catch-allocation formula |
| 007 | [merging agf and lods into one landings source](007-landings-merge-agf-lods.md) | executed — steps 1–6 done, decision record due | `agf`/`lods` are one landings database's two systems; precedence merge recovers 1992-2007 history; renames `.tid_land`→`.lid`; found and fixed `lods`'s raw id (`komunr`) recycling across unrelated trips |
| 008 | [a north-Atlantic vessel registry](008-north-atlantic-vessel-registry.md) | partly built — §7 Phases 1–3 done (raw data landed, four adapters built, merged into `vessel_identity_foreign.parquet` + conflicts check; decisions 035–036), Phase 4 onward still proposal | a **separate**, foreign-external-id-keyed table (EU/FRO/NOR/GFW, plus two hand-built MarineTraffic match sheets and an ASTD-derived non-fishing table), built as `vessel_identity.parquet`'s own shape generalized from `vid` to `external_id` — confirmed IMO wherever EU's `UVI` is populated, every value passing the check-digit algorithm; deliberately kept broader than STK-matching needs since that is this registry's first consumer inside `fishy***`, not its only reason to exist; §7 lays out adapters, a single merge script, a generalized (not duplicated) `R/vid_match.R`, a separate candidate-matching script rather than growing `ais_key.R` further, and flags (TODO item 22) that the trip construct itself — `sources/stk/convert.R`, `ais_ping_union.R`, `ais_trip.R` — is hardcoded to Icelandic `vid` and drops a foreign vessel's pings before this plan's identity work could ever reach them, even though `ports_all`'s 24,653 harbours are already global |
