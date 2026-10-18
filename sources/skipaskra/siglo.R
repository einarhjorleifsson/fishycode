# Samgöngustofa's online ship register, scraped number by number on 2022-12-28.
# Side: preprocessing (vessels). See plan 014; plan 028 step 2.
#
# Input:  raw/external/skipaskra/data-raw/2022-12-28_siglo.rds (raw/external/skipaskra/R/samgongustofa-scrape.R)
# Output: staging/skipaskra/siglo.parquet - one row per registration number (5,677), printed values and parsed numbers
#
# Source-shaped: the register's lookup page as it stood, every number it answered for: registered (Skráð),
# deregistered (Óskráð) and allocated but not yet registered (Úthlutað), in `status`.
#
# - The scraper split each line at ": ", so a field printed empty became a second column ("Nafn:", "Heimahöfn:").
#   Those are merged into `name` and `home_port`; they are never both filled.
# - Numbers are printed the Icelandic way ("1.234,56 t"); each parsed column has its printed text in `<col>_txt`.
#   A 0 is kept as printed (it often stands for not given).
# - `Smíðað` ("1959 af <yard>") is split into `build_year` and `yard`, and `Umdæmisstafir` ("ÁR-050 (Árnessýsla)")
#   into `district`, `district_no` and `region`, each printed text kept. "RE-. (Reykjavík)" has no number, and 34
#   numbers print "- ()".
#
# Not read (decision 121, plan 028 §7): the owners (`Eigendur`, `Eigendur:`), dropped as soon as the file is read.

library(dplyr)
library(nanoparquet)

SCRAPED <- as.Date("2022-12-28")
LEFT_OUT <- c("Eigendur", "Eigendur:")
KEPT <- c("Skráningarnr", "Nafn", "Nafn:", "Gerð", "Skrán.staða", "Umdæmisstafir", "Heimahöfn", "Heimahöfn:",
          "Skráð lengd", "Brúttórúmlestir", "Brúttótonn", "Smíðað")

# Read ---------------------------------------------------------------------------------------------------------------
s <- readRDS(fd_raw("external", "skipaskra", "data-raw", "2022-12-28_siglo.rds"))
stopifnot("a column is neither kept nor left out" = all(names(s) %in% c(KEPT, LEFT_OUT)))
s <- s |> select(-any_of(LEFT_OUT))
stopifnot("a field is printed twice" = !any(!is.na(s$Nafn) & !is.na(s$`Nafn:`)),
          "a field is printed twice" = !any(!is.na(s$Heimahöfn) & !is.na(s$`Heimahöfn:`)))

# Shape --------------------------------------------------------------------------------------------------------------
num <- function(x) as.numeric(chartr(",", ".", gsub(".", "", sub(" (m|t)$", "", x), fixed = TRUE)))
BUILT <- "^([0-9]+) af ?(.*)$"
DISTRICT <- "^([^-]*)-([0-9]*)[.]? [(](.*)[)]$"

out <- s |>
  transmute(vid = as.integer(Skráningarnr), status = `Skrán.staða`,
            name = coalesce(Nafn, `Nafn:`), type = Gerð, home_port = coalesce(Heimahöfn, `Heimahöfn:`),
            district = na_if(sub(DISTRICT, "\\1", Umdæmisstafir), ""),
            district_no = as.integer(na_if(sub(DISTRICT, "\\2", Umdæmisstafir), "")),
            region = na_if(sub(DISTRICT, "\\3", Umdæmisstafir), ""),
            length = num(`Skráð lengd`), grt = num(Brúttórúmlestir), gt = num(Brúttótonn),
            build_year = as.integer(sub(BUILT, "\\1", Smíðað)), yard = na_if(sub(BUILT, "\\2", Smíðað), ""),
            district_txt = Umdæmisstafir, length_txt = `Skráð lengd`, grt_txt = Brúttórúmlestir, gt_txt = Brúttótonn,
            built_txt = Smíðað, scraped = SCRAPED) |>
  arrange(vid)

# Check and write ----------------------------------------------------------------------------------------------------
stopifnot(nrow(out) == nrow(s), !anyNA(out$vid), !anyDuplicated(out$vid),
          "Smíðað is not '<year> af <yard>'" = all(grepl(BUILT, out$built_txt)),
          "Umdæmisstafir is not 'XX-NNN (region)'" = all(grepl(DISTRICT, out$district_txt)),
          "a printed number does not parse" = !anyNA(out$length[!is.na(out$length_txt)]),
          "a printed number does not parse" = !anyNA(out$grt[!is.na(out$grt_txt)]),
          "a printed number does not parse" = !anyNA(out$gt[!is.na(out$gt_txt)]))
PERSONAL <- "owner|operator|eigand|eigend|utgerdaradil|útgerðaraðil|kennitala|^kt|_kt|phone|sími|simi|address|heimilisfang"
stopifnot("a personal column is in the output" = !any(grepl(PERSONAL, names(out), ignore.case = TRUE)),
          "a left-out column is in the output" = !any(names(out) %in% LEFT_OUT))

print(knitr::kable(out |> count(status, name = "numbers") |>
                     bind_rows(tibble(status = "all", numbers = nrow(out))), caption = "staging/skipaskra/siglo"))

write_parquet(out, fd_staging("skipaskra", "siglo.parquet"))
