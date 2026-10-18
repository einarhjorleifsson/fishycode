# Hreiðar's workbook of Icelandic vessels: one row per number and year in use, 1710-2021, as he typed it.
# Side: preprocessing (vessels). See plan 014; plan 028 step 2.
#
# Input:  raw/external/hreidar/data-raw/HREIDAR_Islensk_skip.xlsx, sheet "Data main"
# Output: staging/hreidar/vessel_year.parquet - one row per sheet row (164,164), keyed on `nr` and `year`
#
# Source-shaped: every row and every column but the left-out ones, under English names (MAP gives each column's
# header). Plan 028 §3.2 describes the workbook; which of its values a register column takes is step 3's call.
#
# - The key is `NR`, not `Skskr.nr.` (decision 046). `nr` 90000 and above are boats without a registration number.
#   (`nr`, `year`) is not unique: two groups repeat (2982 in 2021, 90236 in 1883), and both are kept. `xl_row`, the
#   row in the sheet, is unique.
# - `Ár` 9999 is a placeholder, on 1,214 numbers that have no other row: `year` is NA there and `year_placeholder`
#   TRUE.
# - A number typed as text keeps its text in `<col>_txt`, NA where the cell holds a number. `skskr_nr_txt` holds
#   call signs on 10,725 rows, mostly before 1950 ("LBDS TFIH": the Danish one, then the Icelandic).
# - The last seven columns are Hreiðar's own fills: BRL is `Brl ný`, else an estimate; BT is the measured GT, else an
#   estimate; KW is `KW mælt`, else hp × 0.736; Afl is KW / BRL; Lengd is `Lengd skráð`, else an estimate;
#   Stærðarflokkur is a GRT class; formúla marks some estimated rows. Kept as `*_filled`, `kw_per_grt`,
#   `size_class` and `formula`.
# - `NR_ÁR` (NR + Ár / 10000) and the empty `x` are checked and dropped.
#
# Not read (decision 121, plan 028 §7): the operator's and parent company's names and kennitala, and (ask b, by
# default) the counts of people lost and rescued, how they were rescued, and the notes on the fate. The fate class,
# `Endalok`, is kept. The free-text notes `Aths` and `Ath skkr` are kept; a few of them name an owner.

library(dplyr)
library(nanoparquet)

FILE <- fd_raw("external", "hreidar", "data-raw", "HREIDAR_Islensk_skip.xlsx")

LEFT_OUT <- c("Kt útgerðaraðila", "Útgerðaraðili", "kt móðurfélags", "Móðurfélag",
              "Fjöldi fórst", "Fjöldi bjargaðist", "Hvernig bjargaðist", "Aths við endalok")
DROPPED  <- c("NR_ÁR", "x")
MAP <- c(nr = "NR", year = "Ár", name = "Nafn", district = "Staður", district_no = "Númer", skskr_nr = "Skskr.nr.",
         age = "Aldur", build_year = "Ár smíðað", year_out = "Hætt notkun", build_country = "Smíðastaður",
         build_town = "Smíðabær", hull_class = "Smíðaefni megin", hull_material = "Smíðaefni skkr",
         engine_class = "Vélagerð megin", engine_type = "Vélagerð 2", deck = "Opinn/þilaður", segment = "Megingerð",
         segment_ho = "Gerð HÖ", usage = "Notkunarteg", grt_old = "BRL gömul", grt = "Brl ný", gt = "Brúttótonn mæld",
         kw = "KW mælt", hp = "HP Mælt", length = "Lengd skráð", loa = "Mesta lengd", home_port = "Heimahöfn",
         book = "Bók", page = "bls", note_register = "Ath skkr", note = "Aths", website = "Vefsíða", fate = "Endalok",
         grt_filled = "BRL", gt_filled = "BT", kw_filled = "KW", kw_per_grt = "Afl", size_class = "Stærðarflokkur",
         length_filled = "Lengd", formula = "formúla")
NUM_TXT <- c("district_no", "skskr_nr", "year_out", "length", "length_filled")    # numbers with text cells
NUM     <- c("nr", "year", "age", "build_year", "grt_old", "grt", "gt", "kw", "hp", "loa", "page",
             "grt_filled", "gt_filled", "kw_filled", "kw_per_grt")
