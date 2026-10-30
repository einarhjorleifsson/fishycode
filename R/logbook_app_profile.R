# logbook_app_profile.R — each logbook app's habits, applied by rule: the reviewed rows of the app profile (plan 053).
#
# Input:  curate/corrections/logbook_app_profile.yml, the reviewed rows. The flaggers take frames curate/logbook.R
#         makes from the merge after the twins: one row per station with schema, app (decision 253), date, gear,
#         gear_class (app_gear_class()), t1-t4 as recorded, the trip's departure and landing (the afli route's
#         departure from staging/afli_sent/trip.parquet), the record's entry time (record_entered), the vessel's
#         previous station's t3 and t4, and for the positions lat1, lon1, lat2, lon2
# Output: app_profile(): the rows by id, checked against the code; flag_app_times(): t1_flag ... t4_flag, t1_rule ...
#         t4_rule, t1_action ... t4_action, one row per input row; flag_app_trips(): the trip's T1_* and T2_*, one row
#         per flagged trip; flag_app_positions(): pos1_* and pos2_*, one row per input row; flag_app_catch(): species_*;
#         depth_by_app(): z1, z2 in metres, z1_raw, z2_raw, z_unit, z1_basis, z2_basis, z1_* and z2_* flags
#
# Every value stays as recorded (AGENTS.md: an extreme value is flagged, not corrected). A field's flag says what the
# value holds (`placeholder`, `copy_departure`, `trip_time`, ...), its rule the row's id, its action what the flow
# does with it: "flag" leaves it out of every window, link and duration (judged_time_sql(), R/duration_limit.R;
# calc_effort(), R/logbook_effort.R), "note" keeps it. The YAML gives each row's scope (apps, feeds, period, gear
# class, field), its action and flag word, and `note_for`, the values noted rather than flagged; each row's test is
# coded here from its `rule` or `holds` text, and is tested against the counts its evidence names
# ($FISHYDATA/archive/2026-10-30-plan054-step2a/). The rows of one field are tried in APP_TIME_ORDER and the first
# that holds wins, the order of the archive's classes (02_profile.py): the app's own rows (scope app), then the
# placeholder, a date, the departure, the landing, the station's own times, the entry time, the previous station, the
# half-hour grid, the seconds.

APP_PROFILE <- "curate/corrections/logbook_app_profile.yml"

# The rows of each time field, in order. "entry" is no row: a static set equal to the record's entry time is kept as
# recorded, and no later row takes it (T16's note; the archive's class "copy: entry time").
APP_TIME_ORDER <- list(
  t1 = c("T4-marina", "T4-taktikal", "T5", "T6-app", "T1", "T2", "T2-afli", "T3", "T3-afli", "T20", "T8", "T15",
         "T16", "T17", "T6-value", "entry", "T7", "T13", "T12"),
  t2 = c("T8"),
  t3 = c("T8", "T14"),
  t4 = c("T10", "T8", "T18", "T14"))
APP_POS_ORDER <- list(pos1 = c("P5", "P7"), pos2 = c("P6-app", "P6-value", "P5"))
# The flag and note rows applied elsewhere, or not yet: app_profile() stops on any other row the code does not apply.
APP_PROFILE_ELSEWHERE <- c(
  W1 = "the windows: ramb's day window for a station with no usable time (curate/station_window.R)",
  I4 = "needs the landing link (lid_map), made after the merge: listed by the check (plan 053 step 4)",
  P8 = "needs Trackwell's own copy as a frozen list of the 8 merged stations, not yet made")

# The equality of two times within `s` seconds; a time at 00:00:00; the second within its minute; the minutes from a
# to b as DuckDB's date_diff('minute') counts them, minute boundaries crossed, as the archive's classes did.
.app_eq <- function(a, b, s) !is.na(a) & !is.na(b) & abs(as.numeric(a) - as.numeric(b)) <= s
.app_is_date <- function(x) !is.na(x) & as.numeric(x) %% 86400 == 0
.app_sec <- function(x) as.numeric(x) %% 60
.app_dmin <- function(a, b) floor(as.numeric(b) / 60) - floor(as.numeric(a) / 60)
# t3 - t1 within 1 min of m + k x 1,440 min, k >= k0
.app_days <- function(t1, t3, m, k0 = 0) {
  dm <- .app_dmin(t1, t3)
  !is.na(dm) & dm >= m + k0 * 1440 - 1 & abs(((dm - m) %% 1440 + 1) %% 1440 - 1) <= 1
}
# logbook_set_placeholder.yml's rule, as curate/logbook.R had it: the set the haul start less m min cut to the minute,
# or the haul start the set plus m min cut to the minute
.app_offset <- function(t1, t3, m) {
  to_minute <- function(t) t - as.numeric(t) %% 60
  !is.na(t1) & !is.na(t3) & (t1 == to_minute(t3 - m * 60) | t3 == to_minute(t1 + m * 60))
}

