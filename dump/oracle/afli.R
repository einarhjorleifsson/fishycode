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
# ra_email_skeyti, left out of earlier dumps because nanoparquet failed to write it, is tried again.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- mar::connect_mar(rjdbc = TRUE)
out <- fd_raw("oracle", "afli")

# afladagb_xml_mottaka has an XMLTYPE column, which the dump has always fetched through xmlserialize: written below,
# the XML as text
dump_oracle_schema(con, "afli", out, skip = "afladagb_xml_mottaka", script = "dump/oracle/afli.R")

# afladagb_xml_mottaka ---------------------------------------------------------
# Two queries, joined on id (unique: 483,738 rows in the 2026-04 dump). Before 2026-10 they were bound side by
# side, which trusted Oracle to return both in the same row order.
xml <- DBI::dbGetQuery(con, 'SELECT ID, xmlserialize(DOCUMENT SENDING AS CLOB indent size = 2) AS SENDING
                             FROM "AFLI"."AFLADAGB_XML_MOTTAKA"')
names(xml) <- tolower(names(xml))
mottaka <-
  dplyr::tbl(con, dplyr::sql('SELECT ID, RET_VAL, GERD, SKIP_NR, FRA, TIL, LONDUN_FAERSLA, EMAIL_ID, HUGBUNADUR
                              FROM "AFLI"."AFLADAGB_XML_MOTTAKA"')) |>
  dplyr::collect() |>
  dplyr::rename_with(tolower) |>
  dplyr::left_join(xml, by = "id")
mottaka <- .oracle_numbers(mottaka, oracle_fields(con, "afli", "afladagb_xml_mottaka"))
.write_raw(mottaka, file.path(out, "afladagb_xml_mottaka.parquet"), "afli.afladagb_xml_mottaka",
           .dump_run(con, "dump/oracle/afli.R"))
message("afli.afladagb_xml_mottaka: ", nrow(mottaka), " rows")
