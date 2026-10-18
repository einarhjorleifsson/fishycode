# _targets_once.R — the one-time fixes, as their own targets project (plan 014, decisions 075 and 132).
#
# Run:  Sys.setenv(TAR_PROJECT = "once"); targets::tar_outdated()
#       Sys.setenv(TAR_PROJECT = "once"); source("R/tar_make_isolated.R"); tar_make_isolated()
#
# Each fix is built once, reviewed and frozen; the main project (_targets.R) reads its output as a frozen
# input. It is redone ONLY by decision, recorded in curate/decisions/: a redo changes the frozen file and the
# main project rebuilds what depends on it.
#
# The fixes read main-project outputs (the merged pings, the logbook, the landings, the flow's voyages) as
# plain files with no edge back: that is where the AIS -> vid -> logbook -> AIS cycle is broken, by a person
# (AGENTS.md). The `main_*` targets below only watch those files, so tar_outdated() here says when a fix
# would see different evidence. They never build anything.
#
#   vessel key   STK mobile-id -> vid: the cascade, the audit against independent witnesses, the segment
#                table and the key built from it (plans 003, 008, 009). Frozen: curated/vessel/vessel_ais_key.parquet
#   gps logger   the afli logger's positions interpolated from the AIS track (decision 073's build).
#                Frozen: curated/logbook/sensor_gps
#   port radius  the departure radius per port from STK events (decision 060).
#                Frozen: curated/reference/port_radius.parquet
#   register     the annual ship register's history to 2023-12-19: the PDFs and the other witnesses read, every
#                witness's values in one evidence table, the checks (plan 028 steps 1-4, decision 132). Its
#                decision model and `_hist` tables (step 5) will be frozen here too; the live part after
#                2023-12-19 is the main project's. Build it by its last target, which pulls in the rest, never
#                with the whole project: tar_make_isolated(names = "check_skipaskra_discrepancy")

library(targets)

tar_source("R/")
configure_duckdb_temp()

# The pipeline runs in UTC, as the Oracle dumps do (decision 109). The dumps in raw/oracle/ hold plain TIMESTAMPs in
# UTC, and nanoparquet::read_parquet() returns those with no time zone, so format(), lubridate's as_date() and year()
# would read them in the session's zone: on a Mac in Atlantic/Reykjavik that moved dates before 1912 back a day
# (vessel_sign's 1901-01-01 placeholders became 1900-12-31), and anywhere outside UTC it moves every one. DuckDB
# returns them in UTC either way (plan 018 phase 3).
Sys.setenv(TZ = "UTC")

tar_option_set(
  packages = c("tidyverse", "duckdbfs", "ramb", "whack", "geo",
               "sf", "nanoparquet", "duckdb")
)

main_file <- function(...) fd_path(...)

# The register's raw inputs, listed outside the commands so a new file shows in tar_outdated() (input_files(), decision 113)
skipaskra_pdf_files <- input_files("raw", "external", "skipaskra", "reports", pattern = "[.]pdf$")
mbl_files           <- input_files("raw", "external", "skipaskra", "data-raw", "mbl", pattern = "^vid-.*[.]csv$")

