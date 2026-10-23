# dump_oracle.R — dump an Oracle schema, as it is, to raw/oracle/<schema>/ (plan 018).
#
# Input:  an open connection (dump_connect()) and a schema (Oracle owner)
# Output: <out_dir>/<name>.parquet for each table and view, as Oracle holds it: names, values and units unchanged.
#         A table named in `partition` goes to <out_dir>/<name>/year=<y>/data_0.parquet, by calendar year of a date.
#           _overview_tables.parquet  one row per table and view: Oracle's comment and row estimate, what was written,
#                                     what failed and why, and the dump's time, script, commit and driver
#           _overview_fields.parquet  one row per column: Oracle's type, precision, scale and comment
#           _data-dict.yaml           the schema in data-dict's format (https://data-dict.tidyverse.org/): Oracle's
#                                     comments, with types, ranges and examples from the files written
#         Every parquet file carries fd.* stamps in its key/value metadata, read by curated_provenance():
#         fd.source, fd.dumped (the dump's start, its version marker), fd.rows, fd.driver, fd.script, fd.commit, fd.dirty,
#         and fd.note when a column could not be read as the others are (dump_oracle_table()) or held text that is not
#         UTF-8 (.utf8_valid()); the note is also in the overview's `note` and the table's `details` in _data-dict.yaml.
#
# Definitions only: targets sources R/ wholesale, so nothing here may connect at load.
#
# The table-and-view loop used to be copied into six scripts, three in dump/ and three beside the data under
# $FISHYDATA/raw/, and the copies drifted (decision 105). The scripts in dump/oracle/ call these instead.
#
# NUMBER columns are typed by what Oracle declares, not by what the driver returns, so the parquet is the same
# whichever driver read it. The dumps made with ROracle on the servers hold NUMBER(p <= 9, 0) as integers and other
# NUMBERs as doubles. RJDBC returns NUMBER(p, s) as a double, but a NUMBER with scale 0 and no precision (Oracle's
# INTEGER: adb's ids) as text - measured on the adb dump of 2026-10-15, where it broke the station-catch join.

# Columns of a schema (or of one table in it), with Oracle's declared types and comments. The catalogue is read with
# the columns named, never SELECT *: ALL_TAB_COLUMNS holds a LONG (DATA_DEFAULT), which ROracle cannot fetch
# ("unsupported column type", hafdruna 2026-10-16; RJDBC read it as text). `column` is the name in lower case, as the
# files have it; `oracle_column` is Oracle's own spelling, which a query must quote as it is: a column made with
# quotes keeps its case (ops$einarhj.mmsi_icelandic_registry's "stadur" failed as "STADUR", ORA-00904). Two names
# that differ only in case are one name in lower case, so `column` is made unique (.oracle_unique()).
oracle_fields <- function(con, schema, table = NULL) {
  w <- sprintf("OWNER = '%s'", gsub("'", "''", toupper(schema)))
  if (!is.null(table)) w <- sprintf("%s AND TABLE_NAME = '%s'", w, gsub("'", "''", .oracle_part(table)))
  q <- function(sql) DBI::dbGetQuery(con, sql) |> dplyr::rename_with(tolower)
  cols <- q(paste("SELECT TABLE_NAME, COLUMN_NAME, COLUMN_ID, DATA_TYPE, DATA_PRECISION, DATA_SCALE, NULLABLE",
                  "FROM SYS.ALL_TAB_COLUMNS WHERE", w)) |>
    dplyr::rename(table = table_name, column = column_name)
  comm <- q(paste("SELECT TABLE_NAME, COLUMN_NAME, COMMENTS FROM SYS.ALL_COL_COMMENTS WHERE", w)) |>
    dplyr::rename(table = table_name, column = column_name)
  cols |>
    dplyr::left_join(comm, by = c("table", "column")) |>
    dplyr::mutate(owner = tolower(schema), table = tolower(table), oracle_column = column,
                  column = tolower(column), column_id = as.integer(column_id)) |>
    dplyr::relocate(owner) |>
    dplyr::arrange(table, column_id) |>
    dplyr::mutate(column = .oracle_unique(column, oracle_column), .by = table) |>
    tibble::as_tibble()
}

# Oracle's quoted names are case-sensitive and the files' are lower case, so ops$einarhj's raw_index_calc and test,
# with columns N and n, B and b, failed in R ("Names must be unique", hafdruna 2026-10-17). The one spelled in lower
# case keeps its name, or else the first, and the others get _2, _3, ... in column order. dump_oracle_table() notes it.
.oracle_unique <- function(lower, spelled) {
  out <- lower
  for (nm in unique(lower[duplicated(lower)])) {
    i <- which(lower == nm)
    keep <- i[spelled[i] == nm][1]
    if (is.na(keep)) keep <- i[1]
    rest <- setdiff(i, keep)
    out[rest] <- paste0(nm, "_", seq_along(rest) + 1)
  }
  make.unique(out, sep = "_")
}

# Tables and views of a schema, with Oracle's comment and (for tables) its row estimate. Read from the catalogue
# directly: mar::mar_views() calls sql() unqualified, so it fails under Rscript, where dplyr is not attached
# (2026-10-15). `name` is in lower case, as the files have it; `oracle_name` is Oracle's own spelling, which a query
# must quote as it is (.oracle_spelled()).
oracle_objects <- function(con, schema) {
  s <- gsub("'", "''", toupper(schema))
  q <- function(cols, from) DBI::dbGetQuery(con, sprintf("SELECT %s FROM %s WHERE OWNER = '%s'", cols, from, s)) |>
    dplyr::rename_with(tolower)
  tabs <- q("OWNER, TABLE_NAME, TABLESPACE_NAME, NUM_ROWS, LAST_ANALYZED", "SYS.ALL_TABLES") |>
    dplyr::rename(name = table_name) |> dplyr::mutate(type = "table")
  views <- q("OWNER, VIEW_NAME", "SYS.ALL_VIEWS") |>
    dplyr::rename(name = view_name) |> dplyr::mutate(type = "view")
  comm <- q("OWNER, TABLE_NAME, COMMENTS", "SYS.ALL_TAB_COMMENTS")
  objects <- dplyr::bind_rows(tabs, views) |>
    dplyr::mutate(owner = tolower(owner), oracle_name = name, name = tolower(name))
  objects$comments <- comm$comments[match(objects$name, tolower(comm$table_name))]
  objects$num_rows <- as.numeric(objects$num_rows)
  objects |> dplyr::relocate(owner, name, type, comments)
}

# Every table and view the account can see, in every schema: Oracle's comment, its row estimate (tables only; a
# view has none), the number of columns and Oracle's own spelling of the name (oracle_name), from the data
# dictionary alone. No table is read. For choosing what to dump: until 2026-10-17 a schema was found by name, from
# mar's readers or a remark. `oracle_maintained` marks Oracle's own schemas (SYS, MDSYS, ...); NA where the
# database's ALL_USERS has no such column (before 12c).
oracle_catalogue <- function(con) {
  q <- function(sql) DBI::dbGetQuery(con, sql) |> dplyr::rename_with(tolower)
  tabs  <- q("SELECT OWNER, TABLE_NAME, NUM_ROWS, LAST_ANALYZED FROM SYS.ALL_TABLES") |>
    dplyr::rename(name = table_name) |> dplyr::mutate(type = "table")
  views <- q("SELECT OWNER, VIEW_NAME FROM SYS.ALL_VIEWS") |>
    dplyr::rename(name = view_name) |> dplyr::mutate(type = "view")
  comm  <- q("SELECT OWNER, TABLE_NAME, COMMENTS FROM SYS.ALL_TAB_COMMENTS WHERE COMMENTS IS NOT NULL") |>
    dplyr::rename(name = table_name)
  ncol  <- q(paste("SELECT OWNER, TABLE_NAME, COUNT(*) AS N_COLUMNS FROM SYS.ALL_TAB_COLUMNS",
                   "GROUP BY OWNER, TABLE_NAME")) |>
    dplyr::rename(name = table_name)
  users <- tryCatch(q("SELECT USERNAME, ORACLE_MAINTAINED FROM SYS.ALL_USERS"),
                    error = function(e) data.frame(username = character(), oracle_maintained = character()))
  dplyr::bind_rows(tabs, views) |>
    dplyr::left_join(comm, by = c("owner", "name")) |>
    dplyr::left_join(ncol, by = c("owner", "name")) |>
    dplyr::mutate(oracle_maintained = users$oracle_maintained[match(owner, users$username)] == "Y",
                  owner = tolower(owner), oracle_name = name, name = tolower(name),
                  num_rows = as.numeric(num_rows), n_columns = as.integer(n_columns)) |>
    dplyr::relocate(owner, name, type, comments, num_rows, n_columns) |>
    dplyr::arrange(owner, name) |>
    tibble::as_tibble()
}

