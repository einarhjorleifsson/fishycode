# afli's gear, rigging and per-haul sensor values, by part and reading (plan 052)
# Side: preprocessing (afli). See plan 014.
# Input:  raw/oracle/{afli,fs_afli}/{rafr_toga,rafr_lineha,rafr_hringn,rafr_stofn,toga,lineha,hringn,gildra,
#           stofn}.parquet; raw/oracle/fs_afli/afladagb_xml_mottaka.parquet (the headline depth as sent);
#         staging/afli_sent/fishing_sample.parquet (the sent layer); curated/reference/{gear,gear_part_map,
#           gear_part_code}.parquet
# Output: staging/afli/{gear_part,rigging_part,sensor_summary,part_column}.parquet
#
# Written by Claude (AI), 2026-10-29 (decision 244); not checked by a person.
#
# The layers, best first (plan 052 §5, plan 037): what the apps sent, where the loader lost or changed it (hook type
# and size, hand-baiting, hooks per jig, the dredge's size and the bottom, and the headline depth, which the loader
# turned to fathoms on some records and not on others); the loaded rafr_ tables, afli's copy and then fs_afli's for the
# records afli's lacks (2020-07 to 2023, the afli route); the edited tables, afli's and then fs_afli's for the paper
# stations afli lacks, as sources/afli/convert.R reads them (decision 124). Per measure the best layer holding a value
# answers. The edit's changes to a value rafr_ holds are counted in part_column.parquet, not taken: rafr_ is the
# prototype (the maintainer, 2026-10-29). Water depth stays on the station (z1, z2): one home, TODO 113.
#
# The tables carry no time, and read none: plan 052's tables are independent of the set times (TODO 164).

suppressPackageStartupMessages({
  library(DBI)
  library(dplyr)
})

