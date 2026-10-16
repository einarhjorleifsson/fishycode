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
#         fd.source, fd.dumped (the dump's start, its version marker), fd.rows, fd.driver, fd.script, fd.commit, fd.dirty.
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
# quotes keeps its case (ops$einarhj.mmsi_icelandic_registry's "stadur" failed as "STADUR", ORA-00904).
oracle_fields <- function(con, schema, table = NULL) {
  w <- sprintf("OWNER = '%s'", gsub("'", "''", toupper(schema)))
  if (!is.null(table)) w <- sprintf("%s AND TABLE_NAME = '%s'", w, gsub("'", "''", toupper(table)))
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
    tibble::as_tibble()
}

# Tables and views of a schema, with Oracle's comment and (for tables) its row estimate. Read from the catalogue
# directly: mar::mar_views() calls sql() unqualified, so it fails under Rscript, where dplyr is not attached
# (2026-10-15).
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
    dplyr::mutate(owner = tolower(owner), name = tolower(name))
  objects$comments <- comm$comments[match(objects$name, tolower(comm$table_name))]
  objects$num_rows <- as.numeric(objects$num_rows)
  objects |> dplyr::relocate(owner, name, type, comments)
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

# Write a frame as parquet (plain TIMESTAMP) with fd.* stamps in its key/value metadata.
.write_raw <- function(d, path, source, run) {
  kv <- c("fd.source" = source, "fd.dumped" = run$dumped, "fd.rows" = as.character(nrow(d)),
          "fd.driver" = run$driver, "fd.script" = run$script, "fd.commit" = run$commit, "fd.dirty" = run$dirty)
  kv <- kv[!is.na(kv)]
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- .duckdb_quiet()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  duckdb::duckdb_register(con, "d", d)
  meta <- paste(sprintf("%s: %s", shQuote(names(kv), type = "sh"), shQuote(unname(kv), type = "sh")),
                collapse = ", ")
  DBI::dbExecute(con, sprintf("COPY d TO %s (FORMAT parquet, KV_METADATA {%s})", shQuote(path, type = "sh"), meta))
  invisible(path)
}

# Columns the driver cannot fetch are read as text in Oracle's own form: SDO_GEOMETRY as WKT, XMLTYPE as the document.
# adb.fishing_station's location (SDO_GEOMETRY) failed every earlier dump; afli's XML table needed its own query.
# The WKT is cast to VARCHAR2: as a CLOB, each of fishing_station's 690,912 rows left a temporary LOB in the session,
# and the next query waited on Oracle for over 15 min (2026-10-15), most likely while it freed them. A geometry whose
# WKT passes 4,000 characters then fails loudly (ORA-22835) rather than being cut. An XML document is longer than
# that, so it stays a CLOB, read on a connection of its own that is closed before the LOBs are released.
.oracle_text <- c(SDO_GEOMETRY = "TO_CHAR(SDO_UTIL.TO_WKTGEOMETRY(%s))", XMLTYPE = "XMLSERIALIZE(DOCUMENT %s AS CLOB)")
.oracle_lob <- "XMLTYPE"

# The table as a lazy query: every column as it is, those in .oracle_text converted to text under their own name.
# With numbers_as_text, every NUMBER comes as TO_CHAR too (the retry in dump_oracle_table()). Through ROracle a NUMBER
# that may hold decimals (scale not 0) always comes as TO_CHAR, the exact decimal, which .oracle_numbers() turns into
# the nearest double: ROracle's own conversion lands a step off for some values (power_kw 60.3 came through as
# 60.3000000000000043, RJDBC's 60.2999999999999972 is the nearest double; 198 of vessel's 7,047, hafdruna 2026-10-16),
# and then x == 60.3 is FALSE. A whole NUMBER (scale 0) is exact either way.
.oracle_query <- function(con, table, fields, numbers_as_text = FALSE) {
  conv <- c(.oracle_text, if (numbers_as_text) c(NUMBER = "TO_CHAR(%s)"))
  decimal <- .oracle_driver(con) == "ROracle" & fields$data_type %in% "NUMBER" & !(fields$data_scale %in% 0)
  if (!any(fields$data_type %in% names(conv)) && !any(decimal)) return(mar::tbl_mar(con, table))
  x <- strsplit(table, ".", fixed = TRUE)[[1]]
  o <- order(fields$column_id)
  fields <- fields[o, ]
  decimal <- decimal[o]
  cols <- vapply(seq_len(nrow(fields)), function(i) {
    nm <- if (is.null(fields$oracle_column)) toupper(fields$column[i]) else fields$oracle_column[i]
    q <- sprintf('"%s"', gsub('"', '""', nm))
    f <- if (decimal[i]) "TO_CHAR(%s)" else conv[fields$data_type[i]]
    if (is.na(f)) q else paste(sprintf(f, q), "AS", q)
  }, "")
  dplyr::tbl(con, dplyr::sql(sprintf('SELECT %s FROM "%s"."%s"', paste(cols, collapse = ", "),
                                     toupper(x[1]), toupper(x[2])))) |>
    dplyr::rename_with(tolower)
}

