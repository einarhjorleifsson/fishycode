# ices_workflow_scenarios.R — what EFLALO shapes the ICES VMS/logbook workflow accepts,
# and what each shape does to Table 1 and Table 2.
#
# Input:  a checkout of ices-eg/ICES-VMS-and-Logbook-Data-Call (tested at a844911, 2026-10-05),
#         by default a sibling of this repo; override with ICES_VMS_REPO
#           0_global.R                          only its function definitions are evaluated
#           resources/RDB_ISSG_Metier_list.csv  the valid metier list, read locally
#         vmstools 0.77 (installed)
# Output: printed tables only; nothing is written
#
# One synthetic vessel, one 3-day OTB trip (61 hourly pings, 3 h steaming at each end),
# landing 6,000 kg. Blocks 1-3 run with the workflow's own code: functions from 0_global.R
# and vmstools are called, the rest is copied verbatim from the block scripts. Three
# substitutions, none of which touch what is being tested:
# - network steps skipped: DATSU code lists, habitat/depth layers, Benthis gear width
# - TACSAT cleaning skipped: the synthetic pings are all at sea and valid
# - activity detection replaced by a 1-6 kn speed rule, because the workflow's own rule
#   for gears outside autoDetectionGears classes every ping as steaming (shown last)
#
# Expected (2026-10-07): A spreads 1000/2000/3000 kg over days 1-3 with 3 fishing days;
# B and C put all 6000 kg on one day with 1 fishing day; D fails in table 2; E loses every
# EFLALO column; F keeps no trip; G runs but its table 2 row has no rectangle; H crashes;
# dropping the day level spreads 1636/2618/1745; one row per day at sea gives 2000 each.

suppressMessages({
  library(vmstools)
  library(sf)
  library(data.table)
  library(dplyr)
  library(doBy)
  library(lubridate)
  library(here)
})

ices_repo <- Sys.getenv("ICES_VMS_REPO", here("..", "ICES-VMS-and-Logbook-Data-Call"))
stopifnot(file.exists(file.path(ices_repo, "0_global.R")))

# Workflow functions ----------------------------------------------------------
# 0_global.R installs packages and downloads 1.2 GB at top level, so it is not sourced.
# Only its top-level `name <- function(...)` assignments are evaluated.
G <- new.env()
for (e in as.list(parse(file.path(ices_repo, "0_global.R"), keep.source = FALSE))) {
  is_fun <- is.call(e) && (identical(e[[1]], as.name("<-")) || identical(e[[1]], as.name("="))) &&
    is.call(e[[3]]) && identical(e[[3]][[1]], as.name("function"))
  if (is_fun) eval(e, envir = G)
}
attach(G, name = "ices_global", warn.conflicts = FALSE)
valid_metiers <- fread(file.path(ices_repo, "resources", "RDB_ISSG_Metier_list.csv"))$Metier_level6
intvThres <- 240

# Synthetic TACSAT ------------------------------------------------------------
t0 <- as.POSIXct("2024-03-04 06:00", tz = "GMT")
tt <- seq(t0, as.POSIXct("2024-03-06 18:00", tz = "GMT"), by = "1 hour")
n <- length(tt)
tacsat0 <- data.frame(
  VE_COU = "XXX", VE_REF = "V1",
  SI_LATI = 56.2 + seq(0, 0.2, length.out = n),
  SI_LONG = 2.3 + 0.3 * sin(seq(0, 6, length.out = n)),
  SI_DATE = format(tt, "%d/%m/%Y"), SI_TIME = format(tt, "%H:%M"),
  SI_SP = ifelse(seq_len(n) <= 3 | seq_len(n) > n - 3, 10, 3.5),
  SI_HE = 90)
rect <- unique(ICESrectangle(tacsat0))

# Synthetic EFLALO scenarios ---------------------------------------------------
base <- data.frame(
  VE_REF = "V1", VE_FLT = "", VE_COU = "XXX", VE_LEN = 30, VE_KW = 800, VE_TON = 300,
  FT_REF = "T1", FT_DCOU = "XXX", FT_DHAR = "XXAAA", FT_DDAT = "04/03/2024", FT_DTIME = "06:00",
  FT_LCOU = "XXX", FT_LHAR = "XXAAA", FT_LDAT = "06/03/2024", FT_LTIME = "18:00",
  LE_ID = "T1_1", LE_CDAT = "06/03/2024", LE_GEAR = "OTB", LE_MSZ = 100,
  LE_RECT = rect[1], LE_DIV = "27.4.b", LE_MET = "OTB_DEF_100-119_0_0",
  LE_KG_COD = 6000, LE_EURO_COD = 12000, LE_KG_HAD = 0, LE_EURO_HAD = 0)

per_day <- function(kg) {
  x <- base[rep(1, 3), ]
  x$LE_ID <- paste0("T1_", 1:3)
  x$LE_CDAT <- c("04/03/2024", "05/03/2024", "06/03/2024")
  x$LE_KG_COD <- kg
  x$LE_EURO_COD <- 2 * kg
  x
}

