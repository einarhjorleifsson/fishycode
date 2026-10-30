# 055 — The grammar in two views: what a source records, and what the analyst's tables carry

**status:** proposal — written 2026-10-30 at the maintainer's request, after a day's discussion of where aggregated data
belong; its evidence measured read-only the same day in two studies; nothing built; asks a-h (§9) open (TODO 171) ·
**2026-10-30** · **see:** `docs/grammar.qmd`, `docs/grammar_logbooks.qmd`, `docs/one_flow.qmd`, decision 266 (the
records-and-factors table, tested and set aside), decisions 084, 215 and 261, plans 039 and 041, TODOs 123, 127, 136,
140 and 172, `$FISHYDATA/archive/2026-10-30-records-and-statistics/`,
`$FISHYDATA/archive/2026-10-30-nephrops-shrimp-factors/`

Drafted with AI assistance (Claude) on 2026-10-30. The structure and the rules' wording are Claude's; the aim, the
census of the Icelandic track and the verdict on the factor table are the maintainer's. No person has checked the
numbers.

**Measured** (by Claude, read-only): every number below, in the two archives' logs (decision 266 lists them).
**Assumed:**
- that ICES's `landings` are tonnes (as the fiskifelagid study read them);
- that the register's `skip_nr` 1-9999, vor's `skip` and afli's `skipnr` are vids;
- that the fleet's Nephrops of 1960-72 were made by someone from the landings and a key we do not know (§1).

## 0. Where this stands

- **The question** (the maintainer, 2026-10-30): should afli's monthly summaries have been in afli to begin with, and
  does the design need revisiting, since there are also annual catch statistics by FAO area?
- **The aim** (the maintainer, 2026-10-30): tables an analyst can use without knowing the pipeline. A biologist
  interested only in his species wants a quick answer, and the product should be robust enough to keep him from going
  wrong. The ICES datacall is a side product.
- **The day's path:** records against statistics, kept apart; then one cascade from ICES's year × country × area down
  to the fixes; then the maintainer's proposal of one long table of records with factors. That was tested on Nephrops
  and shrimp from 1936 to now: exact as bookkeeping, wrong as an analyst's table, and set aside (decision 266).
- **The grammar today** (825 lines, a chapter of the book) is built around the logbook's hierarchy (trip, station,
  sample) with the streams beside it. It allows aggregates "in their own table" or "as stations" without saying which
  (§ What a row covers), and prefers one table "where totals must close" (§ The coarser unit). Its `annual_aggregate`
  is "historical statistics". Decision 084 keeps afli's summaries out of the station table, read by nothing.

## 1. The evidence, in short

Decision 266 holds the list. The cases the rules (§3) rest on:
- **A sum over mixed quantities is wrong by default**: the long table's `sum(value)` was 2.7-3.0 × the landed total.
- **Partitions cross**: vor's vessel × month against `landed_catch_pre94`'s month × port × gear (1982-90); the fleet's
  Nephrops month × square against the weighing register's vessel × month (1966-72).
- **Lineage holds at a level**: ICES equals the landings within 1-3 % every year 1966-2015 (compiled from them); the
  fleet's Nephrops equal the register by year, not by month (allocated at the year, key unknown); afli's Nephrops
  summaries of 1986-99 are at or below its own hauls in 98.6 % of vessel-months (compiled from them).
- **A flagged total travels**: ICES Nephrops 2018 is 86 × the landings.
- **A census of effort is not one of catch**: catch raised by effort from logging to non-logging vessels came out above
  the landed total in 118 of 151 species-years, by up to 37 %.
- **A total has a population**: foreign vessels landed 25-92 % of the shrimp landed in Iceland from 1999; Icelandic
  shrimp from the Flemish Cap (NAFO) is outside ICES's FAO 27 statistic.
- **A filter can cut a unit**: per year, split landings differ from the year's landings by up to 262 t of shrimp
  (trips across New Year); by decade they agree to the kilogram.
- **Coverage is measurable where a witness exists**: the logbook's share of landed Nephrops was 0 in 1966-68 and
  1971-72, 0.68-0.91 in 1973-81, 0.95 or more in 2000-18; from 2008, 94-100 % of Nephrops landings have an AIS voyage
  ending within a day.

## 2. Two views

"There are two ways to think about things" (the maintainer). They are the first of the project's two committed
boundaries, source-shaped against merged-shaped (AGENTS.md), written as two parts of the grammar, joined by the link.

