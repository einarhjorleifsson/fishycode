# ops$sigfus: the monthly summaries afli's monthly aggregate stations were loaded from, and the fjord squares' places
# (plan 056 §5, TODO 172).
# Side: preprocessing (logbook). See plan 014.
#
# Input:  raw/oracle/ops_sigfus/{gamall_humar,gomul_raekja,gomul_dragnot,fj_reitir}.parquet
# Output: staging/ops_sigfus/nephrops_monthly.parquet  Nephrops 1960-1999: vessel x month x square (x sub-square)
#         staging/ops_sigfus/shrimp_monthly.parquet    shrimp 1953-1986: vessel x month x shrimp area
#         staging/ops_sigfus/seine_monthly.parquet     Danish seine 1960-1970: boat code x month x square, with sets
#         staging/ops_sigfus/fj_reitir.parquet         each (shrimp area, fjord square): its square and sub-square
#
# Each row as the table holds it, under the grammar's names: catch in kg as recorded (no column says whole weight or
# tails); the tow time in hours, the source's unit (afli split a row where its minutes passed 9,999; decision 266).
# vid is skipnr where it names a vessel; 0 or empty is the fleet's (Nephrops) or none, NA here. The seine's skipnr is
# the table's own boat code, never a vid (plan 041 §1.1), so it is boat_code. `.row` is the row's place in the dump.
# Read by counts and columns only: ops$sigfus holds persons' tables too, and none is read here (decision 159).

source("R/paths.R")
suppressMessages(library(dplyr))
Sys.setenv(TZ = "UTC")

raw <- function(t) duckdbfs::open_dataset(fd_raw("oracle", "ops_sigfus", paste0(t, ".parquet"))) |> collect() |>
  mutate(.row = row_number())
vid_of <- function(x) if_else(is.na(x) | x == 0, NA_integer_, as.integer(x))

nephrops <- raw("gamall_humar") |>
  transmute(.row, year = as.integer(ar), month = as.integer(man), vid = vid_of(skipnr), sq = as.integer(reitur),
            ssq = as.integer(smareitur), sid = as.integer(tegund), tow_h = as.numeric(togtimi), catch = as.numeric(afli))
shrimp <- raw("gomul_raekja") |>
  transmute(.row, year = as.integer(ar), month = as.integer(man), vid = vid_of(skipnr), area = as.integer(skiki),
            svaedi = as.integer(svaedi), sid = as.integer(tegund), tow_h = as.numeric(togtimi),
            catch = as.numeric(afli))
seine <- raw("gomul_dragnot") |>
  transmute(.row, year = as.integer(ar), month = as.integer(man), boat_code = as.integer(skipnr),
            sq = as.integer(reitur), sid = as.integer(tegund), n_sets = as.integer(fj_kasta), catch = as.numeric(afli))
fj_reitir <- raw("fj_reitir") |>
  transmute(skiki = as.integer(skiki), fj_reitur = as.integer(fj_reitur), sq = as.integer(reitur),
            ssq = as.integer(smareitur))
stopifnot("a fjord square placed twice" = !anyDuplicated(fj_reitir[c("skiki", "fj_reitur")]))

dir <- fd_staging("ops_sigfus")
for (t in c("nephrops", "shrimp", "seine")) {
  duckdbfs::write_dataset(get(t), file.path(dir, paste0(t, "_monthly.parquet")))
  message(t, "_monthly: ", nrow(get(t)), " rows, ", round(sum(get(t)$catch, na.rm = TRUE) / 1e6, 1), " kt")
}
duckdbfs::write_dataset(fj_reitir, file.path(dir, "fj_reitir.parquet"))
message("fj_reitir: ", nrow(fj_reitir), " fjord squares")