# Run a lazy query through DBI rather than dplyr::collect(): when the driver throws a Java exception, collect()'s error
# wrapper fails on the exception object ("no field, method or inner class called 'use_cli_format'", agf 2026-10-15)
# and Oracle's message is lost.
.oracle_collect <- function(con, q) tibble::as_tibble(DBI::dbGetQuery(con, dbplyr::sql_render(q)))

# One table or view ("schema.name") to one parquet file, as it is. Reports and returns the rows written.
# A table whose fetch fails is fetched once more with its numbers as text: afli.afli (15.7 M rows) failed through RJDBC
# with java.lang.ArrayIndexOutOfBoundsException (2026-10-15), most likely the driver parsing a malformed NUMBER, which
# ROracle on the server had read. .oracle_numbers() turns the text back into numbers, and names any column it cannot.
dump_oracle_table <- function(con, table, path, fields = NULL, run = NULL) {
  if (is.null(fields)) {
    x <- strsplit(table, ".", fixed = TRUE)[[1]]
    fields <- oracle_fields(con, x[1], x[2])
  }
  if (is.null(run)) run <- .dump_run(con, NA_character_)
  fetch <- function(numbers_as_text) {
    if (any(fields$data_type %in% .oracle_lob)) {
      lc <- dump_connect()
      tryCatch(.oracle_collect(lc, .oracle_query(lc, table, fields, numbers_as_text)), finally = DBI::dbDisconnect(lc))
    } else {
      .oracle_collect(con, .oracle_query(con, table, fields, numbers_as_text))
    }
  }
  d <- tryCatch(fetch(FALSE), error = function(e) {
    if (!any(fields$data_type %in% "NUMBER")) stop(e)
    message(sprintf("%s: %s - fetching again with its numbers as text", table,
                    gsub("\033\\[[0-9;]*m", "", conditionMessage(e))))
    fetch(TRUE)
  })
  d <- .oracle_numbers(d, fields)
  .write_raw(d, path, table, run)
  message(sprintf("%s: %s rows", table, format(nrow(d), big.mark = ",")))
  nrow(d)
}

# A table too big for one collect(), by calendar year of `column`, to <dir>/year=<y>/data_0.parquet. A year is fetched
# again until it has been dumped after it ended, read from the partition's own fd.dumped stamp: a year dumped while
# it was running is completed on the next run, whatever the column (a logger may record nothing on 31 December).
# Returns the rows written in this run.
dump_oracle_by_year <- function(con, table, dir, column, fields, run) {
  q <- .oracle_query(con, table, fields)
  span <- .oracle_collect(con, q |> dplyr::summarise(a = min(.data[[column]], na.rm = TRUE), b = max(.data[[column]], na.rm = TRUE)))
  years <- seq(as.integer(format(as.POSIXct(span$a), "%Y")), as.integer(format(as.POSIXct(span$b), "%Y")))
  n <- 0
  for (y in years) {
    f <- file.path(dir, paste0("year=", y), "data_0.parquet")
    if (file.exists(f)) {
      # a year file cut off mid-write has no readable footer, and one of the other driver is not mixed in: both redone
      m <- tryCatch(curated_provenance(f), error = function(e) NULL)
      d0 <- m$value[m$key == "fd.dumped"]
      if (length(d0) && identical(m$value[m$key == "fd.driver"], run$driver) &&
          as.Date(substr(d0, 1, 10)) > as.Date(sprintf("%d-12-31", y))) next
    }
    d <- .oracle_collect(con, q |>
      dplyr::filter(.data[[column]] >= to_date(!!sprintf("%d-01-01", y), "YYYY-MM-DD"),
                    .data[[column]] <  to_date(!!sprintf("%d-01-01", y + 1), "YYYY-MM-DD")))
    d <- .oracle_numbers(d, fields)
    .write_raw(d, f, table, run)
    message(sprintf("%s, %d: %s rows", table, y, format(nrow(d), big.mark = ",")))
    n <- n + nrow(d)
  }
  n
}

