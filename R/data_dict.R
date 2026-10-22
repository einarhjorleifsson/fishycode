# data_dict.R — the raw dictionaries: the hand-kept overlay laid over the dump's, rewritten and checked (plan 040).
#
# Input:  a dump's folder, raw/oracle/<schema>/ (its parquet files, _overview_tables.parquet, _overview_fields.parquet,
#         _data-dict.yaml), and the overlay dump/oracle/meta/<schema>.yml
# Output: rewrite_data_dict() writes <folder>/_data-dict.yaml; check_data_dict() writes nothing
#
# Definitions only: targets sources R/ wholesale.
#
# The overlay's format is in dump/oracle/meta/README.md. dump_oracle_schema() merges it when it writes a dump's
# dictionary (.write_data_dict(), R/dump_oracle.R); rewrite_data_dict() does the same on a dump already made, from its
# files, without Oracle; check_data_dict() is the check when a dump is adopted (dump/oracle/README.md, section 11).
#
#   rewrite_data_dict(fd_raw("oracle_server", "kvoti"))
#   check_data_dict(fd_raw("oracle_server", "kvoti"))
#
# The data-dict tool (version 0.0.3) is the binary datadict::dd_install() puts in R's user cache, or $DATA_DICT, or one
# on the PATH. It is run with a UTF-8 locale. It reads no glob (decision 029), so a table dumped by year is checked one
# year file at a time and the counts are summed.

# A date-time as ISO 8601 in UTC with Z, with its fraction of a second where it has one (S12).
.dd_datetime <- function(x) {
  x <- as.POSIXct(x, tz = "UTC")
  s <- format(x, "%Y-%m-%dT%H:%M:%OS6", tz = "UTC")
  s <- sub("[.]?0+$", "", sub("([.][0-9]*[1-9])0+$", "\\1", s))
  s <- ifelse(grepl("T[0-9]{2}:[0-9]{2}$", s), paste0(s, ":00"), s)   # a whole minute lost its seconds above
  ifelse(is.na(x), NA_character_, paste0(s, "Z"))
}

# YAML as data-dict (YAML 1.2) reads it: R's yaml reads Y, N, yes, no, on and off as booleans (YAML 1.1), and lods'
# veidisvaedi has codes Y and N. A sequence stays a list: as a vector, one of length 1 is written back as a scalar,
# which the spec refuses (Q-1-11).
.dd_read_yaml <- function(path) {
  b <- function(x) if (tolower(x) %in% c("true", "false")) tolower(x) == "true" else x
  yaml::read_yaml(path, handlers = list("bool#yes" = b, "bool#no" = b, seq = function(x) as.list(x)))
}

# The overlay of a dump folder (raw/oracle/<folder>/), or NULL where there is none. Read from the repo the R session
# runs in, as the dump scripts do (run from the repo root).
.data_dict_overlay <- function(folder, dir = NULL) {
  if (is.null(dir)) {
    root <- tryCatch(.repo_root(), error = function(e) NULL)
    if (is.null(root)) return(NULL)
    dir <- file.path(root, "dump", "oracle", "meta")
  }
  f <- file.path(dir, paste0(folder, ".yml"))
  if (file.exists(f)) .dd_read_yaml(f) else NULL
}

