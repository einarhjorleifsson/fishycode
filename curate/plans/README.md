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
