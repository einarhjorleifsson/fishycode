# run_dump.R — run the Oracle dump scripts in their own process, from any R session, and follow them.
#
# Input:  dump/oracle/<schema>.R
# Output: what each script writes (raw/oracle/<schema>/), a log per run in raw/oracle/<schema>/_logs/
#         (<time>[_resume].log, with its exit code in <time>[_resume].log.exit)
#
# Definitions only: targets sources R/ wholesale.
#
# Why a process of its own (2026-10-15). A dump run inside an interactive session (RStudio):
#   - kept the JVM of an earlier dump, with its heap and time zone;
#   - could not take --resume, since source() passes no arguments;
#   - died with the session, and showed its progress only in that session's console.
# Here each script runs in a fresh Rscript, in the background, outlives the session that started it, and keeps the
# machine awake while it runs (caffeinate, on macOS).
#
#   run_dump("kvoti")                       a full dump of one schema
#   run_dump(c("kvoti", "stk"))             one after the other, in one background process
#   run_dump("afli", resume = TRUE)         keep what the last run wrote, dump the rest
#   run_dump("afli", driver = "ROracle")    through ROracle, on the server (decision 109); when not given, the
#                                           driver is FD_DUMP_DRIVER (the server's .Renviron: ROracle), else RJDBC
#   dump_status()                           every schema: running, queued, finished (and how), stopped

.repo_root <- function() {
  d <- normalizePath(getwd(), mustWork = FALSE)
  for (i in 1:6) {
    if (file.exists(file.path(d, "AGENTS.md")) && dir.exists(file.path(d, "dump", "oracle"))) return(d)
    up <- dirname(d)
    if (identical(up, d)) break
    d <- up
  }
  stop("run_dump(): start R in fishycode or below it", call. = FALSE)
}

# A schema's _logs/current: the id of the process that runs or ran its dump, and its log, found by name in the
# schema's own _logs/. A dump copied from another machine still reads: hafdruna's logs name paths under /heima
# (2026-10-16). Its process id belongs to that machine, so it is NA here.
.dump_current <- function(s, log_root) {
  cur <- file.path(log_root, s, "_logs", "current")
  if (!file.exists(cur)) return(list(pid = NA_integer_, log = NA_character_))
  x <- readLines(cur)
  log <- file.path(log_root, s, "_logs", basename(x[2]))
  here <- file.exists(x[2]) || !file.exists(log)
  list(pid = if (here) suppressWarnings(as.integer(x[1])) else NA_integer_, log = log)
}

# The process dumping schema `s` now, from its _logs/current: its id while it runs or waits its turn, NA once its log
# has an exit code or the process is gone. A dump started outside run_dump() leaves no _logs/current and is not seen.
.dump_pid <- function(s, log_root) {
  x <- .dump_current(s, log_root)
  if (is.na(x$pid) || !isTRUE(tools::pskill(x$pid, 0L)) || file.exists(paste0(x$log, ".exit"))) NA_integer_ else x$pid
}

