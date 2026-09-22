# 009 — `CLAUDE.md` exists, as a loader for `AGENTS.md` and nothing else

*2026-09-22; the open question it left was answered the same day — see "Verified" below.
Refines the rule in `000-restructuring.md:295` — "Keep the `AGENTS.md`
convention; do not switch to `CLAUDE.md`" — which stands. Nothing switched.*

## The decision

`AGENTS.md` remains the map and the only place project facts are written. A
`CLAUDE.md` is added whose entire content is `@AGENTS.md`, plus the instruction to
read it and a note saying the file must never acquire facts of its own.

## Why, given 000 said not to

000's rule was about **where the content lives**, and that is unchanged — every fact
is still in `AGENTS.md`, and every reference in this repo still names `AGENTS.md`.
What 000 did not address is **whether the harness loads it**.

The whole record layer assumes `AGENTS.md` reaches every session without being asked
for. That assumption was never tested, and on 2026-09-22 the only context that could be
confirmed as injected was Claude memory's `MEMORY.md`. `CLAUDE.md` is the filename the
harness is documented to load, so importing from there makes the assumption true by
construction instead of by hope.

**Verified 2026-09-22, the same day.** The test item 15b specified was run in a fresh
session: the maintainer asked *"why does `R/` hold function definitions only?"* and the
answer came back from the map — the `tar_source("R/")` rule and the `R/oracle.R`
incident, both quoted, with no read of `AGENTS.md` to find them. **The map arrives.**

Two things the test could not separate, recorded so the next person does not over-read
the result:

- **Which mechanism fired is still unknown.** Both `AGENTS.md` and `CLAUDE.md` were
  injected as project instructions, so the test proves the pair works, not that either
  works alone. That is the outcome this record was designed for — it no longer matters
  which one carries it — but if one is ever removed, the test must be re-run.
- **The map arriving is not the same as it being used promptly.** In the same session
  the question was asked mid-turn and went unanswered until it was asked a second time.
  That is an attention failure, not a loading failure, and no file arrangement fixes
  it. Worth knowing that a loaded map can still be walked past.

## The hazard, and what guards it

A loader that accretes facts becomes a second `AGENTS.md`, and two files stating the
same thing is precisely the drift this layer exists to prevent. `check_bookkeeping()`
therefore fails if `CLAUDE.md` is missing, if its first line is not the import, or if
it grows past 25 lines. Verified against all three breakages, not merely observed to
pass.

## Cost

One more file at the repo root, and a rule that only a check remembers. Accepted: the
alternative is the map reaching a session by luck.