SCHEMA <- "afli"
OUT    <- function(f) fd_staging("afli", f)
WORK   <- OUT("_part")
unlink(WORK, recursive = TRUE)
dir.create(WORK, recursive = TRUE, showWarnings = FALSE)
con <- dbConnect(duckdb::duckdb(), dbdir = file.path(WORK, "part.duckdb"))
dbExecute(con, sprintf("SET threads = 8; SET memory_limit = '12GB'; SET temp_directory = '%s';
                        SET preserve_insertion_order = false", file.path(WORK, "spill")))
q   <- function(s) dbGetQuery(con, s)
say <- function(...) cat(format(Sys.time(), "%H:%M:%S"), sprintf(...), "\n")
raw <- function(s, t) sprintf("read_parquet('%s')", fd_raw("oracle", s, paste0(t, ".parquet")))

# The station's gear ---------------------------------------------------------------------------------------------------
# As the merge has it: the edited stofn (afli's, and fs_afli's paper stations afli lacks), else the loaded rafr_stofn.
say("stations")
dbWriteTable(con, "gear_old", duckdbfs::open_dataset(fd_curated("reference", "gear.parquet")) |>
               filter(version == "old") |> select(gid, gear) |> collect())
dbExecute(con, sprintf("CREATE TABLE fs_sid AS SELECT visir FROM %s WHERE visir > 0 AND visir NOT IN
                        (SELECT visir FROM %s)", raw("fs_afli", "stofn"), raw("afli", "stofn")))
dbExecute(con, sprintf("CREATE TABLE sg AS
  WITH e AS (SELECT visir, veidarf FROM %1$s UNION ALL
             SELECT visir, veidarf FROM %2$s WHERE visir IN (SELECT visir FROM fs_sid)),
       r AS (SELECT visir, veidarf FROM %3$s UNION ALL
             SELECT visir, veidarf FROM %4$s WHERE visir NOT IN (SELECT visir FROM %3$s)),
       a AS (SELECT * FROM e UNION ALL SELECT * FROM r WHERE visir NOT IN (SELECT visir FROM e))
  SELECT a.visir, g.gear FROM a LEFT JOIN gear_old g ON g.gid = a.veidarf",
  raw("afli", "stofn"), raw("fs_afli", "stofn"), raw("afli", "rafr_stofn"), raw("fs_afli", "rafr_stofn")))
stopifnot("a station twice in sg" = q("SELECT count(*) - count(DISTINCT visir) d FROM sg")$d == 0)

# The layers -----------------------------------------------------------------------------------------------------------
# One view per table and copy, with .sid and the station's gear. fs_afli's rafr_ rows only where afli's has none, its
# edited rows only for the paper stations afli lacks.
layer_view <- function(name, schema, table, where = "TRUE") {
  dbExecute(con, sprintf("CREATE VIEW \"%s\" AS SELECT t.visir \".sid\", sg.gear, t.* EXCLUDE (visir)
                          FROM %s t LEFT JOIN sg USING (visir) WHERE %s", name, raw(schema, table), where))
  name
}
LAYERS <- tribble(
  ~layer,              ~schema,   ~table,        ~map_table, ~lr, ~where,
  "afli.rafr_stofn",   "afli",    "rafr_stofn",  "stofn",    2L,  "TRUE",
  "fs_afli.rafr_stofn","fs_afli", "rafr_stofn",  "stofn",    3L,  sprintf("visir NOT IN (SELECT visir FROM %s)", raw("afli", "rafr_stofn")),
  "afli.stofn",        "afli",    "stofn",       "stofn",    4L,  "TRUE",
  "fs_afli.stofn",     "fs_afli", "stofn",       "stofn",    5L,  "visir IN (SELECT visir FROM fs_sid)")
for (t in c("toga", "lineha", "hringn"))
  LAYERS <- bind_rows(LAYERS, tribble(
    ~layer,                          ~schema,   ~table,               ~map_table, ~lr, ~where,
    paste0("afli.rafr_", t),         "afli",    paste0("rafr_", t),   t,          2L,  "TRUE",
    paste0("fs_afli.rafr_", t),      "fs_afli", paste0("rafr_", t),   t,          3L,
      sprintf("visir NOT IN (SELECT visir FROM %s)", raw("afli", paste0("rafr_", t))),
    paste0("afli.", t),              "afli",    t,                    t,          4L,  "TRUE",
    paste0("fs_afli.", t),           "fs_afli", t,                    t,          5L,  "visir IN (SELECT visir FROM fs_sid)"))
LAYERS <- bind_rows(LAYERS, tribble(
  ~layer,          ~schema,   ~table,   ~map_table, ~lr, ~where,
  "afli.gildra",   "afli",    "gildra", "gildra",   4L,  "TRUE",
  "fs_afli.gildra","fs_afli", "gildra", "gildra",   5L,  "visir IN (SELECT visir FROM fs_sid)"))
for (i in seq_len(nrow(LAYERS))) with(LAYERS[i, ], layer_view(layer, schema, table, where))
# The sent layer: only the elements the loader never kept (the XML map), its station gear the merge's
dbExecute(con, sprintf("CREATE VIEW \"afli_sent\" AS SELECT s.\".sid\", sg.gear, s.hook_type, s.hook_size,
  s.hand_baited, s.n_per_unit, s.g_width, s.g_height, s.g_length, s.bottom_type
  FROM read_parquet('%s') s LEFT JOIN sg ON sg.visir = s.\".sid\"", fd_staging("afli_sent", "fishing_sample.parquet")))

# Read, long -----------------------------------------------------------------------------------------------------------
# Each gear table describes some gears; a row of a station whose gear (as the merge has it) is another is the row of
# its gear before a correction, left behind (part_read()).
FITS <- list(toga = c("OTB", "OTM", "SDN", "DRB"), lineha = c("LLS", "GNS", "GND", "LHM"), hringn = "PS",
             gildra = "FPO")
part_init(con, SCHEMA)
for (i in seq_len(nrow(LAYERS))) with(LAYERS[i, ], {
  say("read %s", layer)
  part_read(con, layer, SCHEMA, map_table, layer, lr, FITS[[map_table]])
})
part_read(con, "afli_sent", SCHEMA, "sent", "afli_sent", 1L)
say("settle %s values", format(q("SELECT count(*) n FROM lraw")$n, big.mark = ","))
part_settle(con)

# Three rules that read more than one column ---------------------------------------------------------------------------
## Calm: a wind direction of 0 with no wind --------------------------------------------------------------------------
# On the paper records the compass has eight points and 360 is north; 0 goes with Beaufort 0 on 314,692 of 343,260
# stations. On the electronic ones 0 goes with a speed of 0 or -1 (not recorded) on 103,717 of 133,343 (decision 244).
stofn_layers <- LAYERS$layer[LAYERS$map_table == "stofn"]
dbExecute(con, sprintf("CREATE TABLE calm AS %s", paste(sprintf(
  "SELECT \".sid\" sid, '%1$s' layer FROM \"%1$s\" WHERE vindatt = 0 AND coalesce(m_sek, -1) <= 0
     AND coalesce(vindstig, 0) = 0", stofn_layers), collapse = " UNION ALL ")))
n_calm <- dbExecute(con, "UPDATE lp SET status = 'placeholder', num = NULL, flag = 'placeholder' FROM calm
  WHERE lp.sid = calm.sid AND lp.layer = calm.layer AND lp.col = 'vindatt' AND lp.status = 'ok'")
say("wind direction 0 when calm: %s values made placeholders", format(n_calm, big.mark = ","))

## The rig: the twin flag and the skipper's remark (decision 241) ----------------------------------------------------
# tvo_veidarf is a flag, 0 one gear and 1 two; the remark's twenties say two trawls (20-34) or a pair trawl (40-54,
# one trawl between two vessels). Two where either says two, one where the flag says one, one for a pair trawl the flag
# does not count: today's effort_count rule. The flag and the remark are each taken from their best layer.
toga_layers <- LAYERS |> filter(map_table == "toga")
stofn_lr    <- LAYERS |> filter(map_table == "stofn")
dbExecute(con, sprintf("CREATE TABLE rig AS
  WITH f AS (SELECT sid, arg_min(layer, lr) f_layer, min(lr) f_lr, arg_min(tvo_veidarf, lr) flag FROM (%s) GROUP BY sid),
       r AS (SELECT sid, arg_min(layer, lr) r_layer, min(lr) r_lr, arg_min(athugas, lr) athugas FROM (%s) GROUP BY sid),
       x AS (SELECT coalesce(f.sid, r.sid) sid, f.f_layer, f.f_lr, f.flag, r.r_layer, r.r_lr, r.athugas,
               CASE floor(r.athugas / 20) WHEN 1 THEN 'twin' WHEN 2 THEN 'pair' END remark
             FROM f FULL JOIN r ON f.sid = r.sid)
  SELECT x.*, sg.gear,
    CASE WHEN remark = 'twin' OR flag = 1 THEN 2 WHEN flag = 0 THEN 1 WHEN remark = 'pair' THEN 1 END n,
    CASE WHEN flag = 1 THEN 'flag' WHEN remark = 'twin' THEN 'remark' WHEN flag = 0 THEN 'flag'
         WHEN remark = 'pair' THEN 'remark' END n_from
  FROM x JOIN sg ON sg.visir = x.sid
  WHERE sg.gear IN ('OTB', 'OTM', 'DRB') AND (flag IS NOT NULL OR remark IS NOT NULL)",
  paste(sprintf("SELECT \".sid\" sid, '%s' layer, %d lr, tvo_veidarf FROM \"%s\" WHERE tvo_veidarf IS NOT NULL",
                toga_layers$layer, toga_layers$lr, toga_layers$layer), collapse = " UNION ALL "),
  paste(sprintf("SELECT \".sid\" sid, '%s' layer, %d lr, athugas FROM \"%s\" WHERE athugas IS NOT NULL",
                stofn_lr$layer, stofn_lr$lr, stofn_lr$layer), collapse = " UNION ALL ")))
rig_row <- function(measure, value) sprintf("
  SELECT sid, gear, CASE n_from WHEN 'flag' THEN f_layer ELSE r_layer END layer,
    CASE n_from WHEN 'flag' THEN f_lr ELSE r_lr END lr,
    CASE n_from WHEN 'flag' THEN 'toga' ELSE 'stofn' END tbl,
    CASE n_from WHEN 'flag' THEN 'tvo_veidarf' ELSE 'athugas' END col,
    'rigging_part' \"use\", 'rig' part, '%s' measure, 1 cr, 'ok' status,
    CAST(CASE n_from WHEN 'flag' THEN flag ELSE athugas END AS VARCHAR) raw_txt, %s, 'derived' basis
  FROM rig WHERE n IS NOT NULL", measure, value)
part_add(con, rig_row("n", "n::DOUBLE num"))
part_add(con, rig_row("type", "CASE WHEN remark = 'pair' THEN 'pair' WHEN n = 2 THEN 'twin' ELSE 'single' END chr"))
# A flag that is neither 0 nor 1 counts nothing (twin_count): counted, not carried
print(q("SELECT flag, remark, n, n_from, count(*) stations FROM rig GROUP BY ALL ORDER BY ALL"))

## Hooks in all: tubs x hooks per tub where the record gives no total -------------------------------------------------
line_layers <- LAYERS |> filter(map_table == "lineha")
part_add(con, paste(sprintf("
  SELECT \".sid\" sid, gear, '%1$s' layer, %2$d lr, 'lineha' tbl, 'onglar*bjod' col, 'rigging_part' \"use\",
    'hook_total' part, 'n' measure, 2 cr,
    CASE WHEN onglar::DOUBLE * bjod BETWEEN 10 AND 100000 THEN 'ok' ELSE 'implausible' END status,
    CAST(onglar::DOUBLE * bjod AS VARCHAR) raw_txt, onglar::DOUBLE * bjod raw_num, onglar::DOUBLE * bjod num,
    'count' unit_raw, 'derived' basis,
    CASE WHEN onglar::DOUBLE * bjod BETWEEN 10 AND 100000 THEN NULL ELSE 'implausible' END flag
  FROM \"%1$s\" WHERE gear = 'LLS' AND onglar > 0 AND bjod > 0", line_layers$layer, line_layers$lr),
  collapse = " UNION ALL "))

## The headline depth as sent ----------------------------------------------------------------------------------------
# HOFLINU_DYPI_M is metres and HOFLINU_DYPI fathoms (the schema's documentation from version 30, 2011-01-28; the
# older versions name no unit, and Oracle's column is fathoms). The loader turned the metres into fathoms on some
# records and stored them as sent on others, by app version and not cleanly (the XML map), so rafr_'s value has no
# unit of its own: the message's is read, per record, from the copy the sent layer staged (.xid = message id x 1000 +
# the record's ordinal). FAERSLA splits a message into its records as sources/afli_sent/convert.R does.
say("headline depth from the messages")
FAERSLA <- "(?s)<FAERSLA(?:\\s[^>]*)?>.*?</FAERSLA>"
el <- function(src, tag) sprintf("TRY_CAST(replace(nullif(trim(regexp_extract(%s, '(?s)<%s(?:\\s[^>]*)?>([^<]*)</%s>', 1)), ''), ',', '.') AS DOUBLE)",
                                 src, tag, tag)
dbExecute(con, sprintf("CREATE TABLE hd_rec AS SELECT \".sid\" sid, (\".xid\" // 1000)::INTEGER mid,
  (\".xid\" %% 1000)::INTEGER rec FROM read_parquet('%s') WHERE section = 'FLOTVARPA' AND \".sid\" IS NOT NULL",
  fd_staging("afli_sent", "fishing_sample.parquet")))
dbExecute(con, sprintf("CREATE TABLE hd AS
  WITH m AS (SELECT id::INTEGER mid, regexp_extract_all(sending, '%s') fl FROM %s
             WHERE id IN (SELECT DISTINCT mid FROM hd_rec)),
       f AS (SELECT mid, unnest(fl) fx, generate_subscripts(fl, 1)::INTEGER rec FROM m)
  SELECT h.sid, %s m1, %s m2, %s f1, %s f2 FROM f JOIN hd_rec h USING (mid, rec)",
  FAERSLA, raw("fs_afli", "afladagb_xml_mottaka"), el("fx", "HOFLINU_DYPI_M"), el("fx", "HOFLINU_DYPI_M_LOK"),
  el("fx", "HOFLINU_DYPI"), el("fx", "HOFLINU_DYPI_LOK")))
stopifnot("a record read twice from its message" = q("SELECT count(*) - count(DISTINCT sid) d FROM hd")$d == 0)
hd_sql <- function(moment, m, f) sprintf("
  SELECT h.sid, sg.gear, 'fs_afli.afladagb_xml_mottaka' layer, 1 lr, 'xml' tbl,
    CASE WHEN %2$s IS NOT NULL THEN '%4$s' ELSE '%5$s' END col, 'sensor_summary' \"use\", 1 cr,
    'depth' quantity, 'gear' place, '%1$s' moment, 'gear' mount, 'headline_sensor' instrument,
    CAST(coalesce(%2$s, %3$s) AS VARCHAR) raw_txt, coalesce(%2$s, %3$s) raw_num,
    CASE WHEN %2$s IS NOT NULL THEN 'm' ELSE 'fathom' END unit_raw,
    CASE WHEN %2$s IS NOT NULL THEN %2$s ELSE %3$s * 1.8288 END v, 'recorded' basis
  FROM hd h LEFT JOIN sg ON sg.visir = h.sid
  WHERE coalesce(%2$s, %3$s) IS NOT NULL AND (sg.gear IS NULL OR sg.gear IN ('OTB', 'OTM', 'SDN', 'DRB'))",
  moment, m, f, if (moment == "1") "HOFLINU_DYPI_M" else "HOFLINU_DYPI_M_LOK",
  if (moment == "1") "HOFLINU_DYPI" else "HOFLINU_DYPI_LOK")
for (mo in c("1", "2")) part_add(con, sprintf("
  SELECT * EXCLUDE (v),
    CASE WHEN raw_num IN (0, 1) THEN 'placeholder' WHEN v NOT BETWEEN 2 AND 2000 THEN 'implausible' ELSE 'ok' END status,
    CASE WHEN raw_num IN (0, 1) THEN NULL ELSE v END num,
    CASE WHEN raw_num IN (0, 1) THEN 'placeholder' WHEN v NOT BETWEEN 2 AND 2000 THEN 'implausible' END flag
  FROM (%s)", hd_sql(mo, if (mo == "1") "m1" else "m2", if (mo == "1") "f1" else "f2")))
dbWriteTable(con, "ncol", q(sprintf("SELECT 'fs_afli.afladagb_xml_mottaka' layer, 1 lr, 'xml' tbl, col,
  (SELECT count(*) FROM hd)::DOUBLE n_rows, n_value FROM (
  SELECT 'HOFLINU_DYPI_M' col, count(m1)::DOUBLE n_value FROM hd UNION ALL SELECT 'HOFLINU_DYPI_M_LOK', count(m2) FROM hd
  UNION ALL SELECT 'HOFLINU_DYPI', count(f1) FROM hd UNION ALL SELECT 'HOFLINU_DYPI_LOK', count(f2) FROM hd)")),
  append = TRUE)
# What the loader did, per record: rafr_'s value against the one sent (the XML map's 51 % converted, 49 % not)
cat("\nThe loaded headline depth against the sent one, start of tow:\n")
print(q(sprintf("
  SELECT CASE WHEN h.m1 IS NOT NULL THEN 'HOFLINU_DYPI_M (m)' WHEN h.f1 IS NOT NULL THEN 'HOFLINU_DYPI (fathom)'
              ELSE 'nothing sent' END sent,
    CASE WHEN r.hoflinu_dypi IS NULL THEN 'none loaded'
         WHEN r.hoflinu_dypi = coalesce(h.m1, h.f1) THEN 'loaded as sent'
         WHEN h.m1 IS NOT NULL AND abs(r.hoflinu_dypi - h.m1 / 1.8288) <= 1 THEN 'loaded as fathoms'
         WHEN abs(r.hoflinu_dypi - coalesce(h.m1, h.f1)) <= 1 THEN 'loaded as sent, rounded'
         ELSE 'other' END loaded, count(*) records
  FROM hd h LEFT JOIN (SELECT \".sid\" sid, hoflinu_dypi FROM \"afli.rafr_toga\" UNION ALL
                       SELECT \".sid\", hoflinu_dypi FROM \"fs_afli.rafr_toga\") r USING (sid)
  GROUP BY ALL ORDER BY ALL")))

# Pick and write -------------------------------------------------------------------------------------------------------
say("pick")
part_pick(con)
say("write")
part_write(con, SCHEMA, "afli")

cat("\nEvery value read, by outcome:\n")
print(q("SELECT coalesce(\"use\", '(gear outside)') AS \"use\", status, count(*) n FROM lp GROUP BY ALL ORDER BY ALL"))
cat("\nRows written:\n")
for (f in c("gear_part", "rigging_part", "sensor_summary"))
  cat(sprintf("  %-15s %12s rows, %10s stations\n", f,
              format(q(sprintf("SELECT count(*) n FROM read_parquet('%s')", OUT(paste0(f, ".parquet"))))$n, big.mark = ","),
              format(q(sprintf("SELECT count(DISTINCT \".sid\") n FROM read_parquet('%s')", OUT(paste0(f, ".parquet"))))$n,
                     big.mark = ",")))

dbDisconnect(con, shutdown = TRUE)
unlink(WORK, recursive = TRUE)
