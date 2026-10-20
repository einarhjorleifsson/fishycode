# afli_end_longitude.R — afli's electronic-logbook haul end longitude, recovered from the record the logbook sent.
# Side: preprocessing (afli). See plan 014.
#
# Input:  staging/afli/station.parquet                      (.sid, lon2, lat2)
#         raw/oracle/fs_afli/rafr_stofn.parquet             (visir, lengd_lok, breidd_lok, the record's message keys)
#         raw/oracle/fs_afli/afladagb_xml_mottaka.parquet   (id, sending: the XML each logbook sent)
# Output: staging/afli/end_longitude.parquet  (.sid, lon2, lon2_raw, lon2_basis) — a side table, joined onto afli's
#         stations by curate/logbook.R; station.parquet itself is untouched.
#
# Declaration and evidence: curate/corrections/afli_end_longitude.yml (TODO 106).
#
# In afli.stofn and fs_afli.rafr_stofn, the end longitude (lengd_lok) of an electronic-logbook station is a copy of
# its end latitude (breidd_lok) on most stations of 2010-2012, so the adapter's lon2 is -lat2. The XML the logbook
# sent (STADSETNING_LOK, attributes BREIDD and LENGD) holds both: the copy was made when the record was loaded.
# A station is found in its message by the message id and the record's own id and version (xml_sending_visir,
# xml_faerslu_visir, xml_faerslu_version). lon2 becomes the sent longitude where the sent latitude agrees with
# breidd_lok and the sent longitude differs from it and is a position ("reconstructed"); NA where it cannot be
# recovered ("none"), since
# the stored value is a latitude; lon2_raw keeps the adapter's value. Stations without the fault are "recorded".

library(DBI)
library(duckdb)
library(dplyr)

con <- dbConnect(duckdb())
dbExecute(con, "SET threads = 4; SET memory_limit = '6GB'")
ra <- function(t) fd_raw("oracle", "fs_afli", paste0(t, ".parquet"))

# The stations whose end longitude is the end latitude -------------------------------
station <- duckdbfs::open_dataset(fd_staging("afli", "station.parquet")) |> select(.sid, lon2, lat2) |> collect()
fault <- station |> filter(!is.na(lon2), !is.na(lat2), lon2 == -lat2)
duckdb::duckdb_register(con, "fault", fault |> select(visir = .sid))

# The sent end position of each, from its own message --------------------------------
sent <- dbGetQuery(con, sprintf("
  WITH r AS (SELECT r.visir, r.breidd_lok, r.xml_sending_visir AS mid, r.xml_faerslu_visir AS xv,
                    r.xml_faerslu_version AS xver
             FROM read_parquet('%s') r JOIN fault USING (visir)),
       m AS (SELECT id, sending FROM read_parquet('%s') WHERE id IN (SELECT DISTINCT mid FROM r)),
       x AS (SELECT id, unnest(regexp_extract_all(sending, '<FAERSLA>.*?</FAERSLA>')) AS fx FROM m),
       f AS (SELECT id AS mid,
                    TRY_CAST(regexp_extract(fx, '<VISIR>([0-9]+)</VISIR>', 1) AS DOUBLE) AS xv,
                    TRY_CAST(regexp_extract(fx, '<VERSION>([0-9]+)</VERSION>', 1) AS INTEGER) AS xver,
                    TRY_CAST(regexp_extract(fx, '<STADSETNING_LOK BREIDD=\"([0-9]+)\" LENGD=\"([0-9]+)\"', 1) AS INTEGER) AS x_b2,
                    TRY_CAST(regexp_extract(fx, '<STADSETNING_LOK BREIDD=\"([0-9]+)\" LENGD=\"([0-9]+)\"', 2) AS INTEGER) AS x_l2
             FROM x)
  SELECT r.visir AS \".sid\", r.breidd_lok, count(DISTINCT f.x_b2::VARCHAR || ',' || f.x_l2::VARCHAR) AS n_sent,
         any_value(f.x_b2) AS x_b2, any_value(f.x_l2) AS x_l2
  FROM r LEFT JOIN f ON f.mid = r.mid AND f.xv = r.xv AND f.xver = r.xver
  GROUP BY ALL", ra("rafr_stofn"), ra("afladagb_xml_mottaka")))
dbDisconnect(con, shutdown = TRUE)

# a sent longitude with 60 minutes or more is no position (about 220, mostly three digits); it is not recovered
ok <- sent |> filter(n_sent == 1, x_b2 == breidd_lok, x_l2 != x_b2, x_l2 %% 100 < 60) |>
  transmute(.sid, lon2_sent = -geo::geoconvert.1(x_l2 * 100))

# The side table: every afli station with an end longitude --------------------------
end_lon <- station |>
  filter(!is.na(lon2)) |>
  left_join(ok, by = ".sid", relationship = "one-to-one") |>
  mutate(is_fault  = !is.na(lat2) & lon2 == -lat2,
         lon2_raw  = lon2,
         lon2      = case_when(!is.na(lon2_sent) ~ lon2_sent, is_fault ~ NA_real_, .default = lon2_raw),
         lon2_basis = case_when(!is.na(lon2_sent) ~ "reconstructed", is_fault ~ "none", .default = "recorded")) |>
  select(.sid, lon2, lon2_raw, lon2_basis)
stopifnot(!anyDuplicated(end_lon$.sid))
end_lon |> duckdbfs::write_dataset(fd_staging("afli", "end_longitude.parquet"))

# Report -------------------------------------------------------------------------
cat("== afli end longitude (curate/corrections/afli_end_longitude.yml) ==\n")
cat("stations with an end longitude:", nrow(end_lon), "; of them lon2 = -lat2:", nrow(fault), "\n")
cat("found in their message:", sum(sent$n_sent > 0), "; one sent position:", sum(sent$n_sent == 1),
    "; sent latitude agrees:", sum(sent$n_sent == 1 & sent$x_b2 == sent$breidd_lok, na.rm = TRUE), "\n")
print(end_lon |> count(lon2_basis))
