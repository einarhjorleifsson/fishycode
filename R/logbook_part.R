# logbook_part.R — the logbook's gear, rigging and per-haul sensor values, from a source's own tables to plan 052's
# three tables: gear_part and rigging_part (one row per station and part, one column per measure) and sensor_summary
# (one row per station and reading).
#
# Input:  a DuckDB connection; per source table and layer, a view with `.sid`, `gear` (the station's ICES gear class)
#         and the table's own columns; curated/reference/gear_part_map.parquet and gear_part_code.parquet
# Output: part_init() makes the working tables; part_read() adds one view's values to them, long; part_settle() gives
#         each value its outcome (`status`) and its SI value; part_add() takes rows a source script builds itself;
#         part_pick() keeps the best layer of each measure; part_write() writes the three tables and the account of
#         every source column, staging/<source>/{gear_part,rigging_part,sensor_summary,part_column}.parquet
#
# A layer is a table that holds the values (afli's loaded rafr_toga, its edited toga, ...); `lr` ranks the layers,
# best first, and the map's `rank` ranks two columns of one measure within a layer. Per measure the best layer holding
# a value answers: plan 052 §5's cascade. A row's `layer` names every table that gave one of its values; its `basis` is
# the least certain of its values' (recorded, derived, reconstructed), or "none" where it holds a raw value only.
# Written by Claude (AI), 2026-10-29 (decision 244). Function definitions only.

PART_NUMERIC <- c("n", "length_m", "width_m", "height_m", "height_meshes", "circumference_m", "weight_kg", "area_m2",
                  "mesh_size_mm", "mesh_size_min_mm", "mesh_size_max_mm", "meshes_around", "bar_spacing_mm")
PART_TEXT    <- c("mesh_orientation", "type", "type_raw", "size", "material")
PART_RAW     <- c(length_m = "length_raw", width_m = "width_raw", height_m = "height_raw")
PART_BASIS   <- c("recorded", "derived", "reconstructed", "synthesised", "none")
SENSOR_UNIT  <- c(temperature = "degC", depth = "m", wind_speed = "m/s", wind_direction = "degree",
                  wind_force = "Beaufort", sea_state = "code", bottom_type = "code", fitted = "yes_no")

.sql_in  <- function(x) paste0("(", paste(sprintf("'%s'", x), collapse = ", "), ")")
.sql_case <- function(col, x) paste0("CASE ", col, " ", paste(sprintf("WHEN '%s' THEN '%s'", names(x), x),
                                                               collapse = " "), " END")

part_init <- function(con, schema) {
  map <- duckdbfs::open_dataset(fd_curated("reference", "gear_part_map.parquet")) |> dplyr::collect() |>
    dplyr::filter(.data$schema == !!schema) |>
    dplyr::rename(tbl = "table", col = "column") |>
    dplyr::mutate(gears_in  = ifelse(is.na(gears) | startsWith(gears, "!"), NA, gears),
                  gears_out = ifelse(!is.na(gears) & startsWith(gears, "!"), gsub("!", "", gears), NA))
  code <- duckdbfs::open_dataset(fd_curated("reference", "gear_part_code.parquet")) |> dplyr::collect() |>
    dplyr::filter(.data$schema == !!schema)
  DBI::dbWriteTable(con, "pmap", map, overwrite = TRUE)
  DBI::dbWriteTable(con, "pcode", code, overwrite = TRUE)
  DBI::dbExecute(con, "CREATE OR REPLACE TABLE lraw (sid DOUBLE, gear VARCHAR, layer VARCHAR, lr INTEGER,
                       tbl VARCHAR, col VARCHAR, raw_txt VARCHAR, fit BOOLEAN)")
  DBI::dbExecute(con, "CREATE OR REPLACE TABLE ncol (layer VARCHAR, lr INTEGER, tbl VARCHAR, col VARCHAR,
                       n_rows DOUBLE, n_value DOUBLE)")
  invisible(map)
}