# Each row's test on the frame `d` for field `f`: TRUE where it holds, or the flag word (NA where it does not).
APP_TIME_RULES <- list(
  `T4-marina`   = \(d, f) TRUE,
  `T4-taktikal` = \(d, f) TRUE,
  T10           = \(d, f) TRUE,
  T5            = \(d, f) TRUE,
  `T6-app`      = \(d, f) dplyr::case_when(.app_eq(d$t1, d$departure, 60) ~ "copy_departure",
                                           .app_eq(d$t1, d$landing, 600) & !.app_is_date(d$landing) ~ "copy_landing",
                                           .default = "copy_haul"),
  T1            = \(d, f) .app_offset(d$t1, d$t3, 270) | .app_offset(d$t1, d$t3, 1710),
  T2            = \(d, f) { dm <- .app_dmin(d$t1, d$t3); !is.na(dm) & (abs(dm - 270) <= 1 | abs(dm - 1710) <= 1) },
  T3            = \(d, f) .app_days(d$t1, d$t3, 270, k0 = 2),
  T20           = \(d, f) .app_days(d$t1, d$t3, 210),
  T8            = \(d, f) .app_is_date(d[[f]]),
  T15           = \(d, f) .app_eq(d$t1, d$departure, 60) & .app_sec(d$t1) == 0,
  T16           = \(d, f) dplyr::case_when(.app_eq(d$t1, d$departure, 60) ~ "copy_departure",
                                           .app_eq(d$t1, d$landing, 600) & !.app_is_date(d$landing) ~ "copy_landing"),
  T17           = \(d, f) .app_eq(d$t1, d$departure, 60),
  T18           = \(d, f) .app_eq(d$t4, d$landing, 600) & !.app_is_date(d$landing),
  `T6-value`    = \(d, f) .app_eq(d$t1, d$t3, 60) | .app_eq(d$t1, d$t4, 60),
  T7            = \(d, f) .app_eq(d$t1, d$prev_t4, 60) | .app_eq(d$t1, d$prev_t3, 60),
  T13           = \(d, f) !is.na(d$t3) & d$t3 > d$t1 & .app_dmin(d$t1, d$t3) %% 30 == 0 &
                          .app_sec(d$t1) == .app_sec(d$t3),
  T12           = \(d, f) .app_sec(d$t1) != 0,
  # the end pressed onto the start: a tow's or seine set's t3 onto its t2, a haul's t4 onto its t3
  T14           = \(d, f) if (f == "t3") d$gear_class %in% c("towed", "seine") & .app_eq(d$t3, d$t2, 240)
                          else d$gear_class == "static" & .app_eq(d$t4, d$t3, 240))
APP_TIME_RULES[["T2-afli"]] <- APP_TIME_RULES$T2
APP_TIME_RULES[["T3-afli"]] <- APP_TIME_RULES$T3

# The app as the profile names it: the trip's uppruni (fs_afladagbok) or source (adb), trimmed, the suffixes
# " - GAFL AUTO" and " - Skrifstofa VES" taken off (the profile's vocabulary; curate/logbook.R's section "App").
app_base_name <- function(x) trimws(gsub(" - (GAFL AUTO|Skrifstofa VES)", "", trimws(x)))

# The profile's gear class from gear_window's (towed, static, jigged, other): the Danish seine is the profile's seine.
app_gear_class <- function(gear_class, gear) {
  dplyr::case_when(gear %in% "SDN" ~ "seine", gear_class %in% "jigged" ~ "jig", .default = gear_class)
}

# The reviewed rows by id. Stops on a row the code names but the file lacks, a coded row that is not a flag or a
# note, and a flag or note row the code neither applies nor names in APP_PROFILE_ELSEWHERE.
app_profile <- function(path = APP_PROFILE) {
  rows <- yaml::read_yaml(path)$rows
  names(rows) <- vapply(rows, `[[`, "", "id")
  coded <- c(setdiff(unlist(APP_TIME_ORDER), "entry"), unlist(APP_POS_ORDER), "T11", "T11-afli", "K2", "D4", "D5")
  stopifnot("a row the code applies is missing from the profile" = all(c(coded, "D1", "D2", "D3") %in% names(rows)),
            "a row's id is not unique" = !anyDuplicated(names(rows)))
  acts <- vapply(rows, \(r) r$action, "")
  if (!all(acts[c("D1", "D2", "D3")] == "convert")) stop("app_profile(): rows D1-D3 are no longer unit conversions")
  bad <- coded[!acts[coded] %in% c("flag", "note")]
  if (length(bad)) stop("app_profile(): the code applies rows that are neither flag nor note: ", toString(bad))
  open <- setdiff(names(acts)[acts %in% c("flag", "note")], c(coded, names(APP_PROFILE_ELSEWHERE)))
  if (length(open)) stop("app_profile(): flag or note rows no code applies: ", toString(open))
  unreviewed <- names(rows)[vapply(rows, \(r) is.null(r$reviewed), TRUE)]
  if (length(unreviewed)) stop("app_profile(): rows not reviewed: ", toString(unreviewed))
  rows
}

