# merki — MFRI's older tagging database (taggings, tags, lengths, recaptures, finders), every table as Oracle holds it
# (plan 018).
#
# Input:  Oracle merki
# Output: raw/oracle/merki/: <name>.parquet per table, _overview_tables.parquet, _overview_fields.parquet,
#         _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/merki.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's. On the server it runs
# with the others, or alone: Rscript dump/oracle/all.R merki fiskmerki (dump/oracle/README.md).
#
# Wanted whole (maintainer, 2026-10-24; TODO 144). The tag recaptures' place text is a source of the place-name
# gazetteer (plans 043 and 044), and the ornefni repo's 2022 extract kept only recaptures with coordinates. The
# catalogue of 2026-05-12 statistics lists 45 tables, no views, 549,007 rows:
# - lengdir 176,377 (one row per tag, Oracle's comment), flod 170,684, lengd 96,392;
# - endurheimt 30,311 (one row per recaptured tag: place and time, gear, depth, the fish measured);
# - stodvar 2,058 (taggings), merki 1,423, finnandi 2,454 (finders), and code tables.
# finnandi, contact, tmp_contact and verkefnisstjorar hold persons (names, kennitala, addresses): read them by counts
# and columns only (decision 159).

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "merki", fd_raw("oracle", "merki"), script = "dump/oracle/merki.R")