# One view of one layer: every column must be in the map (used, or not used with its reason), and every used one is
# read long. `view` has `.sid` and `gear`; `table` is the map's name for it. `fits` are the gears the table describes
# (NULL: any): a row of a station whose gear, as the merge has it, is another is a row of the wrong gear's table, left
# where the station's gear was corrected and its old row not deleted (the maintainer's reading, 2026-10-29; 220 afli
# stations in two of its tables, none in rafr_): counted as other_gear_table, never carried. A station of no known
# gear keeps its rows.
part_read <- function(con, view, schema, table, layer, lr, fits = NULL) {
  view <- DBI::dbQuoteIdentifier(con, view)
  cols <- setdiff(DBI::dbGetQuery(con, sprintf("DESCRIBE %s", view))$column_name, c(".sid", "gear"))
  map <- DBI::dbGetQuery(con, sprintf("SELECT * FROM pmap WHERE tbl = '%s'", table))
  unmapped <- setdiff(cols, map$col)
  if (length(unmapped)) stop(sprintf("%s.%s: columns not in gear_part_map: %s", schema, table,
                                     paste(unmapped, collapse = ", ")), call. = FALSE)
  q <- DBI::dbQuoteIdentifier(con, cols)
  n <- DBI::dbGetQuery(con, sprintf("SELECT count(*)::DOUBLE n_rows, %s FROM %s",
                                    paste(sprintf("count(%s)::DOUBLE", q), collapse = ", "), view))
  DBI::dbWriteTable(con, "ncol", data.frame(layer = layer, lr = lr, tbl = table, col = cols, n_rows = n$n_rows,
                                            n_value = unlist(n[1, -1], use.names = FALSE)), append = TRUE)
  used <- intersect(cols, map$col[map$use %in% c("gear_part", "rigging_part", "sensor_summary") & !map$special])
  fit <- if (is.null(fits)) "TRUE" else sprintf("gear IS NULL OR gear IN %s", .sql_in(fits))
  for (c in used)
    DBI::dbExecute(con, sprintf("INSERT INTO lraw SELECT \".sid\", gear, '%s', %d, '%s', '%s', CAST(%s AS VARCHAR), %s
                                 FROM %s WHERE %s IS NOT NULL", layer, lr, table, c, DBI::dbQuoteIdentifier(con, c),
                                fit, view, DBI::dbQuoteIdentifier(con, c)))
  invisible(length(used))
}