# The SQL behind a schema's objects, from the data dictionary: one query per dictionary view below, its columns named
# (a column the database lacks fails the query, ORA-00904), the schema's rows only. Each view shows what the account
# may see. Views and their text whatever the owner, since SELECT ANY TABLE reaches them: all 1,574 outside Oracle's
# own schemas (2026-10-22). Stored PL/SQL (ALL_SOURCE) only where the account owns it or may execute it. DBA_VIEWS,
# DBA_SOURCE and DBMS_METADATA.GET_DDL are refused (ORA-00942, ORA-31603: no SELECT_CATALOG_ROLE).
# A view's text, a materialized view's query, a trigger's body and a column's default are LONG. RJDBC reads them
# whole: every view's text as long as TEXT_LENGTH says (all 617 of the dumped schemas, 2026-10-22). TEXT_VC cut 27 of
# the views at 4,000 bytes, and ROracle cannot fetch a LONG at all (oracle_fields()). A query with a LONG is fetched a
# row at a time, about 55 ms a row (2026-10-22), so a column's default (`long`) is read in a second query, only where
# Oracle says there is one, and joined on: the 21,869 columns of the dumped schemas would take 20 minutes.
# A trigger is the schema's when it owns the trigger or its table, so one on another dumped schema's table is in both
# files. A synonym is the schema's when it owns it, or when it is a public one naming the schema's object.
.oracle_code <- list(
  all_objects = list(
    cols = c("OWNER", "OBJECT_NAME", "SUBOBJECT_NAME", "OBJECT_TYPE", "STATUS", "CREATED", "LAST_DDL_TIME"),
    where = "OWNER = %1$s", order = "OBJECT_TYPE, OBJECT_NAME, SUBOBJECT_NAME"),
  all_tab_columns = list(
    cols = c("OWNER", "TABLE_NAME", "COLUMN_NAME", "COLUMN_ID", "DATA_TYPE", "DATA_TYPE_OWNER", "DATA_LENGTH",
             "CHAR_LENGTH", "CHAR_USED", "DATA_PRECISION", "DATA_SCALE", "NULLABLE", "IDENTITY_COLUMN",
             "DEFAULT_ON_NULL", "DEFAULT_LENGTH"),
    where = "OWNER = %1$s", order = "TABLE_NAME, COLUMN_ID",
    long = list(col = "DATA_DEFAULT", by = c("TABLE_NAME", "COLUMN_NAME"), when = "DEFAULT_LENGTH > 0")),
  all_col_comments = list(
    cols = c("OWNER", "TABLE_NAME", "COLUMN_NAME", "COMMENTS"),
    where = "OWNER = %1$s", order = "TABLE_NAME, COLUMN_NAME"),
  all_views = list(
    cols = c("OWNER", "VIEW_NAME", "TEXT_LENGTH", "TEXT"),
    where = "OWNER = %1$s", order = "VIEW_NAME"),
  all_mviews = list(
    cols = c("OWNER", "MVIEW_NAME", "CONTAINER_NAME", "QUERY_LEN", "QUERY", "MASTER_LINK", "REFRESH_MODE",
             "REFRESH_METHOD", "BUILD_MODE", "LAST_REFRESH_TYPE", "LAST_REFRESH_DATE", "STALENESS", "COMPILE_STATE"),
    where = "OWNER = %1$s", order = "MVIEW_NAME"),
  all_source = list(
    cols = c("OWNER", "NAME", "TYPE", "LINE", "TEXT"),
    where = "OWNER = %1$s", order = "NAME, TYPE, LINE"),
  all_triggers = list(
    cols = c("OWNER", "TRIGGER_NAME", "TRIGGER_TYPE", "TRIGGERING_EVENT", "TABLE_OWNER", "BASE_OBJECT_TYPE",
             "TABLE_NAME", "COLUMN_NAME", "REFERENCING_NAMES", "WHEN_CLAUSE", "STATUS", "DESCRIPTION", "ACTION_TYPE",
             "TRIGGER_BODY"),
    where = "OWNER = %1$s OR TABLE_OWNER = %1$s", order = "OWNER, TRIGGER_NAME"),
  all_synonyms = list(
    cols = c("OWNER", "SYNONYM_NAME", "TABLE_OWNER", "TABLE_NAME", "DB_LINK"),
    where = "OWNER = %1$s OR (OWNER = 'PUBLIC' AND TABLE_OWNER = %1$s)", order = "OWNER, SYNONYM_NAME"),
  all_dependencies = list(
    cols = c("OWNER", "NAME", "TYPE", "REFERENCED_OWNER", "REFERENCED_NAME", "REFERENCED_TYPE",
             "REFERENCED_LINK_NAME", "DEPENDENCY_TYPE"),
    where = "OWNER = %1$s", order = "NAME, TYPE, REFERENCED_OWNER, REFERENCED_NAME, REFERENCED_TYPE")
)

# One dictionary view of .oracle_code (`source`, e.g. "all_views"), for one schema, as Oracle holds it: names in lower
# case, as the dumps have them; the text whole, as the driver returns it.
oracle_code <- function(con, schema, source) {
  s <- .oracle_code[[source]]
  if (is.null(s)) stop("not a dictionary view oracle_code() reads: ", source, call. = FALSE)
  where <- sprintf(s$where, .sql_string(toupper(schema)))
  get <- function(cols, where, order) {
    sql <- sprintf("SELECT %s FROM SYS.%s WHERE %s%s", paste0('"', cols, '"', collapse = ", "), toupper(source), where,
                   if (is.null(order)) "" else paste(" ORDER BY", order))
    DBI::dbGetQuery(con, sql) |> dplyr::rename_with(tolower) |> tibble::as_tibble()
  }
  d <- get(s$cols, where, s$order)
  if (!is.null(s$long)) {
    l <- get(c("OWNER", s$long$by, s$long$col), sprintf("(%s) AND %s", where, s$long$when), NULL)
    d <- dplyr::left_join(d, l, by = tolower(c("OWNER", s$long$by)), relationship = "one-to-one")
  }
  num <- c("text_length", "query_len", "line", "column_id", "data_length", "char_length", "data_precision",
           "data_scale", "default_length")
  for (v in intersect(num, names(d))) d[[v]] <- as.numeric(d[[v]])
  d
}

# The connection every dump uses, through RJDBC (Oracle's JDBC driver, in Java) or ROracle (Oracle's client library).
# The driver comes from FD_DUMP_DRIVER, which run_dump(driver = ) sets, so a dump script, its reconnect and its LOB
# connection all use one driver. RJDBC is the default: it is the only one on the Mac (decisions 106, 109).
#
# RJDBC: rJava starts the JVM with a 0.5 GB heap under Rscript (measured 2026-10-15), and adb's tables exhausted it.
# The JVM also reads Oracle's DATE (no time zone) through its own zone: in Atlantic/Reykjavik a date before 1912 moves
# 16 min 8 s (measured 2026-10-15), and on a machine elsewhere every date would move. In UTC a date comes through as
# Oracle holds it. Both settings take effect only before the JVM starts, so they are set here, first; in a session
# where rJava already runs (RStudio after an earlier dump), restart R.
#
# ROracle: DATE is read through R's time zone (TZ) and Oracle's session time zone (ORA_SDTZ), so both are set to UTC
# before connecting; in an interactive session this changes how R prints times. mar::connect_mar() falls back to
# RJDBC without a word when ROracle is not installed, so the connection's driver is checked.
#
# Either way a DATE before 1912 is read back first, the way a dump writes it (.oracle_check_time()).
# The JVM in UTC was not enough: on 2026-10-16 that check stopped ask and kvoti, a 1900 DATE coming through 16 min
# 8 s late with the JVM in UTC, and 84 files of the RJDBC dumps of 2026-10-15 carry the shift (decision 109). So the
# whole process runs in UTC, R included, whatever the driver; run_dump() also sets it before R starts.
#
# ROracle's text passes through Oracle's client, which converts it to the character set of NLS_LANG: unset, that is
# commonly plain ASCII, and þ, æ, ö, ð come out as '?'. AMERICAN_AMERICA.AL32UTF8 gives UTF-8, and a decimal point in
# the text retry's TO_CHAR (an Icelandic territory gives a comma). .oracle_check_text() checks it (ROracle only).
dump_connect <- function(driver = Sys.getenv("FD_DUMP_DRIVER", "RJDBC"), heap = "8g") {
  driver <- match.arg(driver, c("RJDBC", "ROracle"))
  Sys.setenv(TZ = "UTC", ORA_SDTZ = "UTC", NLS_LANG = "AMERICAN_AMERICA.AL32UTF8")
  if (driver == "ROracle") {
    if (!requireNamespace("ROracle", quietly = TRUE)) stop("ROracle is not installed here", call. = FALSE)
    con <- mar::connect_mar(rjdbc = FALSE)
    message(sprintf("ROracle %s, time zone: %s", utils::packageVersion("ROracle"), Sys.getenv("TZ")))
  } else {
    options(java.parameters = c(paste0("-Xmx", heap), "-Duser.timezone=UTC"))
    con <- mar::connect_mar(rjdbc = TRUE)
    rt <- rJava::.jcall("java/lang/Runtime", "Ljava/lang/Runtime;", "getRuntime")
    tz <- rJava::.jcall(rJava::.jcall("java/util/TimeZone", "Ljava/util/TimeZone;", "getDefault"), "S", "getID")
    message(sprintf("JVM heap: %.1f GB, time zone: %s", rJava::.jcall(rt, "J", "maxMemory") / 2^30, tz))
    if (tz != "UTC") warning("the JVM is not in UTC (it started before dump_connect()): restart R", call. = FALSE)
  }
  if (.oracle_driver(con) != driver)
    stop(sprintf("asked for %s, connected through %s", driver, .oracle_driver(con)), call. = FALSE)
  .oracle_check_time(con)
  if (driver == "ROracle") .oracle_check_text(con)
  con
}

