# afli's electronic logbook as the apps sent it: the sent layer on the grammar's tables (plan 037)
# Side: preprocessing (afli). See plan 014.
# Input:  raw/oracle/fs_afli/afladagb_xml_mottaka.parquet   (the messages: id, sending, snt, gerd)
#         raw/oracle/fs_afli/rafr_stofn.parquet             (visir and each record's message keys, nothing else)
#         curated/reference/{gear,gear_window,port}.parquet
# Output: staging/afli_sent/{record,trip,station,fishing_sample,catch,landing_confirmation}.parquet
#
# One layer only (plan 037 §4): every value here is what an app sent, and nothing is taken from the loaded
# (rafr_*) or edited (afli.*) layers. rafr_stofn is read for the key alone, so that .sid is the edited layer's
# and curate/ can take either layer station by station. Nothing in curate/ reads these tables yet, and the
# adapter chooses between nothing: the units of the depths and the other choices are curate/'s.
#
# The messages hold the skipper's kennitala and name, the software key and free text (decision 159; MFRI's data
# policy). Elements are read by name only, and none of those is read: no output or printed line holds them. DuckDB's
# spill directory may hold the raw text while the queries run; it is under $FISHYDATA and removed at the end.
#
# A record (FAERSLA) is sent again when it is changed (a higher VERSION) and sometimes again unchanged, in another
# message. Every sent copy is kept in record.parquet with what became of it; the latest version of each record is
# the one staged. See docs/data-dict.yaml (staging/afli_sent) for the columns.

# Setup -----------------------------------------------------------------------
suppressPackageStartupMessages({
  library(DBI)
  library(tidyverse)
})

