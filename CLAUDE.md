@AGENTS.md

**This file is a loader, not a second `AGENTS.md`.** It holds no facts and must not
acquire any — everything true about this project lives in `AGENTS.md`, which the line
above imports. Two files stating the same fact is how the record drifts.

It exists because `AGENTS.md` being read at the start of every session is an
*assumption* the whole record layer rests on (see `TODO.md` item 15b), and `CLAUDE.md`
is the filename this harness is documented to load. If the import does not fire, the
sentence below still does the job:

**Read `AGENTS.md` before anything else. It is the map** — what is true now, where each
kind of thing is written down, and what to read before touching a given area. Then run
`check_bookkeeping()` before you commit.

Enforced by `check_bookkeeping()`: this file must exist, must carry the import on its
first line, and must stay short.