# Icelandic letters made in Oracle (UNISTR) must come back as UTF-8, or the dump stops before it writes anything.
# ROracle only: RJDBC's strings are Java's, and its dumps of 2026-10-15 hold þ, æ, ö and ð (1,604 of vessel's 7,047
# names, none with '?').
.oracle_check_text <- function(con) {
  want <- "\u00fe\u00e6\u00f6\u00d0"
  got <- DBI::dbGetQuery(con, "SELECT CAST(UNISTR('\\00FE\\00E6\\00F6\\00D0') AS VARCHAR2(16)) AS S FROM DUAL")[[1]]
  got <- enc2utf8(as.character(got))
  if (!identical(got, want))
    stop("Icelandic letters made in Oracle (U+00FE U+00E6 U+00F6 U+00D0) came back as '", got, "' (NLS_LANG ",
         Sys.getenv("NLS_LANG"), ", R locale ",
         Sys.getlocale("LC_CTYPE"), "): text would not be dumped as UTF-8", call. = FALSE)
  message("text check: Icelandic letters come through (", got, ")")
  invisible(TRUE)
}

# A DATE goes through the driver and DuckDB as a dump writes it, and must come out as Oracle holds it; else the dump
# stops before it writes anything.
.oracle_check_time <- function(con) {
  d <- DBI::dbGetQuery(con, "SELECT TO_DATE('1900-01-01 12:00:00', 'YYYY-MM-DD HH24:MI:SS') AS D FROM DUAL")
  names(d) <- "d"
  raw <- sprintf("%s %s", class(d$d)[1], if (inherits(d$d, "POSIXct")) format(d$d, "%Y-%m-%d %H:%M:%S %Z") else d$d)
  dk <- .duckdb_quiet()
  on.exit(DBI::dbDisconnect(dk, shutdown = TRUE), add = TRUE)
  duckdb::duckdb_register(dk, "t", d)
  got <- DBI::dbGetQuery(dk, "SELECT CAST(CAST(d AS TIMESTAMP) AS VARCHAR) AS v FROM t")$v
  if (!identical(got, "1900-01-01 12:00:00"))
    stop("a DATE of 1900-01-01 12:00:00 would be written as ", got, " (the driver returned ", raw, ", R's time zone ",
         Sys.getenv("TZ"), "): somewhere dates are read through a time zone other than UTC", call. = FALSE)
  message("date check: a 1900 DATE comes through as ", got, " (the driver returned ", raw, ")")
  invisible(TRUE)
}

.oracle_numbers <- function(d, fields) {
  num <- fields$column[fields$data_type %in% "NUMBER"]
  int <- fields$column[fields$data_type %in% "NUMBER" &
                       fields$data_scale %in% 0 &
                       !is.na(fields$data_precision) & fields$data_precision <= 9]
  for (v in intersect(num, names(d))) {
    x <- d[[v]]
    if (is.character(x)) {
      y <- suppressWarnings(as.numeric(x))
      # a double holds integers exactly up to 2^53; past that a whole NUMBER, or any value that does not parse, is
      # kept as text. A decimal NUMBER is a double past 2^53 too, as RJDBC returns it.
      whole <- v %in% fields$column[fields$data_type %in% "NUMBER" & fields$data_scale %in% 0]
      if (any(is.na(y) & !is.na(x)) || (whole && any(abs(y) > 2^53, na.rm = TRUE))) {
        message("  ", v, ": NUMBER returned as text and kept as text (not every value converts exactly)")
        next
      }
      x <- y
    }
    if (v %in% int && is.double(x)) x <- as.integer(x)
    d[[v]] <- x
  }
  d
}

.oracle_driver <- function(con) if (inherits(con, "JDBCConnection")) "RJDBC" else "ROracle"

# What every file of one dump is stamped with. `dumped` is the dump's start: the version marker.
.dump_run <- function(con, script) {
  g <- .git_info()
  list(dumped = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), driver = .oracle_driver(con),
       script = script, commit = g$commit, dirty = tolower(as.character(g$dirty)))
}

# A string as an SQL literal, quotes doubled. shQuote(type = "sh") is shell quoting: it can give double quotes with
# backslash escapes (for a whole vector, once one element holds an apostrophe; on hafdruna it did so for the stamps of
# ops$einarhj."heildarafli"), which DuckDB does not read once a value holds a double quote: that write failed
# (2026-10-17).
.sql_string <- function(x) paste0("'", gsub("'", "''", x, fixed = TRUE), "'")

# Write a frame as parquet (plain TIMESTAMP) with fd.* stamps in its key/value metadata. Text that is not valid UTF-8
# is made valid first and the note says so (.utf8_valid()), as does the note of a frame made valid before. Returns the
# note written, NA for none, invisibly.
.write_raw <- function(d, path, source, run, note = NA_character_) {
  d <- .utf8_valid(d)
  note <- paste(stats::na.omit(c(note, attr(d, "note"))), collapse = "; ")
  if (!nzchar(note)) note <- NA_character_
  kv <- c("fd.source" = source, "fd.dumped" = run$dumped, "fd.rows" = as.character(nrow(d)),
          "fd.driver" = run$driver, "fd.script" = run$script, "fd.commit" = run$commit, "fd.dirty" = run$dirty,
          "fd.note" = note)
  kv <- kv[!is.na(kv)]
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- .duckdb_quiet()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  duckdb::duckdb_register(con, "d", d)
  meta <- paste(sprintf("%s: %s", .sql_string(names(kv)), .sql_string(unname(kv))), collapse = ", ")
  DBI::dbExecute(con, sprintf("COPY d TO %s (FORMAT parquet, KV_METADATA {%s})", .sql_string(path), meta))
  invisible(note)
}

# Oracle can hold text that is not UTF-8 in a UTF-8 database: bytes stored as a client sent them, most likely one that
# said UTF-8 and sent Latin-1, which no driver converts on the way out. DuckDB then refuses the whole parquet file,
# since its text must be UTF-8. Two files of the dumps of 2026-10-16/17 did so: kvoti.kvotategundir_heiti_jn, whose
# insert of 2019-06-28 holds "Makr\xEDll" (Latin-1 í; the table corrected it an hour later), so that kvoti's
# _data-dict.yaml was never written, and ops$einarhj.ices_landed_catch (decision 167). A byte that is not part of a
# valid UTF-8 sequence is read as Windows-1252 (Latin-1 with printable 0x80-0x9F), or as Latin-1 where 1252 has no
# character; valid sequences are kept. The note names the columns, the values and the bytes, so the bytes Oracle holds
# can be told. Returns d, with the note as attribute "note" when a value was changed.
.utf8_valid <- function(d) {
  said <- character()
  for (v in names(d)[vapply(d, is.character, NA)]) {
    x <- d[[v]]
    bad <- which(!is.na(x) & !validUTF8(x))
    if (!length(bad)) next
    fixed <- lapply(x[bad], .utf8_repair)
    d[[v]][bad] <- vapply(fixed, `[[`, "", 1)
    bytes <- sort(unique(unlist(lapply(fixed, `[[`, 2))))
    said[v] <- sprintf("%s (%s %s; bytes %s)", v, format(length(bad), big.mark = ",", trim = TRUE),
                       if (length(bad) == 1) "value" else "values", paste(bytes, collapse = " "))
  }
  if (length(said))
    attr(d, "note") <- paste("text not valid UTF-8, as Oracle holds it, in", paste(said, collapse = ", "),
                             "- each byte outside a valid UTF-8 sequence read as Windows-1252")
  d
}

# One string, its stray bytes read as Windows-1252: the string and the stray bytes in hex.
.utf8_repair <- function(s) {
  b <- charToRaw(s)
  n <- length(b)
  out <- character(); stray <- character()
  i <- 1L
  while (i <= n) {
    x <- as.integer(b[i])
    k <- if (x < 0x80) 1L else if (x >= 0xC2 && x <= 0xDF) 2L else if (x >= 0xE0 && x <= 0xEF) 3L
         else if (x >= 0xF0 && x <= 0xF4) 4L else 0L
    if (k && i + k - 1L <= n && validUTF8(rawToChar(b[i:(i + k - 1L)]))) {
      out <- c(out, rawToChar(b[i:(i + k - 1L)]))
      i <- i + k
      next
    }
    ch <- iconv(rawToChar(b[i]), "CP1252", "UTF-8")
    if (is.na(ch)) ch <- iconv(rawToChar(b[i]), "latin1", "UTF-8")
    out <- c(out, ch); stray <- c(stray, sprintf("%02X", x))
    i <- i + 1L
  }
  s <- paste(out, collapse = "")
  Encoding(s) <- "UTF-8"
  list(s, stray)
}

