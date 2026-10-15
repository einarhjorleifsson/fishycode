# afli — MFRI's logbooks, every table and view as Oracle holds it (plan 018).
#
# Input:  Oracle afli
# Output: raw/oracle/afli/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/afli.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# afladagb_xml_mottaka's XMLTYPE column is read as the XML document, as text, by the dumper (.oracle_text); it no
# longer needs a query of its own. ra_email_skeyti, left out of earlier dumps because nanoparquet failed to write it,
# is tried again.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "afli", fd_raw("oracle", "afli"), script = "dump/oracle/afli.R")