# Where a row's scope holds: its apps ("*" any), feeds (the schema), period (the station's date, an open end NULL)
# and gear (a class or an ICES code, "*" any).
.app_scope <- function(row, d) {
  per <- lapply(row$period, \(x) if (is.null(x)) as.Date(NA) else as.Date(x))
  apps <- unlist(row$apps); gear <- unlist(row$gear)
  ("*" %in% apps | d$app %in% apps) & d$schema %in% unlist(row$feeds) &
    (is.na(per[[1]]) | (!is.na(d$date) & d$date >= per[[1]])) &
    (is.na(per[[2]]) | (!is.na(d$date) & d$date <= per[[2]])) &
    ("*" %in% gear | d$gear_class %in% gear | d$gear %in% gear)
}

# One field's flags: the rows of `order` tried in turn on the values not yet taken, the first that holds wins. Returns
# flag, rule and action, one row per row of d.
.app_apply <- function(d, f, order, rules, profile) {
  n <- nrow(d)
  flag <- rule <- action <- rep(NA_character_, n)
  open <- !is.na(d[[f]])
  for (id in order) {
    if (id == "entry") {
      keep <- open & d$schema %in% c("fs_afladagbok", "adb") & d$gear_class == "static" &
        d$app %in% unlist(profile$T16$apps) & .app_eq(d$t1, d$record_entered, 60)
      open <- open & !keep
      next
    }
    row <- profile[[id]]
    s <- open & .app_scope(row, d)
    if (!any(s)) next
    hit <- rules[[id]](d, f)
    word <- if (is.logical(hit)) dplyr::if_else(rep_len(hit, n), row$flag, NA_character_) else hit
    take <- s & !is.na(word)
    if (!any(take)) next
    act <- rep(row$action, n)
    nf <- row$note_for
    if (!is.null(nf)) {
      noted <- (d$app %in% unlist(nf$apps)) | (d$gear %in% unlist(nf$gear)) | (d$gear_class %in% unlist(nf$gear))
      act[noted] <- "note"
      if (!is.null(nf$flag)) word[noted] <- nf$flag
    }
    flag[take] <- word[take]; rule[take] <- id; action[take] <- act[take]
    open <- open & !take
  }
  tibble::tibble(flag = flag, rule = rule, action = action)
}

# The flags of t1-t4. `d` needs schema, app, date, gear, gear_class, t1-t4, departure, landing, record_entered,
# prev_t3, prev_t4.
flag_app_times <- function(d, profile = app_profile()) {
  out <- lapply(names(APP_TIME_ORDER), \(f) {
    r <- .app_apply(d, f, APP_TIME_ORDER[[f]], APP_TIME_RULES, profile)
    stats::setNames(r, paste(f, names(r), sep = "_"))
  })
  dplyr::bind_cols(out)
}

# The trip's departure (T1) and landing (T2) that copy a station's time (T11, T11-afli), one row per trip flagged.
# `d` is station-level as for flag_app_times(), with .tid. T11 reads the e-logbook's trips by app and gear class as its
# `holds` says; T11-afli the afli route's departure against a static set stamped with seconds. A trip is flagged when
# one of its stations holds.
flag_app_trips <- function(d, profile = app_profile()) {
  p <- profile$T11; pa <- profile[["T11-afli"]]
  tw <- d$app %in% "Trackwell raun"; fo <- d$app %in% "Fontos raun"; gc <- d$gear_class
  s <- .app_scope(p, d)
  dep <- s & ((tw & gc %in% c("towed", "seine") & .app_eq(d$t2, d$departure, 60)) |
              (tw & gc == "static" & .app_eq(d$t3, d$departure, 60)) |
              ((tw | fo) & gc == "jig" & .app_eq(d$t1, d$departure, 60)))
  land <- s & !.app_is_date(d$landing) &
    ((tw & gc %in% c("towed", "seine") & .app_eq(d$t3, d$landing, 600)) |
     ((tw | fo) & gc %in% c("static", "jig") & .app_eq(d$t4, d$landing, 600)))
  dep_afli <- .app_scope(pa, d) & !is.na(d$app) & .app_sec(d$t1) != 0 & .app_eq(d$t1, d$departure, 60) &
    .app_sec(d$departure) == 0
  tibble::tibble(.tid = d$.tid, schema = d$schema, dep = dep, dep_afli = dep_afli, land = land) |>
    dplyr::filter(dep | dep_afli | land) |>
    dplyr::summarise(dep = any(dep), dep_afli = any(dep_afli), land = any(land), .by = c(.tid, schema)) |>
    dplyr::transmute(.tid, schema,
                     T1_flag   = dplyr::if_else(dep | dep_afli, "copy_station", NA_character_),
                     T1_rule   = dplyr::case_when(dep ~ "T11", dep_afli ~ "T11-afli"),
                     T1_action = dplyr::if_else(dep | dep_afli, "flag", NA_character_),
                     T2_flag   = dplyr::if_else(land, p$flag, NA_character_),
                     T2_rule   = dplyr::if_else(land, "T11", NA_character_),
                     T2_action = dplyr::if_else(land, p$action, NA_character_))
}

