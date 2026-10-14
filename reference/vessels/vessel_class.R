# The fisheries-management class of each vessel over time: aflamark, krókaaflamark, strandveiðar, frístundaveiðar, ...
# Side: preprocessing (vessels). See plan 014.
#
# Input:  raw/vessels/kvoti_skipasaga.parquet            Fiskistofa's dated vessel history (dump/oracle/vessel_history.R)
#         raw/external/skipaskra/data/history.rda        the class names: a 2021 extract of the same table that carried them
# Output: curated/vessel/vessel_class.parquet - one row per vid and class period, [t1, t2) in whole days
#
# The class is a licence class, not the usage type (that is vessel_year.parquet's mclass): a boat in a frístundaveiðar
# class at the time of a fix is leisure fishing, and a boat with a fishing class and AIS but no logbook or landings in a
# year is a coverage gap (plan 016 §4 step 5). skipasaga holds a row per change of anything (name, owner, home port);
# consecutive rows of one class are merged. Its history ends 2023-12-07 (the register's system change): the last class
# is open to 2099-12-31 and is carried, not observed, after that date (`observed_to`).

library(dplyr)
library(nanoparquet)

LEISURE <- c(-11L, 95L)   # Frístundaveiðar án aflaheimilda, Frístundaveiðar - krókaaflamark

s <- read_parquet(fd_raw("vessels", "kvoti_skipasaga.parquet")) |>
  # whole days (the source's times are midnight, or a 1901 placeholder with a clock offset); a DATE also compares
  # cleanly with the trail's TIMESTAMP, where a TIMESTAMP WITH TIME ZONE does not
  transmute(vid = as.integer(skip_nr), t1 = as.Date(i_gildi), t2 = as.Date(ur_gildi), class_code = as.integer(flokkur)) |>
  filter(vid > 0, !is.na(t1))
OBSERVED_TO <- max(s$t1, na.rm = TRUE)

e <- new.env()
load(fd_raw("external", "skipaskra", "data", "history.rda"), envir = e)
class_names <- e$history |> distinct(class_code = as.integer(mclass), class_name = mgtm_class) |> distinct(class_code, .keep_all = TRUE)

vessel_class <-
  s |>
  arrange(vid, t1, t2) |>
  group_by(vid) |>
  # a new run starts where the class changes
  mutate(run = cumsum(class_code != lag(class_code, default = first(class_code) + 1L))) |>
  group_by(vid, run, class_code) |>
  summarise(t1 = min(t1), t2 = max(t2), .groups = "drop") |>
  select(-run) |>
  left_join(class_names, by = "class_code") |>
  mutate(leisure = class_code %in% LEISURE,
         observed_to = OBSERVED_TO,
         basis = "recorded") |>
  arrange(vid, t1)

# Assertions -----------------------------------------------------------------------------------------------------------
ov <- vessel_class |> group_by(vid) |> filter(t1 < lag(t2)) |> ungroup()
cat("class periods:", nrow(vessel_class), " vids:", n_distinct(vessel_class$vid), " observed to:", format(OBSERVED_TO),
    " overlapping periods:", nrow(ov), "\n")
if (nrow(ov) > 0.01 * nrow(vessel_class)) stop("more than 1% of class periods overlap", call. = FALSE)
cat("codes without a name:", paste(sort(unique(vessel_class$class_code[is.na(vessel_class$class_name)])), collapse = " "), "\n")
print(vessel_class |> count(class_code, class_name, sort = TRUE), n = 15)

write_curated(vessel_class, fd_curated("vessel", "vessel_class.parquet"),
              inputs = c(fd_raw("vessels", "kvoti_skipasaga.parquet"), fd_raw("external", "skipaskra", "data", "history.rda")))