# Start dump/oracle/<schema>.R for each schema, one after the other, in one background process. Returns its process id
# (NA with wait = TRUE), invisibly.
run_dump <- function(schema, resume = FALSE, driver = NULL, wait = FALSE, root = .repo_root(),
                     log_root = fd_raw("oracle")) {
  scripts <- file.path("dump", "oracle", paste0(schema, ".R"))
  # dump_connect() reads the driver from FD_DUMP_DRIVER; the process runs in UTC from its start, whatever the driver
  # (decision 109: a 1900 DATE came through 16 min 8 s late with only the JVM in UTC)
  env <- paste0("TZ=UTC ORA_SDTZ=UTC NLS_LANG=AMERICAN_AMERICA.AL32UTF8 ",
                if (is.null(driver)) "" else paste0("FD_DUMP_DRIVER=", match.arg(driver, c("RJDBC", "ROracle")), " "))
  if (length(miss <- schema[!file.exists(file.path(root, scripts))]))
    stop("no dump script for ", paste(miss, collapse = ", "), " (dump/oracle/<schema>.R)", call. = FALSE)
  # Two runs of one schema write the same files: two ask runs went into one directory on 2026-10-15.
  busy <- vapply(schema, .dump_pid, 0L, log_root = log_root)
  if (any(!is.na(busy)))
    stop(paste(sprintf("%s is being dumped by process %d", schema[!is.na(busy)], busy[!is.na(busy)]), collapse = "; "),
         ". Wait for it (dump_status()), or stop it first. If that process is not the dump, remove ",
         "<schema>/_logs/current", call. = FALSE)
  dirty <- suppressWarnings(system2("git", c("-C", shQuote(root), "status", "--porcelain", "--", "R", "dump/oracle"),
                                    stdout = TRUE, stderr = FALSE))
  if (length(dirty))
    warning("the dumper has uncommitted changes (", paste(trimws(dirty), collapse = "; "), "): the files will be ",
            "stamped dirty, and their commit will not say what code ran", call. = FALSE)
  when <- format(Sys.time(), "%Y%m%dT%H%M%S")
  logs <- vapply(schema, function(s) {
    d <- file.path(log_root, s, "_logs")
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    file.path(d, sprintf("%s%s.log", when, if (resume) "_resume" else ""))
  }, "")
  steps <- sprintf("%sRscript %s%s > %s 2>&1; echo $? > %s", env, shQuote(scripts), if (resume) " --resume" else "",
                   shQuote(logs), shQuote(paste0(logs, ".exit")))
  body <- sprintf("cd %s && %s", shQuote(root), paste(steps, collapse = "; "))
  awake <- if (nzchar(Sys.which("caffeinate"))) "caffeinate -i " else ""
  if (wait) {
    # this R process waits for the run, so its id is the run's for dump_status() and the guard above
    for (s in schema) writeLines(c(as.character(Sys.getpid()), logs[[s]]), file.path(log_root, s, "_logs", "current"))
    system2("/bin/sh", c("-c", shQuote(paste0(awake, "/bin/sh -c ", shQuote(body)))))
    pid <- NA_integer_
  } else {
    outer <- sprintf("nohup %s/bin/sh -c %s > /dev/null 2>&1 & echo $!", awake, shQuote(body))
    pid <- as.integer(system2("/bin/sh", c("-c", shQuote(outer)), stdout = TRUE))
    for (s in schema) writeLines(c(as.character(pid), logs[[s]]), file.path(log_root, s, "_logs", "current"))
  }
  message(sprintf("%s %s%s%s%s; logs in %s/<schema>/_logs/", if (wait) "ran" else "started",
                  paste(schema, collapse = ", "), if (resume) " (resume)" else "",
                  if (is.null(driver)) "" else paste0(" through ", driver),
                  if (wait) "" else sprintf(" in process %d", pid), log_root),
          if (wait) "" else "\n  follow with dump_status()")
  invisible(pid)
}

# Where each schema's dump stands: running, queued (waiting for an earlier schema in the same process), finished
# (with its exit code and the overview's counts and failures), or stopped (the process ended without finishing it).
dump_status <- function(schema = NULL, log_root = fd_raw("oracle"), lines = 3) {
  if (is.null(schema)) schema <- grep("^_", basename(list.dirs(log_root, recursive = FALSE)), value = TRUE, invert = TRUE)
  out <- lapply(schema, function(s) {
    cur <- .dump_current(s, log_root)
    logs <- sort(list.files(file.path(log_root, s, "_logs"), pattern = "[.]log$", full.names = TRUE))
    log <- if (!is.na(cur$log)) cur$log else if (length(logs)) logs[length(logs)] else NA_character_
    pid <- cur$pid
    alive <- !is.na(pid) && isTRUE(tools::pskill(pid, 0L))
    exit <- if (!is.na(log) && file.exists(paste0(log, ".exit"))) as.integer(readLines(paste0(log, ".exit"))[1]) else NA_integer_
    state <- if (!is.na(exit)) (if (exit == 0) "finished" else sprintf("finished with error %d", exit))
             else if (alive && !is.na(log) && file.exists(log)) "running"
             else if (alive) "queued"
             else if (!is.na(log)) "stopped"
             else "never run"
    ov_path <- file.path(log_root, s, "_overview_tables.parquet")
    # a schema dumped before run_dump() existed has an overview but no log
    if (state == "never run" && file.exists(ov_path)) state <- "finished (no log)"
    counts <- ""
    if (grepl("finished", state) && file.exists(ov_path)) {
      ov <- as.data.frame(nanoparquet::read_parquet(ov_path))
      if ("status" %in% names(ov)) {
        counts <- paste(names(table(ov$status)), table(ov$status), collapse = ", ")
        f <- ov[ov$status %in% "failed", ]
        # Oracle's own message where there is one: R's wrapper around it fills the first 60 characters
        why <- gsub("[[:space:]]+", " ", f$error)
        ora <- regexpr("ORA-[0-9]+[^!]*", why)
        why[ora > 0] <- regmatches(why, ora)
        if (nrow(f)) counts <- paste0(counts, "\n    failed: ", paste(sprintf("%s (%s)", f$name,
          substr(trimws(why), 1, 60)), collapse = "\n            "))
      }
    }
    cat(sprintf("%-14s %s%s\n", s, state, if (nzchar(counts)) paste0(" - ", counts) else ""))
    if (state %in% c("running", "stopped") || grepl("error", state)) {
      tail <- utils::tail(readLines(log, warn = FALSE), lines)
      if (length(tail)) cat(paste0("    | ", tail, collapse = "\n"), "\n")
    }
    data.frame(schema = s, state = state, pid = pid, log = log)
  })
  invisible(do.call(rbind, out))
}