# The positions' flags: pos1 the start (lat1, lon1), pos2 the end (lat2, lon2). `d` needs schema, app, date, gear,
# gear_class, lat1, lon1, lat2, lon2 and t1_rule (P7 takes the static stations T12 took).
APP_POS_RULES <- list(
  P5         = \(d, f) TRUE,
  P7         = \(d, f) d$gear_class == "jig" | (d$gear_class == "static" & d$t1_rule %in% "T12"),
  `P6-app`   = \(d, f) TRUE,
  `P6-value` = \(d, f) !is.na(d$lat1) & !is.na(d$lon1) & d$lat2 == d$lat1 & d$lon2 == d$lon1)
flag_app_positions <- function(d, profile = app_profile()) {
  d$pos1 <- dplyr::if_else(!is.na(d$lat1) | !is.na(d$lon1), 1, NA_real_)
  d$pos2 <- dplyr::if_else(!is.na(d$lat2) | !is.na(d$lon2), 1, NA_real_)
  out <- lapply(names(APP_POS_ORDER), \(f) {
    r <- .app_apply(d, f, APP_POS_ORDER[[f]], APP_POS_RULES, profile)
    stats::setNames(r, paste(f, names(r), sep = "_"))
  })
  dplyr::bind_cols(out)
}

# K2: adb's species 48, which stands for both Grásleppa (951) and Rauðmagi (950). `d` needs schema, app, date, gear,
# gear_class and sid (the species); one row per input row.
flag_app_catch <- function(d, profile = app_profile()) {
  r <- profile$K2
  hit <- .app_scope(r, d) & d$sid %in% 48
  tibble::tibble(species_flag   = dplyr::if_else(hit, r$flag, NA_character_),
                 species_rule   = dplyr::if_else(hit, "K2", NA_character_),
                 species_action = dplyr::if_else(hit, r$action, NA_character_))
}

# Depth by app (rows D1-D5, plan 053 step 8): the e-logbook's depth in metres by the unit the app sends. D2's apps send
# metres (x 1, basis recorded); D1's and D3's fathoms, and so does an app no row names, as the feed has always been
# read (decision 022; x 1.8288, basis reconstructed). D4's zero and D5's copied end depth are flagged and read as none
# (NA, basis none). The value as sent stays in z1_raw and z2_raw. `d` needs schema, app, date, gear, gear_class, z1, z2
# as sent; one row per input row. The vessels whose unit D2 and D3 leave uncertain (z_unit "uncertain") need a frozen
# list from the GEBCO witness, not yet made.
APP_FATHOM_M <- 1.8288
depth_by_app <- function(d, profile = app_profile()) {
  metres <- .app_scope(profile$D2, d)
  f <- dplyr::if_else(metres, 1, APP_FATHOM_M)
  d4 <- .app_scope(profile$D4, d) & !is.na(d$z1)
  d5 <- .app_scope(profile$D5, d) & !is.na(d$z2)
  basis <- \(z, none) dplyr::case_when(is.na(z) ~ NA_character_, none ~ "none", metres ~ "recorded",
                                       .default = "reconstructed")
  tibble::tibble(
    z1_raw = d$z1, z2_raw = d$z2,
    z1 = dplyr::if_else(d4, NA_real_, d$z1 * f), z2 = dplyr::if_else(d5, NA_real_, d$z2 * f),
    z_unit = dplyr::if_else(metres, "metres", "fathoms"),
    z1_basis = basis(d$z1, d4), z2_basis = basis(d$z2, d5),
    z1_flag = dplyr::if_else(d4, profile$D4$flag, NA_character_),
    z1_rule = dplyr::if_else(d4, "D4", NA_character_),
    z1_action = dplyr::if_else(d4, profile$D4$action, NA_character_),
    z2_flag = dplyr::if_else(d5, profile$D5$flag, NA_character_),
    z2_rule = dplyr::if_else(d5, "D5", NA_character_),
    z2_action = dplyr::if_else(d5, profile$D5$action, NA_character_))
}