### 2.1 Part one: the analyst's view (merged-shaped: `curated/` and the user tables)

What the product carries, for someone who has not read part two:
- **A quantity**: logged kg (whole weight), landed kg (whole weight), a statistic, an effort measure (fishing hours,
  days at sea, trips, kW-hours, hook-days), value. Each is its own quantity: a table, or a column, holds one.
- **Over a cell**: time × place × vessel × gear × species, each dimension at its own resolution (§ What each field
  group covers), with no invented precision.
- **With its provenance**: `basis` (how we made the value), lineage (how the source made it, §4) and coverage (what
  share of the population the source holds, §4).
- **What is safe**: a sum within one quantity over filters that keep whole units; effort apart from species, so the
  zeros of "my species" are not lost; a total and its population named.

This part is also the specification of the user tables after v0 (TODO 140): one quantity per table or view, the
factors of a split applied and named, never offered as a column to multiply.

### 2.2 Part two: the builders' view (source-shaped: `staging/`)

What each source records, in its own structure: today's levels (trip, station, sample, configuration, environment,
observation), the streams, the field groups' resolution, basis and layer. Kept, with the rules of §3 added in their
sections, and the logbook's appendix (`grammar_logbooks.qmd`) as now.

### 2.3 The bridge

The link (decision 215): every fix tied to the records that may cover it, with the evidence for each link. The catch on
the fixes is derived by the user with ramb's split (decision 261), under the rules of §3.

## 3. The rules

Each is a sentence or two in a section of the grammar; the wording is a draft.

| # | rule | section | case (§1) |
|---|---|---|---|
| 1 | **One table only where its rows partition one quantity**: no row contains another, every row of one quantity (logged, landed, a statistic). Replaces "Aggregates can be kept two ways" and reconciles § The coarser unit with it. | What a row covers; The coarser unit | `sum(value)` 2.7-3.0 × |
| 2 | **Resolutions can cross.** "Finer" is per field group: one source can know the vessel and not the place, another the place and not the vessel. Then neither is the finer record; a value moves between them only by a split with a key, basis `synthesised`. | What each field group covers | vor against `landed_catch_pre94`; the fleet's Nephrops against the register |
| 3 | **A split is made within a unit**: the finest where both the whole and the key hold the quantity, else the next coarser (the landing, then the vessel-month, then the vessel-year). The unit is part of the split's basis, beside its key. | Moving a value between units | the coarse units gather the mismatches: vessel-year factors 0.03-65 |
| 4 | **The round trip holds over whole units.** A filter on the parts' time or place cuts units; the sum then reports the quantity where and when the parts are, not where the whole was recorded. | Moving a value between units | 262 t between years, 0 between decades |
| 5 | **No split from a flagged total**: the step leaves it out, as it leaves out a flagged duration ("an extreme value is flagged, not corrected"). | Moving a value between units; Basis | ICES 2018 86 × |
| 6 | **Lineage holds at a level** (§4). | Layer; a new § Lineage | ICES compiled; the fleet's Nephrops allocated at the year |
| 7 | **A census of effort is not a census of catch.** A sample raised by effort is biased by whatever makes the sampled units differ. A total comes from a census of the quantity wherever one exists. | Coverage | up to 37 % high |
| 8 | **A total has a population** (Icelandic vessels, FAO area 27). A row outside it is outside: not `none`, not 0. | Coverage; Basis | foreign shrimp, the Flemish Cap |

Two that follow: `annual_aggregate` stays a resolution of a **record** (a vessel's yearly return, as some small-scale
fleets file), and "historical statistics" become sources of their own, described by lineage and coverage (ask c). A
split may be stored as a ratio on its parts, as part two's implementation note; it is never the analyst's column.

## 4. Lineage and coverage

Two properties of a source in a period, beside resolution and basis. They describe the source, so they live with its
description: the dump's overlay (`dump/oracle/meta/<schema>.yml`, plan 040), per table and period (ask f).

