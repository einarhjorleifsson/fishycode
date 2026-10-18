# Morgunblaðið's online vessel register (200 mílur), scraped vessel by vessel around the turn of 2023.
# Side: preprocessing (vessels). See plan 014; plan 028 step 2.
#
# Input:  raw/external/skipaskra/data-raw/mbl/vid-*.csv (5,803 files, long: variable, value, vid)
# Output: staging/skipaskra/mbl.parquet - one row per vid, the printed values and the numbers parsed from them
#
# Source-shaped: the newspaper's fields, curated by hand by the newspaper, not by the authority (plan 028 §3.6).
#
# - Every value is read as text. A parsed column has its printed text beside it in `<col>_txt`; a 0 is kept as
#   printed (it often stands for not given: about half of `loa`, `breadth`, `depth` and `nt`).
# - The scraper (raw/external/skipaskra/R/mbl-scrape_info.R) turned only the FIRST comma into a point, so the
#   thousands points survive: "1.100,0" is "1.100.0". Every point but the last is dropped before parsing.
# - The newspaper's own pages print a whole GT of 1,000 and more divided by 1,000 (2982: "4.14 t", siglo "4.139 t"):
#   85 of the 4,308 GTs both scrapes print, and one GRT. Kept as printed, for the checks of plan 028 §5.
# - `call_sign` drops the hyphen of "TF-IX"; `imo` drops the "IMO", and "IMO0" is NA.
# - `scraped` is "2022-12-28/2023-01-09", the span of the scrape logs' names. The info logs are all 2023-01-09 and
#   cover 101-500, 1001-3700 and 5000-9999 (the 2001-3700 run halted on a syntax error); the 2022-12-28 logs are the
#   photo scrape. No file is dated by itself, so the span is given for every vid.
# - Two files (vid 5665 and 9999) also hold a catch table, scraped by mistake: its columns and rows are dropped.
#
# Not read (decision 121, plan 028 §7): `Útgerð` (the operator), `Sími` (a phone number) and `Heimasíða` (a home page,
# which names the operator or a person). They are dropped as soon as the files are read.

library(dplyr)
library(nanoparquet)

DIR <- fd_raw("external", "skipaskra", "data-raw", "mbl")
SCRAPED <- "2022-12-28/2023-01-09"

LEFT_OUT <- c("Útgerð", "Sími", "Heimasíða")
MAP <- c(registration_no = "Skipanr.", name = "Nafn", home_port = "Heimahöfn", type = "Tegund",
         operational_category = "Útgerðarflokkur", processing_licence = "Vinnsluleyfi", length = "Skráð lengd",
         loa = "Mesta lengd", breadth = "Breidd", depth = "Dýpt", grt = "Brúttórúmlestir", gt = "Brúttótonn",
         nt = "Nettótonn", hp = "Hestöfl", build_year = "Smíðaár", yard = "Smíðastöð", build_place = "Smíðastaður",
         hull_material = "Efni í bol", engine = "Vél", previous_name = "Fyrra nafn", changes = "Breytingar",
         mmsi = "MMSI", call_sign = "Kallmerki", imo = "IMO")
NUM <- c("length", "loa", "breadth", "depth", "grt", "gt", "nt", "hp", "build_year")

# Read ---------------------------------------------------------------------------------------------------------------
files <- list.files(DIR, "^vid-[0-9]+[.]csv$", full.names = TRUE)
long <- purrr::map(files, function(f)
  suppressMessages(readr::read_csv(f, col_types = readr::cols(.default = readr::col_character()),
                                   col_select = c(variable, value, vid), progress = FALSE)) |>
    mutate(file_vid = as.integer(sub("^vid-([0-9]+)[.]csv$", "\\1", basename(f))))) |>
  bind_rows() |>
  filter(!is.na(variable), !variable %in% LEFT_OUT)

stopifnot("a field is neither mapped nor left out" = all(long$variable %in% MAP),
          "a vid differs from its file name" = all(as.integer(long$vid) == long$file_vid),
          "a field repeats within a file" = !anyDuplicated(long[c("file_vid", "variable")]))

# Shape --------------------------------------------------------------------------------------------------------------
wide <- long |>
  transmute(vid = file_vid, variable = names(MAP)[match(variable, MAP)], value) |>
  tidyr::pivot_wider(names_from = variable, values_from = value)
for (n in setdiff(names(MAP), names(wide))) wide[[n]] <- NA_character_
stopifnot("Skipanr. differs from the vid" = all(as.integer(wide$registration_no) == wide$vid))

num <- function(x) {
  x <- sub(" (m|t)$", "", x)
  stopifnot("a single point before three digits: thousands or decimals?" = !any(grepl("^[0-9]+[.][0-9]{3}$", x)))
  as.numeric(gsub("[.](?=.*[.])", "", x, perl = TRUE))
}

out <- wide |> select(vid, all_of(setdiff(names(MAP), "registration_no")))
for (n in NUM) {
  out[[paste0(n, "_txt")]] <- out[[n]]
  out[[n]] <- num(out[[n]])
  stopifnot("a printed number does not parse" = !any(is.na(out[[n]]) & !is.na(out[[paste0(n, "_txt")]])))
}
out <- out |>
  mutate(build_year = as.integer(build_year),
         call_sign_txt = call_sign, call_sign = toupper(gsub("-", "", call_sign)),
         imo_txt = imo, imo = na_if(sub("^IMO", "", imo), "0"),
         scraped = SCRAPED) |>
  relocate(ends_with("_txt"), .before = scraped) |>
  arrange(vid)

# Check and write ----------------------------------------------------------------------------------------------------
stopifnot(nrow(out) == length(files), !anyDuplicated(out$vid))
PERSONAL <- "owner|operator|eigand|eigend|utgerdaradil|útgerðaraðil|^útgerð$|kennitala|^kt|_kt|phone|sími|simi|address|heimilisfang|heimasíða"
stopifnot("a personal column is in the output" = !any(grepl(PERSONAL, names(out), ignore.case = TRUE)),
          "a left-out field is in the output" = !any(names(out) %in% LEFT_OUT))

print(knitr::kable(tibble(
  vids = nrow(out), name = sum(!is.na(out$name)), gt = sum(!is.na(out$gt)), grt = sum(!is.na(out$grt)),
  mmsi = sum(!is.na(out$mmsi)), call_sign = sum(!is.na(out$call_sign)), imo = sum(!is.na(out$imo)),
  previous_name = sum(!is.na(out$previous_name)), changes = sum(!is.na(out$changes))),
  caption = "staging/skipaskra/mbl"))

write_parquet(out, fd_staging("skipaskra", "mbl.parquet"))
