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

# Start dump/oracle/<schema>.R for each schema, one after the other, in one background process. Returns its process id
# (NA with wait = TRUE), invisibly.
run_dump <- function(schema, resume = FALSE, wait = FALSE, root = .repo_root(), log_root = fd_raw("oracle")) {
  scripts <- file.path("dump", "oracle", paste0(schema, ".R"))
  if (length(miss <- schema[!file.exists(file.path(root, scripts))]))
    stop("no dump script for ", paste(miss, collapse = ", "), " (dump/oracle/<schema>.R)", call. = FALSE)
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
  steps <- sprintf("Rscript %s%s > %s 2>&1; echo $? > %s", shQuote(scripts), if (resume) " --resume" else "",
                   shQuote(logs), shQuote(paste0(logs, ".exit")))
  body <- sprintf("cd %s && %s", shQuote(root), paste(steps, collapse = "; "))
  awake <- if (nzchar(Sys.which("caffeinate"))) "caffeinate -i " else ""
  if (wait) {
    for (s in schema) writeLines(c("NA", logs[[s]]), file.path(log_root, s, "_logs", "current"))
    system2("/bin/sh", c("-c", shQuote(paste0(awake, "/bin/sh -c ", shQuote(body)))))
    pid <- NA_integer_
  } else {
    outer <- sprintf("nohup %s/bin/sh -c %s > /dev/null 2>&1 & echo $!", awake, shQuote(body))
    pid <- as.integer(system2("/bin/sh", c("-c", shQuote(outer)), stdout = TRUE))
    for (s in schema) writeLines(c(as.character(pid), logs[[s]]), file.path(log_root, s, "_logs", "current"))
  }
  message(sprintf("%s %s%s%s; logs in %s/<schema>/_logs/", if (wait) "ran" else "started",
                  paste(schema, collapse = ", "), if (resume) " (resume)" else "",
                  if (wait) "" else sprintf(" in process %d", pid), log_root),
          if (wait) "" else "\n  follow with dump_status()")
  invisible(pid)
}

# Where each schema's dump stands: running, queued (waiting for an earlier schema in the same process), finished
# (with its exit code and the overview's counts and failures), or stopped (the process ended without finishing it).
dump_status <- function(schema = NULL, log_root = fd_raw("oracle"), lines = 3) {
  if (is.null(schema)) schema <- basename(list.dirs(log_root, recursive = FALSE))
  out <- lapply(schema, function(s) {
    cur <- file.path(log_root, s, "_logs", "current")
    logs <- sort(list.files(file.path(log_root, s, "_logs"), pattern = "[.]log$", full.names = TRUE))
    log <- if (file.exists(cur)) readLines(cur)[2] else if (length(logs)) logs[length(logs)] else NA_character_
    pid <- if (file.exists(cur)) suppressWarnings(as.integer(readLines(cur)[1])) else NA_integer_
    alive <- !is.na(pid) && isTRUE(tools::pskill(pid, 0L))
    exit <- if (!is.na(log) && file.exists(paste0(log, ".exit"))) as.integer(readLines(paste0(log, ".exit"))[1]) else NA_integer_
    state <- if (!is.na(exit)) (if (exit == 0) "finished" else sprintf("finished with error %d", exit))
             else if (alive && !is.na(log) && file.exists(log)) "running"
             else if (alive) "queued"
             else if (!is.na(log)) "stopped"
             else "never run"
    ov_path <- file.path(log_root, s, "_overview_tables.parquet")
    counts <- ""
    if (grepl("finished", state) && file.exists(ov_path)) {
      ov <- as.data.frame(nanoparquet::read_parquet(ov_path))
      if ("status" %in% names(ov)) {
        counts <- paste(names(table(ov$status)), table(ov$status), collapse = ", ")
        f <- ov[ov$status %in% "failed", ]
        if (nrow(f)) counts <- paste0(counts, "\n    failed: ", paste(sprintf("%s (%s)", f$name,
          substr(gsub("[[:space:]]+", " ", f$error), 1, 60)), collapse = "\n            "))
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