# The overlay laid over a dictionary written from the dump (a list as yaml reads it). `overlay` is a list, a path or
# NULL. The overlay wins on every property it sets; a table's details are the overlay's, then the dump's note. The
# representative values are made to fit the merged type. A table, column or relationship the overlay names that the
# dump does not hold is left out and listed in the dictionary's todo, so validate-spec reports it.
.data_dict_merge <- function(dd, overlay) {
  if (is.null(overlay)) return(dd)
  if (is.character(overlay)) overlay <- .dd_read_yaml(overlay)
  lacking <- character()
  tabs <- vapply(dd$tables, `[[`, "", "name")
  for (ot in overlay$tables) {
    i <- match(ot$name, tabs)
    if (is.na(i)) { lacking <- c(lacking, ot$name); next }
    t <- dd$tables[[i]]
    note <- t$details
    for (p in setdiff(names(ot), c("name", "columns"))) t[[p]] <- ot[[p]]
    if (!is.null(ot$details) && !is.null(note)) t$details <- paste0(ot$details, "\n\nFrom the dump: ", note)
    cols <- vapply(t$columns, `[[`, "", "name")
    for (oc in ot$columns) {
      j <- match(oc$name, cols)
      if (is.na(j)) { lacking <- c(lacking, paste0(ot$name, ".", oc$name)); next }
      t$columns[[j]] <- .data_dict_merge_column(t$columns[[j]], oc, paste0(ot$name, ".", oc$name))
    }
    t <- t[c(intersect(c("name", "label", "source", "description", "details", "definitions", "constraints", "todo",
                         "columns"), names(t)), setdiff(names(t), c("name", "label", "source", "description", "details",
                                                                    "definitions", "constraints", "todo", "columns")))]
    dd$tables[[i]] <- t
  }
  tabs <- vapply(dd$tables, `[[`, "", "name")
  for (r in overlay$relationships) {
    named <- setdiff(unique(regmatches(r$join, gregexpr("[A-Za-z_][A-Za-z0-9_$]*(?=[.])", r$join, perl = TRUE))[[1]]),
                     names(r$aliases))
    named <- union(named, unlist(r$aliases))
    if (all(named %in% tabs)) dd$relationships <- c(dd$relationships, list(r))
    else lacking <- c(lacking, sprintf("the relationship %s", r$join))
  }
  if (!is.null(overlay$glossary)) dd$glossary <- c(dd$glossary, overlay$glossary)
  if (length(lacking))
    dd$todo <- paste(c(dd$todo, paste0("The overlay names what this dump does not hold: ", paste(lacking, collapse = ", "),
                                       ". Correct dump/oracle/meta/", overlay$name, ".yml.")), collapse = " ")
  dd
}

.data_dict_merge_column <- function(col, oc, where) {
  empty <- is.null(col$type)   # no value in the dump (.write_data_dict())
  if (identical(oc$type, "enum")) {
    v <- oc$values
    if (is.null(v) || !length(v) || !all(vapply(v, is.character, NA)))
      stop(where, ": an enum's values must be a map from code to label, each label text (quote it)", call. = FALSE)
  }
  for (p in setdiff(names(oc), "name")) col[[p]] <- oc[[p]]
  ty <- col$type
  if (identical(ty, "enum")) col$examples <- col$range <- NULL
  if (identical(ty, "datetime") && !is.null(col$time_zone) && !is.null(col$range))
    col$range <- lapply(col$range, function(v) if (is.character(v)) sub("Z$", "", v) else v)
  if (empty && !is.null(ty) && is.null(col$range) && is.null(col$examples)) {
    if (grepl("^(number\\((ordinal|quantity)\\)|date|datetime)$", ty)) col$range <- list(-Inf, Inf)
    else if (!identical(ty, "enum") && !identical(ty, "boolean")) {
      col$todo <- paste(col$todo, sprintf("The overlay types it %s%s; no value here to show.", ty,
                                          if (is.null(col$units)) "" else paste0(", in ", col$units)))
      col$type <- col$units <- NULL
    }
  }
  first <- c("name", "label", "type", "units", "time_zone", "values", "range", "examples", "constraints", "description",
             "details", "todo")
  col[c(intersect(first, names(col)), setdiff(names(col), first))]
}

# Rewrite a dump's _data-dict.yaml from its files and the overlay, without Oracle: after the overlay changes, or to
# give an older dump the writer's fixes. The objects and columns are the dump's own overviews; the description keeps
# the dump's time, script and commit, from the overview's stamps. Returns the columns' table (.write_data_dict()).
rewrite_data_dict <- function(dir, overlay = .data_dict_overlay(basename(dir))) {
  ov_path <- file.path(dir, "_overview_tables.parquet")
  objects <- as.data.frame(nanoparquet::read_parquet(ov_path))
  fields  <- as.data.frame(nanoparquet::read_parquet(file.path(dir, "_overview_fields.parquet")))
  if (is.null(objects$partitioned)) objects$partitioned <- dir.exists(file.path(dir, objects$name))
  m <- curated_provenance(ov_path)
  stamp <- function(k) { v <- m$value[m$key == paste0("fd.", k)]; if (length(v)) v[1] else NA_character_ }
  run <- list(dumped = stamp("dumped"), script = stamp("script"), commit = stamp("commit"))
  g <- .git_info()
  .write_data_dict(dir, objects$owner[1], objects, fields, run, overlay = overlay,
                   rewritten = list(at = format(Sys.time(), "%Y-%m-%d", tz = "UTC"), commit = g$commit))
}