# Each value's outcome: other_gear_table (its table is another gear's), the map row its gear selects (none:
# gear_outside), then empty, placeholder, unknown_code, unparsed, implausible or ok; its SI value, text, raw value,
# basis and flag.
part_settle <- function(con) {
  num_set <- .sql_in(PART_NUMERIC)
  DBI::dbExecute(con, sprintf("
    CREATE OR REPLACE TABLE lp AS
    WITH j AS (
      SELECT r.*, m.map_id,
        coalesce((m.gears_in IS NULL OR list_contains(string_split(m.gears_in, ','), r.gear)) AND
                 (m.gears_out IS NULL OR r.gear IS NULL OR NOT list_contains(string_split(m.gears_out, ','), r.gear)),
                 false) ok
      FROM lraw r JOIN pmap m ON m.tbl = r.tbl AND m.col = r.col
      WHERE m.use IN ('gear_part', 'rigging_part', 'sensor_summary') AND NOT m.special),
    sel AS (
      SELECT * EXCLUDE (ok) FROM j WHERE ok AND fit
      UNION ALL
      SELECT sid, any_value(gear), layer, any_value(lr), tbl, col, any_value(raw_txt), bool_and(fit), NULL::INTEGER
      FROM j GROUP BY sid, layer, tbl, col HAVING NOT bool_or(ok AND fit)),
    v AS (
      SELECT s.*, TRY_CAST(replace(trim(s.raw_txt), ',', '.') AS DOUBLE) raw_num,
        CASE WHEN TRY_CAST(s.raw_txt AS DOUBLE) = floor(TRY_CAST(s.raw_txt AS DOUBLE))
             THEN CAST(CAST(TRY_CAST(s.raw_txt AS DOUBLE) AS BIGINT) AS VARCHAR) ELSE trim(s.raw_txt) END code_txt
      FROM sel s),
    x AS (
      SELECT v.*, m.use, m.part, m.measure, coalesce(m.rank, 1) cr, m.quantity, m.place, m.moment, m.mount,
        m.instrument, m.unit_raw, m.to_si, m.zero, m.placeholder, m.min_si, m.max_si, m.code_list, m.basis mbasis,
        m.flag mflag, m.type_fixed, c.type ctype,
        CASE lower(trim(v.raw_txt)) WHEN 'true' THEN 1 WHEN 'false' THEN 0 ELSE v.raw_num END present_num
      FROM v LEFT JOIN pmap m ON m.map_id = v.map_id
      LEFT JOIN pcode c ON c.list = m.code_list AND c.code = v.code_txt),
    s AS (
      SELECT *,
        CASE
          WHEN NOT fit THEN 'other_gear_table'
          WHEN map_id IS NULL THEN 'gear_outside'
          WHEN trim(raw_txt) = '' THEN 'empty'
          WHEN coalesce(list_contains(string_split(placeholder, ','), code_txt), false) THEN 'placeholder'
          WHEN raw_num = 0 AND zero = 'empty' THEN 'empty'
          WHEN raw_num = 0 AND zero = 'placeholder' THEN 'placeholder'
          WHEN code_list IS NOT NULL AND ctype IS NULL THEN 'unknown_code'
          WHEN measure = 'present' AND (present_num IS NULL OR present_num NOT IN (0, 1)) THEN 'implausible'
          WHEN (measure IN %1$s OR (use = 'sensor_summary' AND code_list IS NULL)) AND raw_num IS NULL THEN 'unparsed'
          WHEN to_si IS NOT NULL AND (raw_num * to_si < min_si OR raw_num * to_si > max_si) THEN 'implausible'
          ELSE 'ok' END status
      FROM x)
    SELECT sid, gear, layer, lr, tbl, col, map_id, use, part, measure, cr, quantity, place, moment, mount, instrument,
      status, raw_txt, raw_num, unit_raw, type_fixed,
      CASE WHEN status IN ('ok', 'implausible') OR (code_list = 'sounder' AND status = 'unknown_code') THEN
        CASE WHEN use = 'sensor_summary' THEN
               CASE code_list WHEN 'yes_no' THEN TRY_CAST(ctype AS DOUBLE) WHEN 'sounder' THEN 1
                              ELSE raw_num * to_si END
             WHEN measure = 'present' THEN present_num
             WHEN measure IN %1$s THEN raw_num * to_si END END num,
      CASE WHEN measure IN ('type', 'mesh_orientation') OR code_list = 'sounder' THEN ctype
           WHEN measure IN ('type_raw', 'size', 'material') AND status = 'ok' THEN trim(raw_txt) END chr,
      CASE WHEN measure = 'type' OR code_list = 'sounder' THEN code_txt END chr_raw,
      CASE WHEN status IN ('empty', 'gear_outside', 'other_gear_table') THEN NULL
           WHEN (measure IN %1$s OR (use = 'sensor_summary' AND code_list IS NULL)) AND to_si IS NULL THEN 'none'
           ELSE mbasis END basis,
      CASE WHEN status IN ('placeholder', 'unknown_code', 'implausible', 'unparsed') THEN status
           WHEN mflag IS NOT NULL AND status = 'ok' THEN mflag END flag
    FROM s", num_set))
  invisible(DBI::dbGetQuery(con, "SELECT count(*) n FROM lp")$n)
}

# Rows a source script builds itself (afli's rig from the flag and the remark, its derived hook count, the headline
# depth from the sent message), in lp's shape; missing columns are NULL.
part_add <- function(con, sql) {
  cols <- DBI::dbGetQuery(con, "DESCRIBE lp")
  got  <- DBI::dbGetQuery(con, sprintf("DESCRIBE %s", sql))$column_name
  stopifnot("part_add(): a column lp does not have" = all(got %in% cols$column_name))
  sel <- ifelse(cols$column_name %in% got, sprintf("\"%s\"", cols$column_name),
                sprintf("NULL::%s \"%s\"", cols$column_type, cols$column_name))
  DBI::dbExecute(con, sprintf("INSERT INTO lp SELECT %s FROM (%s)", paste(sel, collapse = ", "), sql))
}

# The best layer of each measure (gear and rigging) and of each reading (sensors). A value flagged as implausible or a
# placeholder is a value: it answers, as recorded, and a worse layer's does not replace it.
part_pick <- function(con) {
  DBI::dbExecute(con, "
    CREATE OR REPLACE TABLE lk AS
    SELECT *, lr * 100 + cr ord,
      CASE WHEN use = 'sensor_summary' THEN concat_ws('|', quantity, place, coalesce(moment, ''), instrument)
           ELSE concat_ws('|', use, part, measure) END pkey
    FROM lp WHERE status NOT IN ('empty', 'gear_outside', 'other_gear_table')")
  DBI::dbExecute(con, "
    CREATE OR REPLACE TABLE best AS
    SELECT k.* FROM lk k JOIN (SELECT sid, pkey, min(ord) ord FROM lk GROUP BY sid, pkey) b USING (sid, pkey, ord)")
  stopifnot("part_pick(): two values answer one measure" =
              DBI::dbGetQuery(con, "SELECT count(*) - count(DISTINCT (sid, pkey)) d FROM best")$d == 0)
}

# The three tables and the account, written to staging/<dir>/.
part_write <- function(con, schema, dir) {
  out <- function(f) fd_staging(dir, f)
  rank_sql <- paste0("CASE basis ", paste(sprintf("WHEN '%s' THEN %d", PART_BASIS, seq_along(PART_BASIS)),
                                           collapse = " "), " END")
  lab_sql  <- paste0("CASE max_rank ", paste(sprintf("WHEN %d THEN '%s'", seq_along(PART_BASIS), PART_BASIS),
                                              collapse = " "), " ELSE 'none' END")
  meas <- c(
    sprintf("max(num) FILTER (WHERE measure = '%1$s') \"%1$s\"", PART_NUMERIC),
    sprintf("max(chr) FILTER (WHERE measure = '%1$s') \"%1$s\"", setdiff(PART_TEXT, c("type", "type_raw"))),
    # a unit's type (net, tub, jig, trap) is the column's, not a value (the map's type_fixed)
    "coalesce(max(chr) FILTER (WHERE measure = 'type'), max(type_fixed) FILTER (WHERE measure = 'n')) \"type\"",
    "coalesce(max(chr_raw) FILTER (WHERE measure = 'type'), max(chr) FILTER (WHERE measure = 'type_raw')) type_raw",
    "CAST(max(num) FILTER (WHERE measure = 'present') AS BOOLEAN) present",
    sprintf("max(raw_num) FILTER (WHERE measure = '%s') %s", names(PART_RAW), PART_RAW),
    sprintf("string_agg(DISTINCT unit_raw, ', ') FILTER (WHERE measure IN %s) unit_raw", .sql_in(names(PART_RAW))))
  for (u in c("gear_part", "rigging_part")) {
    sql <- sprintf("
      WITH b AS (SELECT *, %4$s basis_rank, (num IS NOT NULL OR chr IS NOT NULL) has_value FROM best WHERE use = '%1$s'),
      ly AS (SELECT sid, part, string_agg(layer, ' + ' ORDER BY lr) layer
             FROM (SELECT sid, part, layer, min(lr) lr FROM b GROUP BY ALL) GROUP BY ALL),
      w AS (SELECT sid, part, %2$s,
              max(basis_rank) FILTER (WHERE has_value) max_rank,
              string_agg(measure || '=' || trim(raw_txt) || ': ' || flag, '; ' ORDER BY measure)
                FILTER (WHERE flag IS NOT NULL) flag
            FROM b GROUP BY sid, part)
      SELECT w.sid \".sid\", '%3$s' \"schema\", w.part, w.* EXCLUDE (sid, part, max_rank, flag), %5$s basis,
        ly.layer, w.flag
      FROM w JOIN ly USING (sid, part) ORDER BY w.sid, w.part",
      u, paste(meas, collapse = ",\n              "), schema, rank_sql, lab_sql)
    DBI::dbExecute(con, sprintf("COPY (%s) TO '%s' (FORMAT parquet)", sql, out(paste0(u, ".parquet"))))
  }
  DBI::dbExecute(con, sprintf("COPY (
    SELECT sid \".sid\", '%s' \"schema\", quantity, place, moment, mount, instrument,
      CASE WHEN status = 'placeholder' THEN NULL ELSE num END \"value\", %s unit, raw_num value_raw, unit_raw,
      CASE WHEN chr IS NOT NULL AND quantity = 'fitted' THEN chr END \"type\",
      CASE WHEN quantity = 'fitted' THEN chr_raw END type_raw, basis, layer, flag
    FROM best WHERE use = 'sensor_summary' ORDER BY sid, quantity, place, moment, instrument) TO '%s' (FORMAT parquet)",
    schema, .sql_case("quantity", SENSOR_UNIT), out("sensor_summary.parquet")))
  # The account: every column of every layer's table, with each value's outcome. `lost_*` are values a better layer
  # or column answered, equal to the answer or not.
  DBI::dbExecute(con, sprintf("COPY (
    WITH o AS (
      SELECT p.layer, p.tbl, p.col, p.map_id, p.status,
        p.status NOT IN ('empty', 'gear_outside', 'other_gear_table') AND b.layer = p.layer AND b.col = p.col used,
        p.status NOT IN ('empty', 'gear_outside', 'other_gear_table') AND NOT (b.layer = p.layer AND b.col = p.col) lost,
        coalesce(b.num IS NOT DISTINCT FROM p.num AND b.chr IS NOT DISTINCT FROM p.chr, false) same
      FROM lp p LEFT JOIN best b ON b.sid = p.sid AND b.pkey = CASE WHEN p.use = 'sensor_summary'
        THEN concat_ws('|', p.quantity, p.place, coalesce(p.moment, ''), p.instrument)
        ELSE concat_ws('|', p.use, p.part, p.measure) END),
    s AS (
      SELECT layer, tbl, col,
        count(*) FILTER (WHERE status = 'empty') n_empty, count(*) FILTER (WHERE status = 'other_gear_table') n_other_gear_table,
        count(*) FILTER (WHERE status = 'gear_outside') n_gear_outside,
        count(*) FILTER (WHERE status = 'placeholder') n_placeholder,
        count(*) FILTER (WHERE status = 'unknown_code') n_unknown_code,
        count(*) FILTER (WHERE status = 'unparsed') n_unparsed, count(*) FILTER (WHERE status = 'implausible') n_implausible,
        count(*) FILTER (WHERE used) n_used, count(*) FILTER (WHERE lost AND same) n_lost_equal,
        count(*) FILTER (WHERE lost AND NOT same) n_lost_differs
      FROM o GROUP BY ALL)
    SELECT '%s' \"schema\", n.layer, n.lr, n.tbl \"table\", n.col \"column\", n.n_rows, n.n_value,
      s.* EXCLUDE (layer, tbl, col)
    FROM ncol n LEFT JOIN s ON s.layer = n.layer AND s.tbl = n.tbl AND s.col = n.col
    ORDER BY n.lr, n.tbl, n.col) TO '%s' (FORMAT parquet)", schema, out("part_column.parquet")))
  invisible(TRUE)
}
