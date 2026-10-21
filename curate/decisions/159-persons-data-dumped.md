# 159 — The Oracle dumps take persons' data too: registers, staff, owners, contact details and logs

*2026-10-21. Overturns decision 121's "Left out, and why" for orri, ufs, uv and fs_afli; dw's skips stay. Run on the
server and adopted the same day (below).*

- **Who decided.** The maintainer, 2026-10-21, while a full new Oracle dump was being considered: "we take them all".
  The reasons given: what a dump writes stays on MFRI's machines (the maintainer's Mac and the server), and the
  rule of 2026-10-18 (AGENTS.md) already allows kennitala up to and including `curated/`, under `$FISHYDATA`, never
  published. Earlier the same day the maintainer kept `dw` as it is, skips included.
- **Who did the work.** Claude (Anthropic) edited the four scripts and wrote this record.

## What changes

The skip lists of decision 121 go, except where a skip is not about persons:

| Schema | Now dumped (Oracle's row estimate) | Still left out |
|---|---|---|
| `orri` | `thjodskra` (383,296), `br_thjodskra`, `einst` (0), `fyrirt` (38,605), `starfsmenn` (306) and its three views | nothing |
| `ufs` | `adilar` (11,575) and `adilar_jn` (173,025); `skipasaga_v`, `skipaskra_v`, `skip_aukaadilar_v` (who owned and ran each vessel when); `iptolur`, `log_*`, `notenda_log_*`, `errlog` (at most 132,254) | Oracle's own Java tables |
| `uv` | `starfsm` (166), `veidisv_starfsm` (13,311), `hafro_notendur_v` | nothing |
| `fs_afli` | `afladagbok_afhending` (773), `ra_umsoknir_skip`, `ra_umsoknir_umbodsmenn`, `rafr_afladagb_skipstjorar_t` (133), `vefthj_stofn_uppruni` (2); `ra_email_skeyti` (168,725) through ROracle only, as afli's copy, since RJDBC fetches its LOBs one row at a time | nothing else |
| `dw` | unchanged | its seven skips (the landings copies and the owner tables) |

ask's guarded `*_sec_v` views, agf's `aflagrunnur_sec_v`, stk's two views and Oracle's own tables stay out for
their own reasons, which are not persons. None of the opened tables nears the dumper's size limit (50 M rows).

## What follows

- `_data-dict.yaml`, written beside each dump under `$FISHYDATA`, holds example values of every column, so of these
  tables' names and kennitala too. It stays under `$FISHYDATA`; nothing from it may enter the repo or `docs/`.
- Claude reads these tables by counts and column names only and never prints their rows into a session: what a
  session prints goes to the model's provider, which MFRI's data policy does not allow for personal data.
- No reader in fishycode uses them yet. The vessel owners and operators over time (`ufs`'s three views and
  `adilar`) are the likely first use, for the vessel registry (plans 021, 028).

## The run of 2026-10-21, compared and adopted

On the server (ROracle), with biota and channel (TODO 105). Scripts, logs and a README in
`$FISHYDATA/archive/2026-10-todo109/`; done by Claude, the runs started by the maintainer.

- **The runs.** 05:48: channel (39 of 42) and biota (96 of 96, 218 M rows). 06:55: channel resumed with the geometry
  fallbacks of 6a579d4: `country` and `station` written, only `target_species_v` failing (broken in Oracle).
  10:43: `all.R --resume` of the six: ufs dumped its 16 opened tables, but orri, uv and fs_afli were skipped whole,
  since `.dump_finished()` counts a deliberately skipped object as finished. 11:37: `run_dump(c("orri", "uv",
  "fs_afli"), resume = TRUE)` dumped theirs: orri 8 (`thjodskra` 383,296 rows, `fyrirt` 38,605), uv 3, fs_afli 6. All
  exit 0.
- **Compared** with the Mac's copy (md5 per file, `compare_dumps()` where they differ). orri 22, ufs 44 and uv 9 files
  identical; fs_afli 200 of 273 identical, the other 73 its logger's years 2026-2098 (2,714 rows of future-dated
  readings), refetched because a year not yet ended always is: the same rows, only `fd.dumped` differs. Only on the
  server: the 33 opened tables, nothing else. channel and biota are new.
- **Adopted.** The six schemas moved into `raw/oracle/`; the Mac's four old copies to
  `archive/raw-oracle_2026-10-21/`. No target became outdated (the files the targets read are among the identical
  ones), so nothing is rebuilt.
- **Left:** `.dump_finished()` should not count a schema finished whose skip list has since shrunk, and
  `fs_afladagbok.takt_json_form` is still not dumped (TODO 110).