# Columns the driver cannot fetch are read as text in Oracle's own form: SDO_GEOMETRY as WKT, XMLTYPE as the document.
# adb.fishing_station's location (SDO_GEOMETRY) failed every earlier dump; afli's XML table needed its own query.
# The WKT is cast to VARCHAR2: as a CLOB, each of fishing_station's 690,912 rows left a temporary LOB in the session,
# and the next query waited on Oracle for over 15 min (2026-10-15), most likely while it freed them. A geometry whose
# WKT passes 4,000 characters then fails loudly (ORA-22835) rather than being cut, and its table is read again with
# the WKT as a CLOB (dump_oracle_table()). An XML document is longer than that, so it stays a CLOB, read on a
# connection of its own that is closed before the LOBs are released.
.oracle_text <- c(SDO_GEOMETRY = "TO_CHAR(SDO_UTIL.TO_WKTGEOMETRY(%s))", XMLTYPE = "XMLSERIALIZE(DOCUMENT %s AS CLOB)")
.oracle_lob <- "XMLTYPE"

# The table as a lazy query: every column as it is, those in .oracle_text converted to text under their own name.
# With numbers_as_text, every NUMBER comes as TO_CHAR too (the retry in dump_oracle_table()). Through ROracle a NUMBER
# that may hold decimals (scale not 0) always comes as TO_CHAR, the exact decimal, which .oracle_numbers() turns into
# the nearest double: ROracle's own conversion lands a step off for some values (power_kw 60.3 came through as
# 60.3000000000000043, RJDBC's 60.2999999999999972 is the nearest double; 198 of vessel's 7,047, hafdruna 2026-10-16),
# and then x == 60.3 is FALSE. A whole NUMBER (scale 0) is exact either way. The columns in `native` come as the driver
# returns them: Oracle cannot write some of their values as text (dump_oracle_table()). The columns in `nul` come
# without their NUL characters, which R cannot hold (.oracle_nul()); in Oracle, '' is NULL, so REPLACE drops them.
# `geometry` is how an SDO_GEOMETRY comes: "text" (WKT, at most 4,000 characters), "clob" (WKT of any length) or
# "parts" (as stored, .oracle_parts()).
.oracle_query <- function(con, table, fields, numbers_as_text = FALSE, native = character(), nul = character(),
                          geometry = "text") {
  conv <- c(.oracle_text, if (numbers_as_text) c(NUMBER = "TO_CHAR(%s)"))
  if (geometry == "clob") conv["SDO_GEOMETRY"] <- "SDO_UTIL.TO_WKTGEOMETRY(%s)"
  decimal <- .oracle_driver(con) == "ROracle" & fields$data_type %in% "NUMBER" & !(fields$data_scale %in% 0) &
             !fields$column %in% native
  renamed <- !is.null(fields$oracle_column) && any(fields$column != tolower(fields$oracle_column))
  if (!any(fields$data_type %in% names(conv)) && !any(decimal) && !length(nul) && !renamed)
    return(mar::tbl_mar(con, table))
  o <- order(fields$column_id)
  fields <- fields[o, ]
  decimal <- decimal[o]
  quoted <- .oracle_name(fields)
  parts <- geometry == "parts"
  cols <- vapply(seq_len(nrow(fields)), function(i) {
    q <- quoted[i]
    if (parts && fields$data_type[i] %in% "SDO_GEOMETRY") return(.oracle_parts(q, fields$column[i]))
    f <- if (decimal[i]) "TO_CHAR(%s)" else if (fields$column[i] %in% nul) "REPLACE(%s, CHR(0), '')"
         else conv[fields$data_type[i]]
    paste(if (is.na(f)) q else sprintf(f, q), "AS", sprintf('"%s"', fields$column[i]))
  }, "")
  from <- paste0(.oracle_ref(table), if (parts) " t")
  dplyr::tbl(con, dplyr::sql(sprintf("SELECT %s FROM %s", paste(cols, collapse = ", "), from))) |>
    dplyr::rename_with(tolower)
}

# An SDO_GEOMETRY as Oracle stores it, for a table where Oracle cannot write one as WKT: channel.station holds 148,842
# lines (gtype 2002) whose element type, 1003, is a polygon's, and TO_WKTGEOMETRY raises ORA-13199 (hafdruna,
# 2026-10-21). Each geometry becomes seven columns: <col>_gtype, _srid, the point's _x, _y and _z, and _elem_info and
# _ordinates as comma-separated lists. Every number comes through TO_CHAR with a decimal point whatever the session's
# territory, since a comma separates the lists; .oracle_parts_typed() makes numbers of the first five. An attribute is
# reached only through a table alias (t, .oracle_query()), and Oracle rejects these subqueries in a GROUP BY. LISTAGG
# raises ORA-01489 past 4,000 bytes rather than cut a geometry; station's hold 4 ordinates at most.
.oracle_parts <- function(quoted, column) {
  g <- paste0("t.", quoted)
  num <- function(x) sprintf("TO_CHAR(%s, 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')", x)
  arr <- function(a) sprintf("(SELECT LISTAGG(%s, ',') WITHIN GROUP (ORDER BY ROWNUM) FROM TABLE(%s.%s) e)",
                             num("e.COLUMN_VALUE"), g, a)
  expr <- c(num(paste0(g, c(".SDO_GTYPE", ".SDO_SRID", ".SDO_POINT.X", ".SDO_POINT.Y", ".SDO_POINT.Z"))),
            arr("SDO_ELEM_INFO"), arr("SDO_ORDINATES"))
  paste(expr, "AS", sprintf('"%s_%s"', column, c("gtype", "srid", "x", "y", "z", "elem_info", "ordinates")),
        collapse = ", ")
}

.oracle_parts_typed <- function(d, geo) {
  for (g in geo) {
    for (p in c("gtype", "srid")) d[[paste0(g, "_", p)]] <- as.integer(d[[paste0(g, "_", p)]])
    for (p in c("x", "y", "z")) d[[paste0(g, "_", p)]] <- as.numeric(d[[paste0(g, "_", p)]])
  }
  d
}

# Columns as a query must name them: Oracle's own spelling, quoted.
.oracle_name <- function(fields) {
  nm <- if (is.null(fields$oracle_column)) toupper(fields$column) else fields$oracle_column
  sprintf('"%s"', gsub('"', '""', nm))
}

# A table as a query must name it, "SCHEMA"."NAME", from "schema.name": in upper case, as Oracle folds a name made
# without quotes, unless a part is given in quotes, which keeps its spelling (the convention of mar::tbl_mar()).
# ops$einarhj's heildarafli, raw_index_calc and test were made from R with quoted lower-case names, and
# "OPS$EINARHJ"."HEILDARAFLI" does not exist (ORA-00942, hafdruna 2026-10-17).
.oracle_part <- function(x) ifelse(grepl('"', x, fixed = TRUE), gsub('"', "", x, fixed = TRUE), toupper(x))
.oracle_ref <- function(table) {
  x <- .oracle_part(strsplit(table, ".", fixed = TRUE)[[1]])
  sprintf('"%s"."%s"', x[1], x[2])
}
# An object's name as dump_oracle_schema() passes it on: lower case where Oracle's spelling is upper case, so the
# usual name is unchanged, and quoted otherwise.
.oracle_spelled <- function(name) ifelse(name == toupper(name), tolower(name), sprintf('"%s"', name))

# The text columns of a table that hold a NUL character (CHR(0)), with the number of values that do, in one scan.
# R's strings cannot hold NUL, so such a table fails whatever the driver: uv.veidisvaedi ("embedded nul in string",
# ROracle, hafdruna 2026-10-17), and kvoti's adili_jn and eftirlits_gjald_utan_ees (decision 109). Not a CLOB:
# fs_afladagbok's takt_json_form holds signed PDF files there, whose NULs are their content.
.oracle_nul <- function(con, table, fields) {
  txt <- fields[fields$data_type %in% c("VARCHAR2", "CHAR", "NVARCHAR2", "NCHAR"), ]
  if (!nrow(txt)) return(stats::setNames(numeric(), character()))
  has <- paste0("SUM(CASE WHEN INSTR(", .oracle_name(txt), ", CHR(0)) > 0 THEN 1 ELSE 0 END)", collapse = ", ")
  q <- sprintf("SELECT %s FROM %s", has, .oracle_ref(table))
  n <- as.numeric(unlist(DBI::dbGetQuery(con, q), use.names = FALSE))
  n <- stats::setNames(n, txt$column)
  n[!is.na(n) & n > 0]
}

# The decimal NUMBERs of a table whose TO_CHAR fails (ORA-01722): Oracle cannot write some stored value of theirs as
# text. One scan of the table per decimal column.
.oracle_untextable <- function(con, table, fields) {
  dec <- fields[fields$data_type %in% "NUMBER" & !(fields$data_scale %in% 0), ]
  bad <- vapply(.oracle_name(dec), function(q) inherits(tryCatch(
    DBI::dbGetQuery(con, sprintf("SELECT MAX(LENGTH(TO_CHAR(%s))) FROM %s", q, .oracle_ref(table))),
    error = function(e) e), "error"), NA)
  dec$column[bad]
}