INT     <- c("nr", "year", "age", "build_year", "district_no", "skskr_nr", "year_out")

# Read ---------------------------------------------------------------------------------------------------------------
# Each cell as Excel holds it (col_types "list"), so a number typed as text can be told from a number. The left-out
# columns are skipped at the read, never loaded.
hdr <- names(readxl::read_excel(FILE, sheet = "Data main", n_max = 0))
stopifnot("a left-out column is missing: the sheet changed" = all(LEFT_OUT %in% hdr),
          "a column is neither mapped nor left out" = all(hdr %in% c(MAP, LEFT_OUT, DROPPED)))
raw <- readxl::read_excel(FILE, sheet = "Data main", col_types = ifelse(hdr %in% LEFT_OUT, "skip", "list"))

cls <- unique(unlist(lapply(raw, function(v) vapply(v, function(x) class(x)[1], ""))))
stopifnot("a cell is neither number, text nor empty" = all(cls %in% c("numeric", "character", "logical")))
cell_num <- function(v) vapply(v, function(x) if (is.numeric(x)) x
                               else if (is.character(x)) suppressWarnings(as.numeric(trimws(x))) else NA_real_, 0)
cell_txt <- function(v) vapply(v, function(x) if (is.character(x)) x else NA_character_, "")
cell_chr <- function(v) vapply(v, function(x) if (is.character(x)) x
                               else if (is.numeric(x)) format(x, digits = 15) else NA_character_, "")
whole <- function(x) { stopifnot("a count or year is not whole" = all(x == round(x), na.rm = TRUE)); as.integer(x) }

nr_ar <- cell_num(raw$NR_ÁR) - (cell_num(raw$NR) + cell_num(raw$`Ár`) / 10000)
stopifnot("NR_ÁR is not NR + Ár / 10000" = all(abs(nr_ar) < 1e-6), "x is not empty" = all(is.na(cell_chr(raw$x))))

# Shape --------------------------------------------------------------------------------------------------------------
d <- raw[unname(MAP)]
names(d) <- names(MAP)
text_in_num <- vapply(NUM, function(n) sum(!is.na(cell_txt(d[[n]]))), 0L)
stopifnot("text in a column read as numbers only: give it a _txt column" = all(text_in_num == 0))

out <- tibble(xl_row = seq_len(nrow(d)) + 1L)
for (n in names(MAP)) {
  if (n %in% c(NUM, NUM_TXT)) {
    out[[n]] <- if (n %in% INT) whole(cell_num(d[[n]])) else cell_num(d[[n]])
    if (n %in% NUM_TXT) out[[paste0(n, "_txt")]] <- cell_txt(d[[n]])
  } else out[[n]] <- cell_chr(d[[n]])
}
out <- out |>
  mutate(year_placeholder = year == 9999L, year = if_else(year_placeholder, NA_integer_, year), .after = year) |>
  arrange(nr, year, xl_row)

# Check and write ----------------------------------------------------------------------------------------------------
stopifnot(nrow(out) == nrow(raw), !anyNA(out$nr), !anyNA(out$year_placeholder))
PERSONAL <- "owner|operator|eigand|eigend|utgerdaradil|útgerðaraðil|kennitala|^kt|_kt|phone|sími|simi|address|heimilisfang"
stopifnot("a personal column is in the output" = !any(grepl(PERSONAL, names(out), ignore.case = TRUE)),
          "a left-out header is in the output" = !any(names(out) %in% LEFT_OUT))

print(knitr::kable(tibble(
  rows = nrow(out), numbers = n_distinct(out$nr), numbers_90000 = n_distinct(out$nr[out$nr >= 90000]),
  years = paste(range(out$year, na.rm = TRUE), collapse = "-"), placeholder_rows = sum(out$year_placeholder),
  repeated_nr_year = sum(duplicated(out[c("nr", "year")])), skskr_nr_text = sum(!is.na(out$skskr_nr_txt)),
  fate = sum(!is.na(out$fate))), caption = "staging/hreidar/vessel_year"))

write_parquet(out, fd_staging("hreidar", "vessel_year.parquet"))