.dd_bin <- function() {
  b <- if (requireNamespace("datadict", quietly = TRUE)) datadict::dd_path(check = FALSE) else ""
  if (!nzchar(b)) b <- Sys.getenv("DATA_DICT", Sys.which("data-dict")[[1]])
  if (!nzchar(b) || !file.exists(b)) stop("no data-dict binary: datadict::dd_install(), or set DATA_DICT", call. = FALSE)
  b
}

# One run of the tool, its JSON report parsed.
.dd_json <- function(bin, args) {
  out <- suppressWarnings(system2(bin, c(args, "--json"), stdout = TRUE, stderr = FALSE,
                                  env = "LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8"))
  if (!length(out)) stop("data-dict ", args[1], " gave no report", call. = FALSE)
  jsonlite::fromJSON(paste(out, collapse = "\n"), simplifyVector = FALSE)
}

# The check when a dump is adopted (decision 109's swap, after compare_dumps()): validate-spec on the dump's
# _data-dict.yaml, then, where it passes, validate-data on the tables that carry an assertion or an enum, which only
# the overlay gives. A failing check is reported with its counts; the rows' values stay out of the report, in the
# attribute "problems" (they are data). `tables` checks those instead. A check is news when it fails otherwise than
# its description expects (.dd_expected()), or cannot be evaluated: that is what is explained before a dump is adopted.
# Returns, invisibly, one row per check, summed over a table's year files: the table, the check's code (D07 an
# assertion, D04 an enum's values, M.. the file against the dictionary), its columns, the assertion, the outcome, the
# rows read and failed, the failures expected, and whether it is news. Attributes: "spec" (validate-spec's problems),
# "problems" (validate-data's, with the values they quote) and "files" (the checks per year file).
check_data_dict <- function(dir, tables = NULL, data = TRUE, bin = .dd_bin()) {
  f <- file.path(dir, "_data-dict.yaml")
  spec <- .dd_json(bin, c("validate-spec", f))
  sp <- .dd_problems(spec$problems)
  n_err <- sum(sp$severity == "error")
  message(sprintf("%s: validate-spec %s, %d errors, %d warnings%s", basename(dir), spec$status, n_err,
                  sum(sp$severity == "warning"),
                  if (nrow(sp)) paste0(" (", paste(names(table(sp$code)), table(sp$code), collapse = ", "), ")") else ""))
  out <- data.frame(table = character(), file = character(), code = character(), columns = character(),
                    assertion = character(), outcome = character(), rows = numeric(), failed = numeric())
  if (n_err || !data) return(invisible(structure(out, spec = sp)))
  dd <- .dd_read_yaml(f)
  checked <- vapply(dd$tables, function(t) length(t$constraints) > 0 ||
    any(vapply(t$columns, function(c) length(c$constraints) > 0 || identical(c$type, "enum"), NA)), NA)
  todo <- if (is.null(tables)) dd$tables[checked] else dd$tables[vapply(dd$tables, `[[`, "", "name") %in% tables]
  problems <- list()
  for (t in todo) {
    src <- t$source$parquet
    files <- if (grepl("[*?]", src)) Sys.glob(file.path(dir, src)) else file.path(dir, src)
    for (p in files) {
      if (grepl("[*?]", src)) {
        one <- dd
        one$tables <- list(utils::modifyList(t, list(source = list(parquet = normalizePath(p)))))
        one$relationships <- NULL
        tf <- tempfile("data-dict_", fileext = ".yaml")
        yaml::write_yaml(one, tf)
        r <- .dd_json(bin, c("validate-data", tf))
        unlink(tf)
      } else {
        r <- .dd_json(bin, c("validate-data", "--table", t$name, f))
      }
      part <- if (grepl("[*?]", src)) substring(p, nchar(dir) + 2) else src
      for (s in r$steps) {
        if (is.null(s$table) || s$table != t$name) next
        out[nrow(out) + 1, ] <- list(t$name, part, s$code, paste(unlist(s$columns), collapse = ", "),
                                     if (is.null(s$assertion)) NA_character_ else s$assertion, s$outcome,
                                     if (is.null(s$row_count)) NA_real_ else s$row_count,
                                     if (is.null(s$failed_row_count)) NA_real_ else s$failed_row_count)
      }
      problems <- c(problems, lapply(r$problems, function(x) c(x, list(file = part))))
    }
  }
  if (!nrow(out)) return(invisible(structure(out, spec = sp, problems = problems, files = out)))
  out$assertion[is.na(out$assertion)] <- ""
  key <- paste(out$table, out$code, out$columns, out$assertion, sep = "\r")
  res <- do.call(rbind, lapply(split(out, factor(key, unique(key))), function(d) data.frame(
    table = d$table[1], code = d$code[1], columns = d$columns[1], assertion = d$assertion[1],
    outcome = if (any(d$outcome == "unevaluated")) "unevaluated" else if (any(d$outcome == "fail")) "fail" else "pass",
    rows = sum(d$rows, na.rm = TRUE), failed = sum(d$failed, na.rm = TRUE))))
  rownames(res) <- NULL
  ex <- .dd_expected(dd)
  res$expected <- ex$expected[match(paste(res$table, res$assertion), paste(ex$table, ex$assertion))]
  res$expected[is.na(res$expected) & res$code %in% c("D04", "D07")] <- 0
  res$news <- res$outcome == "unevaluated" | (res$outcome == "fail" & !res$code %in% c("D04", "D07")) |
              (res$code %in% c("D04", "D07") & res$failed != res$expected)
  shown <- res[res$code %in% c("D04", "D07") | res$outcome != "pass", ]
  for (i in seq_len(nrow(shown)))
    message(sprintf("  %-4s %-20s %-4s %s of %s rows false%s  %s", if (shown$news[i]) "NEWS" else "ok",
                    shown$table[i], shown$code[i], format(shown$failed[i], big.mark = ","),
                    format(shown$rows[i], big.mark = ","),
                    if (isTRUE(shown$expected[i] > 0)) sprintf(" (expected %s)", format(shown$expected[i], big.mark = ","))
                    else "",
                    if (nzchar(shown$assertion[i])) shown$assertion[i] else paste("values of", shown$columns[i])))
  invisible(structure(res, spec = sp, problems = problems, files = out))
}

