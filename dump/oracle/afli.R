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
# Five tables with LOB columns are left out. The driver fetches a LOB one row at a time: afladagb_xml_mottaka's
# 483,738 XML documents came at about 3 MB/s with the session at 2 % CPU, and the dump was stopped (2026-10-15).
# Getting them needs a tool that fetches LOBs in bulk.
#   afladagb_xml_mottaka   the XML received from the logbook apps; the April dump in raw/logbooks/afli/ (made on the
#                          server) is the copy sources/afli/xml*.R read until then
#   rafr_mottaka_view      a view with an XML CLOB (xml_clob)
#   ra_email_skeyti        e-mails, two CLOBs; nothing reads them
#   ps_txn, create$java$lob$table   Oracle's own tables (BLOBs)
# afladagb_schema (an XMLTYPE, 37 rows) is small and is dumped. sjalfvirkir_maelar (28.2 M logger readings) goes by
# year of its time, timi: whole, it lost the connection after 6 min (ORA-17002, 2026-10-15).
# After a run with failures, `Rscript dump/oracle/afli.R --resume` keeps what was written and dumps the rest.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "afli", fd_raw("oracle", "afli"),
                   skip = c("afladagb_xml_mottaka", "rafr_mottaka_view", "ra_email_skeyti", "ps_txn",
                            "create$java$lob$table"),
                   partition = list(sjalfvirkir_maelar = "timi"),
                   script = "dump/oracle/afli.R")
