# audit_split_reader.R — where a human would split a mobile-id in two.
#
# Function definitions only. Used by curate/checks/ais_key_split_candidates.R.
#
# The manual match (raw/ais/stk/stk_mobile_match-and-duals.ods) split a mobile-id into
# two vids by reading its time-speed profile, its spatial pattern (down to a last trip
# out of Icelandic waters), the vessel registry's changes and the logbook and landings
# month by month. Measured on the ODS's own splits (decision 047 §6c): every one falls
# inside a silence of the mid's pings (60 of 60, 90 % of them a year or longer), so the
# candidates are the silences of >= 180 days, and each is read for four families of
# evidence. The logbook family fires rarely and is the costliest, so it is left out;
# the rule survives without it.
#
#   profile   the last 8 active weeks and the first 8 differ: centroid >= 150 km or
#             speed-histogram distance >= 0.4
#   abroad    the last position before, or the first after, is outside Icelandic waters
#   handover  the registry gives the mid's call sign or MMSI to a different hull before
#             and after the silence
#   reg_end   the key vid's own registry lifetime ends at the silence (+-1 year, and
#             below the snapshot horizon)
#
# Calibrated against W1's independent eras on the Icelandic vessels: >= 3 families,
# 19 of 19 checkable silences are real vessel changes; exactly 2, 7 of 22.

# Silences of >= gap_min days on mids the key claims as an Icelandic vid ----------------
split_silences <- function(days, key_v, gap_min = 180) {
  days |>
    dplyr::arrange(mid, d) |>
    dplyr::group_by(mid) |>
    dplyr::mutate(d_prev = dplyr::lag(d), gap = as.numeric(d - d_prev)) |>
    dplyr::ungroup() |>
    dplyr::filter(!is.na(gap), gap >= gap_min) |>
    dplyr::transmute(mid, d_prev, d_next = d, gap) |>
    dplyr::inner_join(key_v, by = "mid", relationship = "many-to-many") |>
    dplyr::filter(d1 <= d_prev, d2 >= d_prev) |>
    dplyr::distinct(mid, d_prev, d_next, .keep_all = TRUE) |>
    dplyr::transmute(sid = dplyr::row_number(), mid, d_prev, d_next, gap, vid = K)
}

# Last position before and first after each silence ------------------------------------
# stk: the trail's SELECT (stk_trail_sql()).
split_end_positions <- function(con, sil, stk) {
  DBI::dbWriteTable(con, "sil", dplyr::transmute(sil, sid, mid = as.numeric(mid), d_prev, d_next), overwrite = TRUE)
  f <- DBI::dbGetQuery(con, sprintf("
    with l as (select s.sid, t.lat, t.lon, row_number() over (partition by s.sid order by t.time desc) rn from sil s join (%s) t on t.mid = s.mid and cast(t.time as date) = s.d_prev where t.time >= timestamp '2007-06-01'),
         f as (select s.sid, t.lat, t.lon, row_number() over (partition by s.sid order by t.time asc) rn from sil s join (%s) t on t.mid = s.mid and cast(t.time as date) = s.d_next where t.time >= timestamp '2007-06-01')
    select l.sid, l.lat lat_last, l.lon lon_last, f.lat lat_first, f.lon lon_first from l join f on f.sid = l.sid and f.rn = 1 where l.rn = 1",
    stk, stk))
  # 'Icelandic waters': a generous box around the island and its fishing grounds
  inice <- function(lat, lon) lat >= 62 & lat <= 68.6 & lon >= -28.5 & lon <= -10
  dplyr::as_tibble(f) |>
    dplyr::mutate(E_abroad = !inice(lat_last, lon_last) | !inice(lat_first, lon_first))
}

