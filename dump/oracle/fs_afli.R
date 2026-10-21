# fs_afli — the Directorate of Fisheries' copy of the logbook schema, every table as Oracle holds it (plan 018).
#
# Input:  Oracle fs_afli
# Output: raw/oracle/fs_afli/: <name>.parquet per table, _overview_tables.parquet, _overview_fields.parquet,
#         _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/fs_afli.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Added 2026-10-17 (maintainer), found through raw/oracle/_catalogue/. 78 of its 80 tables are afli's by name
# (stofn, rafr_stofn and afladagb_xml_mottaka with one column more), about 115 M rows by Oracle's estimates. Those
# estimates, though older than afli's, give it more electronic logbook rows than afli's dump holds:
# rafr_stofn 1,318,771 (January 2024) against 1,149,278, rafr_afli 4,159,300 (March 2023) against 3,625,502,
# rafr_sjalfvirkir_maelar 27,095,036 (2021) against 23,610,639. So it may hold records afli lacks.
# Dumped to be compared with afli. afladagbok_sidast_breytt (6.9 M rows: when each logbook record last changed) is
# not in afli.
# Set as afli.R is: sjalfvirkir_maelar by year of timi, and the XML table only through ROracle.
# The names, addresses, kennitala, phone numbers and e-mail of logbook recipients, applicants, agents and skippers
# (afladagbok_afhending, ra_umsoknir_skip, ra_umsoknir_umbodsmenn, rafr_afladagb_skipstjorar_t, vefthj_stofn_uppruni)
# and the e-mails (ra_email_skeyti) were left out from 2026-10-17 to 2026-10-21. The e-mails are LOBs, which RJDBC
# fetches one row at a time: through ROracle only, as afli's copy (afli.R).
# Persons' data are dumped since 2026-10-21 (maintainer): kennitala may be carried up to curated/ (2026-10-18), under
# $FISHYDATA only and never published; _data-dict.yaml holds examples of their values there too.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "fs_afli", fd_raw("oracle", "fs_afli"),
                   skip_rjdbc = c("afladagb_xml_mottaka", "ra_email_skeyti"),
                   partition = list(sjalfvirkir_maelar = "timi"),
                   script = "dump/oracle/fs_afli.R")
