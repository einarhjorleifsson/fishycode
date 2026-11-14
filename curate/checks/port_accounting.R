# port_accounting.R — every port list's every feature in one outcome, counted (plan 075 §2.4).
# Side: preprocessing (ports). See plan 014.
#
# Input:  raw/ports/* (each list's raw rows, counted as port_feature.R reads them),
#         curated/reference/port_feature.parquet and port_layer.parquet (reference/ports/port_layer.R),
#         overrides/port_pid_pinned.csv
# Output: curated/check/port_accounting.parquet - one row per list, outcome and reason group: the features counted, with
#         `verdict` "ok" or what failed
#
# Bookkeeping, not an agreement rate (decision 155): the raw rows of each list are counted from the raw files again, and
# every one must appear once in the outcome table, in exactly one outcome. The script stops, after writing, unless:
#   - each list's raw rows = its rows with an outcome, and no key appears twice;
#   - every port has exactly one chosen feature among the port-making lists, and every chosen feature is a port's anchor;
#   - no feature but a chosen one, a witness or a duplicate has a port, and every flagged feature has a reason;
#   - no two ports' areas overlap;
#   - every einar harbour (and its pinned acronym) is a port of its own.

library(sf)
library(dplyr)

sf_use_s2(FALSE)
raw_n <- c(
  einar    = nrow(read_sf(fd_staging("ports", "ports_iceland_faroe.gpkg"))),
  jeppe    = nrow(read_sf(fd_raw("ports", "havnepolygoner3.gpkg"))),
  maksims  = nrow(read_sf(fd_raw("ports", "maksims", "harbours.shp"))),
  emodnet  = nrow(read_sf(fd_raw("ports", "ports_emodnet.gpkg"))),
  osm      = nrow(read_sf(fd_raw("ports", "ports_osm.gpkg"))),
  vmstools = nrow(read_sf(fd_raw("ports", "ports_vmstools.gpkg"))),
  gfw      = nrow(read_sf(fd_raw("ports", "ports_gfw_named_anchorages_v2_pipe_v3_202601.gpkg"))),
  gisco    = nrow(read_sf(fd_raw("ports", "ports_giscoR.gpkg"))),
  marta    = nrow(readxl::read_excel(fd_raw("ports", "marta", "landings_portos_Einer.xlsx"))),
  unlocode = nrow(nanoparquet::read_parquet(fd_raw("ports", "unlocode.parquet"))))

f <- as.data.frame(nanoparquet::read_parquet(fd_curated("reference", "port_feature.parquet")))
f$geom <- NULL
ly <- read_curated_sf(fd_curated("reference", "port_layer.parquet"))
pins <- read.csv("overrides/port_pid_pinned.csv", colClasses = "character")
raw <- f[!f$derived, ]

fails <- character()
fail <- function(ok, what) if (!isTRUE(ok)) fails <<- c(fails, what)
n_out <- table(factor(raw$source, levels = names(raw_n)))
fail(all(n_out == raw_n), paste("raw rows differ:", paste(names(raw_n)[n_out != raw_n], collapse = ", ")))
fail(!anyDuplicated(paste(f$source, f$feature_key)), "a key twice")
fail(all(f$outcome %in% c("chosen", "witness", "duplicate", "flagged")), "an unknown outcome")
fail(!anyNA(f$reason), "an outcome without a reason")
mk <- f[f$source != "gfw", ]                       # a GFW anchorage takes its dock area's outcome
ch <- mk[mk$outcome == "chosen", ]
fail(!anyDuplicated(ch$port_key) && setequal(ch$port_key, ly$port_key) &&
       all(paste0(ch$source, ":", ch$feature_key) == ch$port_key), "a port without exactly one chosen feature")
fail(all(is.na(f$port_key[f$outcome == "flagged"])), "a flagged feature with a port")
fail(all(!is.na(f$port_key[f$outcome != "flagged"])), "a chosen, witness or duplicate feature without a port")
fail(all(f$pid[!is.na(f$port_key)] %in% c(ly$pid, NA)), "a feature's pid is not its port's")
ar <- st_transform(ly[ly$geom_type == "area", ], 3035)
fail(sum(lengths(st_overlaps(ar))) == 0, "two ports' areas overlap")
eh <- ly[ly$anchor_source == "einar", ]
fail(nrow(eh) == raw_n[["einar"]] && setequal(eh$pid_acronym, pins$pid), "an einar harbour is not a port of its own")

acc <- f |>
  mutate(list = ifelse(derived, paste0(source, " (derived)"), source),
         reason_group = sub(":.*| [0-9,]+ km off$", "", sub("^in GFW dock area [^:]+: ", "dock area: ", reason))) |>
  count(list, outcome, reason_group, name = "features") |>
  arrange(list, outcome, desc(features)) |>
  mutate(verdict = if (length(fails)) paste(fails, collapse = "; ") else "ok")
cat("ports", nrow(ly), "by basis:", paste(names(table(ly$basis)), table(ly$basis), collapse = ", "), "\n")
print(as.data.frame(tidyr::pivot_wider(acc |> count(list, outcome, wt = features), names_from = outcome, values_from = n,
                                       values_fill = 0)))
write_curated(acc, fd_curated("check", "port_accounting.parquet"),
              inputs = c(fd_curated("reference", "port_feature.parquet"), fd_curated("reference", "port_layer.parquet")))
if (length(fails)) stop("port_accounting: ", paste(fails, collapse = "; "))