# What came through for columns read as the driver returns them: Oracle's count of their values against the values
# fetched, as a note for the file. The counts are read by position, as Oracle names unquoted aliases in capitals.
.oracle_note_native <- function(con, table, fields, native, d) {
  f <- fields[match(native, fields$column), ]
  q <- sprintf("SELECT COUNT(*), %s FROM %s", paste0("COUNT(", .oracle_name(f), ")", collapse = ", "),
               .oracle_ref(table))
  held <- tryCatch(as.numeric(unlist(DBI::dbGetQuery(con, q), use.names = FALSE)), error = function(e) NULL)
  note <- sprintf("TO_CHAR fails on %s (ORA-01722): read as the driver's doubles, not as exact text",
                  paste(native, collapse = ", "))
  if (is.null(held)) return(paste0(note, "; Oracle could not count them"))
  got <- vapply(native, function(v) sum(!is.na(d[[v]])), 0)
  note <- paste0(note, "; values Oracle holds that are empty here: ",
                 paste(sprintf("%s %s", native, format(held[-1] - got, big.mark = ",", trim = TRUE)), collapse = ", "))
  if (held[1] != nrow(d)) note <- paste0(note, sprintf(" (Oracle counted %s rows, %s were fetched)",
                                                       format(held[1], big.mark = ","), format(nrow(d), big.mark = ",")))
  note
}

# Run a lazy query through DBI rather than dplyr::collect(): when the driver throws a Java exception, collect()'s error
# wrapper fails on the exception object ("no field, method or inner class called 'use_cli_format'", agf 2026-10-15)
# and Oracle's message is lost.
.oracle_collect <- function(con, q) tibble::as_tibble(DBI::dbGetQuery(con, dbplyr::sql_render(q)))

# One table or view ("schema.name") to one parquet file, as it is. Reports and returns the rows written.
# A table whose fetch fails is fetched once more with its numbers as text: afli.afli (15.7 M rows) failed through RJDBC
# with java.lang.ArrayIndexOutOfBoundsException (2026-10-15), most likely the driver parsing a malformed NUMBER, which
# ROracle on the server had read. .oracle_numbers() turns the text back into numbers, and names any column it cannot.
# Through ROracle the same table fails otherwise: Oracle's own TO_CHAR, which reads decimals exactly (.oracle_query()),
# raises ORA-01722 on afli.afli and v_afli (hafdruna 2026-10-16), most likely on malformed stored NUMBERs, which an
# April dump with ROracle had read natively. The columns at fault are then found one by one and read natively; the
# note says which, and how many of their values Oracle holds that came through empty.
# A table with NUL characters in its text fails in R itself ("embedded nul in string"): it is fetched once more with
# them removed from the columns that hold them, and the note says which and in how many values (.oracle_nul()).
# A table whose geometry's WKT passes 4,000 characters (ORA-22835: channel.country, one of 17 at 26,220) is fetched
# once more with the WKT as a CLOB, on a connection of its own, as XMLTYPE is (.oracle_text). A table with a geometry
# Oracle cannot write as WKT at all (a spatial error, ORA-13000 to 13499: channel.station's ORA-13199) is fetched with
# each geometry as stored (.oracle_parts()), and so is one whose CLOB fetch fails so. The note says which.
# Returns the rows written, with the note, if any, as attribute "note".
dump_oracle_table <- function(con, table, path, fields = NULL, run = NULL) {
  if (is.null(fields)) {
    x <- strsplit(table, ".", fixed = TRUE)[[1]]
    fields <- oracle_fields(con, x[1], x[2])
  }
  if (is.null(run)) run <- .dump_run(con, NA_character_)
  fetch <- function(numbers_as_text, native = character(), nul = character(), geometry = "text") {
    if (any(fields$data_type %in% .oracle_lob) || geometry == "clob") {
      lc <- dump_connect()
      tryCatch(.oracle_collect(lc, .oracle_query(lc, table, fields, numbers_as_text, native, nul, geometry)),
               finally = DBI::dbDisconnect(lc))
    } else {
      .oracle_collect(con, .oracle_query(con, table, fields, numbers_as_text, native, nul, geometry))
    }
  }
  clean <- function(e) gsub("\033\\[[0-9;]*m", "", conditionMessage(e))
  geo <- fields$column[fields$data_type %in% "SDO_GEOMETRY"]
  note <- NA_character_
  d <- tryCatch(fetch(FALSE), error = function(e) {
    msg <- clean(e)
    if (length(geo) && grepl("ORA-22835", msg)) {
      message(sprintf("%s: a WKT passes 4,000 characters (ORA-22835) - fetching %s again as a CLOB", table,
                      paste(geo, collapse = ", ")))
      d <- tryCatch(fetch(FALSE, geometry = "clob"), error = function(e) e)
      if (!inherits(d, "error")) {
        long <- vapply(geo, function(g) max(c(0, nchar(d[[g]])), na.rm = TRUE), 0)
        note <<- sprintf(paste("%s read as WKT in a CLOB, on a connection of its own: a WKT passes 4,000 characters",
                               "(ORA-22835)"), paste(sprintf("%s (longest %s characters)", geo,
                                                             format(long, big.mark = ",", trim = TRUE)),
                                                     collapse = ", "))
        return(d)
      }
      e <- d
      msg <- clean(e)
    }
    if (length(geo) && grepl("ORA-13[0-4][0-9]{2}", msg)) {
      # ASCII only: through RJDBC the message ends in Java's encoding of a NUL (C0 80), which went into the note
      ora <- regmatches(msg, regexpr("ORA-13[0-4][0-9]{2}:[ -~]*", msg, useBytes = TRUE))
      note <<- sprintf(paste("Oracle cannot write %s as WKT (%s): read as stored, each in <column>_gtype, _srid,",
                             "_x, _y, _z (its point), _elem_info and _ordinates (comma-separated, in Oracle's order)"),
                       paste(geo, collapse = ", "), ora)
      message(sprintf("%s: %s - fetching again", table, note))
      return(.oracle_parts_typed(fetch(FALSE, geometry = "parts"), geo))
    }
    if (grepl("embedded nul|null byte", msg)) {
      nul <- .oracle_nul(con, table, fields)
      if (!length(nul)) stop(e)
      note <<- sprintf(paste("NUL characters (CHR(0)) removed from %s: R cannot hold them; a value of NULs only is",
                             "empty here"), paste(sprintf("%s (%s values)", names(nul),
                                                          format(nul, big.mark = ",", trim = TRUE)), collapse = ", "))
      message(sprintf("%s: %s - fetching again", table, note))
      return(fetch(FALSE, nul = names(nul)))
    }
    if (.oracle_driver(con) == "ROracle" && grepl("ORA-01722", msg)) {
      native <- .oracle_untextable(con, table, fields)
      if (!length(native)) stop(e)
      message(sprintf("%s: TO_CHAR fails on %s (ORA-01722) - fetching %s as the driver returns %s", table,
                      paste(native, collapse = ", "), if (length(native) > 1) "them" else "it",
                      if (length(native) > 1) "them" else "it"))
      d <- fetch(FALSE, native)
      note <<- .oracle_note_native(con, table, fields, native, d)
      return(d)
    }
    if (!any(fields$data_type %in% "NUMBER")) stop(e)
    message(sprintf("%s: %s - fetching again with its numbers as text", table, msg))
    fetch(TRUE)
  })
  d <- .oracle_numbers(d, fields)
  ren <- !is.null(fields$oracle_column) & fields$column != tolower(fields$oracle_column)
  if (any(ren)) {
    cased <- paste(sprintf('"%s" is %s here', fields$oracle_column[ren], fields$column[ren]), collapse = ", ")
    note <- paste(stats::na.omit(c(note, paste("names that differ only in case in Oracle:", cased))), collapse = "; ")
  }
  note <- .write_raw(d, path, table, run, note)
  message(sprintf("%s: %s rows", table, format(nrow(d), big.mark = ",")))
  if (!is.na(note)) message("  ", note)
  structure(nrow(d), note = note)
}

