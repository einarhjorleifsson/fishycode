# ask — the Directorate of Fisheries' code lists and access control, every table and view as Oracle holds it (plan 018).
#
# Input:  Oracle ask
# Output: raw/oracle/ask/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand by the maintainer, since the password is in the macOS keychain: run_dump("ask") (R/run_dump.R), or
#   Rscript dump/oracle/ask.R
#
# Two things here point at ask:
#   - fs_afladagbok's gear codes: ws_veidi.veidarfaeri_id refers to ASK.VEIDARFAERI, the Directorate's own gear list;
#   - agf's aflagrunnur_sec_v is guarded by ASK.ADGANGUR_PKG and ASK.VALIN_HOFN (users and their chosen ports).
# Views guarded the same way may fail on the first run; the overview records them, and they become skips here.
# Thirteen did, on the server's first ROracle run (2026-10-16): ORA-20290, no row in ask.valin_hofn for this login.
# They are left out; the tables they read are dumped.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "ask", fd_raw("oracle", "ask"),
                   skip = c("athugasemdir_sec_v", "bilar_sec_v", "bruttovigtun_gama_sec_v", "endurvigtun_vidtakendur_sec_v",
                            "fradrattarlidir_hafnar_sec_v", "fradrattur_sec_v", "landanir_flutningstaekja_v",
                            "landanir_sec_v", "landanir_vigtarnotur_sec_v", "vigtanir_sec_v", "vigtanir_v15_sec_v",
                            "vigtarnotur_flutningstaekja_v", "vigtarnotur_sec_v"),
                   script = "dump/oracle/ask.R")