# What each assertion is expected to give on the dump it was tested on: the count in its description ("Expected false
# on 157 rows", "on 1 row"), else 0. A known defect is checked by the claim the data should meet, and its count is the defect's.
.dd_expected <- function(dd) {
  rows <- lapply(dd$tables, function(t) {
    a <- c(t$constraints, unlist(lapply(t$columns, function(c) c$constraints), recursive = FALSE))
    a <- Filter(function(x) is.list(x) && !is.null(x$assert), a)
    if (!length(a)) return(NULL)
    n <- vapply(a, function(x) {
      d <- if (is.null(x$description)) "" else x$description
      m <- regmatches(d, regexpr("[Ee]xpected false on [0-9,]+ rows?", d))
      if (length(m)) as.numeric(gsub("[^0-9]", "", m)) else 0
    }, 0)
    data.frame(table = t$name, assertion = vapply(a, function(x) x$assert, ""), expected = n)
  })
  r <- do.call(rbind, rows)
  if (is.null(r)) data.frame(table = character(), assertion = character(), expected = numeric()) else r
}

# The problems of a report, without the values they quote.
.dd_problems <- function(p) {
  if (!length(p)) return(data.frame(code = character(), severity = character(), table = character(),
                                    columns = character(), message = character()))
  g <- function(x, k) if (is.null(x[[k]])) NA_character_ else paste(unlist(x[[k]]), collapse = ", ")
  data.frame(code = vapply(p, g, "", "code"), severity = vapply(p, g, "", "severity"),
             table = vapply(p, g, "", "table"), columns = vapply(p, g, "", "columns"),
             message = vapply(p, g, "", "expected"))
}