# A table too big for one collect(), by calendar year of `column`, to <dir>/year=<y>/data_0.parquet. A year is fetched
# again until it has been dumped after it ended, read from the partition's own fd.dumped stamp: a year dumped while
# it was running is completed on the next run, whatever the column (a logger may record nothing on 31 December).
# Returns the rows written in this run, with the notes of its years, if any, as attribute "note".
dump_oracle_by_year <- function(con, table, dir, column, fields, run) {
  q <- .oracle_query(con, table, fields)
  span <- .oracle_collect(con, q |> dplyr::summarise(a = min(.data[[column]], na.rm = TRUE), b = max(.data[[column]], na.rm = TRUE)))
  years <- seq(as.integer(format(as.POSIXct(span$a), "%Y")), as.integer(format(as.POSIXct(span$b), "%Y")))
  n <- 0
  notes <- character()
  for (y in years) {
    f <- file.path(dir, paste0("year=", y), "data_0.parquet")
    if (file.exists(f)) {
      # a year file cut off mid-write has no readable footer, and one of the other driver is not mixed in: both redone
      m <- tryCatch(curated_provenance(f), error = function(e) NULL)
      d0 <- m$value[m$key == "fd.dumped"]
      # a kept year counts too: afli.sjalfvirkir_maelar's overview said 2,714 rows after a resume, of 28,234,223
      if (length(d0) && identical(m$value[m$key == "fd.driver"], run$driver) &&
          as.Date(substr(d0, 1, 10)) > as.Date(sprintf("%d-12-31", y))) {
        n <- n + sum(as.numeric(m$value[m$key == "fd.rows"]))
        next
      }
    }
    d <- .oracle_collect(con, q |>
      dplyr::filter(.data[[column]] >= to_date(!!sprintf("%d-01-01", y), "YYYY-MM-DD"),
                    .data[[column]] <  to_date(!!sprintf("%d-01-01", y + 1), "YYYY-MM-DD")))
    d <- .oracle_numbers(d, fields)
    nt <- .write_raw(d, f, table, run)
    message(sprintf("%s, %d: %s rows", table, y, format(nrow(d), big.mark = ",")))
    if (!is.na(nt)) {
      message("  ", nt)
      notes <- c(notes, sprintf("%d: %s", y, nt))
    }
    n <- n + nrow(d)
  }
  if (length(notes)) structure(n, note = paste(notes, collapse = "; ")) else n
}

# The schema in data-dict's format, beside the files: Oracle's comments, types from the files, ranges from the whole
# file and examples from its first 10,000 rows (from the whole file where those hold none). Examples are data, so the
# yaml is handled as the data are. The hand-kept overlay (dump/oracle/meta/<folder>.yml, plan 040) is laid over it by
# .data_dict_merge() (R/data_dict.R); one that cannot be read is named in the dictionary's todo, and the dictionary is
# written without it, so a faulty overlay never costs a dump its dictionary. `rewritten` is set by rewrite_data_dict().
#
# Two of the spec's errors were the writer's (plan 040 §2, measured 2026-10-22):
#   S12  a datetime's range written "2003-06-18 17:56:20", or "2003-06-18" at midnight: it is ISO 8601 with Z, or
#        zoneless where the overlay gives a time_zone; and text examples that YAML 1.2 reads as numbers, unquoted by
#        R's yaml (1.1) writer ("62E5", "1e5"), which are now always quoted
#   S07  a column with no examples or range: one with no value in the whole file is kept by name only, with Oracle's
#        declared type in details and a todo (plan 040, ask f, the reversible option: the next dump with a value
#        types it again); one whose values all lie past the first 10,000 rows takes its examples from the whole file,
#        the five smallest: a DISTINCT alone returns them in a different order each run, and a rewrite moved them
# Returns, invisibly, one row per column: its type, the values the file holds, and whether the first 10,000 rows held
# one (plan 040 §5).
.write_data_dict <- function(out_dir, schema, objects, fields, run, overlay = .data_dict_overlay(basename(out_dir)),
                             rewritten = NULL) {
  num_type <- "^(TINYINT|SMALLINT|INTEGER|BIGINT|HUGEINT|UTINYINT|USMALLINT|UINTEGER|UBIGINT|FLOAT|DOUBLE|DECIMAL)"
  dd_type <- function(t) {
    if (grepl(num_type, t)) "number"
    else if (grepl("^TIMESTAMP", t)) "datetime"
    else if (t == "DATE") "date"
    else if (t == "BOOLEAN") "boolean"
    else "string"
  }
  show <- function(x, type) {
    if (type == "number") {
      x <- as.numeric(x); w <- x[!is.na(x)]
      return(if (length(w) && all(w == round(w)) && all(abs(w) < 2^31)) as.integer(x) else x)
    }
    if (type == "datetime") return(.dd_datetime(x))
    if (type == "date") return(format(as.Date(x), "%Y-%m-%d"))
    x <- as.character(x)
    lapply(ifelse(nchar(x) > 60, paste0(substr(x, 1, 57), "..."), x), function(v) structure(v, quoted = TRUE))
  }
  declared <- function(f) {
    if (!nrow(f) || is.na(f$data_type)) return("not in Oracle's catalogue")
    if (f$data_type %in% "NUMBER" && !is.na(f$data_precision))
      return(sprintf("NUMBER(%s,%s)", f$data_precision, ifelse(is.na(f$data_scale), 0, f$data_scale)))
    f$data_type
  }
  q <- function(...) sprintf('"%s"', gsub('"', '""', paste0(...)))
  con <- .duckdb_quiet()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  written <- objects[objects$status %in% "written", ]
  # an overview row kept by a resume can name a file no longer there: stk's three views of the whole trail (TODO 110)
  there <- vapply(seq_len(nrow(written)), function(i) if (isTRUE(written$partitioned[i]))
    length(Sys.glob(file.path(out_dir, written$name[i], "*", "*.parquet"))) > 0
    else file.exists(file.path(out_dir, paste0(written$name[i], ".parquet"))), NA)
  gone <- written$name[!there]
  written <- written[there, ]
  seen <- list()
  tables <- lapply(seq_len(nrow(written)), function(i) {
    nm  <- written$name[i]
    src <- if (isTRUE(written$partitioned[i])) file.path(nm, "*", "*.parquet") else paste0(nm, ".parquet")
    rp  <- sprintf("read_parquet(%s, hive_partitioning = false)", .sql_string(file.path(out_dir, src)))
    desc <- DBI::dbGetQuery(con, paste("DESCRIBE SELECT * FROM", rp))
    types <- vapply(desc$column_type, dd_type, "")
    ranged <- desc$column_name[types %in% c("number", "datetime", "date")]
    # a float's NaN sorts above every number in DuckDB, and a range may not hold one
    bound <- function(f, cn, ct) if (grepl("^(FLOAT|DOUBLE)", ct)) sprintf("%s(CASE WHEN isnan(%s) THEN NULL ELSE %s END)", f, q(cn), q(cn))
                                 else sprintf("%s(%s)", f, q(cn))
    agg <- c(sprintf("count(%s) AS %s", q(desc$column_name), q("n_", desc$column_name)),
             unlist(lapply(which(desc$column_name %in% ranged), function(j) {
               cn <- desc$column_name[j]; ct <- desc$column_type[j]
               c(paste(bound("min", cn, ct), "AS", q("min_", cn)), paste(bound("max", cn, ct), "AS", q("max_", cn)))
             })))
    stat <- DBI::dbGetQuery(con, sprintf("SELECT count(*) AS %s, %s FROM %s", q("rows_"), paste(agg, collapse = ", "), rp))
    head <- DBI::dbGetQuery(con, sprintf("SELECT * FROM %s LIMIT 10000", rp))
    fl <- fields[fields$table == nm, ]
    cols <- lapply(seq_len(nrow(desc)), function(j) {
      cn <- desc$column_name[j]; ty <- types[[j]]
      cm <- fl$comments[match(cn, fl$column)]
      cm <- if (is.na(cm) || !nzchar(cm)) "No comment in Oracle." else cm
      n  <- as.numeric(stat[[paste0("n_", cn)]])
      ex <- head[[cn]][!is.na(head[[cn]])]
      seen[[length(seen) + 1]] <<- data.frame(table = nm, column = cn, type = ty, rows = as.numeric(stat$rows_),
                                              values = n, in_head = length(ex) > 0)
      if (n == 0)
        return(list(name = cn, description = cm,
                    details = sprintf("Oracle declares %s. No value in this dump, so it is listed by name only.",
                                      declared(fl[match(cn, fl$column), ])),
                    todo = "No value in this dump: typed, with examples, when a dump holds one."))
      e <- list(name = cn, type = ty)
      if (cn %in% ranged) {
        r <- c(stat[[paste0("min_", cn)]], stat[[paste0("max_", cn)]])
        if (length(r) == 2 && !anyNA(r)) e$range <- as.list(show(r, ty))
      }
      if (ty %in% c("number", "string")) {
        ex <- unique(ex)
        if (ty == "number") ex <- ex[is.finite(as.numeric(ex))]
        if (!length(ex))
          ex <- DBI::dbGetQuery(con, sprintf("SELECT DISTINCT %s AS v FROM %s WHERE %s IS NOT NULL%s ORDER BY v LIMIT 5",
                                             q(cn), rp, q(cn), if (ty == "number") sprintf(" AND isfinite(%s)", q(cn))
                                             else ""))$v
        if (length(ex)) e$examples <- as.list(show(utils::head(ex, 5), ty))
      }
      e$description <- cm
      e
    })
    e <- list(name = nm, source = list(parquet = src),
              description = if (is.na(written$comments[i]) || !nzchar(written$comments[i])) "No comment in Oracle."
                            else written$comments[i])
    if (!is.null(written$note) && !is.na(written$note[i])) e$details <- written$note[i]
    e$columns <- cols
    e
  })
  dd <- list(`$version` = "0.1.0", `$learn_more` = "https://data-dict.tidyverse.org/",
             name = schema,
             description = sprintf("Oracle schema %s at MFRI, dumped as it is on %s (%s, commit %s).",
                                   schema, run$dumped, run$script, substr(run$commit, 1, 7)),
             details = paste("Written by dump_oracle_schema() (R/dump_oracle.R, plan 018). Descriptions are Oracle's own",
                             "table and column comments. Ranges cover the whole file; examples come from its first",
                             "10,000 rows, or from the whole file where those hold none, and may hold personal data,",
                             "so this file is handled as the data are. Types, units, code labels, evidence and",
                             "assertions where they are known come from the overlay",
                             paste0("dump/oracle/meta/", basename(out_dir), ".yml"), "(plan 040)."),
             tables = tables)
  if (!is.null(rewritten))
    dd$details <- paste0(dd$details, sprintf(" Rewritten from the dump's files on %s by rewrite_data_dict(), commit %s.",
                                             rewritten$at, substr(rewritten$commit, 1, 7)))
  if (length(gone))
    dd$todo <- paste0("Written by the dump's overview, but not on disk, so left out: ", paste(gone, collapse = ", "), ".")
  dd <- tryCatch(.data_dict_merge(dd, overlay), error = function(e) {
    dd$todo <- paste("The overlay could not be laid over this dictionary:", conditionMessage(e))
    dd
  })
  yaml::write_yaml(dd, file.path(out_dir, "_data-dict.yaml"))
  invisible(do.call(rbind, seen))
}

