# 106 — RJDBC stays the Oracle driver

*2026-10-15. Written by Claude (AI-assisted); the choice is the maintainer's ("we just stick with what we got").
Plan 018.*

## Why it was asked

The dumps through RJDBC needed one fix after another (decision 105, plan 018): an 8 GB JVM heap, the JVM in UTC,
NUMBER returned as text, LOBs fetched one row at a time, geometry and XML read as text, a retry with numbers as text,
a reconnect after a lost connection. The maintainer asked whether a driver with no R or Java in the data path would
do better: python-oracledb, then DuckDB reading Oracle itself.

## What was measured

Each route was tried first with a made-up user and password. Oracle answers ORA-01017 only after the connection and
the login exchange have worked, so a route that gets it can fail only at the account. No real password was used in
Claude's shell.

| route | reaches the login? | the account (`ops$einarhj`, a 10G verifier only) |
|---|---|---|
| RJDBC (ojdbc11), today's dumper | yes | logs in |
| python-oracledb 26.0.1, thin | yes: ORA-01017 in 2 s | refused: DPY-3015, verifier 0x939 |
| DuckDB `oracle_scanner` 0.4.0 (community, krokozyab/quack-oracle), DuckDB 1.5.6 | direct, no: "Oracle TCP read timed out" after 30 s, by name, by IP, with a connect descriptor, and with `READ_TIMEOUT 90`; through a local TCP relay to the same server, yes: ORA-01017 in 1.4 s | refused by design: its README accepts the 12C verifier only |
| DuckDB core `odbc` with Oracle Instant Client's ODBC driver | not tried | not known |

- Through the relay, the scanner's exchange ran to the end (CONNECT, RESEND, CONNECT, ACCEPT, then DATA) in the same
  packets as python-oracledb's. The server and the network are therefore fine, and the timeout is the extension's own.
  Its cause is not known.
- Instant Client for Apple silicon exists in version 23 only (23.26.2: Basic 136,841,563 bytes, ODBC 1,057,182
  bytes). Whether a version 23 client still logs in with a 10G verifier is not established. A secondary source says
  23ai removed `SQLNET.ALLOWED_LOGON_VERSION_CLIENT=11`, while Oracle's ODP.NET 26 reference still lists it.
  Nothing was downloaded.

## Choice

RJDBC stays (maintainer, 2026-10-15). Its faults are handled in `R/dump_oracle.R`, and the dumps run outside
RStudio through `run_dump()`.

## If it is reopened

One DBA action unblocks both other routes: a password reset that gives `ops$einarhj` a 12C verifier (Oracle
desupported the 10G verifier in 21c). Then:

- python-oracledb thin works as it stands;
- `oracle_scanner` works through the relay until its timeout is fixed upstream. The relay's packet trace is what to
  report there.

The trial scripts were committed with this record and removed in the next commit: `git log -- dump/trial` finds them.
They are `dump_oracle_trial.py` (python-oracledb, with its venv in `~/.venvs/fishydump`), `oracle_scanner_trial.R`
and `tns_relay.py` (the relay, which logs each packet's type and length, never the data).