# Every schema named, one after the other, each through run_dump(wait = TRUE) with its own log; this run's own log is
# raw/oracle/_logs/<time>_all.log, so the whole sweep, data and logs, sits under raw/oracle/ (decision 109). The
# directories are created when missing. It stops at the first schema whose script fails as a whole (no login, the date
# check): that would fail every schema alike. A table that fails is recorded in its schema's overview and does not
# stop the run. With resume, the same call picks up after a failure: a schema whose last run exited 0 with nothing
# failed, through the same driver, is skipped; any other keeps the files an earlier run of the driver completed and
# dumps the rest (dump_oracle_schema(resume = TRUE)). Returns the exit code of each schema run, invisibly.
run_dump_all <- function(schema = NULL, driver = NULL, resume = FALSE, root = .repo_root(), log_root = fd_raw("oracle")) {
  if (is.null(schema)) schema <- .dump_schemas(root)
  if (!dir.exists(log_root)) dir.create(log_root, recursive = TRUE)
  dir.create(file.path(log_root, "_logs"), showWarnings = FALSE)
  log <- file.path(log_root, "_logs", sprintf("%s_all.log", format(Sys.time(), "%Y%m%dT%H%M%S")))
  say <- function(...) {
    line <- paste(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), sprintf(...))
    cat(line, "\n", sep = "", file = log, append = TRUE)
    message(line)
  }
  say("dump of %s through %s%s, from %s (commit %s), into %s", paste(schema, collapse = ", "),
      if (is.null(driver)) Sys.getenv("FD_DUMP_DRIVER", "RJDBC") else driver, if (resume) ", resuming" else "", root,
      substr(.git_info()$commit, 1, 7), log_root)
  exit <- stats::setNames(rep(NA_integer_, length(schema)), schema)
  for (s in schema) {
    if (resume && .dump_finished(s, log_root, if (is.null(driver)) Sys.getenv("FD_DUMP_DRIVER", "RJDBC") else driver)) {
      say("%s: finished in an earlier run with nothing failed - skipped", s)
      exit[[s]] <- 0L
      next
    }
    if (!dir.exists(file.path(log_root, s))) { dir.create(file.path(log_root, s)); say("%s: created %s", s, file.path(log_root, s)) }
    say("%s: started", s)
    t0 <- Sys.time()
    r <- tryCatch(run_dump(s, resume = resume, driver = driver, wait = TRUE, root = root, log_root = log_root),
                  error = function(e) e)
    if (inherits(r, "error")) { say("%s: not started - %s", s, conditionMessage(r)); exit[[s]] <- -1L; break }
    slog <- .dump_current(s, log_root)$log
    exit[[s]] <- suppressWarnings(as.integer(readLines(paste0(slog, ".exit"))[1]))
    tail <- utils::tail(readLines(slog, warn = FALSE), 3)
    say("%s: exit %s after %.1f min; log %s", s, exit[[s]], as.numeric(difftime(Sys.time(), t0, units = "mins")), slog)
    for (l in tail) say("%s:   | %s", s, l)
    if (!identical(exit[[s]], 0L)) { say("%s failed as a whole: stopping here", s); break }
  }
  say("done: %d of %d schemas exited 0", sum(exit %in% 0L), length(schema))
  invisible(exit)
}

# Did the last run of schema `s` end well: exit 0, an overview with nothing failed, every written table of `driver`?
# An object the overview lists without dumping it (`tables =`) leaves the schema unfinished: orri and ops$einarhj were
# dumped in part until 2026-10-17, and their scripts now take the whole schema, which --resume completes.
.dump_finished <- function(s, log_root, driver) {
  log <- .dump_current(s, log_root)$log
  ov <- file.path(log_root, s, "_overview_tables.parquet")
  if (is.na(log) || !file.exists(ov)) return(FALSE)
  ex <- paste0(log, ".exit")
  if (!file.exists(ex) || !identical(suppressWarnings(as.integer(readLines(ex)[1])), 0L)) return(FALSE)
  o <- as.data.frame(nanoparquet::read_parquet(ov))
  all(c("status", "driver") %in% names(o)) && !any(o$status %in% c("failed", "listed")) &&
    all(o$driver[o$status %in% "written"] == driver)
}