# The schema in data-dict's format, beside the files: Oracle's comments, types from the files, ranges from the whole
# file and examples from its first 10,000 rows. Examples are data, so the yaml is handled as the data are.
.write_data_dict <- function(out_dir, schema, objects, fields, run) {
  dd_type <- function(t) {
    if (grepl("^(TINYINT|SMALLINT|INTEGER|BIGINT|HUGEINT|UTINYINT|USMALLINT|UINTEGER|UBIGINT|FLOAT|DOUBLE|DECIMAL)", t)) "number"
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
    x <- as.character(x)
    ifelse(nchar(x) > 60, paste0(substr(x, 1, 57), "..."), x)
  }
  con <- .duckdb_quiet()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  written <- objects[objects$status %in% "written", ]
  tables <- lapply(seq_len(nrow(written)), function(i) {
    nm  <- written$name[i]
    src <- if (written$partitioned[i]) file.path(nm, "*", "*.parquet") else paste0(nm, ".parquet")
    rp  <- sprintf("read_parquet(%s, hive_partitioning = false)", shQuote(file.path(out_dir, src), type = "sh"))
    desc <- DBI::dbGetQuery(con, paste("DESCRIBE SELECT * FROM", rp))
    types <- vapply(desc$column_type, dd_type, "")
    ranged <- desc$column_name[types %in% c("number", "datetime", "date")]
    rng <- if (length(ranged)) DBI::dbGetQuery(con, sprintf("SELECT %s FROM %s", paste(
      sprintf("min(\"%s\") AS \"min_%s\", max(\"%s\") AS \"max_%s\"", ranged, ranged, ranged, ranged),
      collapse = ", "), rp)) else NULL
    head <- DBI::dbGetQuery(con, sprintf("SELECT * FROM %s LIMIT 10000", rp))
    fl <- fields[fields$table == nm, ]
    cols <- lapply(seq_len(nrow(desc)), function(j) {
      cn <- desc$column_name[j]; ty <- types[[j]]
      cm <- fl$comments[match(cn, fl$column)]
      e <- list(name = cn, type = ty)
      r <- if (cn %in% ranged && !is.null(rng)) c(rng[[paste0("min_", cn)]], rng[[paste0("max_", cn)]])
      if (length(r) && !anyNA(r)) e$range <- as.list(show(r, ty))
      ex <- unique(head[[cn]][!is.na(head[[cn]])])
      if (length(ex) && ty %in% c("number", "string")) e$examples <- as.list(show(utils::head(ex, 5), ty))
      e$description <- if (is.na(cm) || !nzchar(cm)) "No comment in Oracle." else cm
      e
    })
    list(name = nm, source = list(parquet = src),
         description = if (is.na(written$comments[i]) || !nzchar(written$comments[i])) "No comment in Oracle."
                       else written$comments[i],
         columns = cols)
  })
  dd <- list(`$version` = "0.1.0", `$learn_more` = "https://data-dict.tidyverse.org/",
             name = schema,
             description = sprintf("Oracle schema %s at MFRI, dumped as it is on %s (%s, commit %s).",
                                   schema, run$dumped, run$script, substr(run$commit, 1, 7)),
             details = paste("Written by dump_oracle_schema() (R/dump_oracle.R, plan 018). Descriptions are Oracle's own",
                             "table and column comments. Ranges cover the whole file; examples come from its first",
                             "10,000 rows and may hold personal data, so this file is handled as the data are."),
             tables = tables)
  yaml::write_yaml(dd, file.path(out_dir, "_data-dict.yaml"))
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
    return(list(rows = prev$rows[j], seconds = prev$seconds[j], stamp = as.list(prev[j, keys, drop = FALSE])))
  }
  m <- tryCatch(curated_provenance(f), error = function(e) NULL)
  v <- if (is.null(m)) character() else stats::setNames(m$value, m$key)
  if (!all(c("fd.rows", "fd.dumped", "fd.driver") %in% names(v)) || v[["fd.driver"]] != run$driver) return(NULL)
  stamp <- list(dumped = v[["fd.dumped"]], driver = v[["fd.driver"]])
  for (k in c("script", "commit", "dirty")) if (paste0("fd.", k) %in% names(v)) stamp[[k]] <- v[[paste0("fd.", k)]]
  list(rows = as.numeric(v[["fd.rows"]]), seconds = NA_real_, stamp = stamp)
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
  fields <- oracle_fields(con, schema)
  .write_raw(fields, file.path(out_dir, "_overview_fields.parquet"), paste0(schema, " columns"), run)

  n <- nrow(objects)
  objects$partitioned <- objects$name %in% names(partition)
  rows <- rep(NA_real_, n); status <- rep(NA_character_, n)
  error <- rep(NA_character_, n); seconds <- rep(NA_real_, n)
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
      rows[i] <- kept$rows; seconds[i] <- kept$seconds; status[i] <- "written"
      for (k in names(kept$stamp)) stamp[[k]][i] <- kept$stamp[[k]]
      stamp$resumed[i] <- TRUE
      next
    }
    if (objects$type[i] == "view" && !objects$partitioned[i]) {
      cnt <- tryCatch(as.numeric(DBI::dbGetQuery(con, sprintf('SELECT COUNT(*) AS n FROM "%s"."%s"', toupper(schema),
                                                              toupper(nm)))$n), error = function(e) NA_real_)
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
        dump_oracle_by_year(con, paste0(schema, ".", nm), file.path(out_dir, nm), partition[[nm]], fl, run)
      else
        dump_oracle_table(con, paste0(schema, ".", nm), file.path(out_dir, paste0(nm, ".parquet")), fl, run),
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
      rows[i] <- r
      status[i] <- "written"
    }
  }

  objects <- objects |>
    dplyr::mutate(rows = rows, status = status, error = error, seconds = seconds) |>
    dplyr::bind_cols(stamp)
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
