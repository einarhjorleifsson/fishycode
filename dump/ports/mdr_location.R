# The EU's fisheries location list: DG MARE's Master Data Register (MDR), code list LOCATION.
# Output: raw/ports/mdr_location_<YYYYMMDD>.xls   the file as delivered, one per fetch date, never overwritten
#
# Every EU logbook, landing declaration, sales note, transport document and inspection report names its place by this
# list's code (IFDM Recommendation 7, 2016). It is UN/LOCODE cut to what the Member States need, plus codes of the
# Commission's own for the smaller fishing ports and landing places UNECE would not take (CC + 3 characters), added at the
# Member States' request (IFDM Recommendations 115, 2021, and 225, 2026, among others). One sheet, ALL_LOCATION: ISO3,
# Code, Name, Latitude, Longitude, the flags FishingPort, LandingPlace and CommercialPort (Y/N), UNLoCode, Coordinates,
# Function, StartDate, EndDate. The file of 2026-11-14 was last saved by DG MARE on 2026-07-24 (31,446 rows).
#
# Where it is published: the MDR's code list index, CircaBC (MARE / MDR / Information / MDR_MatrixIndex.html), which
# links the file below; open to guests. Found with the maintainer, 2026-11-14 (plan 075). Read by R/mdr_location.R; the
# port layer's build does not read it (held out by the maintainer, 2026-11-14, after its test as a witness).

URL <- "https://circabc.europa.eu/sd/a/87b27a74-533d-4c96-b7e6-4d703f90e13f/MDR_Location.xls"
out <- fd_raw("ports", paste0("mdr_location_", Sys.getenv("MDR_DATE", format(Sys.Date(), "%Y%m%d")), ".xls"))
stopifnot("a fetch is never overwritten" = !file.exists(out))
tmp <- tempfile(fileext = ".xls")
httr2::request(URL) |> httr2::req_user_agent("fishycode port list") |> httr2::req_timeout(300) |> httr2::req_perform(path = tmp)
x <- readxl::read_excel(tmp, sheet = "ALL_LOCATION", n_max = 5)
stopifnot("the columns are as expected" = all(c("ISO3", "Code", "Name", "Latitude", "Longitude", "FishingPort", "LandingPlace",
                                                "CommercialPort", "UNLoCode", "StartDate", "EndDate") %in% names(x)))
file.copy(tmp, out)
message(out, ": ", file.size(out), " bytes, md5 ", tools::md5sum(out))
