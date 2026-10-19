# The fisheries-management class of each vessel over time: aflamark, krókaaflamark, strandveiðar, frístundaveiðar, ...
# from the ship register's history (plan 028 step 7).
# Side: preprocessing (vessels). See plan 014.
#
# Input:  curated/vessel/register/vessel_operational_hist.parquet  the register's class (operational_category_no) for every
#                                                                   year: kvoti's dated history to 2023-12-19 (it outranks
#                                                                   the `vessel` schema's back-fill, decision 144), the
#                                                                   `vessel` schema's own after, within the hull's
#                                                                   registered life
#         raw/oracle/vessel/operational_category.parquet           the class codes' names
#         raw/oracle/vessel/vessel_operational_hist.parquet        the `vessel` schema's last entry, for `observed_to`
# Output: curated/vessel/vessel_class.parquet - one row per vid and class period, [t1, t2) in whole days
#
# The class is a licence class, not the usage type (that is vessel_year.parquet's mclass): a boat in a frístundaveiðar
# class at the time of a fix is leisure fishing, and a boat with a fishing class and AIS but no logbook or landings in a
# year is a coverage gap (plan 016 §4 step 5). The register changes a stretch wherever any column of the table does;
# consecutive stretches of one class that touch are merged, and a gap (time off the register) is kept. The last class is
# open to 2099-12-31 and is carried, not observed, after the `vessel` schema's last entry (`observed_to`): the dump of
# 2026-10-16 holds no change after 2026-06-16 in any of its history tables.
#
# The name comes from the code table, not the register's `operational_category`: that column follows its own witnesses,
# and where kvoti gives the code it names the `vessel` schema's class (534 rows name another class than their code). A
# code the table lacks takes the name the `vessel` schema's rows give it (12, Hvalveiðiskip, from 2026-02-18).

library(dplyr)
library(nanoparquet)

OPEN <- as.Date("2099-12-31")
LEISURE <- c(-11L, 89L, 95L)   # Frístundaveiðar án aflaheimilda, - aflamark, - krókaaflamark

f_op <- fd_curated("vessel", "register", "vessel_operational_hist.parquet")
f_oc <- fd_raw("oracle", "vessel", "operational_category.parquet")
f_vo <- fd_raw("oracle", "vessel", "vessel_operational_hist.parquet")
op <- read_parquet(f_op) |>
  transmute(vid = as.integer(registration_no), t1 = valid_from, t2 = coalesce(valid_to, OPEN),
            class_code = suppressWarnings(as.integer(operational_category_no)), name = operational_category, source, basis) |>
  filter(!is.na(class_code))
OBSERVED_TO <- as.Date(max(read_parquet(f_vo, col_select = "valid_from")$valid_from, na.rm = TRUE))

class_names <- read_parquet(f_oc) |> transmute(class_code = as.integer(operational_category_no), class_name = name)
class_names <- bind_rows(
  class_names,
  op |> filter(source == "vessel", !is.na(name), !class_code %in% class_names$class_code) |>
    count(class_code, class_name = name) |> arrange(class_code, desc(n)) |> distinct(class_code, .keep_all = TRUE) |> select(-n))

vessel_class <-
  op |>
  arrange(vid, t1) |>
  group_by(vid) |>
  mutate(run = cumsum(class_code != lag(class_code, default = -999L) | t1 != lag(t2, default = as.Date("1800-01-01")))) |>
  group_by(vid, run, class_code) |>
  summarise(t1 = min(t1), t2 = max(t2), basis = paste(sort(unique(basis)), collapse = "+"), .groups = "drop") |>
  select(-run) |>
  left_join(class_names, by = "class_code") |>
  mutate(leisure = class_code %in% LEISURE, observed_to = OBSERVED_TO) |>
  select(vid, class_code, t1, t2, class_name, leisure, observed_to, basis) |>
  arrange(vid, t1)

# Assertions -----------------------------------------------------------------------------------------------------------
ov <- vessel_class |> group_by(vid) |> filter(t1 < lag(t2)) |> ungroup()
cat("class periods:", nrow(vessel_class), " vids:", n_distinct(vessel_class$vid), " observed to:", format(OBSERVED_TO),
    " overlapping periods:", nrow(ov), "\n")
if (nrow(ov)) stop(nrow(ov), " class periods overlap: the register gives one class at a time", call. = FALSE)
nn <- sort(unique(vessel_class$class_code[is.na(vessel_class$class_name)]))
if (length(nn)) stop("codes without a name: ", paste(nn, collapse = " "), call. = FALSE)
print(vessel_class |> count(class_code, class_name, sort = TRUE), n = 15)

write_curated(vessel_class, fd_curated("vessel", "vessel_class.parquet"), inputs = c(f_op, f_oc, f_vo))
