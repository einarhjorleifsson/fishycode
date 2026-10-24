# fiskmerki — MFRI's tagging database in use now (the kerfi/fiskmerki app: tags, tagged fish, recaptures, finders,
# electronic tag readings), every table and view as Oracle holds it (plan 018).
#
# Input:  Oracle fiskmerki
# Output: raw/oracle/fiskmerki/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/fiskmerki.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's. On the server it runs
# with the others, or alone: Rscript dump/oracle/all.R merki fiskmerki (dump/oracle/README.md).
#
# Wanted whole (maintainer, 2026-10-24; TODO 144, plan 043 ask f).
# - Why: ENDURHEIMTUR.ORNEFNI is the recapture's place. Picked in the app from ORRI.ORNEFNI, it holds "NAFN-HEITI" and
#   the place's position, sea area and square; otherwise it is the text typed. 13,633 recaptures registered before 2010
#   have a place name and no coordinates (kb-hafro-kerfi). That is the cross-check plan 044 lacks.
# - What: the catalogue of 2026-02-13 statistics lists 39 tables and 14 views, 20,062,397 rows:
#   - rafgogn 18,734,422 (the electronic tags' readings, 6 columns): under max_rows, so one file. A year partition
#     would need its date column, known after this first run.
#   - merki 260,448, fiskar 229,481, endurheimtur 42,344;
#   - endurheimtur_otengt 401 (recaptures not matched to a tag);
#   - finnendur 3,250 (finders), the *_jn journals, and code tables.
# - Persons: finnendur and finnendur_texti hold persons (names, kennitala, addresses, letters). Read them by counts and
#   columns only (decision 159).
# - Left out, both views over tables dumped whole (tables, not views: AGENTS.md), after the first run of 2026-10-24:
#   - rafaudkenni_summur_v fails inside Oracle (ORA-01722, invalid number), with its numbers fetched as text too;
#   - rafgogn_v, over rafgogn's 19.8 M readings, gave no row in ten minutes and was stopped. Its SQL text is in
#     _code/ (dump/oracle/code.R).
#   That run was stopped there and finished with --resume, which kept the 48 files it had written.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "fiskmerki", fd_raw("oracle", "fiskmerki"), skip = c("rafaudkenni_summur_v", "rafgogn_v"),
                   script = "dump/oracle/fiskmerki.R")