SCHEMA <- "afli"
LAYER  <- "sent"
OUT    <- function(f) fd_staging("afli_sent", f)
SPILL  <- OUT("_spill")
unlink(SPILL, recursive = TRUE)
dir.create(SPILL, recursive = TRUE, showWarnings = FALSE)
con <- dbConnect(duckdb::duckdb())
dbExecute(con, sprintf("SET threads = 8; SET memory_limit = '12GB'; SET temp_directory = '%s';
                        SET preserve_insertion_order = false", SPILL))
q   <- function(s) dbGetQuery(con, s)
say <- function(...) cat(format(Sys.time(), "%H:%M:%S"), sprintf(...), "\n")
SRC <- fd_raw("oracle", "fs_afli", "afladagb_xml_mottaka.parquet")

gear_mapping <- duckdbfs::open_dataset(fd_curated("reference", "gear.parquet")) |> collect() |>
  filter(version == "old")
gear_window  <- duckdbfs::open_dataset(fd_curated("reference", "gear_window.parquet")) |> collect()
harbours     <- duckdbfs::open_dataset(fd_curated("reference", "port.parquet")) |> collect() |>
  select(hid, port, pid) |>
  drop_na(hid, port)

# SQL helpers: an element's text, an attribute's value, and the casts --------
# (?s) lets '.' cross line breaks: a record spanning lines is otherwise missed (the TODO 113 notes). An element
# pattern needs whitespace, '>' or '/' after the name, so <DYPI> never matches <DYPI_LOK>.
el  <- function(src, tag) sprintf("nullif(trim(regexp_extract(%s, '(?s)<%s(?:\\s[^>]*)?>([^<]*)</%s>', 1)), '')",
                                  src, tag, tag)
at  <- function(src, tag, a)
  sprintf("nullif(trim(regexp_extract(%s, '<%s\\s[^>]*?\\b%s\\s*=\\s*[\"'']([^\"'']*)[\"'']', 1)), '')", src, tag, a)
blk <- function(src, tag) sprintf("regexp_extract(%s, '(?s)<%s(?:\\s[^>]*)?(?:/>|>.*?</%s>)')", src, tag, tag)
FAERSLA <- "(?s)<FAERSLA(?:\\s[^>]*)?>.*?</FAERSLA>"
GEAR    <- "BOTNVARPA|FLOTVARPA|HUMARVARPA|RAEKJUVARPA|DRAGNOT|PLOGUR|LINA|NET|FAERI|HRINGNOT"
# A catch item: the species, the weight as logged with its state, and the mean weight before or after it
ITEM <- paste0("(?s)<AFLI>\\s*<TEGUND>[^<]*</TEGUND>\\s*(?:<MEDALTHYNGD>[^<]*</MEDALTHYNGD>\\s*)?",
               "<AFLI\\s[^>]*>[^<]*</AFLI>\\s*(?:<MEDALTHYNGD>[^<]*</MEDALTHYNGD>\\s*)?</AFLI>")

# Messages --------------------------------------------------------------------
# The message's own elements outside its records. Of the receipt's columns only the id, the time received (snt)
# and the test mark (gerd = 9) are read; the app is the one the message names (Oracle's hugbunadur is a copy of it
# where set, and is set on no message that names none).
say("messages")
dbExecute(con, sprintf("CREATE TEMP TABLE msg AS
  WITH m AS (SELECT id, snt, gerd, regexp_replace(sending, '%s', '', 'g') head FROM read_parquet('%s'))
  SELECT id::INTEGER mid, snt received, gerd = 9 test_message,
    TRY_CAST(%s AS INTEGER) vid, %s app_sent,
    TRY_CAST(%s AS DATE) period_from, TRY_CAST(%s AS DATE) period_to,
    regexp_extract_all(head, '<LONDUN\\s[^>]*>') londun
  FROM m", FAERSLA, SRC, el("head", "SKIP_NR"), el("head", "HUGBUNADUR"), el("head", "TIMAB_FRA"),
  el("head", "TIMAB_TIL")))
dbExecute(con, "ALTER TABLE msg ADD COLUMN app VARCHAR; ALTER TABLE msg ADD COLUMN app_version VARCHAR;
  UPDATE msg SET app = nullif(trim(regexp_replace(app_sent, '\\s*[0-9]+(\\.[0-9]+)+\\s*$', '')), ''),
                 app_version = nullif(regexp_extract(app_sent, '([0-9]+(\\.[0-9]+)+)\\s*$', 1), '')")

# Records: every element staged, as text -------------------------------------
# One pass over the messages: each record split out, its STOFN block and its gear section's block cut, and every
# element read from them by name. The catch items are kept as a list of strings for the next step.
say("records")
st <- "st"; g <- "g"
fields <- c(
  visir_sent    = el("fx", "VISIR"),
  version       = el("fx", "VERSION"),
  record_closed = el("fx", "FAERSLA_LOKUD"),
  edited_after_closing = at(st, "STOFN", "BREYTT_EFTIR_LOKUN"),
  vedags        = el(st, "VEDAGS"),
  veidarf       = el(st, "VEIDARF"),
  ahofn         = el(st, "AHOFN"),
  dypi          = el(st, "DYPI"),
  dypi_lok      = el(st, "DYPI_LOK"),
  pos_lat       = at(st, "POS", "LAT"),
  pos_lon       = at(st, "POS", "LON"),
  pos_end_lat   = at(st, "POS_END", "LAT"),
  pos_end_lon   = at(st, "POS_END", "LON"),
  st_breidd     = at(st, "STADSETNING", "BREIDD"),
  st_lengd      = at(st, "STADSETNING", "LENGD"),
  st_lok_breidd = at(st, "STADSETNING_LOK", "BREIDD"),
  st_lok_lengd  = at(st, "STADSETNING_LOK", "LENGD"),
  londun_dags   = at(st, "LONDUN", "DAGSETNING"),
  londun_hofn   = at(st, "LONDUN", "HOFN"),
  # towed gear (BOTNVARPA, FLOTVARPA, HUMARVARPA, RAEKJUVARPA, DRAGNOT, PLOGUR)
  i_botni       = el(g, "I_BOTNI"),
  togtimi       = el(g, "TOGTIMI"),
  tvo_veidarf   = el(g, "TVO_VEIDARF"),
  moskvi_el     = el(g, "MOSKVI"),
  moskvi_vod    = el(g, "MOSKVI_VOD"),
  fj_i_kilo     = el(g, "FJ_I_KILO"),
  tog_lengd     = el(g, "TOG_LENGD"),
  vir_lengd     = el(g, "VIR_LENGD"),
  hoflinulengd  = el(g, "HOFLINULENGD"),
  fotreipi      = el(g, "FOTREIPI"),
  botngerd      = el(g, "BOTNGERD"),
  plog_breidd   = at(g, "PLOG_STAERD", "BREIDD"),
  plog_haed     = at(g, "PLOG_STAERD", "HAED"),
  plog_lengd    = at(g, "PLOG_STAERD", "LENGD"),
  # static gear and jigs (LINA, NET, FAERI): the section's own attributes, then its elements
  klst          = at(g, "(?:LINA|FAERI)", "KLST"),
  naetur        = at(g, "NET", "NAETUR"),
  onglar        = at(g, "LINA", "ONGLAR"),
  fj_bjoda      = at(g, "LINA", "FJ_BJODA"),
  beita         = at(g, "LINA", "BEITA"),
  fj_kroka_el   = el(g, "FJ_KROKA"),
  faeri_fj_kroka = at(g, "FAERI", "FJ_KROKA"),
  fjoldi        = at(g, "(?:NET|FAERI)", "FJOLDI"),
  net_haed      = at(g, "NET", "HAED"),
  net_lengd     = at(g, "NET", "MEDAL_LENGD_NETA"),
  net_moskvi    = at(g, "NET", "MOSKVI"),
  fj_tap_neta   = at(g, "NET", "FJ_TAP_NETA"),
  krokar_gerd   = at(g, "KROKAR", "GERD"),
  krokar_staerd = at(g, "KROKAR", "STAERD"),
  handbeitt     = el(g, "HANDBEITT"),
  logn_hefst    = el(g, "LOGN_HEFST"),
  drattur_hefst = el(g, "DRATTUR_HEFST"),
  drattur_lykur = el(g, "DRATTUR_LYKUR"),
  upphaf_veida  = el(g, "UPPHAF_VEIDA"),
  lok_veida     = el(g, "LOK_VEIDA"),
  # purse seine (HRINGNOT)
  klukkan       = el(g, "KLUKKAN"),
  kast_nr       = el(g, "KAST_NR"),
  not_l         = at(g, "NOT", "L_NOTAR"),
  not_d         = at(g, "NOT", "D_NOTAR"),
  not_moskvi    = at(g, "NOT", "MOSKVI"))
dbExecute(con, sprintf("CREATE TEMP TABLE xt AS
  WITH m AS (SELECT id, regexp_extract_all(sending, '%s') fl FROM read_parquet('%s')),
       f AS (SELECT id::INTEGER mid, unnest(fl) fx, generate_subscripts(fl, 1)::INTEGER rec FROM m),
       b AS (SELECT mid, rec, fx, %s st, regexp_extract(fx, '<(%s)[\\s>/]', 1) section,
                    regexp_extract(fx, '(?s)<(?:%s)(?:\\s[^>]*)?(?:/>|>.*?</(?:%s)>)') g FROM f)
  SELECT mid, rec, nullif(section, '') section, %s,
    len(regexp_extract_all(fx, '<AFLI>')) n_afli, regexp_extract_all(fx, '%s') items
  FROM b", FAERSLA, SRC, blk("fx", "STOFN"), GEAR, GEAR, GEAR,
  paste(sprintf("%s \"%s\"", fields, names(fields)), collapse = ",\n    "), ITEM))

## Parse ----------------------------------------------------------------------
# Decimal commas are read as decimal points: Fishing Log 2.6 sends DYPI and DYPI_LOK with one on ~156,000 records,
# with up to 15 decimals, so none is a thousands separator. Every text that does not parse is counted below.
num <- function(x) sprintf("TRY_CAST(replace(%s, ',', '.') AS DOUBLE)", x)
int <- function(x) sprintf("TRY_CAST(%s AS INTEGER)", x)
dbl <- function(x) sprintf("TRY_CAST(%s AS DOUBLE)", x)
tms <- function(x) sprintf("TRY_CAST(%s AS TIMESTAMP)", x)
dat <- function(x) sprintf("TRY_CAST(%s AS DATE)", x)
lgl <- function(x) sprintf("CASE lower(%s) WHEN 'true' THEN true WHEN 'false' THEN false END", x)
casts <- c(visir_sent = dbl, version = int, record_closed = tms, edited_after_closing = lgl, vedags = dat,
           veidarf = int, ahofn = int, dypi = num, dypi_lok = num, pos_lat = num, pos_lon = num,
           pos_end_lat = num, pos_end_lon = num, st_breidd = int, st_lengd = int, st_lok_breidd = int,
           st_lok_lengd = int, londun_dags = dat, londun_hofn = int, i_botni = int, togtimi = num,
           tvo_veidarf = lgl, moskvi_el = num, moskvi_vod = num, fj_i_kilo = num, tog_lengd = num,
           vir_lengd = num, hoflinulengd = num, fotreipi = num, botngerd = function(x) x,
           plog_breidd = num, plog_haed = num, plog_lengd = num, klst = num, naetur = num, onglar = num,
           fj_bjoda = num, beita = int, fj_kroka_el = num, faeri_fj_kroka = num, fjoldi = num, net_haed = num,
           net_lengd = num, net_moskvi = num, fj_tap_neta = num, krokar_gerd = int, krokar_staerd = int,
           handbeitt = lgl, logn_hefst = tms, drattur_hefst = tms, drattur_lykur = tms, upphaf_veida = tms,
           lok_veida = tms, klukkan = int, kast_nr = int, not_l = num, not_d = num, not_moskvi = num)
stopifnot(setequal(names(casts), names(fields)))
dbExecute(con, sprintf("CREATE TEMP TABLE x AS
  SELECT xt.mid, xt.rec, xt.mid * 1000 + xt.rec xid, m.vid, m.received, m.test_message, m.app, m.app_version,
    xt.section, %s, xt.n_afli, xt.items
  FROM xt JOIN msg m USING (mid)",
  paste(sprintf("%s \"%s\"", mapply(\(f, n) f(paste0("xt.\"", n, "\"")), casts, names(casts)), names(casts)),
        collapse = ",\n    ")))
stopifnot(q("SELECT max(rec) m FROM x")$m < 1000)
unparsed <- q(sprintf("SELECT %s FROM xt t JOIN x USING (mid, rec)", paste(sprintf(
  "count(*) FILTER (WHERE t.%1$s IS NOT NULL) \"%1$s|sent\",
   count(*) FILTER (WHERE t.%1$s IS NOT NULL AND x.%1$s IS NULL) \"%1$s|unparsed\"",
  names(casts)), collapse = ", "))) |>
  pivot_longer(everything(), names_to = c("element", ".value"), names_sep = "[|]")
dbExecute(con, "DROP TABLE xt")

## Catch items ----------------------------------------------------------------
say("catch items")
dbExecute(con, sprintf("CREATE TEMP TABLE ci AS
  WITH i AS (SELECT mid, rec, unnest(items) it FROM x)
  SELECT mid, rec, TRY_CAST(%s AS INTEGER) sid, %s slaegt,
    TRY_CAST(replace(regexp_extract(it, '<AFLI\\s[^>]*>([^<]*)</AFLI>', 1), ',', '.') AS DOUBLE) catch,
    TRY_CAST(replace(%s, ',', '.') AS DOUBLE) mean_weight_g
  FROM i", el("it", "TEGUND"), lgl(at("it", "AFLI", "SLAEGT")), el("it", "MEDALTHYNGD")))
dbExecute(con, "ALTER TABLE x DROP COLUMN items")

# Each record to Oracle's key, and every sent copy in one outcome ------------
say("keys and outcomes")
# Oracle holds the sent VISIR as sent, negated, or as -(1,000,000 + VISIR) (2003-2011), tried in that order. Each
# rafr_stofn row is the load of one sent record: its message id, version and VISIR. A copy repeated in its message
# (same VISIR and VERSION) is matched once, the first.
dbExecute(con, sprintf("CREATE TEMP TABLE rs AS SELECT visir, xml_sending_visir mid, xml_faerslu_visir xv,
  xml_faerslu_version xver FROM read_parquet('%s')", fd_raw("oracle", "fs_afli", "rafr_stofn.parquet")))
dbExecute(con, "CREATE TEMP TABLE x1 AS
  SELECT *, row_number() OVER (PARTITION BY mid, visir_sent, x.version ORDER BY rec) copy_no FROM x")
dbExecute(con, "DROP TABLE x; ALTER TABLE x1 RENAME TO x")
dbExecute(con, "CREATE TEMP TABLE lm AS
  SELECT rs.visir, x.mid, x.rec, k.f key_form
  FROM rs, (SELECT unnest([1, 2, 3]) f) k, x
  WHERE x.copy_no = 1 AND x.mid = rs.mid AND x.version = rs.xver
    AND rs.xv = CASE k.f WHEN 1 THEN x.visir_sent WHEN 2 THEN -x.visir_sent ELSE -x.visir_sent - 1000000 END
  QUALIFY row_number() OVER (PARTITION BY rs.visir ORDER BY k.f, x.rec) = 1")


# Oracle loads some versions of one record as rows of their own (mostly two versions in one message, the older
# deleted): 14,370 records hold 30,286 rows ($FISHYDATA/archive/2026-10-plan037/visir-reuse/). A vessel's loaded rows of
# one VISIR whose dates lie within 31 days of each other are therefore one record, and its .sid is the row loaded from
# its highest version (then the last received). The apps reuse their VISIR numbers years apart, so the number alone
# is no identity.
# A copy Oracle did not load belongs to a loaded record when it has the same vessel (the message's SKIP_NR) and VISIR
# and a fishing date (VEDAGS) within 31 days of one of that record's loaded copies; of several, the nearest in date,
# then in time received. Failing that, it is the same haul as a loaded record sent under another VISIR (an app
# renumbering its records) when the vessel, the date and the gear section are the same and so is a time the app sent:
# the on-bottom or the purse seine's clock time (HHMM), or the set, haul or jig start (to the second). Such a copy is
# kept with that record but never staged: its VERSION counts another number's versions. A start position alone is not
# enough (40 records): consecutive hauls can share it.
# The copies of a record Oracle never loaded are grouped by vessel and VISIR the same way: a gap of more than 31
# days between consecutive dates starts another record. A copy in a test message (gerd = 9) is a version of a
# loaded record or of nothing. A copy repeated in its message belongs to the record of its first copy.
WINDOW <- 31
dbExecute(con, "CREATE TEMP TABLE lc AS
  SELECT lm.visir, lm.key_form, x.mid, x.rec, x.xid, x.vid, x.visir_sent, x.vedags, x.received, x.version, x.section,
    x.i_botni, x.klukkan, x.logn_hefst, x.drattur_hefst, x.upphaf_veida
  FROM lm JOIN x USING (mid, rec)")
dbExecute(con, sprintf("CREATE TEMP TABLE lg AS
  WITH o AS (SELECT *, CASE WHEN date_diff('day', lag(vedags) OVER w, vedags) <= %d THEN 0 ELSE 1 END brk
             FROM lc WINDOW w AS (PARTITION BY vid, visir_sent ORDER BY vedags NULLS LAST, visir)),
       c AS (SELECT *, sum(brk) OVER (PARTITION BY vid, visir_sent ORDER BY vedags NULLS LAST, visir) cl FROM o)
  SELECT visir, mid, rec, xid, key_form, version,
    first_value(visir) OVER (PARTITION BY vid, visir_sent, cl ORDER BY version DESC, received DESC, visir) ident,
    count(*) OVER (PARTITION BY vid, visir_sent, cl) n_rows
  FROM c", WINDOW))
dbExecute(con, sprintf("CREATE TEMP TABLE um AS
  SELECT u.mid, u.rec, lg.ident
  FROM x u JOIN lc ON lc.vid = u.vid AND lc.visir_sent = u.visir_sent
    AND abs(date_diff('day', u.vedags, lc.vedags)) <= %d
  JOIN lg ON lg.visir = lc.visir
  WHERE u.copy_no = 1 AND (u.mid, u.rec) NOT IN (SELECT (mid, rec) FROM lm)
  QUALIFY row_number() OVER (PARTITION BY u.mid, u.rec ORDER BY abs(date_diff('day', u.vedags, lc.vedags)),
    abs(date_diff('second', u.received, lc.received)), lc.visir) = 1", WINDOW))
dbExecute(con, "CREATE TEMP TABLE hm AS
  SELECT u.mid, u.rec, lg.ident
  FROM x u JOIN lc ON lc.vid = u.vid AND lc.vedags = u.vedags AND lc.section = u.section
    AND (lc.i_botni = u.i_botni OR lc.klukkan = u.klukkan OR lc.logn_hefst = u.logn_hefst
         OR lc.drattur_hefst = u.drattur_hefst OR lc.upphaf_veida = u.upphaf_veida)
  JOIN lg ON lg.visir = lc.visir
  WHERE u.copy_no = 1 AND (u.mid, u.rec) NOT IN (SELECT (mid, rec) FROM lm)
    AND (u.mid, u.rec) NOT IN (SELECT (mid, rec) FROM um)
  QUALIFY row_number() OVER (PARTITION BY u.mid, u.rec ORDER BY abs(date_diff('second', u.received, lc.received)),
    lc.visir) = 1")
# the record's id where Oracle holds no version of it: -(10^10 + xid) of its first copy (see Staged records below)
dbExecute(con, sprintf("CREATE TEMP TABLE nl AS
  WITH n AS (SELECT mid, rec, vid, visir_sent, vedags, xid FROM x
             WHERE copy_no = 1 AND NOT test_message AND (mid, rec) NOT IN (SELECT (mid, rec) FROM lm)
               AND (mid, rec) NOT IN (SELECT (mid, rec) FROM um) AND (mid, rec) NOT IN (SELECT (mid, rec) FROM hm)),
       o AS (SELECT *, CASE WHEN date_diff('day', lag(vedags) OVER w, vedags) <= %d THEN 0 ELSE 1 END brk
             FROM n WINDOW w AS (PARTITION BY vid, visir_sent ORDER BY vedags NULLS LAST, xid)),
       c AS (SELECT *, sum(brk) OVER (PARTITION BY vid, visir_sent ORDER BY vedags NULLS LAST, xid) cl FROM o)
  SELECT mid, rec, -(1e10 + min(xid) OVER (PARTITION BY vid, visir_sent, cl)) ident FROM c", WINDOW))
# c1: the record of every first copy, how it was found, and the rafr_stofn row(s) it was loaded as (a sent record
# Oracle loaded twice from one message has two, the 34)
dbExecute(con, "CREATE TEMP TABLE c1 AS
  SELECT mid, rec, ident, true copy_loaded, key_form, 'loaded' via, visir sid_loaded FROM lg
  UNION ALL SELECT mid, rec, ident, false, NULL, 'visir', NULL FROM um
  UNION ALL SELECT mid, rec, ident, false, NULL, 'haul', NULL FROM hm
  UNION ALL SELECT mid, rec, ident, false, NULL, 'never', NULL FROM nl")
dbExecute(con, "CREATE TEMP TABLE cr AS
  SELECT c1.* FROM c1
  UNION ALL
  SELECT x.mid, x.rec, c1.ident, false, NULL, c1.via, NULL FROM x
  JOIN x x0 ON x0.mid = x.mid AND x0.visir_sent = x.visir_sent AND x0.version = x.version AND x0.copy_no = 1
  JOIN c1 ON c1.mid = x0.mid AND c1.rec = x0.rec
  WHERE x.copy_no > 1")
# the copy loaded as the record's .sid row, and how many rafr_stofn rows the record holds
dbExecute(con, "CREATE TEMP TABLE vl AS SELECT ident, version version_loaded, xid xid_loaded, n_rows n_oracle_rows
  FROM lg WHERE visir = ident")
# The staged copy of each record: the highest VERSION, then the copy loaded as its .sid row, then any copy Oracle
# loaded, then the last received
dbExecute(con, "CREATE TEMP TABLE sc AS
  SELECT cr.ident, x.mid, x.rec, x.xid, x.version FROM cr JOIN x USING (mid, rec) LEFT JOIN vl USING (ident)
  WHERE x.copy_no = 1 AND cr.via <> 'haul'
  QUALIFY row_number() OVER (PARTITION BY cr.ident ORDER BY x.version DESC, coalesce(x.xid = vl.xid_loaded, false) DESC,
    cr.copy_loaded DESC, x.received DESC, x.mid DESC, x.rec DESC) = 1")

# One outcome per sent copy; a copy that is the source of two rafr_stofn rows is one row, with n_sid = 2
dbExecute(con, "CREATE TEMP TABLE fate AS
  WITH c AS (SELECT mid, rec, min(ident) ident, count(DISTINCT sid_loaded) n_sid, min(sid_loaded) sid_loaded,
                    bool_or(copy_loaded) copy_loaded, min(key_form) key_form, min(via) via FROM cr GROUP BY ALL)
  SELECT x.xid, x.mid, x.rec, x.vid, x.visir_sent, x.version, x.vedags, x.received, x.test_message, x.app,
    x.app_version, c.ident, c.sid_loaded, coalesce(c.n_sid, 0) n_sid, coalesce(c.copy_loaded, false) copy_loaded,
    c.key_form, sc.xid xid_staged, sc.version version_staged, vl.version_loaded, coalesce(sc.xid = x.xid, false) staged,
    CASE WHEN x.copy_no > 1                          THEN 'repeated in the message'
         WHEN c.ident IS NULL                        THEN 'test message'
         WHEN c.via = 'haul'                         THEN 'same haul as a loaded record, another VISIR'
         WHEN sc.xid = x.xid AND c.copy_loaded       THEN 'loaded'
         WHEN sc.xid = x.xid AND c.ident > -1e9      THEN 'newer than the loaded one'
         WHEN sc.xid = x.xid                         THEN 'never loaded'
         WHEN c.copy_loaded AND x.version < sc.version THEN 'loaded, a newer version sent'
         WHEN c.copy_loaded                          THEN 'loaded, the same version staged from another message'
         WHEN x.version < sc.version                 THEN 'older version'
         ELSE 'same version, other message' END outcome
  FROM x LEFT JOIN c USING (mid, rec) LEFT JOIN sc ON sc.ident = c.ident LEFT JOIN vl ON vl.ident = c.ident")
stopifnot(q("SELECT count(*) n FROM fate")$n == q("SELECT count(*) n FROM x")$n,
          q("SELECT count(*) n FROM (SELECT ident FROM sc GROUP BY 1 HAVING count(*) > 1)")$n == 0)

# Staged records ---------------------------------------------------------------
# One row per record: .sid is Oracle's visir of the record's row (above), or -(10^10 + xid) of the record's first
# copy where Oracle holds no version of it, outside every Oracle id (rafr_stofn's run from -1,326,693 to -379,
# afli.stofn's from -2,768,723,449), so that no key is NA and none can be taken for another layer's station.
say("staged records")
rec <- q("SELECT sc.ident \".sid\", vl.version_loaded, vl.xid_loaded, vl.n_oracle_rows, x.* EXCLUDE (copy_no)
          FROM sc JOIN x USING (mid, rec) LEFT JOIN vl ON vl.ident = sc.ident") |>
  as_tibble() |>
  rename(.xid = xid) |>
  mutate(loaded        = .sid > -1e9,
         copy_loaded   = loaded & .xid == xid_loaded,
         n_oracle_rows = coalesce(as.integer(n_oracle_rows), 0L),
         schema        = SCHEMA,
         layer         = LAYER) |>
  select(-xid_loaded)
# copies under the record's own VISIR (its versions and resends), and copies of the same haul under another
n_versions <- q("SELECT cr.ident \".sid\", count(DISTINCT x.version) FILTER (WHERE cr.via <> 'haul') n_versions,
                   count(DISTINCT x.xid) FILTER (WHERE cr.via <> 'haul') n_copies,
                   count(DISTINCT x.xid) FILTER (WHERE cr.via = 'haul') n_other_visir
                 FROM cr JOIN x USING (mid, rec) GROUP BY 1") |>
  mutate(across(-.sid, as.integer))
rec <- rec |> left_join(n_versions, by = ".sid", relationship = "one-to-one")

# DDMM (degrees and minutes, west positive) to decimal degrees, as sources/afli/convert.R reads Oracle's copy
ddmm <- function(x) sign(x) * (abs(x) %/% 100 + (abs(x) %% 100) / 60)
MOBILE <- c("BOTNVARPA", "FLOTVARPA", "HUMARVARPA", "RAEKJUVARPA", "DRAGNOT", "PLOGUR")
STATIC <- c("LINA", "NET", "FAERI")
rec <- rec |>
  mutate(date      = as_datetime(vedags),
         # POS is decimal degrees to the arc-second, west negative; STADSETNING the older apps' DDMM
         lat1      = coalesce(pos_lat, ddmm(st_breidd)),
         lon1      = coalesce(pos_lon, -ddmm(st_lengd)),
         lat2      = coalesce(pos_end_lat, ddmm(st_lok_breidd)),
         lon2      = coalesce(pos_end_lon, -ddmm(st_lok_lengd)),
         pos1_form = case_when(!is.na(pos_lat) ~ "degrees", !is.na(st_breidd) ~ "ddmm"),
         pos2_form = case_when(!is.na(pos_end_lat) ~ "degrees", !is.na(st_lok_breidd) ~ "ddmm"),
         T2        = as_datetime(londun_dags),
         hid2      = londun_hofn,
         n_crew    = ahofn)

# Trip ------------------------------------------------------------------------
# Derived as in sources/afli/convert.R: the records of a vessel that share the landing date and port they were
# sent with (STOFN/LONDUN), .tid the least Oracle .sid among them (so it equals the edited layer's where the
# grouping is the same), or the least .sid where Oracle loaded none of them. T1 is the first fishing date; no
# departure port is sent, so the trip has no hid1 or pid1.
# (dplyr joins match NA to NA, so the 88 records sent with no LONDUN make their trips as in a group_by)
TRIP <- c("vid", "T2", "hid2")
first_of <- function(d, by) d |> arrange({{ by }}) |> distinct(vid, T2, hid2, .keep_all = TRUE)
rec <- rec |>
  left_join(rec |> filter(loaded) |> first_of(.sid) |> select(all_of(TRIP), .tid_l = .sid), by = TRIP) |>
  left_join(rec |> first_of(.sid) |> select(all_of(TRIP), .tid_a = .sid), by = TRIP) |>
  left_join(rec |> first_of(date) |> select(all_of(TRIP), T1 = date), by = TRIP) |>
  mutate(.tid = coalesce(.tid_l, .tid_a)) |>
  select(-.tid_l, -.tid_a)
# the trip's values (crew, app) from the record whose .sid is its .tid
trip <-
  rec |>
  arrange(.tid, .sid != .tid) |>
  distinct(.tid, .keep_all = TRUE) |>
  select(.tid, vid, T1, T2, hid2, n_crew, schema, layer, app, app_version) |>
  left_join(harbours, by = join_by(hid2 == hid)) |>
  rename(pid2 = pid)

# Station ---------------------------------------------------------------------
# z1_raw, z2_raw: DYPI and DYPI_LOK as sent. Their unit is not decided here: SeaData 1.x sent fathoms, the later
# apps mostly metres, and Fishing Log 2.6 and 2.7 fathoms on some vessels in some periods (the TODO 113 notes);
# the per-vessel-period unit test is curate/'s. sq and ssq are derived from the start position (geo, as Oracle
# derives reitur and smareitur).
station <-
  rec |>
  mutate(ok_pos = !is.na(lat1) & !is.na(lon1),
         sq     = if_else(ok_pos, as.integer(geo::d2r(lat1, lon1)), NA_integer_),
         ssq    = if_else(ok_pos, as.integer(geo::d2sr(lat1, lon1) %% 10), NA_integer_),
         sq_basis = if_else(is.na(sq), "none", "derived"),
         z1_raw = dypi,
         z2_raw = dypi_lok) |>
  select(.sid, .tid, .xid, date, lon1, lat1, lon2, lat2, pos1_form, pos2_form, sq, ssq, sq_basis, z1_raw, z2_raw,
         record_closed, edited_after_closing, version, n_versions, n_copies, n_other_visir, loaded, copy_loaded,
         version_loaded, n_oracle_rows, schema, layer, app, app_version)

# Fishing sample --------------------------------------------------------------
## Timing ----------------------------------------------------------------------
# By the gear section the app sent, which is one per record. Towed gear (and the purse seine's KLUKKAN): t2 is the
# fishing date at the on-bottom clock time (I_BOTNI, HHMM), t3 is t2 + TOGTIMI ("derived"). Lines and nets: t1, t3,
# t4 are the set start, haul start and haul end (LOGN_HEFST, DRATTUR_HEFST, DRATTUR_LYKUR). Jigs: FAERI's start and
# end of fishing (UPPHAF_VEIDA, LOK_VEIDA) are t3 and t4, where Oracle loads them (drattur_hefst, drattur_lykur) and
# so where sources/afli/convert.R has them. The duration is TOGTIMI (minutes), else NAETUR (nights) or KLST (hours)
# as sent, in minutes; duration_d and duration_h keep NAETUR and KLST unrounded (Oracle rounds both, TODO 108).
fishing_sample <-
  rec |>
  select(.tid, .sid, .xid, vid, date, veidarf, section, i_botni, klukkan, togtimi, klst, naetur, logn_hefst,
         drattur_hefst, drattur_lykur, upphaf_veida, lok_veida, schema, layer, app, app_version) |>
  rename(gid_old = veidarf) |>
  left_join(gear_mapping |> select(gid_old = gid, gid = map, gear, target, target2), by = "gid_old") |>
  mutate(hhmm       = case_when(section %in% MOBILE ~ i_botni, section == "HRINGNOT" ~ klukkan),
         duration_d = if_else(section %in% STATIC, naetur, NA_real_),
         duration_h = if_else(section %in% STATIC, klst, NA_real_),
         duration_m = case_when(section %in% MOBILE ~ togtimi,
                                !is.na(duration_d) ~ duration_d * 24 * 60,
                                !is.na(duration_h) ~ duration_h * 60),
         t1 = if_else(section %in% c("LINA", "NET"), logn_hefst, NA_POSIXct_),
         t3 = case_when(section %in% c("LINA", "NET") ~ drattur_hefst, section == "FAERI" ~ upphaf_veida),
         t4 = case_when(section %in% c("LINA", "NET") ~ drattur_lykur, section == "FAERI" ~ lok_veida)) |>
  # duration_m_raw is kept; an implausible duration becomes NA (R/duration_limit.R), as in sources/afli/convert.R
  apply_duration_limit(gear_window) |>
  mutate(duration_m = if_else(duration_m <= 0, NA_real_, duration_m),
         hhmm = if_else(!is.na(hhmm) & hhmm >= 0, hhmm, NA_integer_),
         hh   = hhmm %/% 100L,
         hh   = if_else(hh < 24L, hh, NA_integer_),
         mm   = hhmm %% 100L,
         mm   = if_else(mm < 60L & !is.na(hh), mm, NA_integer_),
         t2   = if_else(!is.na(hh) & !is.na(mm), date + hours(hh) + minutes(mm), NA_POSIXct_),
         t3_derived = is.na(t3) & !is.na(t2) & !is.na(duration_m),
         t3   = if_else(t3_derived, t2 + minutes(as.integer(duration_m)), t3)) |>
  select(-c(hhmm, hh, mm, i_botni, klukkan, togtimi, klst, naetur, logn_hefst, drattur_hefst, drattur_lykur,
            upphaf_veida, lok_veida))

## Overlap QC, as in sources/afli/convert.R -----------------------------------
fishing_sample <- fishing_sample |>
  arrange(vid, date, t2) |>
  osfd::fd_flag_time_overlaps(t2, t3, by = vid) |>
  mutate(.impossible = .checks %in% c("start after end", "start equals end"),
         t2 = if_else(.impossible, NA, t2),
         t3 = if_else(.impossible, NA, t3)) |>
  select(-vid, -date, -.impossible) |>
  mutate(t1_basis = if_else(is.na(t1), "none", "recorded"),
         t2_basis = if_else(is.na(t2), "none", "recorded"),
         t3_basis = case_when(is.na(t3) ~ "none", t3_derived ~ "derived", .default = "recorded"),
         t4_basis = if_else(is.na(t4), "none", "recorded"),
         duration_m_basis = if_else(is.na(duration_m), "none", "recorded")) |>
  select(-t3_derived)

## Gear dimensions and effort --------------------------------------------------
# The columns of sources/afli/convert.R's dims, by gear class (from the gear code sent, VEIDARF), each from the
# element the loader puts in the Oracle column the edited layer reads. Differences from it: TVO_VEIDARF (two
# trawls) is twin_gear, not n_units; the Danish seine's TOG_LENGD and the purse seine's L_NOTAR and D_NOTAR are in
# metres as sent (Oracle converts them to fathoms); and the hooks per jig line, the hook type and size and
# hand-baiting, which Oracle never loaded.
dims <-
  rec |>
  select(.sid, veidarf, section, tvo_veidarf, moskvi_el, moskvi_vod, fj_i_kilo, tog_lengd, vir_lengd, hoflinulengd,
         fotreipi, botngerd, plog_breidd, plog_haed, plog_lengd, onglar, fj_bjoda, beita, fj_kroka_el,
         faeri_fj_kroka, fjoldi, net_haed, net_lengd, net_moskvi, fj_tap_neta, krokar_gerd, krokar_staerd,
         handbeitt, not_l, not_d, not_moskvi) |>
  left_join(gear_mapping |> select(veidarf = gid, gear), by = "veidarf") |>
  mutate(
    effort_unit = case_when(gear %in% c("OTB", "OTM", "DRB") ~ "gear-minutes",
                            gear %in% c("SDN", "PS")         ~ "setting",
                            gear == "LLS"                    ~ "hook-days",
                            gear %in% c("GNS", "GND")        ~ "net-days",
                            gear == "LHM"                    ~ "jig-hours",
                            gear == "FPO"                    ~ "trap-hours"),
    n_total = case_when(gear == "LLS" & !is.na(fj_kroka_el)                   ~ fj_kroka_el,
                        gear == "LLS" & !is.na(onglar) & !is.na(fj_bjoda)     ~ onglar * fj_bjoda),
    n_total_basis = case_when(is.na(n_total) ~ "none", !is.na(fj_kroka_el) ~ "recorded", .default = "derived"),
    n_units = case_when(gear == "LLS" ~ fj_bjoda, gear %in% c("GNS", "GND", "LHM") ~ fjoldi),
    n_per_unit = case_when(gear == "LLS" ~ onglar, gear == "LHM" ~ faeri_fj_kroka),
    effort_count = case_when(gear %in% c("OTB", "OTM", "DRB", "SDN", "PS") ~ 1,
                             gear == "LLS" ~ n_total,
                             gear %in% c("GNS", "GND", "LHM") ~ fjoldi),
    g_mesh   = case_when(gear %in% c("DRB", "SDN") ~ moskvi_el, gear %in% c("GNS", "GND") ~ net_moskvi,
                         gear == "PS" ~ not_moskvi),
    g_width  = if_else(gear == "DRB", plog_breidd, NA_real_),
    g_height = case_when(gear == "DRB" ~ plog_haed, gear %in% c("GNS", "GND") ~ net_haed, gear == "PS" ~ not_d),
    g_length = case_when(gear == "DRB" ~ plog_lengd, gear %in% c("GNS", "GND") ~ fjoldi * net_lengd,
                         gear == "PS" ~ not_l),
    length_togle    = if_else(gear == "SDN", tog_lengd, NA_real_),
    length_virle    = if_else(gear == "SDN", vir_lengd, NA_real_),
    mesh_vod        = if_else(gear == "SDN", moskvi_vod, NA_real_),
    length_headline = if_else(gear == "SDN", hoflinulengd, NA_real_),
    length_fotreipi = if_else(gear == "SDN", fotreipi, NA_real_),
    bottom_type     = if_else(gear %in% c("OTB", "OTM", "DRB"), botngerd, NA_character_),
    catch_nperkg    = if_else(gear %in% c("OTB", "OTM", "DRB"), fj_i_kilo, NA_real_),
    n_lost          = if_else(gear %in% c("GNS", "GND"), fj_tap_neta, NA_real_),
    twin_gear = tvo_veidarf, bait = beita, hook_type = krokar_gerd, hook_size = krokar_staerd,
    hand_baited = handbeitt) |>
  select(.sid, effort_count, effort_unit, n_units, bottom_type, catch_nperkg, g_mesh, g_width, g_height, g_length,
         length_togle, length_virle, mesh_vod, length_headline, length_fotreipi, n_total, n_total_basis, n_per_unit,
         n_lost, twin_gear, bait, hook_type, hook_size, hand_baited)

fishing_sample <- fishing_sample |>
  left_join(dims, by = ".sid", relationship = "one-to-one") |>
  mutate(effort_duration = case_when(
           effort_unit == "gear-minutes" ~ duration_m,
           effort_unit == "hook-days"    ~ duration_m / (60 * 24),
           effort_unit == "net-days"     ~ duration_m / (60 * 24),
           effort_unit == "jig-hours"    ~ duration_m / 60,
           effort_unit == "trap-hours"   ~ duration_m / 60,
           effort_unit == "setting"      ~ 1,
           .default = NA_real_),
         effort = effort_count * effort_duration) |>
  relocate(.tid, .sid, .xid, gid_old, gid, gear, target, target2, section, t1, t2, t3, t4, duration_m,
           duration_m_raw, .duration_source, duration_d, duration_h, effort_count, effort_unit, effort_duration,
           effort, .checks)

# Catch -------------------------------------------------------------------------
# The weight as logged, in the state it was logged in (SLAEGT: true gutted, false ungutted), one row per species
# and state. No whole weight is computed here: Oracle's is round(gutted x 1.25) for every species, and the choice
# of factor is curate/'s (plan 037 §4, ask e). A mean weight (MEDALTHYNGD, g) is kept where the row is one item.
catch <-
  q("SELECT sc.ident \".sid\", sc.xid \".xid\", ci.sid,
       CASE WHEN ci.slaegt THEN 'GUTT' WHEN NOT ci.slaegt THEN 'UNGU' END condition, sum(ci.catch) catch,
       count(*) n_items, CASE WHEN count(*) = 1 THEN any_value(ci.mean_weight_g) END mean_weight_g
     FROM ci JOIN sc USING (mid, rec) GROUP BY ALL") |>
  as_tibble() |>
  left_join(rec |> select(.sid, schema, layer, app, app_version), by = ".sid", relationship = "many-to-one") |>
  mutate(n_items = as.integer(n_items), catch_basis = "recorded") |>
  relocate(.sid, .xid, sid, catch, condition, catch_basis, n_items, mean_weight_g) |>
  arrange(.sid, sid, condition)

# Landing confirmations -----------------------------------------------------------
# A message of its own (londun_faersla L), one LONDUN each: the vessel, the landing date and port, and the period
# its records cover (TIMAB_FRA, the first fishing date, is no departure). Declarations ashore, not a trip.
landing_confirmation <-
  q(sprintf("WITH l AS (SELECT mid, vid, received, period_from, period_to, app, app_version, unnest(londun) lx FROM msg)
             SELECT mid, vid, TRY_CAST(%s AS DATE) dags, TRY_CAST(%s AS INTEGER) hid2, period_from, period_to,
               received, app, app_version FROM l", at("lx", "LONDUN", "DAGSETNING"), at("lx", "LONDUN", "HOFN"))) |>
  as_tibble() |>
  mutate(T2 = as_datetime(dags), period_from = as_datetime(period_from), period_to = as_datetime(period_to),
         schema = SCHEMA, layer = LAYER) |>
  left_join(harbours |> select(hid, pid2 = pid), by = join_by(hid2 == hid)) |>
  select(mid, vid, T2, hid2, pid2, period_from, period_to, received, schema, layer, app, app_version)

# Every sent record ---------------------------------------------------------------
record <- q("SELECT * FROM fate") |>
  as_tibble() |>
  transmute(.xid = xid, mid, rec, vid, visir_sent, version, date = as_datetime(vedags), received, test_message,
            .sid = ident, .sid_loaded = sid_loaded, n_sid = as.integer(n_sid), copy_loaded, key_form,
            .xid_staged = xid_staged, version_staged,
            version_loaded, staged, outcome, schema = SCHEMA, layer = LAYER, app, app_version)

# Report ----------------------------------------------------------------------
rafr <- q("SELECT count(*) n_rafr, count(*) FILTER (WHERE visir IN (SELECT visir FROM lm)) found,
              count(*) FILTER (WHERE visir IN (SELECT ident FROM sc)) staged_sid FROM rs")
items <- q("SELECT (SELECT sum(n_afli) FROM x) n_afli_tags, (SELECT count(*) FROM ci) items,
             (SELECT count(*) FILTER (WHERE sid IS NULL OR slaegt IS NULL OR catch IS NULL) FROM ci) items_incomplete")
dbDisconnect(con, shutdown = TRUE)
unlink(SPILL, recursive = TRUE)

cat("\n== afli, the sent layer (plan 037) ==\n")
cat("messages read; sent records (copies):", nrow(record), "\n")
print(record |> count(outcome, staged) |> arrange(desc(n)), n = 20)
cat("\nloaded copies by the form of the id in Oracle (1 as sent, 2 negated, 3 -(1e6 + id)):\n")
print(record |> filter(copy_loaded) |> count(key_form))
cat("\nrafr_stofn rows:", rafr$n_rafr, "; found in their message:", rafr$found, "; not:", rafr$n_rafr - rafr$found,
    "\n  of those found, the staged record's .sid:", rafr$staged_sid, "; another row of a staged record:",
    rafr$found - rafr$staged_sid, "\n")
cat("copies loaded as two rafr_stofn rows:", sum(record$n_sid > 1), "; staged records Oracle holds as several rows:",
    sum(station$n_oracle_rows > 1), "\n")
cat("\nstaged stations:", nrow(station), "; Oracle holds a version:", sum(station$loaded),
    "; the staged copy is the one loaded:", sum(station$copy_loaded), "\n")
cat("catch: <AFLI> item containers", items$n_afli_tags, "; items read", items$items,
    "; incomplete", items$items_incomplete, "; rows staged", nrow(catch), "\n")
cat("\nelements sent but not parsed (shown where any):\n")
print(unparsed |> filter(unparsed > 0))
cat("\ngear section against the gear class of the code sent (rows where they disagree):\n")
print(fishing_sample |> count(section, gear) |>
        filter(!(section %in% MOBILE & gear %in% c("OTB", "OTM", "DRB", "SDN")) &
               !(section == "LINA" & gear == "LLS") & !(section == "NET" & gear %in% c("GNS", "GND")) &
               !(section == "FAERI" & gear == "LHM") & !(section == "HRINGNOT" & gear == "PS")), n = 40)
cat("\nlanding confirmations:", nrow(landing_confirmation), "\n")

# Export -----------------------------------------------------------------------
stopifnot(!anyDuplicated(station$.sid), !anyDuplicated(station$.xid), !anyDuplicated(fishing_sample$.sid),
          !anyDuplicated(trip$.tid),
          !anyDuplicated(record$.xid))
record               |> duckdbfs::write_dataset(OUT("record.parquet"))
trip                 |> duckdbfs::write_dataset(OUT("trip.parquet"))
station              |> duckdbfs::write_dataset(OUT("station.parquet"))
fishing_sample       |> duckdbfs::write_dataset(OUT("fishing_sample.parquet"))
catch                |> duckdbfs::write_dataset(OUT("catch.parquet"))
landing_confirmation |> duckdbfs::write_dataset(OUT("landing_confirmation.parquet"))
