# agf — the landings, every table and view as Oracle holds it (plan 018).
#
# Input:  Oracle agf
# Output: raw/oracle/agf/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/agf.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Two views are left out, as in every earlier dump, now with the reason (both failed on 2026-10-15):
#   aflagrunnur_sec_v       a per-user secured view: ORA-20290, the user has no row in ask.valin_hofn (chosen ports)
#   aflagrunnur_th_igildi_v failed with a Java exception the error wrapper hid; aflagrunnur and aflagrunnur_v are dumped

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "agf", fd_raw("oracle", "agf"), skip = c("aflagrunnur_sec_v", "aflagrunnur_th_igildi_v"),
                   script = "dump/oracle/agf.R")