# The schemas with a dump script, in the order a full run takes them: a small one first, to fail fast; stk last.
# all.R runs them; catalogue.R lists every schema without dumping one, and code.R keeps the SQL behind each.
.dump_schemas <- function(root = .repo_root()) {
  order <- c("asfis", "taxon", "fs_ufs", "uv", "rdbes", "dw", "dwstg", "fiskist", "simalinu", "ufs", "gear", "orri",
             "vessel", "channel", "ops_einarhj", "ops_sigfus", "logbook", "fiskifelagid", "agf", "ask", "vor", "kvoti", "kvotix",
             "adb", "fs_afladagbok", "afli", "fs_afli", "biota", "stk")
  scripts <- setdiff(sub("[.]R$", "", list.files(file.path(root, "dump", "oracle"), pattern = "[.]R$")),
                     c("all", "catalogue", "code"))
  c(intersect(order, scripts), setdiff(scripts, order))
}

# Is this machine ready to dump? Packages, $FISHYDATA and its free space, the commit the stamps will name, R's
# locale, then a connection through `driver` with its date and text checks, and each schema's objects and columns
# read as a dump reads them. Dumps nothing. Returns TRUE when all is well, invisibly; dump/oracle/all.R --check prints it.
dump_check <- function(schema = NULL, driver = Sys.getenv("FD_DUMP_DRIVER", "ROracle"), root = .repo_root()) {
  ok <- TRUE
  say <- function(good, ...) { message(if (isTRUE(good)) "  ok    " else "  NOT OK ", sprintf(...)); if (!isTRUE(good)) ok <<- FALSE }
  message("dump check, driver ", driver, ", from ", root)
  need <- c("mar", "DBI", "dplyr", "dbplyr", "duckdb", "nanoparquet", "tibble", "yaml",
            if (driver == "ROracle") "ROracle" else c("rJava", "RJDBC"))
  miss <- need[!vapply(need, requireNamespace, TRUE, quietly = TRUE)]
  say(!length(miss), "R %s; packages%s", getRversion(), if (length(miss)) paste(": missing", paste(miss, collapse = ", ")) else " all there")
  say(isTRUE(l10n_info()[["UTF-8"]]), "R locale %s%s", Sys.getlocale("LC_CTYPE"),
      if (isTRUE(l10n_info()[["UTF-8"]])) "" else " - not UTF-8: put LANG=en_US.UTF-8 in .Renviron")
  fd <- Sys.getenv("FISHYDATA")
  say(nzchar(fd), "FISHYDATA %s", if (nzchar(fd)) fd else "is not set: put FISHYDATA=/path in .Renviron")
  if (nzchar(fd)) {
    where <- if (dir.exists(fd)) fd else dirname(fd)
    df <- suppressWarnings(system2("df", c("-k", shQuote(where)), stdout = TRUE))
    free <- if (length(df) >= 2) as.numeric(strsplit(trimws(df[length(df)]), "[[:space:]]+")[[1]][4]) / 2^20 else NA
    say(isTRUE(free > 40), "%.0f GB free at %s (wanted 40: the Mac's unfinished dumps hold 11 GB, stk's trail adds about 9)",
        free, where)
  }
  g <- .git_info()
  say(!is.na(g$commit), "commit %s%s", substr(g$commit, 1, 7), if (isTRUE(g$dirty)) ", with uncommitted changes" else "")
  if (length(miss)) { message("connection not tried: install the missing packages first"); return(invisible(FALSE)) }
  con <- tryCatch(dump_connect(driver), error = function(e) e)
  if (inherits(con, "error")) { say(FALSE, "connection: %s", conditionMessage(con)); return(invisible(FALSE)) }
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  say(TRUE, "connected through %s; the date%s check passed", .oracle_driver(con), if (driver == "ROracle") " and text" else "")
  for (s in if (is.null(schema)) .dump_schemas(root) else schema) {
    o <- sub("^ops_", "ops$", s)
    n <- tryCatch(c(nrow(oracle_objects(con, o)), nrow(oracle_fields(con, o))), error = function(e) e)
    if (inherits(n, "error")) say(FALSE, "%s: %s", s, conditionMessage(n))
    else say(n[1] > 0 && n[2] > 0, "%s: %d tables and views, %d columns read from the catalogue", s, n[1], n[2])
  }
  message(if (ok) "ready to dump" else "not ready: see NOT OK above")
  invisible(ok)
}
