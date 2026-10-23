# 184 — An open end is NA in a written table; a far date stands in for it only inside a computation

*2026-10-23. The maintainer's rule, asked after decision 183. The STK key keeps its open-end date ("we just keep it as
is"), and that date is not to be used throughout. The rule below was proposed by Claude and approved by the maintainer
("yes, write the decision and the AGENTS.md line"). The record and the survey are Claude's (AI) and have not been
checked by a person. No code changed, nothing to rebuild.*

## Found

The tables under `curated/vessel/` write an open end in three ways (read-only, 2026-10-23):

- **2028-12-24, an arbitrary open-end date:**
  - the STK key and the tables it is built from: `vessel_ais_key` `d2` (20,491 rows), `vessel_ais_key_cascade`
    (20,502), `ais_key_all` (19,133), `vessel_ais_device` (10);
  - the MMSI periods: `mmsi` `mmsi_t2` (3,421), `vessel_identity` `t2` (4,574) and `mmsi_t2` (4,866),
    `vessel_identity_all` (4,550 and 4,842), `vessel` `mmsi_t2` (2,216).
- **2099-12-31:** `vessel_sign` `t2` (4,150) and `vessel_class` `t2` (1,823).
- **NA:**
  - the register's tables (`curated/vessel/register/`, `valid_to`; 2,244 in `vessel_hist`);
  - `vessel_identity_foreign` (GFW and the Faroese register, 98,241);
  - the crosswalk's MMSI rows (`vessel_ais_link`, 2,193).

  `vessel_register.R` reaches its NA with a far date (`FAR`, 2100-01-01) inside the computation, turned back to NA
  before writing. Several other scripts use such a stand-in only internally: `OPEN_T2` in `ais_ping_union.R`, `T_OPEN2` in
  `vessel_ais_link.R`, 2100-12-31 in `R/vid_match.R`.

Two kinds of end follow other rules:

- **The crosswalk's STK rows.** They end an open stretch on 2028-12-25 (20,491), the key's date plus a day, where the
  crosswalk's other rows have NA (TODO 129).
- **A source's own end.** `vessel_identity_foreign` keeps the EU fleet register's own event end date, 2100-12-31
  (70,433 rows), as the register delivers it.

## Chosen

- **A table fishycode writes has NA for an open end.** Where a computation needs a date for it (a between-join, a
  `pmin()`), a far date may stand in inside the script, and is turned back to NA before writing, as `vessel_register.R`
  does. A flag (`d2_is_open`) or a basis may say why the end is open.
- **NA rather than a date.** A reader that forgets an NA fails at once: a between-join drops every open row in its
  first build. A reader that forgets a date fails silently once that date has passed. And an analyst sees no made-up
  date in the file.
- **Not 2028-12-24 throughout.** It is the nearest of the dates in use. `vessel_sign` and `vessel_class` carry no flag,
  so moving their open ends there would put decision 183's defect into every join on them, from 2028-12-25.
- **The existing tables stay as they are** (maintainer). The STK key and the MMSI periods keep 2028-12-24, and
  `vessel_sign` and `vessel_class` keep 2099-12-31. A table moves to NA only together with its readers, by a decision
  record.
- **Until then, every reader treats the date as open.** The STK joins read `d2_is_open` (decision 183).
  `ais_ping_union.R` and `vessel_ais_link.R` open an MMSI's last period themselves. `vessel_register.R`,
  `skipaskra_history.R` and `checks/skipaskra_discrepancy.R` read `mmsi_t2 >= 2028-12-24` as open.
- **A source's own end date is kept as given.** The EU register's 2100-12-31 is the source's value: an adapter never
  rewrites it, and a reader treats it as that source's open end. The rule is for the ends fishycode writes.

## Left

- The crosswalk's STK rows, which break the rule today (TODO 129).
- New code follows the rule (`AGENTS.md`, Coding conventions).