scenarios <- list(
  A_daily_events   = per_day(c(1000, 2000, 3000)),
  B_trip_CDAT_land = base,
  C_trip_CDAT_dep  = transform(base, LE_CDAT = "04/03/2024"),
  D_trip_CDAT_NA   = transform(base, LE_CDAT = NA),
  E_totals_only    = base |>
    mutate(LE_KG_TOT = LE_KG_COD, LE_EURO_TOT = LE_EURO_COD) |>
    select(-c(LE_KG_COD, LE_EURO_COD, LE_KG_HAD, LE_EURO_HAD)),
  F_no_times       = transform(base, FT_DTIME = NA, FT_LTIME = NA),
  G_no_rect        = transform(base, LE_RECT = NA),
  H_single_species = select(base, -c(LE_KG_HAD, LE_EURO_HAD)))

# One pass of blocks 1-3 --------------------------------------------------------
run <- function(eflalo, tacsat = tacsat0, year = 2024,
                level = c("day", "ICESrectangle", "trip")) {
  out <- list()
  ## Block 1: format and clean (1.1, 1.3.3-1.3.6) --------------------------------
  tacsat <- formatTacsat(tacsat)
  tacsat$SI_DATIM <- as.POSIXct(paste(tacsat$SI_DATE, tacsat$SI_TIME), tz = "GMT", format = "%d/%m/%Y  %H:%M")
  eflalo <- formatEflalo(eflalo)
  eflalo <- eflalo[!duplicated(create_trip_id(eflalo)), ]
  eflalo$FT_DDATIM <- convert_to_datetime(eflalo$FT_DDAT, eflalo$FT_DTIME)
  eflalo$FT_LDATIM <- convert_to_datetime(eflalo$FT_LDAT, eflalo$FT_LTIME)
  eflalo <- eflalo[!is.na(eflalo$FT_DDATIM) & !is.na(eflalo$FT_LDATIM), ]
  eflalo <- remove_before_jan(eflalo, year)
  eflalo <- eflalo[which(eflalo$FT_LDATIM >= eflalo$FT_DDATIM), ]
  out$eflalo_rows_after_clean <- nrow(eflalo)
  if (nrow(eflalo) == 0) return(out)
  ## Block 2: link, activity, dispatch (2.2-2.4) ---------------------------------
  tacsatp <- data.frame(mergeEflalo2Tacsat(eflalo, tacsat))
  out$pings_in_a_trip <- sum(tacsatp$FT_REF != 0)
  tacsatp <- subset(tacsatp, FT_REF != 0)
  for (col in c("LE_GEAR", "LE_MSZ", "VE_LEN", "VE_KW", "LE_RECT", "LE_MET", "LE_WIDTH", "VE_FLT", "VE_COU"))
    tacsatp[[col]] <- eflalo[[col]][match(tacsatp$FT_REF, eflalo$FT_REF)]
  for (col in c("LE_GEAR", "LE_MSZ", "LE_RECT", "LE_MET")) {
    a <- suppressWarnings(trip_assign(tacsatp, eflalo, col = col, haul_logbook = F))
    tacsatp <- rbindlist(list(tacsatp[tacsatp$FT_REF %!in% a$FT_REF, ], a), fill = T)
  }
  tacsatp <- intvTacsat(as.data.frame(tacsatp), level = "trip", fill.na = TRUE)
  tacsatp$INTV[tacsatp$INTV > intvThres] <- 2 * intvThres
  tacsatp$INTV[is.na(tacsatp$INTV)] <- intvThres
  tacsatp$SI_STATE <- ifelse(tacsatp$SI_SP >= 1 & tacsatp$SI_SP <= 6, "f", "s")   # substitution
  tacsatp <- tacsatp[tacsatp$LE_GEAR == sapply(strsplit(tacsatp$LE_MET, "_"), `[`, 1), ]
  tacsatp <- tacsatp |> filter(LE_MET %in% valid_metiers)
  # 2.4.1, verbatim: the step that fails on one species column or on totals only
  idx_kg <- grep("LE_KG_", colnames(eflalo)[colnames(eflalo) %!in% c("LE_KG_TOT")])
  idx_euro <- grep("LE_EURO_", colnames(eflalo)[colnames(eflalo) %!in% c("LE_EURO_TOT")])
  if ("LE_KG_TOT" %!in% names(eflalo)) eflalo$LE_KG_TOT <- rowSums(eflalo[, idx_kg], na.rm = TRUE)
  if ("LE_EURO_TOT" %!in% names(eflalo)) eflalo$LE_EURO_TOT <- rowSums(eflalo[, idx_euro], na.rm = TRUE)
  eflalo <- eflalo[, -c(idx_kg, idx_euro)]
  out$eflalo_cols_after_2.4.1 <- ncol(eflalo)
  if (ncol(eflalo) == 0) return(out)
  eflaloM <- subset(eflalo, FT_REF %in% unique(tacsatp$FT_REF))
  tacsatp$SI_STATE <- ifelse(tacsatp$SI_STATE == "f", 1, 0)
  tacsatp <- tacsatp[tacsatp$SI_STATE == 1 & !is.na(tacsatp$INTV) & tacsatp$INTV > 0, ]
  tE <- suppressWarnings(splitAmongPings(tacsat = tacsatp, eflalo = eflaloM, variable = "all",
                                         level = level, conserve = TRUE, by = "INTV"))
  out$table1_kg_by_day <- tE |>
    group_by(SI_DATE) |>
    summarise(fishing_pings = n(), kg = round(sum(LE_KG_TOT, na.rm = TRUE)))
  ## Block 3: table 2, verbatim (3.1) ---------------------------------------------
  eflalo$Year <- year(eflalo$FT_LDATIM)
  eflalo$Month <- month(eflalo$FT_LDATIM)
  eflalo$INTV <- 1
  eflalo$record <- 1
  res <- aggregate(eflalo$record, by = as.list(eflalo[, c("VE_COU", "VE_REF", "LE_CDAT")]), FUN = sum, na.rm = TRUE)
  colnames(res) <- c("VE_COU", "VE_REF", "LE_CDAT", "nrRecords")
  eflalo <- merge(eflalo, res, by = c("VE_COU", "VE_REF", "LE_CDAT"))
  eflalo$INTV <- eflalo$INTV / eflalo$nrRecords
  out$table2 <- eflalo |>
    group_by(Month, LE_RECT, LE_MET) |>
    summarise(FishingDays = sum(INTV), TotWeight = sum(LE_KG_TOT), .groups = "drop")
  out
}

