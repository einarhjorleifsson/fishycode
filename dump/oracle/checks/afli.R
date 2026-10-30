# afli's read-only checks against Oracle: the rows of afli.afli that TO_CHAR rejects (TODO 70), and the rows of
# afli.sjalfvirkir_maelar by year, to set its overview row right (TODO 110).
#
# Input:  Oracle afli.afli, afli.sjalfvirkir_maelar
# Output: raw/oracle/afli/_checks/to_char_rejects.parquet   one row per afli.afli row where TO_CHAR fails on a column:
#                                                            its ROWID, visir where readable, and DUMP() of each number
#         raw/oracle/afli/_checks/sjalfvirkir_maelar_rows.parquet  rows by year of timi, as the dump partitions it
#         each stamped as a dump is (fd.dumped, fd.driver, fd.commit)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database (plan 054 §7, the Oracle sitting):
#   Rscript dump/oracle/checks/afli.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# The first query is plan 018 §3's: it fetches no raw NUMBER, only DUMP(), which shows the stored bytes and never
# fails, and it scans afli.afli once (a few minutes). Whether its rows are the 48 empty `afli` values of the April copy
# is answered afterwards, from this file.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
run <- .dump_run(con, "dump/oracle/checks/afli.R")
out <- fd_raw("oracle", "afli", "_checks")

rejects <- DBI::dbGetQuery(con, "
WITH FUNCTION bad(x NUMBER) RETURN NUMBER IS s VARCHAR2(200);
  BEGIN s := TO_CHAR(x); RETURN 0; EXCEPTION WHEN OTHERS THEN RETURN 1; END;
SELECT ROWIDTOCHAR(ROWID) AS rid,
       CASE WHEN bad(visir) = 0 THEN TO_CHAR(visir) END AS visir,
       DUMP(visir) AS d_visir, DUMP(sokntegund) AS d_sokntegund, DUMP(tegund) AS d_tegund,
       DUMP(afli) AS d_afli, DUMP(medalthyngd_gr) AS d_medalthyngd_gr, DUMP(magn) AS d_magn
FROM afli.afli
WHERE bad(visir) + bad(sokntegund) + bad(tegund) + bad(afli) + bad(medalthyngd_gr) + bad(magn) > 0")
.write_raw(rejects, file.path(out, "to_char_rejects.parquet"), "afli.afli: rows TO_CHAR rejects (TODO 70)", run)
message(sprintf("afli.afli: %d rows TO_CHAR rejects", nrow(rejects)))

maelar <- DBI::dbGetQuery(con, "
SELECT EXTRACT(YEAR FROM timi) AS year, COUNT(*) AS n FROM afli.sjalfvirkir_maelar
GROUP BY EXTRACT(YEAR FROM timi) ORDER BY 1")
.write_raw(maelar, file.path(out, "sjalfvirkir_maelar_rows.parquet"),
           "afli.sjalfvirkir_maelar: rows by year of timi (TODO 110)", run)
message(sprintf("afli.sjalfvirkir_maelar: %s rows", format(sum(maelar$n), big.mark = ",")))

DBI::dbDisconnect(con)