- **Lineage**: `primary` (each row an observed event), `compiled` (a sum of primaries), `raised` (a sample scaled up),
  `allocated` (a total spread by someone's key), `unknown`; with its evidence (a document, a measured test, or none)
  and its level. Tested as bookkeeping, strongest first: equal cell for cell (a copy); equal after a constant factor (a
  conversion); the coarse cell the sum of the fine (compiled); coarse holding fine with a steady ratio (raised); equal
  only at a coarser level (allocated, key unknown). Agreement between sources of shared or unknown lineage is never a
  check.
- **Coverage**: the **claim** (a regulation, a rule), the **measure** (the share of units held, against a witness of
  independent lineage) and the **gap** (what no witness can show: a unit present but wrong inside). A claimed census is
  not a census until measured. The Icelandic track is a census of vessels at sea (the maintainer, 2026-10-30: nearly
  every vessel carries it, and switching it off brings a helicopter within 30 minutes), from the years the trail holds
  positions (2007 on): the witness that measures the landings' and the logbooks' coverage. Before it there is no
  witness of trips, and the landings' census stays a claim.

## 5. Small-scale fisheries

The rules matter more there than in Iceland. A small-scale fishery typically holds detailed pings for a sample of
boats, catch sampled at landing sites, and a frame survey counting boats: no census of catch.
- Rule 7 is the main risk: trackers sit on the larger or keener boats, as Iceland's logbooks sat with the vessels that
  fished harder. Here the bias is measured (up to 37 %); there it is assumed.
- Rule 2 is the normal case: the landing survey knows site × day × gear and no position; the trackers know position and
  time and no catch.
- Rule 8 names what a raised total covers (the frame survey's boats: registered, motorised, active).
- Lineage at a level, and coverage as claim, measure and gap, describe national statistics raised from samples.

**Iceland's past is a small-scale fishery whose truth is partly known**: volunteer logbooks as the detailed sample,
landings as the census. Methods for data-poor fleets can be run on it and their error measured (done criterion 3), and
ramb can carry those errors to users who cannot measure them (one-flow article, step 6).

## 6. What changes elsewhere

Nothing here needs a rebuild: each change lands where code is next written.
- **`docs/one_flow.qmd`** (note of 2026-10-30): "kg in = kg out, whatever the filter" holds over whole units (rule 4);
  the fallback units gather the mismatches, and the unit belongs in the basis (rule 3); done criterion 3, one path
  measured: catch raised by effort is up to 37 % high (rule 7).
- **Decision 084's line on aggregates** is replaced by rule 1: a summary goes into the logbook where it partitions the
  logged quantity (plan 041's design holds); the fleet's Nephrops of 1960-72 do not, being of unknown quantity (ask g).
- **Plan 039** (landings before 1992-09): its crossing tables need a declared precedence (rule 2; TODO 123).
- **ramb**: the split's unit in its basis (rule 3), no split from a flagged total (rule 5), and the bottom-up move
  documented with its measured bias (rule 7).
- **The user tables** (TODO 140): one quantity per table; the population on every landed row (rule 8); the e-logbooks'
  tow time in the column a user reads (decision 266).

## 7. Steps

1. The asks answered, and a decision record of the revision.
2. **Part one written** in `docs/grammar.qmd`, ahead of today's text; part two revised with rules 1-8 in their
   sections; § Lineage new; § Coverage rewritten as claim, measure and gap; `quarto render` clean.
3. `docs/grammar_logbooks.qmd`'s passage on aggregates and `docs/one_flow.qmd`'s three items.
4. The amendments of §6 as their owners' steps (plans 039 and 041, TODO 140, ramb), each with its own record.

## 8. What it does not do

- It builds nothing and triggers no rebuild.
- It does not design the user tables after v0 (TODO 140), stage ICES's statistic, place the fjord-square hauls (TODO
  172) or unpark plan 041.
- It does not review the grammar's names (TODO 127), beyond the words it adds: quantity, cell, lineage, coverage.

## 9. Asks

a. **Two parts**: the analyst's view first, then the builders' (recommended), or the builders' first as today?

b. **The rules** (§3): as drafted, each open to its own amendment?

c. **`annual_aggregate`**: kept as a record's resolution, the statistics described as sources (recommended), or dropped
   from `station_type`?

d. **The landed total's population**: landed in Iceland, foreign vessels included, or landed by Icelandic vessels? For
   shrimp after 2000 they differ by a factor of 2-10.

e. **ICES from 1966**: a witness only, since it is compiled from the landings (recommended), and the national total
   before 1966?

f. **Lineage and coverage**: in the dump's overlay, per table and period (recommended), or a table of their own?

g. **The fleet's Nephrops of 1960-72**: a source of unknown quantity, kept apart from the logged catch (recommended)?
   Who made them, and from what?

h. **Where it is written**: `docs/grammar.qmd` in place (recommended), or a new chapter for part one with today's text
   as part two?