# What a resumed run keeps of table `nm`: NULL to dump it again, else its rows, seconds and stamps. A table is kept when
# the last overview says it was written, or, when there is no overview (a run killed before its end writes none: the
# kvoti run in RStudio, 2026-10-15), when its file reads back with the stamps .write_raw() puts in the footer, which a
# file cut off mid-write lacks. Either way only a file of the same driver is kept, so one directory never mixes them.
# A partitioned table is never kept whole: dump_oracle_by_year() keeps each year dumped after it ended.
.dump_kept <- function(nm, out_dir, prev, run, partitioned) {
  if (partitioned) return(NULL)
  f <- file.path(out_dir, paste0(nm, ".parquet"))
  if (!file.exists(f)) return(NULL)
  j <- if (is.null(prev)) NA else match(nm, prev$name)
  if (!is.na(j) && prev$status[j] %in% "written" && identical(prev$driver[j], run$driver)) {
    keys <- intersect(c("dumped", "script", "commit", "dirty", "driver"), names(prev))
    return(list(rows = prev$rows[j], seconds = prev$seconds[j], stamp = as.list(prev[j, keys, drop = FALSE]),
                note = if (is.null(prev$note)) NA_character_ else prev$note[j]))
  }
  m <- tryCatch(curated_provenance(f), error = function(e) NULL)
  v <- if (is.null(m)) character() else stats::setNames(m$value, m$key)
  if (!all(c("fd.rows", "fd.dumped", "fd.driver") %in% names(v)) || v[["fd.driver"]] != run$driver) return(NULL)
  stamp <- list(dumped = v[["fd.dumped"]], driver = v[["fd.driver"]])
  for (k in c("script", "commit", "dirty")) if (paste0("fd.", k) %in% names(v)) stamp[[k]] <- v[[paste0("fd.", k)]]
  list(rows = as.numeric(v[["fd.rows"]]), seconds = NA_real_, stamp = stamp,
       note = if ("fd.note" %in% names(v)) v[["fd.note"]] else NA_character_)
}

# Does the connection still answer?
.oracle_alive <- function(con) tryCatch({ DBI::dbGetQuery(con, "SELECT 1 FROM DUAL"); TRUE }, error = function(e) FALSE)

# Every table and view of a schema, as it is. A table that fails is recorded and the loop goes on.
#   tables     dump only these (the overview still lists every object); for a schema that is not ours to dump whole
#   skip       objects deliberately left out; the caller says why
#   skip_rjdbc left out only when the driver is RJDBC: tables with LOB columns, which it fetches one row at a time
#              (3 MB/s), and objects that fail in its Java layer. ROracle is expected to read them: the April dump made
#              with it on the server holds afli.afladagb_xml_mottaka (decision 109)
#   partition  list(table = "date column"): dumped by calendar year (dump_oracle_by_year())
#   max_rows   a table Oracle estimates bigger than this, and not partitioned, is listed but not dumped. A view has no
#              estimate, so its rows are counted first (SELECT COUNT(*)), and a bigger one is listed too: stk's views
#              of the whole trail were fetched whole into memory, stk_vms_v's 303,784,194 rows among them, and the run
#              went silent on the next ones (hafdruna, 2026-10-16). The trail itself is dumped by year.
#   resume     keep what an earlier run of the same driver wrote completely and dump the rest (.dump_kept()); on by
#              `--resume` on the command line (Rscript dump/oracle/afli.R --resume), which dump/oracle/all.R passes
# A table that fails on a dead connection is tried once more on a new one: afli's dump of 2026-10-15 lost its
# connection on sjalfvirkir_maelar (ORA-17002), and the 27 tables after it failed on the dead connection. The new
# one comes from `connect`; a test passes one that refuses, so that it never reaches the real database (a test on a
# stand-in did, through dump_connect() and the keychain, 2026-10-16: read-only queries on tables that do not exist).
# Returns the overview, invisibly.
dump_oracle_schema <- function(con, schema, out_dir, tables = NULL, skip = character(), skip_rjdbc = character(),
                               partition = list(), max_rows = 5e7, script = NA_character_, connect = dump_connect,
                               resume = "--resume" %in% commandArgs(trailingOnly = TRUE)) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  run <- .dump_run(con, script)
  ov_path <- file.path(out_dir, "_overview_tables.parquet")
  prev    <- if (file.exists(ov_path)) as.data.frame(nanoparquet::read_parquet(ov_path)) else NULL
  before  <- prev$name
  if (resume && !all(c("status", "rows", "dumped") %in% names(prev))) prev <- NULL   # an overview without them

  objects <- oracle_objects(con, schema)
  if (length(bad <- setdiff(c(tables, skip, skip_rjdbc, names(partition)), objects$name)))
    stop("not in ", schema, ": ", paste(bad, collapse = ", "), call. = FALSE)
  # Oracle's comments are made valid here, not only in their file: _data-dict.yaml takes them from memory, and
  # yaml::write_yaml() aborts R on text that is not UTF-8 (2026-10-22)
  fields <- .utf8_valid(oracle_fields(con, schema))
  .write_raw(fields, file.path(out_dir, "_overview_fields.parquet"), paste0(schema, " columns"), run)

  n <- nrow(objects)
  objects$partitioned <- objects$name %in% names(partition)
  rows <- rep(NA_real_, n); status <- rep(NA_character_, n)
  error <- rep(NA_character_, n); note <- rep(NA_character_, n); seconds <- rep(NA_real_, n)
  stamp <- data.frame(dumped = rep(run$dumped, n), script = run$script, commit = run$commit, dirty = run$dirty,
                      driver = run$driver, resumed = FALSE)
  if (run$driver != "RJDBC") skip_rjdbc <- character()
  for (i in seq_len(n)) {
    nm <- objects$name[i]
    why <- if (!is.null(tables) && !nm %in% tables) "listed"
           else if (nm %in% c(skip, skip_rjdbc)) "skipped"
           else if (!objects$partitioned[i] && isTRUE(objects$num_rows[i] > max_rows)) "too_big"
           else NA_character_
    if (!is.na(why)) {
      status[i] <- why
      if (why != "listed") message(sprintf("%s.%s: %s", schema, nm, why))
      next
    }
    kept <- if (resume) .dump_kept(nm, out_dir, prev, run, objects$partitioned[i]) else NULL
    if (!is.null(kept)) {
      rows[i] <- kept$rows; seconds[i] <- kept$seconds; status[i] <- "written"; note[i] <- kept$note
      for (k in names(kept$stamp)) stamp[[k]][i] <- kept$stamp[[k]]
      stamp$resumed[i] <- TRUE
      next
    }
    ref <- paste0(schema, ".", .oracle_spelled(objects$oracle_name[i]))
    if (objects$type[i] == "view" && !objects$partitioned[i]) {
      # the count by position: Oracle names an unquoted alias in capitals, so `AS n` came back as N, $n was NULL, and
      # no view was ever too big (stk's trail_all and view_trail were fetched whole on hafdruna, 2026-10-16)
      cnt <- tryCatch(as.numeric(DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) FROM %s", .oracle_ref(ref)))[[1]]),
                      error = function(e) NA_real_)
      if (isTRUE(cnt > max_rows)) {
        status[i] <- "too_big"; rows[i] <- cnt
        message(sprintf("%s.%s: too_big (a view of %s rows)", schema, nm, format(cnt, big.mark = ",")))
        next
      }
    }
    t0 <- Sys.time()
    fl <- fields[fields$table == nm, ]
    attempt <- function() tryCatch(
      if (objects$partitioned[i])
        dump_oracle_by_year(con, ref, file.path(out_dir, nm), partition[[nm]], fl, run)
      else
        dump_oracle_table(con, ref, file.path(out_dir, paste0(nm, ".parquet")), fl, run),
      error = function(e) e)
    r <- attempt()
    if (inherits(r, "error") && !.oracle_alive(con)) {
      message(sprintf("%s.%s: the connection is lost - reconnecting and trying once more", schema, nm))
      con <- connect()
      r <- attempt()
    }
    seconds[i] <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    invisible(gc(FALSE))   # an R reference holds its Java result until R's gc runs, whatever the Java heap
    if (inherits(r, "error")) {
      status[i] <- "failed"
      error[i]  <- gsub("\033\\[[0-9;]*m", "", conditionMessage(r))
      message(sprintf("%s.%s: FAILED - %s", schema, nm, error[i]))
    } else {
      rows[i] <- as.numeric(r)
      if (!is.null(attr(r, "note"))) note[i] <- attr(r, "note")
      status[i] <- "written"
    }
  }

  objects <- objects |>
    dplyr::mutate(rows = rows, status = status, error = error, note = note, seconds = seconds) |>
    dplyr::bind_cols(stamp) |>
    .utf8_valid()
  .write_raw(objects, ov_path, paste0(schema, " objects"), run)
  dd <- tryCatch(.write_data_dict(out_dir, schema, objects, fields, run), error = function(e) e)
  if (inherits(dd, "error")) message("  _data-dict.yaml not written: ", conditionMessage(dd))

  failed <- objects$name[objects$status == "failed"]
  # Files an earlier dump of this schema wrote that this one did not: dropped from Oracle, or failed now.
  # Left in place, since raw/ is never deleted by code; the overview says they are not from this dump.
  stale <- setdiff(before, objects$name[objects$status %in% c("written", "skipped")])
  stale <- stale[file.exists(file.path(out_dir, paste0(stale, ".parquet"))) | dir.exists(file.path(out_dir, stale))]
  message(sprintf("%s: %d written (%d kept from the last run), %d failed, %d skipped, %d too big, %d listed only -> %s",
                  schema, sum(status == "written"), sum(stamp$resumed), length(failed), sum(status == "skipped"),
                  sum(status == "too_big"), sum(status == "listed"), out_dir))
  if (length(failed)) message("  failed: ", paste(failed, collapse = ", "))
  if (length(stale))  message("  not from this dump (older files kept): ", paste(stale, collapse = ", "))
  invisible(objects)
}

