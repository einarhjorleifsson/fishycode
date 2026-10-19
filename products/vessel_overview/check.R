# Checks the vessel overview's R service (plan 030 step 3): the column allowlist, every endpoint's answer for three
# vessels and the time it takes, a photo served whole, and the requests it must refuse. Stops at the first failure.
#
# Input:  what products/vessel_overview/api.R reads
# Output: a printed table; nothing written
#
# Run from the repository root:  Rscript products/vessel_overview/check.R
# It calls the app in this process, with no server: the same code a request reaches. Year ranges and the whole history
# (from=1900&to=2100) are asked too (decision 143). The vessels (plan 030 §4.4):
# 2757 (most pings in 2026-09), 3739 (no logbook trip, no register history), 2652 (no ping since 2024).

source("R/paths.R")
source("products/vessel_overview/api.R")

con <- DBI::dbConnect(duckdb::duckdb())
app <- vessel_overview_app(con, "products/vessel_overview/www")
get <- function(path, query = "") app$call(list(REQUEST_METHOD = "GET", PATH_INFO = path, QUERY_STRING = query))
read_answer <- function(body) {
  f <- tempfile(fileext = ".parquet"); writeBin(body, f); on.exit(unlink(f))
  list(cols = DBI::dbGetQuery(con, sprintf("DESCRIBE SELECT * FROM read_parquet('%s')", f))$column_name,
       n = DBI::dbGetQuery(con, sprintf("SELECT count(*) AS n FROM read_parquet('%s')", f))$n)
}

# 1. No personal column is allowlisted -------------------------------------------------------------------------------
stopifnot("a personal column is allowlisted" = !any(unlist(ALLOW) %in% PERSONAL))

# 2. Every endpoint: columns exactly as allowlisted, none personal, rows and time --------------------------------------
asks <- c(list(c("vessels", "")), lapply(c(2757L, 3739L, 2652L), function(v) {
  base <- paste0("vid=", v)
  all <- paste0(base, "&from=1900&to=2100")
  list(c("register", base), c("landings", paste0(base, "&n=20")), c("trips", paste0(base, "&n=10")),
       c("stations", paste0(base, "&n=10")), c("station_catch", paste0(base, "&n=10")), c("trail_years", base),
       c("trail", base), c("photos", base), c("trail", paste0(base, "&from=2024&to=2026")),
       c("landings", all), c("trips", all), c("trip_summary", all), c("stations", paste0(base, "&from=2025&to=2026")),
       c("station_catch", paste0(base, "&from=2025&to=2026")), c("landing_trips", base), c("landings", paste0(base, "&n=1")),
       c("voyages", paste0(base, "&from=2024&to=2026")), c("port_calls", paste0(base, "&from=2024&to=2026")),
       c("voyages", paste0(base, "&n=5")), c("port_calls", paste0(base, "&n=5")))
}) |> unlist(recursive = FALSE),
lapply(c(2757L, 3739L, 2652L), function(v) lapply(names(HIST), function(t) c("hist", sprintf("vid=%d&table=%s", v, t)))) |>
  unlist(recursive = FALSE))

res <- do.call(rbind, lapply(asks, function(a) {
  t0 <- Sys.time(); r <- get(paste0("/api/", a[1]), a[2]); s <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (r$status != 200L) stop(sprintf("/api/%s?%s answered %d: %s", a[1], a[2], r$status, r$body))
  key <- if (a[1] == "hist") paste0("hist_", sub("^.*table=", "", a[2])) else a[1]
  x <- read_answer(r$body)
  if (!identical(x$cols, ALLOW[[key]])) stop(sprintf("/api/%s?%s: columns differ from the allowlist", a[1], a[2]))
  data.frame(query = paste0(a[1], "?", a[2]), rows = x$n, kb = round(length(r$body) / 1024, 1), seconds = round(s, 3))
}))
print(knitr::kable(res, caption = "vessel overview: every endpoint"))
# The vessel list is computed once, when the server starts, and kept: its limit is the start's, not a click's
start <- startsWith(res$query, "vessels?")
stopifnot("an answer took a second or more" = all(res$seconds[!start] < 1),
          "the vessel list took five seconds or more" = all(res$seconds[start] < 5))

# 3. A photo is served whole, from the files the index lists ----------------------------------------------------------
ph <- DBI::dbGetQuery(con, sprintf("SELECT vid, path, md5 FROM %s WHERE best AND kind = 'photo' ORDER BY vid LIMIT 1",
                                   src("staging", "mbl", "photo.parquet")))
r <- get("/photo", sprintf("vid=%d&file=%s", ph$vid, basename(ph$path)))
f <- tempfile(); writeBin(r$body, f)
stopifnot("a listed photo is not served whole" = r$status == 200L && unname(tools::md5sum(f)) == ph$md5)

# 4. What it must refuse ------------------------------------------------------------------------------------------------
refuse <- list(c("/api/register", "vid=abc", 400L), c("/api/register", "vid=1;DROP", 400L),
               c("/api/register", "", 400L), c("/api/hist", "vid=2757&table=vessel_owners_hist", 400L),
               c("/api/trail", "vid=2757&from=2024", 400L), c("/api/trail", "vid=2757&from=x&to=2026", 400L),
               c("/api/nope", "vid=1", 404L), c("/photo", "vid=2757&file=../../x.jpg", 404L),
               c("/photo", sprintf("vid=%d&file=9999-0001.jpg", ph$vid), 404L), c("/etc/passwd", "", 404L))
for (x in refuse) {
  st <- get(x[1], x[2])$status
  if (st != as.integer(x[3])) stop(sprintf("%s?%s answered %d, not %s", x[1], x[2], st, x[3]))
}
cat(sprintf("all checks passed: %d answers, %d refusals, one photo (vid %d)\n", nrow(res), length(refuse), ph$vid))
