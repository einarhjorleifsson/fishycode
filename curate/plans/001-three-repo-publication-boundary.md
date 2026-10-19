# 001 — the three-repo publication boundary

**Status:** proposal — §4 done (fishycode public since 2026-10-16); §3 answered (decision 118, and plan 033's ask c
on 2026-10-19: rendered figures and tables may be published, data files may not); §5 answered but for where
`fishydata` lives and its backup, which waits on the maintainer (TODO 15). `fishyweb`'s role passes to the book of
plan 033. **Drafted:** 2026-09-22, from the maintainer's statement of intent.

**Measured vs assumed.** The repository facts below — remote state, commit counts, the
token, the absence of Oracle credentials in tracked code — were checked on 2026-09-22
and are measured. Everything about what *should* be published is proposal. The
disclosure-control claim in §3 is reasoning from the data's content, not from any legal
text that has been read; it needs a competent human check before it binds anything.

## 1. The intent

| repo | home | audience |
|---|---|---|
| `fishycode` | public GitHub | anyone. Scripts only, never data |
| `fishydata` | institute space — local disk or cloud. **Never public** | the maintainer, colleagues |
| `fishyweb` | open web page | anyone |

Data flows `fishycode` → `fishydata` → `fishyweb`. **Learning flows the other way:**
what is found writing a `fishyweb` article feeds back to `fishycode`, which changes
`fishydata`. That reversal is the reason to think about the boundaries now rather than
at first publication.

## 2. A public `fishycode` is a provenance record, not a runnable pipeline

Whoever clones it cannot run it, for reasons that compound:

- `fishydata` is private, and `dump/` needs Oracle credentials and the institute network.
- Several inputs are not regenerable **even here**: the GEBCO raster
  (`../decisions/002-missing-gebco-raster.md`), the frozen harbour geometry
  (`../decisions/005-harbour-geometry-is-a-frozen-input.md`), the undeclared `dump/`
  inputs (`../decisions/003-undeclared-dump-inputs.md`), and the two astd months that
  are DEFLATE64 and unreadable from R (`TODO.md` item 14).

This is a legitimate thing to publish — it says how the artefact was made — but the
README has to say so, or every visitor opens an issue asking why `tar_make()` fails.

**These are also exactly where the feedback loop breaks.** A `fishyweb` finding that
implicates a frozen input has nowhere to land: the code that would express the fix
cannot rebuild the thing it fixes. Worth knowing before relying on the loop.

## 3. The boundary with teeth is `fishydata` → `fishyweb`

`fishycode` going public is a *code* disclosure question, and a small one. The open web
page reading a private, vessel-identifying archive is a *data* disclosure question, and
nothing currently decides it.

`curated/logbook/trip.parquet` is 1.8 M rows keyed to individual vessels. Fine-grained
maps of trawl footprints can identify a named vessel's fishing grounds, which is
commercially sensitive and in places legally restricted. **No rule currently states what
aggregation level may leave `fishydata`.**

This binds work that already exists: `TODO.md` item 16 inventories 22 written `ramb/`
posts in the pulled `fishyweb` repo, 17 of which read data. They were written when
everything was internal. If `fishyweb` becomes open, their disposition is not
port/archive/drop — it is **disclosure review, then** port/archive/drop.

**Proposed, not decided:** a single declared rule — minimum vessels per aggregate,
minimum spatial cell, and an explicit allowlist of publishable curated tables — living
in `fishycode` and enforced by a function, on the same principle as
`AGENTS.md`'s "prefer enforcement over instruction". Whether that rule is right is for
the maintainer and the institute, not for this file.

**Answered in part (maintainer, confirmed 2026-10-17; first said 2026-10-02):** the three-vessel rule applies only
to the ICES VMS datacall, where the delivery lists the vessels of each cell (`AnonymizedVesselID`) and ICES applies
it. No minimum vessel count applies anywhere else, `fishyweb` included. Still open: the minimum spatial cell, and the
allowlist of tables that may leave `fishydata`.

**Answered (maintainer, 2026-10-19, plan 033 ask c).** The open web page is now the book of plan 033, which takes over
`fishyweb`'s pages. All of it may be public "as long as no data goes with it":

- rendered figures and tables from the data may be published;
- no data file may, so the allowlist of tables is empty;
- an interactive widget counts as data, since it writes its points into the page, so vessel-level data are shown as
  static figures;
- no personal data, as `AGENTS.md` already rules.

No minimum spatial cell is set for rendered figures (Claude's reading of the answer, which shows vessel-level
figures). The book's `check_book()` enforces the file and widget rules (plan 033 §10).

## 4. Before the first push to a public remote

Measured 2026-09-22:

- **There is no git remote yet.** 59 commits, 3.1 MB of history, entirely local.
  History rewriting is free now and disruptive after the first push.
  *2026-10-15: a private remote went up, so the server can clone the dumper (decision 109):
  `github.com/einarhjorleifsson/fishycode`, created private and empty by the maintainer, `main` pushed
  at 1a959ae (414 commits). Nothing is public. History can still be rewritten before it goes public, at
  the cost of a force-push and a fresh clone wherever it was cloned. 2026-10-16: the maintainer deleted that
  repo, revoked the Mapbox token, and recreated the repo **public**; `main` was pushed with its history as it
  was, not rewritten.*
- **A Mapbox token is committed**, in `curate/ais_trip.R:179`,
  `reference/geo/h3_index.R:82` and `docs/stk_data-inspection.qmd:10`, entering at
  commit `bde740b`. It is a `pk.` *public* token — designed for client-side use, so not
  a secret leak — but it is scoped to the `fishvice` account and unrestricted. Either
  URL-restrict it at Mapbox or move it to `Sys.getenv()`.
  *2026-10-16: moved out of the working tree (the maintainer's go). The three files no longer set it:
  mapdeck reads any environment variable named like `MAPBOX_TOKEN`, kept in `~/.Renviron`. It stays in the
  history from `bde740b`. Recommended (Claude): revoke it at Mapbox and make a new one, rather than rewrite
  the history, since the curated files' `fd.commit` stamps and the decision records cite commit ids. A
  history scan the same day found no other secret, no ID numbers and no data files beyond `overrides/`.*
- **No Oracle credentials in tracked code.** `dump/` obtains them externally. Checked,
  not assumed.
- `.gitignore` already excludes every data extension and `.Renviron`; no data file
  appears anywhere in history.

## 5. Open questions

- Where does `fishydata` actually live once it leaves this laptop, and does that home
  have a backup story? 404 GB.
- Does `fishyweb` read `fishydata` directly, or only pre-rendered extracts committed to
  it? The answer determines whether the disclosure rule is enforced once at export or
  on every page build.
  *Answered by plan 033 (asks a and c, 2026-10-19): the book lives in `fishycode/docs`, renders on this machine
  from `$FISHYDATA`, and only the rendered pages are published, so the rule is enforced at every build.*
- Is `ramb` (the installed package, 62 exports) public? It sits between all three.
  *Yes: `github.com/einarhjorleifsson/ramb` is public (checked 2026-10-19).*
