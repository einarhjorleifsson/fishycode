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
