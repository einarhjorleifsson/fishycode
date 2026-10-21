# 159 — The Oracle dumps take persons' data too: registers, staff, owners, contact details and logs

*2026-10-21. Overturns decision 121's "Left out, and why" for orri, ufs, uv and fs_afli; dw's skips stay. Not yet
run: the scripts change, the dumps on disk do not until each schema is dumped again.*

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