quietly <- function(expr) {
  # splitAmongPings and eflalo2Pings print progress lines; keep only the result
  res <- NULL
  invisible(capture.output(res <- tryCatch(suppressWarnings(expr),
                                           error = function(e) list(ERROR = conditionMessage(e)))))
  res
}

# Scenarios ---------------------------------------------------------------------
for (s in names(scenarios)) {
  cat("\n=====", s, "=====\n")
  print(quietly(run(scenarios[[s]])))
}

cat("\n===== B with the day level dropped from the dispatch =====\n")
print(quietly(run(scenarios$B_trip_CDAT_land, level = c("ICESrectangle", "trip")))$table1_kg_by_day)

cat("\n===== one row per day at sea, kg split equally =====\n")
print(quietly(run(per_day(c(2000, 2000, 2000))))[c("table1_kg_by_day", "table2")])

cat("\n===== a vessel with pings but no EFLALO trip =====\n")
m <- quietly(mergeEflalo2Tacsat(formatEflalo(transform(base, VE_REF = "OTHER")), formatTacsat(tacsat0)))
print(table(FT_REF = m$FT_REF))

# Which columns must exist? ---------------------------------------------------
cat("\n===== formatEflalo / formatTacsat with one column dropped =====\n")
for (cc in names(base))
  cat(sprintf("EFLALO %-12s %s\n", cc,
              tryCatch({ formatEflalo(base[, setdiff(names(base), cc)]); "ok" }, error = function(e) "ERROR")))
for (cc in names(tacsat0))
  cat(sprintf("TACSAT %-12s %s\n", cc,
              tryCatch({ formatTacsat(tacsat0[, setdiff(names(tacsat0), cc)]); "ok" }, error = function(e) "ERROR")))

# The speed rule for gears outside autoDetectionGears ---------------------------
# 2_eflalo_tacsat_analysis.R lines 398-412, verbatim. `LE_l5MET` does not exist and
# speedarr has no LE_GEAR column, so no ping is ever set to "f".
cat("\n===== speed rule for non-autodetected gears (2.3.3, verbatim) =====\n")
nonsubTacsat <- data.frame(LE_GEAR = c("LLS", "LLS", "GNS"), LE_L5MET = c("LLS_DEF", "LLS_DEF", "GNS_DEF"),
                           SI_SP = c(0.5, 3, 8))
speedarr <- data.frame(LE_L5MET = c("GNS_DEF", "LLS_DEF"), min = 1, max = 6)
metiers <- unique(nonsubTacsat$LE_l5MET)
nonsubTacsat$SI_STATE <- NA
for (mm in metiers) {
  nonsubTacsat$SI_STATE[
    nonsubTacsat$LE_GEAR == mm &
      nonsubTacsat$SI_SP >= speedarr[speedarr$LE_GEAR == mm, "min"] &
      nonsubTacsat$SI_SP <= speedarr[speedarr$LE_GEAR == mm, "max"]
  ] <- "f";
}
nonsubTacsat$SI_STATE[
  nonsubTacsat$LE_GEAR == "NA" &
    nonsubTacsat$SI_SP >= speedarr[speedarr$LE_GEAR == "MIS", "min"] &
    nonsubTacsat$SI_SP <= speedarr[speedarr$LE_GEAR == "MIS", "max"]
] <- "f"
nonsubTacsat$SI_STATE[is.na(nonsubTacsat$SI_STATE)] <- "s"
print(nonsubTacsat)   # all "s", including the 3 kn longline ping

detach("ices_global")