# Profile shift across each silence ---------------------------------------------------------
split_profile_shift <- function(wk, sil, weeks = 8L, nmin = 100) {
  w0 <- as.Date("2007-01-01"); wk$wi <- as.integer((wk$wk - w0) / 7)
  spc <- grep("^sp[0-9]+$", names(wk), value = TRUE); dtc <- grep("^dt[0-9]+$", names(wk), value = TRUE)
  hell <- function(a, b) { a <- a / sum(a); b <- b / sum(b); sqrt(0.5 * sum((sqrt(a) - sqrt(b))^2)) }
  hav <- function(la1, lo1, la2, lo2) 111.2 * sqrt((la1 - la2)^2 + ((lo1 - lo2) * cos(pi * (la1 + la2) / 360))^2)
  by_mid <- split(wk, wk$mid); ss <- split(sil, sil$mid)
  one <- function(m, h) {
    d <- by_mid[[as.character(m)]]; if (is.null(d)) return(NULL)
    M <- as.matrix(d[, c("n", "slat", "slon", spc, dtc)]); idx <- setNames(seq_len(nrow(d)), d$wi)
    prof <- function(ii) { s <- colSums(M[ii, , drop = FALSE]); if (s[["n"]] < nmin) NULL else list(lat = s[["slat"]] / s[["n"]], lon = s[["slon"]] / s[["n"]], sp = s[spc], dt = s[dtc]) }
    dplyr::bind_rows(lapply(seq_len(nrow(h)), function(k) {
      wp <- as.integer((h$d_prev[k] - w0) / 7); wn <- as.integer((h$d_next[k] - w0) / 7)
      pw <- tail(d$wi[d$wi <= wp], weeks); qw <- head(d$wi[d$wi >= wn], weeks)
      if (length(pw) < 3 || length(qw) < 3) return(NULL)
      a <- prof(idx[as.character(pw)]); b <- prof(idx[as.character(qw)]); if (is.null(a) || is.null(b)) return(NULL)
      tibble::tibble(sid = h$sid[k], shift_space = min(hav(a$lat, a$lon, b$lat, b$lon), 300) / 300, shift_speed = hell(a$sp, b$sp)) }))
  }
  dplyr::bind_rows(Map(one, as.numeric(names(ss)), ss)) |>
    dplyr::mutate(E_profile = shift_space >= .5 | shift_speed >= .4)
}

# Registry handover across each silence ------------------------------------------------------
# The mid's identifiers are read off its own STK fields: a call sign (TF + two letters)
# or a 9-digit MMSI. A handover is a different holder of that call sign or MMSI on each
# side of the silence.
split_registry_handover <- function(con, sil, key, identity) {
  tok <- key |>
    tidyr::pivot_longer(c(loid, glid), values_to = "s") |>
    dplyr::filter(!is.na(s)) |>
    dplyr::mutate(s = toupper(trimws(s))) |>
    dplyr::transmute(mid = as.numeric(mid), cs = dplyr::if_else(grepl("^TF[A-Z]{2}$", s), s, NA_character_),
                     mmsi = dplyr::if_else(grepl("^[0-9]{9}$", s), s, NA_character_)) |>
    dplyr::filter(!is.na(cs) | !is.na(mmsi)) |>
    dplyr::distinct()
  idn <- identity |>
    dplyr::filter(!vid %in% 3700:4999) |>
    dplyr::transmute(hvid = as.integer(vid), cs, mmsi, t1 = as.Date(t1), t2 = as.Date(t2))
  DBI::dbWriteTable(con, "tok", tok, overwrite = TRUE); DBI::dbWriteTable(con, "idn", idn, overwrite = TRUE)
  DBI::dbWriteTable(con, "sil2", dplyr::transmute(sil, sid, mid = as.numeric(mid), d_prev, d_next), overwrite = TRUE)
  DBI::dbExecute(con, "create or replace temp table mi as select distinct tok.mid, idn.hvid, idn.t1, idn.t2 from tok join idn on (tok.cs is not null and tok.cs = idn.cs) or (tok.mmsi is not null and tok.mmsi = idn.mmsi)")
  DBI::dbExecute(con, "create or replace temp table hp as select distinct s.sid, mi.hvid from sil2 s join mi on mi.mid = s.mid and mi.t1 <= s.d_prev and mi.t2 >= s.d_prev")
  DBI::dbExecute(con, "create or replace temp table hn as select distinct s.sid, mi.hvid from sil2 s join mi on mi.mid = s.mid and mi.t1 <= s.d_next and mi.t2 >= s.d_next")
  h <- DBI::dbGetQuery(con, "select s.sid,
      exists (select 1 from hn where hn.sid = s.sid and hn.hvid not in (select hvid from hp where hp.sid = s.sid)) and
      exists (select 1 from hp where hp.sid = s.sid and hp.hvid not in (select hvid from hn where hn.sid = s.sid)) E_registry_handover
    from sil2 s")
  dplyr::as_tibble(h)
}
