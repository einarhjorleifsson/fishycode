library(tidyverse)
library(rvest)
library(countrycode)

# Country codes ISO_3166 -------------------------------------------------------
page <- read_html("https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes")
# Extract clean country names from <a> link text (avoids CSS contamination)
names_clean <- page |>
  html_element("table.wikitable") |>
  html_elements("tr") |>
  _[-(1:2)] |>
  map_chr(\(row) {
    first_td <- html_elements(row, "td")[1]
    if (length(first_td) == 0) return(NA_character_)
    links <- html_elements(first_td, "a")
    if (length(links) == 0) return(html_text2(first_td))
    txts <- html_text2(links)
    if (length(txts) == 1) txts
    else paste(txts[-length(txts)], collapse = ", ") |>
      paste(txts[length(txts)], sep = " and ")
  })
iso3166 <- page |>
  html_element("table.wikitable") |>
  html_table() |>
  setNames(c("name", "sovereignty", "alpha_2", "alpha_3", "numeric", "iso3166_2", "tld")) |>
  slice(-(1:2)) |>
  mutate(
    name    = names_clean[-1],   # drop extra header row to align
    name = str_remove(name, " and .*$"),
    name = ifelse(name == ", Taiwan (Province of China)",
                  "Taiwan (Province of China)",
                  name),
    alpha_2 = str_extract(alpha_2, "\\b[A-Z]{2}\\b")
  ) |>
  filter(!is.na(alpha_2))
iso3166 |> nanoparquet::write_parquet(fd_staging("aux", "country_codes_ISO3166.parquet"))
# MMSI country code ------------------------------------------------------------
maritime_identification_digits <-
  "https://en.wikipedia.org/wiki/Maritime_identification_digits" |>
  read_html() %>%
  #html_nodes(xpath='//*[@id="mw-content-text"]/table[1]') %>%
  html_table() |>
  bind_rows() |>
  janitor::clean_names() |>
  rename(MID = codes)
maritime_identification_digits <-
  maritime_identification_digits |>
  mutate(MID = str_remove(MID, "\\(218 from former German Democratic Republic\\)")) |>
  separate(MID, into = paste0("c", 1:20), extra = "drop", sep = ";") |>
  gather(dummy, MID, -country) |>
  select(-dummy) |>
  mutate(MID = str_trim(MID)) |>
  drop_na()
maritime_identification_digits |>
  nanoparquet::write_parquet(fd_staging("aux", "maritime_identification_digits.parquet"))


## Call signs and country ------------------------------------------------------
# ITU call-sign prefix -> flag state, scraped from Wikipedia's table of
# international call sign series.
#
# This replaces a read of ops$einarhj.vessel_cs_itu_prefix, a private Oracle
# table with no build script anywhere on disk - it existed only as a table and
# the 711-row parquet it had produced. Scraping makes it reproducible and
# removes the last Oracle dependency from the reference layer.
#
# The series column holds either a single prefix ("AX"), a range ("AA-AL",
# occasionally three-part like "TA-TB-TC"), or a prefix with parenthesised
# sub-allocations ("B (BM-BQ, BU-BX)"). Ranges never cross the first character,
# so only the second varies, over letters or digits according to its type.
# Sub-allocations each contribute their own two-character prefix, which is why
# HB appears once for Switzerland and three times for Liechtenstein.

LETTERS_ <- LETTERS
DIGITS_  <- as.character(0:9)

expand_series <- function(s) {
  s <- str_trim(s)
  if (str_detect(s, "\\(")) {
    subs <- str_trim(str_split(str_remove_all(str_extract(s, "\\(.*\\)"), "[()]"), ",")[[1]])
    return(unlist(lapply(subs, function(u)
      if (str_detect(u, "\u2013|-")) expand_series(u) else str_sub(u, 1, 2))))
  }
  if (!str_detect(s, "\u2013|-")) return(s)
  ab <- str_split(s, "\u2013|-")[[1]]                  # three-part ranges exist
  a  <- str_trim(ab[1]); b <- str_trim(ab[length(ab)])
  if (nchar(a) == 1) return(a)
  p  <- str_sub(a, 1, 1); c1 <- str_sub(a, 2, 2); c2 <- str_sub(b, 2, 2)
  alpha <- if (c1 %in% DIGITS_) DIGITS_ else LETTERS_
  paste0(p, alpha[seq(match(c1, alpha), match(c2, alpha))])
}

cs_series <-
  read_html("https://en.wikipedia.org/wiki/ITU_prefix") |>
  html_table() |>
  (\(x) x[[which.max(vapply(x, nrow, integer(1)))]])() |>
  setNames(c("series", "country")) |>
  mutate(country = str_trim(str_remove_all(country, "\\[[^]]*\\]")))   # drop footnote markers

callsign_prefix <-
  cs_series |>
  rowwise() |>
  mutate(cs_prefix = list(expand_series(series))) |>
  ungroup() |>
  tidyr::unnest(cs_prefix) |>
  # Strip qualifiers before the ISO lookup: "France (and its Overseas
  # departments/territories)", "Netherlands - Former Netherlands Antilles".
  # The UN, ICAO and WMO hold call-sign blocks and have no ISO code; they stay NA.
  mutate(.iso_name = str_trim(str_remove(str_remove(country, "\\s*\\(.*\\)"), "\\s*\u2013.*$")),
         iso2 = countrycode(.iso_name, "country.name", "iso2c", warn = FALSE),
         iso3 = countrycode(.iso_name, "country.name", "iso3c", warn = FALSE)) |>
  select(cs_prefix, country, iso2, iso3)

callsign_prefix |>
  nanoparquet::write_parquet(fd_staging("aux", "callsign_prefix.parquet"))


