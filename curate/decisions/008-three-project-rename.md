# 008 — the three-project rename: `_data` → `fishydata`, `fishydata` → `fishycode`

*2026-09-22. Executed and verified in one sitting. Closes `TODO.md` item 15,
which is deleted from there now it is done and recorded here.*

The names are one generation behind the structure. `_data` holds the artefact other
people would want; `fishydata` holds the machinery that builds it; there is no name at
all for a reading surface, because none exists. The rename, as executed:

| now | should be | what it is |
|---|---|---|
| `~/stasi/_data` (404 GB) | `~/stasi/fishydata` | the artefact |
| `~/stasi/fishydata` (5 MB) | `~/stasi/fishycode` | the machinery |
| — | `fishyweb` | a way to read the artefact without R. Does not exist. |

**Cheap in the code.** The data root is hard-coded in exactly one place —
`.Renviron:1: FISHYDATA=/Users/einarhj/stasi/_data`. Everything else goes through
`fd_raw()` / `fd_staging()` / `fd_curated()`. The env var is *already* named
`FISHYDATA`, which is the argument for the rename in miniature. Same filesystem, so
the 404 GB move is a rename, not a copy.

**Expensive if done in the wrong order, or half-done.** Four hazards, none of which
error loudly — all four were designed around in the script, none fired:

- `mv _data fishydata` with the target occupied does not refuse — it nests, putting
  404 GB *inside* the 5 MB repo, where `.gitignore` does not cover it. Rename the code
  repo out of the way first.
- Claude Desktop keys memory and session history by cwd path:
  `~/.claude/projects/-Users-einarhj-stasi-fishydata/` holds `memory/` (MEMORY.md plus
  3 files) and 4 session transcripts. Renaming the repo orphans them; renaming `_data`
  to `fishydata` then points the *data tree* at them, so a data-tree session silently
  inherits the pipeline's memory. Move the key in the same sitting.
- `fishydata_2024-2026` contains its own `fishydata.Rproj`, so three directories
  currently answer to the name. The `fishycode` half is what actually buys clarity.
- Renaming a directory out from under an open R session or Claude session strands it.
  Do it with both closed.

**Sequence:**
```
cd ~/stasi && mv fishydata fishycode && mv _data fishydata
mv ~/.claude/projects/-Users-einarhj-stasi-fishydata \
   ~/.claude/projects/-Users-einarhj-stasi-fishycode
# then .Renviron: FISHYDATA=/Users/einarhj/stasi/fishydata
```
`.Renviron` lives inside the repo, so it travels with the rename.

**Not verified:** whether `~/.claude.json` also holds per-project state keyed by
absolute path (permissions, history). Check before the move, not after.

**check:** `grep -rn 'stasi/_data' ~/stasi/fishycode` returns nothing (plain `_data`
is useless as a pattern — it matches `open_dataset`/`write_dataset` everywhere), and
`.Renviron` must be grepped BY NAME: recursive grep in this shell skips dotfiles, so a
clean recursive sweep does not mean the one real reference is gone;
`Rscript -e 'Sys.getenv("FISHYDATA")'` resolves to an existing directory and
`fd_curated("logbook", "trip.parquet")` opens; `~/.claude/projects/` has a
`-Users-einarhj-stasi-fishycode` key carrying the old `memory/`; no directory under
`~/stasi/` other than the data tree answers to `fishydata`.

**Why it waited.** Payoff is legibility, not function, and doing it mid-thread makes
every path in `TODO.md` and in recent commit messages stale. It was held for a quiet
point, and taken at one.

**Done 2026-09-22**, by `~/stasi/rename-fishy.sh` run from Terminal with Claude Desktop
and R both quit. The script did the preflight the hazard list asks for — refusing if
Claude is running, if `fishycode` or the new Claude key already exists, if the repo is
dirty, or if an R process is alive — then moved the code repo out of the way *before*
moving the 404 GB tree onto its name.

Checks run afterwards, not asserted:

- `.Renviron:1` reads `FISHYDATA=/Users/einarhj/stasi/fishydata`, grepped by name.
- `Rscript -e 'Sys.getenv("FISHYDATA")'` resolves, and `dir.exists()` on it is `TRUE`.
- `fd_curated("logbook", "trip.parquet")` opens: 1,815,425 rows × 12 cols. The path
  indirection survived the rename, which is the only thing that could have broken.
- `grep -rn 'stasi/_data'` over the repo returns hits only in prose describing the
  rename itself. No code reference survives.
- `~/.claude/projects/-Users-einarhj-stasi-fishycode/memory/` carries the old
  `MEMORY.md` plus its three files; the `-…-fishydata` key is gone, so the data tree
  cannot inherit the pipeline's memory.
- `fishydata.Rproj` → `fishycode.Rproj` (untracked and gitignored, so the rename is
  local only). `fishydata_2024-2026/fishydata.Rproj` still carries the old name; it is
  an archive and nothing opens it, so it was left alone.

**The one thing the plan did not predict.** `~/.claude.json` *does* hold per-project
state keyed by absolute path — the "not verified" note above was the right worry. The
script moved the key correctly, but a second key for `/Users/einarhj/stasi/fishydata`
reappeared afterwards when the data tree was opened. It carries only
`hasTrustDialogAccepted: true` — no history, no memory, no permissions — so it is inert
and was left in place. The pre-rename backup is at `~/.claude.json.pre-rename.1790066886`,
which confirms only one key existed before.

