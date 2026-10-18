# licence_lost_century.R — put back the century kvoti lost from a few revocation, exemption and arrears dates.
# Side: once (licence history). See plan 014; plan 029 §5.2; decision 133.
#
# Input:  staging/kvoti/{licence_revocation,licence_exemption,licence_arrears}.parquet
# Output: staging/kvoti/licence_date_fix.parquet (table, record, column, value_raw, value, flag) — a side table, read
#         by reference/vessels/licence_evidence.R; the staged tables are untouched.
#
# Declaration and evidence: curate/corrections/licence_lost_century.yml. `record` is the staged table's own key:
# `row` for the revocations and arrears, `id` for the exemptions.

library(dplyr)

read_staged <- function(name, key, cols) {
  duckdbfs::open_dataset(fd_staging("kvoti", paste0(name, ".parquet"))) |>
    select(record = all_of(key), entered, all_of(cols)) |>
    collect() |>
    tidyr::pivot_longer(all_of(cols), names_to = "column", values_to = "value_raw") |>
    mutate(table = name)
}

dates <- bind_rows(read_staged("licence_revocation", "row", c("t1", "t2")),
                   read_staged("licence_exemption", "id", c("t1", "t2", "closed")),
                   read_staged("licence_arrears", "row", c("t1", "t2")))

year <- function(x) as.integer(format(x, "%Y", tz = "UTC"))
fix <- dates |>
  filter(!is.na(value_raw), year(value_raw) < 1000) |>
  mutate(candidate = as.POSIXct(paste0(2000 + year(value_raw), format(value_raw, "-%m-%d %H:%M:%S", tz = "UTC")),
                                tz = "UTC"),
         ok = year(value_raw) < 100 & abs(as.numeric(difftime(candidate, entered, units = "days"))) <= 366,
         value = if_else(ok, candidate, as.POSIXct(NA, tz = "UTC")),
         flag = if_else(ok, "lost_century", "lost_century_unresolved")) |>
  select(table, record, column, value_raw, value, flag)

stopifnot("a resolved date lies outside 1991-2026" =
            all(between(year(fix$value[!is.na(fix$value)]), 1991, 2026)))
cat(sprintf("licence lost century: %d dates, %d resolved, %d left for review\n",
            nrow(fix), sum(!is.na(fix$value)), sum(is.na(fix$value))))
print(count(fix, table, flag))

fix |> duckdbfs::write_dataset(fd_staging("kvoti", "licence_date_fix.parquet"))