list(

  # ── What the fixes read from the main project (watched, never built here) ───
  tar_target(main_lookups, c(main_file("staging", "aux", "country_codes_ISO3166.parquet"),
                             main_file("staging", "aux", "maritime_identification_digits.parquet"),
                             main_file("staging", "aux", "callsign_prefix.parquet")), format = "file"),
  tar_target(main_vessel, main_file("curated", "vessel", "vessel.parquet"), format = "file"),
  tar_target(main_vessel_identity, main_file("curated", "vessel", "vessel_identity.parquet"), format = "file"),
  tar_target(main_landing, main_file("curated", "landing", "landings.parquet"), format = "file"),
  tar_target(main_logbook, c(main_file("curated", "logbook", "trip.parquet"),
                             main_file("curated", "logbook", "fishing_sample.parquet")), format = "file"),
  tar_target(main_ping_union, main_file("staging", "ais", "ping_union"), format = "file"),
  tar_target(main_ais_ping, c(main_file("curated", "ais", "ping"),
                              main_file("curated", "ais", "voyage.parquet")), format = "file"),
  tar_target(main_stk_event, c(main_file("staging", "ais", "stk_event.parquet"),
                               main_file("staging", "aux", "ports.fgb")), format = "file"),
  # read by the register history only (main_landing and main_logbook above serve it too)
  tar_target(main_mmsi, main_file("curated", "vessel", "mmsi.parquet"), format = "file"),
  tar_target(main_landing_catch, main_file("curated", "landing", "catch.parquet"), format = "file"),

  # ── Vessel key ───────────────────────────────────────────────────────────────
  # The annual ship register: the call sign per vessel per year, 2007-2022. Dates the holder of a call
  # sign for the segment table (decision 049). A source adapter, run here because only the key reads it.
  tar_target(skipaskra, produces(
    "sources/skipaskra/annual_call_sign.R",
    fd_staging("skipaskra", "annual_call_sign.parquet")), format = "file"),

  # NOT a registry: a fitted model with residual error. It emits entity_class and basis as well as vid
  # (plan 003, decisions 012, 013).
  tar_target(vessel_ais_key_cascade, {
    main_lookups; main_vessel; main_vessel_identity
    produces("reference/vessels/ais_key_cascade.R",
             fd_curated("vessel", "vessel_ais_key_cascade.parquet"))
  }, format = "file"),

  tar_target(check_ais_key_registry, {
    vessel_ais_key_cascade; main_vessel
    produces("curate/checks/ais_key_registry.R",
             fd_curated("check", "ais_key_registry.parquet"))
  }, format = "file"),

  tar_target(check_ais_key_split_candidates, {
    vessel_ais_key_cascade; main_vessel; main_vessel_identity
    produces("curate/checks/ais_key_split_candidates.R",
             fd_curated("check", "ais_key_split_candidates.parquet"))
  }, format = "file"),

  # The whole key, row by row, against witnesses that never read it: other-provider AIS by MMSI (never stk,
  # never gps), logbook, landings. Long-running by design: a ledger, not a test.
  tar_target(check_ais_key_audit, {
    vessel_ais_key_cascade; main_landing; main_logbook; main_ping_union
    check_ais_key_registry; check_ais_key_split_candidates
    produces("curate/checks/ais_key_audit.R",
             fd_curated("check", "ais_key_audit_ledger.parquet"),
             fd_curated("check", "ais_key_audit_discrepancy.parquet"),
             fd_curated("check", "ais_key_audit_w1.parquet"),
             fd_curated("check", "ais_key_audit_lb_hits.parquet"),
             fd_curated("check", "ais_key_audit_lb_n.parquet"))
  }, format = "file"),

  # The segment table: every mobile-id tiled, a vid for every stretch, no ping unassigned (plan 009).
  tar_target(check_ais_key_segments, {
    vessel_ais_key_cascade; main_vessel_identity; skipaskra; check_ais_key_audit; check_ais_key_split_candidates
    produces("curate/checks/ais_key_segments.R",
             fd_curated("check", "ais_key_segments.parquet"))
  }, format = "file"),

  # The key the main project consumes, built from the segment table (decision 053).
  tar_target(vessel_ais_key, {
    check_ais_key_segments; vessel_ais_key_cascade; main_vessel; main_vessel_identity
    produces("reference/vessels/ais_key.R",
             fd_curated("vessel", "vessel_ais_key.parquet"),
             fd_curated("vessel", "vessel_ais_device.parquet"))
  }, format = "file"),

  tar_target(check_ais_key_coverage, {
    vessel_ais_key
    produces("curate/checks/ais_key_coverage.R",
             fd_curated("check", "ais_key_coverage.parquet"))
  }, format = "file"),

  tar_target(check_ais_key_twins, {
    check_ais_key_segments; main_vessel
    produces("curate/checks/ais_key_twins.R",
             fd_curated("check", "ais_key_twins.parquet"))
  }, format = "file"),

  tar_target(check_ais_key_vessel_recall, {
    check_ais_key_segments; check_ais_key_audit; main_vessel; main_landing; main_logbook
    produces("curate/checks/ais_key_vessel_recall.R",
             fd_curated("check", "ais_key_vessel_recall.parquet"))
  }, format = "file"),

  tar_target(check_ais_key_resolution, {
    check_ais_key_audit; check_ais_key_split_candidates; main_vessel; main_vessel_identity
    produces("curate/checks/ais_key_resolution.R",
             fd_curated("check", "ais_key_resolution.parquet"))
  }, format = "file"),

  tar_target(check_ais_key_landings, {
    vessel_ais_key_cascade; main_vessel; main_landing
    produces("curate/checks/ais_key_landings.R",
             fd_curated("check", "ais_key_landings.parquet"))
  }, format = "file"),

  # Reused Icelandic call signs, checked from the raw STK side rather than off the finished key.
  tar_target(check_ais_key_reused_callsign, {
    vessel_ais_key_cascade; main_vessel; main_landing
    produces("curate/checks/ais_key_reused_callsign.R",
             fd_curated("check", "ais_key_reused_callsign.parquet"))
  }, format = "file"),

  # ── GPS logger positions ─────────────────────────────────────────────────────
  tar_target(sensor_gps, {
    main_ais_ping; main_logbook
    produces("curate/logbook_sensor_gps.R", fd_curated("logbook", "sensor_gps"))
  }, format = "file"),

  # ── Port radius ──────────────────────────────────────────────────────────────
  tar_target(port_radius, {
    main_stk_event
    produces("reference/ports/port_radius.R",
             fd_curated("reference", "port_radius.parquet"))
  }, format = "file"),

  # ── Register history (plan 028, decision 132) ────────────────────────────────
  # The annual register PDFs, 2004-2022, read whole (decision 130).
  tar_target(skipaskra_pdf, skipaskra_pdf_files, format = "file"),
  tar_target(skipaskra_register, {
    skipaskra_pdf
    produces("sources/skipaskra/register.R", fd_staging("skipaskra", "register.parquet"))
  }, format = "file"),
  tar_target(skipaskra_event, {
    skipaskra_pdf
    produces("sources/skipaskra/event.R",
             fd_staging("skipaskra", "event.parquet"), fd_staging("skipaskra", "event_total.parquet"))
  }, format = "file"),
  tar_target(skipaskra_lists, {
    skipaskra_pdf
    produces("sources/skipaskra/lists.R",
             fd_staging("skipaskra", "draught.parquet"), fd_staging("skipaskra", "index_list.parquet"),
             fd_staging("skipaskra", "summary.parquet"), fd_staging("skipaskra", "name_prerogative.parquet"))
  }, format = "file"),

  # The other witnesses outside Oracle (plan 028 step 2).
  tar_target(hreidar_raw, fd_raw("external", "hreidar", "data-raw", "HREIDAR_Islensk_skip.xlsx"), format = "file"),
  tar_target(hreidar_vessel_year, {
    hreidar_raw
    produces("sources/hreidar/vessel_year.R", fd_staging("hreidar", "vessel_year.parquet"))
  }, format = "file"),
  tar_target(mbl_raw, mbl_files, format = "file"),
  tar_target(mbl_register, {
    mbl_raw
    produces("sources/mbl/register.R", fd_staging("mbl", "register_2023-01.parquet"))
  }, format = "file"),
  tar_target(samgongustofa_raw, fd_raw("external", "skipaskra", "data-raw", "2022-12-28_siglo.rds"), format = "file"),
  tar_target(samgongustofa_register, {
    samgongustofa_raw
    produces("sources/samgongustofa/register.R", fd_staging("samgongustofa", "register_2022-12-28.parquet"))
  }, format = "file"),
  tar_target(marinetraffic_raw, fd_raw("external", "marinetraffic",
                                       c("STK_MARINETRAFFIC_MATCTH.xlsx", "CS_MARINE_TRAFFIC_MATCH4.xlsx")), format = "file"),
  tar_target(marinetraffic_icelandic, {
    marinetraffic_raw
    produces("sources/marinetraffic/icelandic.R", fd_staging("marinetraffic", "icelandic.parquet"))
  }, format = "file"),

  # The Oracle tables the evidence and the checks read, as dumped (plan 018).
  tar_target(register_oracle, c(
    fd_raw("oracle", "vessel", paste0(c("vessel", "vessel_hist", "vessel_identification_hist", "vessel_measurement_hist",
                                        "vessel_engines_hist", "vessel_operational_hist", "vessel_owners_hist",
                                        "vessel_fishery_hist"), ".parquet")),
    fd_raw("oracle", "kvoti", paste0(c("skipasaga", "skipaskra_siglo", "skip_extra", "veidileyfi", "veidileyfi_eydd",
                                       "veidileyfi_sviptingar", "strandveidileyfi_v", "dragnot_leyfi", "grasleppusaga",
                                       "tegund_veidileyfis"), ".parquet")),
    fd_raw("oracle", "ufs", paste0(c("skip", "skip_jn", "skipasaga", "skipasaga_jn"), ".parquet")),
    fd_raw("oracle", "ops_einarhj", "mmsi_icelandic_registry_20230115.parquet")), format = "file"),

  # Every witness's values in the `vessel` schema's tables (plan 028 step 3).
  tar_target(skipaskra_evidence, {
    skipaskra_register; skipaskra_lists; skipaskra_event; hreidar_vessel_year; mbl_register; samgongustofa_register
    marinetraffic_icelandic; register_oracle; main_mmsi
    produces("reference/vessels/skipaskra_evidence.R", fd_curated("vessel", "skipaskra", "evidence.parquet"))
  }, format = "file"),

  # The checks of plan 028 §5 (step 4): inside an edition, between editions, the witnesses, landings and logbooks.
  tar_target(check_skipaskra_discrepancy, {
    skipaskra_evidence; skipaskra_register; skipaskra_event; skipaskra_lists; register_oracle
    main_landing; main_landing_catch; main_logbook
    produces("curate/checks/skipaskra_discrepancy.R",
             fd_curated("check", "skipaskra_discrepancy.parquet"), fd_curated("check", "skipaskra_agreement.parquet"))
  }, format = "file")
)