# The SQL behind a schema (oracle_code()), to <out_dir>/<view>.parquet, one file per dictionary view of .oracle_code,
# and <out_dir>/_overview.parquet: per view, the rows written, or the refusal with Oracle's code, and notes. An empty
# view is written: it is a result. A view that fails writes nothing, and the file of an earlier run stays, as in
# dump_oracle_schema(). A query that fails on a dead connection is tried once more on a new one from `connect`.
# Returns the overview, invisibly.
dump_oracle_code <- function(con, schema, out_dir, script = NA_character_, connect = dump_connect) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  run <- .dump_run(con, script)
  src <- names(.oracle_code)
  n <- length(src)
  rows <- rep(NA_real_, n); status <- rep(NA_character_, n); error <- rep(NA_character_, n)
  seconds <- rep(NA_real_, n)
  got <- list()
  for (i in seq_len(n)) {
    t0 <- Sys.time()
    r <- tryCatch(oracle_code(con, schema, src[i]), error = function(e) e)
    if (inherits(r, "error") && !.oracle_alive(con)) {
      message(sprintf("%s %s: the connection is lost - reconnecting and trying once more", schema, src[i]))
      con <- connect()
      r <- tryCatch(oracle_code(con, schema, src[i]), error = function(e) e)
    }
    seconds[i] <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (inherits(r, "error")) {
      status[i] <- "failed"
      error[i]  <- .oracle_error(r)
    } else {
      got[[src[i]]] <- r
      rows[i] <- nrow(r)
      status[i] <- "written"
    }
  }
  note <- .oracle_code_notes(got, schema)
  for (s in names(got))
    .write_raw(got[[s]], file.path(out_dir, paste0(s, ".parquet")), paste(schema, s), run, note[[s]])
  ov <- data.frame(owner = tolower(schema), source = src, rows = rows, status = status, error = error,
                   note = unname(note[src]), seconds = seconds, dumped = run$dumped, script = run$script,
                   commit = run$commit, dirty = run$dirty, driver = run$driver)
  .write_raw(ov, file.path(out_dir, "_overview.parquet"), paste(schema, "code"), run)

  said <- ifelse(status == "written", format(rows, big.mark = ",", trim = TRUE), paste0("FAILED (", error, ")"))
  message(sprintf("%s: %s", schema, paste(src, said, collapse = ", ")))
  for (i in which(!is.na(ov$note))) message("  ", src[i], ": ", ov$note[i])
  kept <- src[status == "failed" & file.exists(file.path(out_dir, paste0(src, ".parquet")))]
  if (length(kept)) message("  not from this dump (older files kept): ", paste(kept, collapse = ", "))
  invisible(ov)
}

# Oracle's own message (ORA-nnnnn and its text) without the wrappers of R and the driver, or the whole message when
# there is none: ROracle's "unsupported column type" is not Oracle's. ASCII only, as in dump_oracle_table().
.oracle_error <- function(e) {
  msg <- gsub("\033\\[[0-9;]*m", "", conditionMessage(e))
  ora <- regmatches(msg, gregexpr("ORA-[0-9]{5}:[ -~]*", msg, useBytes = TRUE))[[1]]
  ora <- trimws(sub(" *https?://.*$", "", ora))
  if (length(ora)) paste(unique(ora), collapse = " | ") else trimws(gsub("[[:space:]]+", " ", msg))
}

# What the overview says of a dictionary view beyond its rows: whether each LONG text is as long as Oracle says
# (TEXT_LENGTH, QUERY_LEN, DEFAULT_LENGTH, in bytes), and which of the schema's code objects have no line in
# all_source (listed in all_objects, or depended on by the schema's own objects). NA where there is nothing to say.
.oracle_code_notes <- function(got, schema) {
  note <- stats::setNames(rep(NA_character_, length(.oracle_code)), names(.oracle_code))
  some <- function(x, k = 20) paste(c(utils::head(x, k), if (length(x) > k) sprintf("and %d more", length(x) - k)),
                                    collapse = ", ")
  key <- function(name, type) if (length(name)) paste0(name, " (", type, ")") else character()
  # a row with neither a text nor a length (a column with no default) has nothing to check
  whole <- function(d, name, text, len) {
    if (is.null(d)) return(NA_character_)
    d <- d[!is.na(d[[text]]) | !is.na(d[[len]]), ]
    if (!nrow(d)) return(NA_character_)
    b <- ifelse(is.na(d[[text]]), 0, nchar(d[[text]], type = "bytes"))
    off <- which(is.na(d[[len]]) | b != d[[len]])
    if (!length(off)) return(sprintf("%s whole on all %d (bytes equal %s)", text, nrow(d), toupper(len)))
    label <- if (length(name) > 1) paste(d[[name[1]]], d[[name[2]]], sep = ".") else d[[name]]
    sprintf("%s not as long as %s on %d of %d: %s", text, toupper(len), length(off), nrow(d),
            some(sprintf("%s (%s bytes of %s)", label[off], b[off], d[[len]][off])))
  }
  note[["all_tab_columns"]] <- whole(got$all_tab_columns, c("table_name", "column_name"), "data_default",
                                     "default_length")
  note[["all_views"]]  <- whole(got$all_views, "view_name", "text", "text_length")
  note[["all_mviews"]] <- whole(got$all_mviews, "mview_name", "query", "query_len")
  tr <- got$all_triggers
  if (!is.null(tr) && any(is.na(tr$trigger_body)))
    note[["all_triggers"]] <- sprintf("no body on %d of %d: %s", sum(is.na(tr$trigger_body)), nrow(tr),
                                      some(tr$trigger_name[is.na(tr$trigger_body)]))
  sc <- got$all_source
  if (!is.null(sc)) {
    code <- c("FUNCTION", "PROCEDURE", "PACKAGE", "PACKAGE BODY", "TYPE", "TYPE BODY")
    o  <- got$all_objects
    dp <- got$all_dependencies
    o  <- if (is.null(o)) NULL else o[o$object_type %in% code, ]
    dp <- if (is.null(dp)) NULL else dp[dp$referenced_owner %in% toupper(schema) & dp$referenced_type %in% code, ]
    shown  <- unique(key(sc$name, sc$type))
    hidden <- sort(setdiff(unique(c(key(o$object_name, o$object_type), key(dp$referenced_name, dp$referenced_type))),
                           shown))
    if (length(shown) || length(hidden))
      note[["all_source"]] <- paste0(sprintf("source of %d code objects", length(shown)),
        if (length(hidden)) sprintf("; no line for %d that all_objects lists or the schema's objects depend on: %s",
                                    length(hidden), some(hidden)))
  }
  note
}
