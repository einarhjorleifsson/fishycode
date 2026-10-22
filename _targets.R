# _targets.R — the build graph for the whole pipeline.
#
# Run:  targets::tar_make()            build what is stale
#       targets::tar_outdated()        what would rebuild
#       targets::tar_visnetwork()      see the graph
#
# Every target is format = "file": the command returns the path(s) it produced
# and targets hashes the contents, so a downstream target rebuilds when an
# upstream file actually changes — not merely when it is touched.
#
# Coverage is deliberately complete. The predecessor pipeline declared 8 of 63
# scripts, omitting the expensive AIS chain entirely, so tar_outdated() reported
# "up to date" while the state of the costly half was unknown. A partly-declared
# graph is worse than none: it reports confidence it has not earned.
#
# Two things sit OUTSIDE this graph, on purpose:
#   dump/       extraction from Oracle and vendor archives. Needs credentials and
#               a server, writes immutable raw/, and is run on its own schedule.
#               What it writes enters as declared file inputs, so a new dump or
#               feed month shows in tar_outdated() (decision 113).
#   _targets_once.R
#               the three one-time fixes (the STK vessel key, the GPS logger positions,
#               the port radius): a second targets project (`TAR_PROJECT=once`, see
#               _targets.yaml), run only by decision. Their outputs re-enter here as
#               frozen inputs (plan 014, decision 075).
# products/ are consumers of the sweep and are run on demand, not on every build.
#
# Each script names its layer in a `# Side:` header line - preprocessing (no AIS),
# once, or flow - and check_bookkeeping() enforces it (plan 014).

library(targets)

tar_source("R/")

# See R/duckdb_temp.R for what this works around and why it's a function call
# here rather than a top-level variable assignment. Runs in every process that
# sources _targets.R (main and any callr worker), so it lands before any
# target's first duckdbfs call.
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

# The Faroese register is a file per vessel, listed here rather than in a command for the same reason as the feeds
# below (decision 113): a listing in a command is not redone, so it would never see a new vessel's file.
fro_files <- sort(list.files(fd_raw("external", "fro"), "^vid-.*[.]csv$", full.names = TRUE), method = "radix")
# The mbl vessel photos (plan 030), for the same reason: if the rest of the 2022 scrape is found, it lands in this folder.
mbl_photo_files <- input_files("raw", "external", "skipaskra", "jpg", pattern = "[.]jpg$")
mbl_photo_recovered <- sort(list.files(fd_raw("external", "skipaskra"), "^mbl-photo-recover_.*[.]csv$", full.names = TRUE),
                            method = "radix")

# produces() and frozen_input() are in R/source_script.R, shared with _targets_once.R.
# source_script() sources with encoding = "UTF-8", which is not optional: the scripts
# carry Icelandic gear and port names (veidarfaeri, Grasleppunet, ...), and a
# subprocess whose locale is not UTF-8 reads them as Latin-1. It also clears what the
# script leaves behind - objects, options, attached packages - so one target cannot
# change the next. Build with tar_make_isolated() (R/tar_make_isolated.R): one session
# per target, because a one-session tar_make() swelled to 111 GB (decision 073).

# The partitioned inputs, listed here rather than in their targets' commands (decision 113): a listing made in a command
# is not redone until the command changes, so it would never see a new partition. About 0.1 s for the ~320 files.
stk_trail_files <- input_files("raw", "oracle", "stk", "trail")
astd_files      <- input_files("staging", "ais", "astd")
astd_b_files    <- input_files("staging", "ais", "astdB")
# The Fjarskiptastofa MMSI lists, for the same reason (decision 116): mmsi.R reads every list in the folder.
mmsi_list_files <- input_files("raw", "mmsi", pattern = "[.]xlsx$")
# The vid ledger (plan 021 §6 f): one file per allocation, written by allocate_vids() (R/allocate_vids.R) outside the
# graph, so a new allocation shows in tar_outdated(). Empty until the first allocation; the crosswalk builds without it.
vid_ledger_files <- sort(list.files(fd_path("curated", "vessel", "vid_ledger"), "^batch_.*[.]parquet$",
                                    full.names = TRUE), method = "radix")

list(

  # ── Reference ───────────────────────────────────────────────────────────────
  # Slow-moving lookups. Everything downstream depends on some of these.

  tar_target(dictionary, produces(
    "reference/dictionary.R",
    fd_curated("reference", "dictionary.parquet")), format = "file"),

  # Each reader of raw/oracle/ names the tables its output is built from, so a new dump marks it outdated (decision
  # 116). mapping.R also reads afli's stofn and fs_afladagbok's ws_veidi, for a printed check after the save: not inputs.
  tar_target(gear_raw, fd_raw("oracle", "asfis", "asfis.parquet"), format = "file"),
  tar_target(gear, {
    gear_raw
    produces("reference/gear/mapping.R", fd_curated("reference", "gear.parquet"))
  }, format = "file"),

  # Speed windows and window class per gear (plan 010). Reads gear.parquet.
  tar_target(gear_window, {
    gear
    produces("reference/gear/windows.R",
             fd_curated("reference", "gear_window.parquet"))
  }, format = "file"),

  # Harbour geometry. kaenugardr was absorbed on 2026-09-21 (decision 006), so
  # these are produced here rather than hand-copied in as an artifact.
  #
  # ports_iceland is a correction, not a producer: the bootstrap that made
  # raw/ports/ports_iceland_faroe.gpkg cannot be re-run (decision 005), so the
  # fix is applied to the artifact, raw -> staging. raw/ stays immutable.
  tar_target(ports_iceland, produces(
    "curate/corrections/ports_iceland.R",
    fd_staging("ports", "ports_iceland_faroe.gpkg")), format = "file"),

  # The Iceland/Faroe pids are pinned (decision 082): a reviewed input, not a computed one.
  tar_target(port_pid_pinned, "overrides/port_pid_pinned.csv", format = "file"),
  tar_target(ports_all, {
    ports_iceland
    port_pid_pinned
    produces("reference/ports/ports_all.R",
             fd_staging("ports", "ports_all.gpkg"),
             fd_curated("reference", "port_geometry.parquet"))
  }, format = "file"),

  # harbour_codes.R reads the pids from staging/ports/ports_all.gpkg; without the edge
  # it could run before ports_all and read the old file (decision 082).
  tar_target(port_raw, c(fd_raw("oracle", "agf", "aflagrunnur_v.parquet"),
                         fd_raw("oracle", "agf", "aflagrunnur.parquet"),
                         fd_raw("oracle", "kvoti", "stadur.parquet")), format = "file"),
  tar_target(port, {
    ports_iceland
    ports_all
    port_raw
    produces("reference/ports/harbour_codes.R",
             fd_curated("reference", "port.parquet"))
  }, format = "file"),

  tar_target(port_code_raw, fd_raw("oracle", "agf", "aflagrunnur_v.parquet"), format = "file"),
  tar_target(port_code, {
    port_code_raw
    produces("reference/ports/port_code.R", fd_curated("reference", "port_code.parquet"))
  }, format = "file"),

  # Geometry validation of the raw spatial layers. Its outputs go to
  # staging/aux_valid/; shapes.R then crops and buffers them into staging/aux/.
  # The two stages were separate directories in the old tree (data-raw/aux vs
  # data/aux) and must stay separate, or shapes.R overwrites its own input.
  tar_target(shapes_raw, produces(
    "reference/geo/shapes_raw.R",
    fd_staging("aux_valid", "ices_areas.gpkg"),
    fd_staging("aux_valid", "gebco.gpkg"),
    fd_staging("aux_valid", "eusm.gpkg")), format = "file"),

  # Port polygons are now produced by the ports_all target above, so targets can
  # see when they change. Previously this read a hand copy of kaenugardr's
  # output, which is why a corrected geometry did not propagate. This only crops
  # and buffers them.
  tar_target(shapes, {
    shapes_raw
    ports_all
    produces("reference/geo/shapes.R",
             fd_staging("aux", "ports.fgb"),
             fd_staging("aux", "ices_areas_500m-buffer.fgb"),
             fd_staging("aux", "eusm.fgb"))
  }, format = "file"),

  # STK's own harbour code -> the standard pid (plan 011 §3.2). Seeded from where each
  # code's `I` events fall; reviewed decisions enter through overrides/stk_hid_pid.csv.
  tar_target(stk_hid_pid_overrides, "overrides/stk_hid_pid.csv", format = "file"),
  tar_target(stk_hid_pid, {
    shapes
    stk_hid_pid_overrides
    stk_trail_raw
    produces("reference/ports/stk_hid_pid.R",
             fd_curated("reference", "stk_hid_pid.parquet"))
  }, format = "file"),

  # h3_index.R reads staging/aux/eusm.fgb and ices_areas_500m-buffer.fgb, both written by
  # shapes; without this edge a changed habitat or area layer never reached area_h3. Coarse
  # on purpose: a rewrite changes the bytes of even an unchanged .fgb, so no file target
  # could tell a real change from a rewrite.
  tar_target(area_h3, {
    shapes
    produces("reference/geo/h3_index.R", fd_curated("reference", "area_h3.parquet"))
  }, format = "file"),

  # Country codes, maritime identification digits, call-sign prefixes.
  tar_target(lookups, produces(
    "reference/lookups.R",
    fd_staging("aux", "country_codes_ISO3166.parquet"),
    fd_staging("aux", "maritime_identification_digits.parquet"),
    fd_staging("aux", "callsign_prefix.parquet")), format = "file"),

  # The MMSI archive, rebuilt from every source (plan 016): the four Fjarskiptastofa lists, the Oracle snapshots, Oracle's
  # current table, the old archive's hand-set windows, and two declared corrections. File targets, so a new list or
  # dump shows in tar_outdated() - before plan 016 no vessel target depended on a raw file.
  tar_target(mmsi_raw, c(mmsi_list_files,
                         fd_raw("oracle", "ops_einarhj", "vessel_mmsi_20190627.parquet"),
                         fd_raw("oracle", "ops_einarhj", "vessel_mmsi_20201215.parquet"),
                         fd_raw("oracle", "ops_einarhj", "vessel_mmsi_20220405.parquet"),
                         fd_raw("oracle", "ops_einarhj", "mmsi_icelandic_registry.parquet"),
                         fd_raw("oracle", "vessel", "vessel_mmsi.parquet"), fd_raw("vessels", "mmsi_iceland_archieves.parquet"),
                         "overrides/mmsi_list_errors.csv", "overrides/mmsi_broadcast.csv"), format = "file"),
  tar_target(vessel_raw, c(fd_raw("oracle", "vessel", "vessel_v.parquet"),
                           fd_raw("external", "hreidar", "data-raw", "HREIDAR_Islensk_skip.xlsx")), format = "file"),
  tar_target(mmsi, {
    mmsi_raw; vessel_raw
    produces("reference/vessels/mmsi.R", fd_curated("vessel", "mmsi.parquet"))
  }, format = "file"),

  # The ship register: the history to 2023-12-19, frozen in the `once` project (plan 028 steps 1-5, decision 136), and the
  # `vessel` schema's own history after it, through the same decision model (plan 028 step 6, decision 142). The
  # register's tables for every year, in curated/vessel/register/.
  tar_target(register_history, frozen_input("curated", "vessel", "skipaskra"), format = "file"),
  tar_target(register_live_raw, c(
    fd_raw("oracle", "vessel", paste0(c("vessel", "vessel_identification", "vessel_measurement", "vessel_engines",
                                        "vessel_operational", "vessel_fishery", "vessel_owners", "vessel_hist",
                                        "vessel_identification_hist", "vessel_measurement_hist", "vessel_engines_hist",
                                        "vessel_operational_hist", "vessel_fishery_hist", "vessel_owners_hist"), ".parquet")),
    fd_raw("oracle", "ufs", paste0(c("skip", "skip_jn", "skipasaga", "skipasaga_jn"), ".parquet")),
    "overrides/skipaskra_reviewed.csv"), format = "file"),
  tar_target(vessel_register, {
    register_history; register_live_raw; mmsi
    produces("reference/vessels/vessel_register.R",
             file.path(fd_curated("vessel", "register"),
                       paste0(c("vessel_hist", "vessel_identification_hist", "vessel_measurement_hist", "vessel_engines_hist",
                                "vessel_operational_hist", "vessel_fishery_hist", "vessel_owners_hist", "vessel_mmsi_hist",
                                "vessel_event", "registered", "decision", "annual_call_sign"), ".parquet")),
             fd_curated("check", "vessel_register_open.parquet"))
  }, format = "file"),
  # Call sign, local sign (ÍS-8) and name over time (plan 016 step 6b), from the register (plan 028 step 7). Nothing in
  # this project reads it.
  tar_target(vessel_sign, {
    vessel_register
    produces("reference/vessels/vessel_sign.R", fd_curated("vessel", "vessel_sign.parquet"))
  }, format = "file"),

  # The register's readers (plan 028 step 7). registry.R takes yh1/yh2, the first and last year on the register, and
  # also reads agf/aflagrunnur, for a printed check after the save: not an input (decision 116).
  tar_target(vessel, {
    mmsi; vessel_raw; vessel_register
    produces("reference/vessels/registry.R", fd_curated("vessel", "vessel.parquet"))
  }, format = "file"),

  # Usage type, kW and length by year (the effort on a fix uses the kW of its year), and the fisheries-management class
  # over time (leisure, and coverage gaps by year). Plan 016 §4 step 5, from the register (plan 028 step 7). Hreiðar's
  # segment comes from his staged workbook, built in the `once` project.
  tar_target(hreidar_vessel_year, frozen_input("staging", "hreidar", "vessel_year.parquet"), format = "file"),
  tar_target(vessel_year, {
    vessel_raw; vessel_register; hreidar_vessel_year
    produces("reference/vessels/vessel_year.R", fd_curated("vessel", "vessel_year.parquet"))
  }, format = "file"),
  tar_target(vessel_class, {
    vessel_register
    produces("reference/vessels/vessel_class.R", fd_curated("vessel", "vessel_class.parquet"))
  }, format = "file"),

  # The mbl vessel photos indexed by vid, with the scrape's logs for mbl's image id and the files it never delivered
  # (plan 030 step 1, decision 137), and the manifests of the photos fetched again by their logged URLs (decision 145).
  # Nothing in the flow reads it; products/vessel_overview does. Internal use only.
  tar_target(mbl_photo_raw, c(mbl_photo_files, mbl_photo_recovered,
                              fd_raw("external", "skipaskra",
                                     c("nohup_2022-12-27.log", "nohup2.log",
                                       sprintf("mbl-scrape_2022-12-28_%s.log",
                                               c("153000", "160000", "163000", "170000", "173000", "180000"))))),
             format = "file"),
  tar_target(mbl_photo, {
    mbl_photo_raw
    produces("sources/mbl/photo.R", fd_staging("mbl", "photo.parquet"))
  }, format = "file"),

  # vid -> what the hull was called, and when. The vid is the keel; mmsi, cs and
  # uid are attributes of it at a time. Consumed by ais_key.R's lifetime flag and
  # by curate/ais_ping_union.R, which resolves the MMSI-keyed commercial feeds
  # through it. See curate/decisions/015.
  tar_target(vessel_identity, {
    vessel; mmsi
    produces("reference/vessels/identity.R",
             fd_curated("vessel", "vessel_identity.parquet"))
  }, format = "file"),

  # The foreign registers, each staged as its source has it: the EU fleet register (an event ledger), the Faroese
  # register (a page per vessel), Norway's register (a sheet per year) and GFW's fishing vessel list (v3, a row per MMSI
  # and year). identity_foreign.R joins them into one table per (source, external_id, period), and identity_all.R adds
  # the Icelandic one. Built by hand on 2026-09-26 until now (plan 008 Phase 7, plan 021 step 1). Read by the crosswalk,
  # vessel_ais_link (below), and by ais_key_foreign.R, run by hand (plan 008); nothing in the flow reads them yet.
  tar_target(eu_raw, fd_raw("external", "eu", "vesselRegistryListResults.csv"), format = "file"),
  tar_target(eu, {
    eu_raw
    produces("sources/eu/convert.R", fd_staging("eu", "vessel_event.parquet"))
  }, format = "file"),
  tar_target(fro_raw, fro_files, format = "file"),
  tar_target(fro, {
    fro_raw
    produces("sources/fro/convert.R", fd_staging("fro", "vessel.parquet"))
  }, format = "file"),
  tar_target(norway_vessel_registry_raw, fd_raw("external", "nor", "norway_vessel-registry.xlsx"), format = "file"),
  tar_target(norway_vessel_registry, {
    norway_vessel_registry_raw
    produces("sources/norway/vessel_registry.R", fd_staging("norway", "vessel_registry.parquet"))
  }, format = "file"),
  tar_target(gfw_raw, fd_raw("external", "gfw", "fishing-vessels-v3", "fishing-vessels-v3.csv"), format = "file"),
  tar_target(gfw, {
    gfw_raw
    produces("sources/gfw/convert.R", fd_staging("gfw", "vessel.parquet"))
  }, format = "file"),
  tar_target(vessel_identity_foreign, {
    eu; fro; norway_vessel_registry; gfw
    produces("reference/vessels/identity_foreign.R",
             fd_curated("vessel", "vessel_identity_foreign.parquet"))
  }, format = "file"),
  tar_target(vessel_identity_all, {
    vessel_identity; vessel_identity_foreign
    produces("reference/vessels/identity_all.R",
             fd_curated("vessel", "vessel_identity_all.parquet"))
  }, format = "file"),

  # ── Frozen inputs: the three one-time fixes (plan 014, decision 075) ─────────
  # Built in the `once` project (_targets_once.R), reviewed, and redone only by
  # decision. A deliberate redo changes the file's hash and propagates from here.
  # The key is NOT a registry: a fitted model with residual error, audited by the
  # checks that build it (plans 003, 009).

  tar_target(vessel_ais_key,
    frozen_input("curated", "vessel", "vessel_ais_key.parquet"), format = "file"),

  # The afli logger's positions, interpolated once from the AIS track (decision 073's
  # build). Enters the feed union as provider gps from plan 014 phase 3.
  tar_target(sensor_gps,
    frozen_input("curated", "logbook", "sensor_gps"), format = "file"),

  # The departure radius per port, measured once from STK events.
  tar_target(port_radius,
    frozen_input("curated", "reference", "port_radius.parquet"), format = "file"),

  # ── Inputs built outside the graph (decision 113) ───────────────────────────
  # The STK trail as dumped (decision 111), the ASTD feeds as dump/ais/astd.R and astd_b.R stage them, and EMODnet's
  # 2017 extract. A new dump or feed month marks its readers outdated; before, each needed a tar_invalidate() by hand.
  # A changed input is rehashed whole, ~3.5 GB/s: the trail 3 s, ASTD 38 s, ASTDB 8 s, EMODnet 1 s.
  tar_target(stk_trail_raw, stk_trail_files, format = "file"),
  tar_target(astd_staged, astd_files, format = "file"),
  tar_target(astd_b_staged, astd_b_files, format = "file"),
  tar_target(emodnet_raw, fd_raw("ais", "EmodNet", "is2017.csv"), format = "file"),

  # ── The vessel crosswalk (plan 021 steps 2-4) ───────────────────────────────
  # What each MMSI feed claims about its vessel, by MMSI and year; then each feed id and period to a hull and its vid.
  # The vid numbering is outside the graph: the ledger enters as an input, like overrides/, and allocate_vids() extends
  # it by hand. Nothing in the flow reads the crosswalk yet: its reader is the union (plan 021 step 6).
  tar_target(astd_identity, {
    astd_staged
    produces("sources/astd/identity.R", fd_staging("astd", "identity.parquet"))
  }, format = "file"),
  tar_target(astd_b_identity, {
    astd_b_staged
    produces("sources/astd_b/identity.R", fd_staging("astd_b", "identity.parquet"))
  }, format = "file"),
  tar_target(emodnet_identity, {
    emodnet_raw
    produces("sources/emodnet/identity.R", fd_staging("emodnet", "identity.parquet"))
  }, format = "file"),
  tar_target(stk_mobile_raw, fd_raw("oracle", "stk", "mobile.parquet"), format = "file"),
  tar_target(vessel_ais_link_overrides, "overrides/vessel_ais_link.csv", format = "file"),
  tar_target(vid_ledger, vid_ledger_files, format = "file"),
  tar_target(vessel_ais_link, {
    astd_identity; astd_b_identity; emodnet_identity; lookups
    vessel_identity; vessel; vessel_identity_foreign; vessel_ais_key; stk_mobile_raw
    vessel_ais_link_overrides; vid_ledger
    produces("curate/vessel_ais_link.R",
             fd_curated("vessel", "vessel_ais_link.parquet"),
             fd_curated("check", "vessel_ais_link_review.parquet"))
  }, format = "file"),
  # Plan 021 §2.2's table rebuilt from the crosswalk, by year: which route reaches each MMSI, and what it carries.
  tar_target(check_vessel_ais_link_routes, {
    vessel_ais_link; astd_identity; vessel_identity_foreign
    produces("curate/checks/vessel_ais_link_routes.R",
             fd_curated("check", "vessel_ais_link_routes.parquet"))
  }, format = "file"),

  # ── Source adapters ─────────────────────────────────────────────────────────
  # raw/ → staging/<source>/. Mutually independent, so tar_make(workers = 4)
  # runs them in parallel. Each must emit the four-table grammar.

  # The Oracle tables each adapter reads (decision 116). afli's kvoti/lods_londun is read only in its if (FALSE) block.
  # fs_afli gives the eytt flag and the paper stations afli lacks (decision 124).
  tar_target(afli_raw, c(unlist(lapply(c("afli", "fs_afli"), \(s)
                           fd_raw("oracle", s, paste0(c("stofn", "toga", "lineha", "gildra", "hringn", "afli"),
                                                      ".parquet")))),
                         fd_raw("oracle", "fs_afli", "rafr_stofn.parquet")), format = "file"),
  tar_target(afli, {
    dictionary; gear; gear_window; port; afli_raw
    produces("sources/afli/convert.R",
             fd_staging("afli", "trip.parquet"),
             fd_staging("afli", "station.parquet"),
             fd_staging("afli", "fishing_sample.parquet"),
             fd_staging("afli", "catch.parquet"),
             fd_staging("afli", "aggregate.parquet"))
  }, format = "file"),

  # Correction, not part of the adapter (AGENTS.md) - a side table, joined onto
  # afli_station by curate/logbook.R, never written back into station.parquet.
  tar_target(afli_depth_units, {
    afli; area_h3
    produces("curate/corrections/afli_depth_units.R",
             fd_staging("afli", "depth.parquet"))
  }, format = "file"),

  # Correction (curate/corrections/afli_end_longitude.yml): the end longitude the logbook sent, where Oracle holds the
  # end latitude in its place; a side table joined onto afli_station by curate/logbook.R.
  tar_target(afli_xml_raw, fd_raw("oracle", "fs_afli", "afladagb_xml_mottaka.parquet"), format = "file"),
  tar_target(afli_end_longitude, {
    afli; afli_raw; afli_xml_raw
    produces("curate/corrections/afli_end_longitude.R",
             fd_staging("afli", "end_longitude.parquet"))
  }, format = "file"),

  # afli's sent layer (plan 037): the records as the apps sent them, keyed to rafr_stofn's visir (in afli_raw) so
  # that .sid is the edited layer's. Read by nothing in curate/ yet.
  tar_target(afli_sent, {
    gear; gear_window; port; afli_raw; afli_xml_raw
    produces("sources/afli_sent/convert.R",
             fd_staging("afli_sent", "record.parquet"),
             fd_staging("afli_sent", "trip.parquet"),
             fd_staging("afli_sent", "station.parquet"),
             fd_staging("afli_sent", "fishing_sample.parquet"),
             fd_staging("afli_sent", "catch.parquet"),
             fd_staging("afli_sent", "landing_confirmation.parquet"))
  }, format = "file"),

  tar_target(fs_afladagbok_raw, c(fd_raw("oracle", "fs_afladagbok", "ws_veidiferd.parquet"),
                                  fd_raw("oracle", "fs_afladagbok", "ws_veidi.parquet"),
                                  fd_raw("oracle", "fs_afladagbok", "ws_dragnot_varpa.parquet"),
                                  fd_raw("oracle", "fs_afladagbok", "ws_plogur.parquet"),
                                  fd_raw("oracle", "fs_afladagbok", "ws_linanethandf.parquet"),
                                  fd_raw("oracle", "fs_afladagbok", "ws_gildra.parquet"),
                                  fd_raw("oracle", "fs_afladagbok", "ws_hringn.parquet"),
                                  fd_raw("oracle", "fs_afladagbok", "ws_afli.parquet")), format = "file"),
  tar_target(fs_afladagbok, {
    dictionary; gear; gear_window; port; fs_afladagbok_raw
    produces("sources/fs_afladagbok/convert.R",
             fd_staging("fs_afladagbok", "trip.parquet"),
             fd_staging("fs_afladagbok", "station.parquet"),
             fd_staging("fs_afladagbok", "fishing_sample.parquet"),
             fd_staging("fs_afladagbok", "catch.parquet"))
  }, format = "file"),

  # Tables, not views (decision 170); station_v misreads the positions (adb_station_v_positions.yml)
  tar_target(adb_raw, c(fd_raw("oracle", "adb", "fishing_trip.parquet"),
                        fd_raw("oracle", "adb", "fishing_station.parquet"),
                        fd_raw("oracle", "adb", "trawl_and_seine_net.parquet"),
                        fd_raw("oracle", "adb", "dredge.parquet"),
                        fd_raw("oracle", "adb", "line_and_net.parquet"),
                        fd_raw("oracle", "adb", "trap.parquet"),
                        fd_raw("oracle", "adb", "surrounding_net.parquet"),
                        fd_raw("oracle", "adb", "catch.parquet")), format = "file"),
  # adb's own gear crosswalk (its code -> the new gid), read by logbook_gear (plan 034), not by the adapter
  tar_target(adb_gear_code, fd_raw("oracle", "adb", "fishing_gear.parquet"), format = "file"),
  tar_target(adb, {
    dictionary; gear; adb_raw
    produces("sources/adb/convert.R",
             fd_staging("adb", "trip.parquet"),
             fd_staging("adb", "station.parquet"),
             fd_staging("adb", "fishing_sample.parquet"),
             fd_staging("adb", "catch.parquet"))
  }, format = "file"),

  # Correction, not part of the adapter (AGENTS.md) - a side table, joined onto
  # adb_station by curate/logbook.R (curate/decisions/023-adb-wired-into-logbook.md).
  tar_target(adb_lon_sign, {
    adb
    produces("curate/corrections/adb_vs_fs_afladagbok.R",
             fd_staging("adb", "lon_sign.parquet"))
  }, format = "file"),

  # The ERS catch reports of foreign vessels, 2014-2018 (decision 126, plan 026): the adapter, its three corrections
  # (side tables, joined by curate/logbook.R) and the trips cut at landings in Iceland.
  tar_target(aflaskeyti_raw, fd_raw("oracle", "dw", "dw_aflaskeyti.parquet"), format = "file"),
  tar_target(aflaskeyti, {
    gear; aflaskeyti_raw
    produces("sources/aflaskeyti/convert.R",
             fd_staging("aflaskeyti", "trip.parquet"),
             fd_staging("aflaskeyti", "station.parquet"),
             fd_staging("aflaskeyti", "fishing_sample.parquet"),
             fd_staging("aflaskeyti", "catch.parquet"))
  }, format = "file"),
  tar_target(aflaskeyti_coordinates, {
    aflaskeyti
    produces("curate/corrections/aflaskeyti_coordinates.R", fd_staging("aflaskeyti", "coordinates.parquet"))
  }, format = "file"),
  tar_target(aflaskeyti_local_time, {
    aflaskeyti; aflaskeyti_raw
    produces("curate/corrections/aflaskeyti_local_time.R", fd_staging("aflaskeyti", "time.parquet"))
  }, format = "file"),
  tar_target(aflaskeyti_trip, {
    aflaskeyti; aflaskeyti_local_time; landing; afli; fs_afladagbok
    produces("curate/aflaskeyti_trip.R",
             fd_staging("aflaskeyti", "trip_landing.parquet"),
             fd_staging("aflaskeyti", "station_trip.parquet"))
  }, format = "file"),
  # The state of each weight: the Icelandic vessels' own hauls in the staged afli logbook (upstream of the merge).
  tar_target(aflaskeyti_weight, {
    aflaskeyti; aflaskeyti_local_time; aflaskeyti_raw; afli
    produces("curate/corrections/aflaskeyti_weight.R", fd_staging("aflaskeyti", "weight.parquet"))
  }, format = "file"),

  tar_target(aflagrunnur_raw, fd_raw("oracle", "agf", "aflagrunnur.parquet"), format = "file"),
  tar_target(aflagrunnur, {
    aflagrunnur_raw
    produces("sources/aflagrunnur/convert.R",
             fd_staging("landing", "agf", "landings.parquet"),
             fd_staging("landing", "agf", "catch.parquet"))
  }, format = "file"),

  tar_target(lods_raw, fd_raw("oracle", "kvoti", "lods_slaegt.parquet"), format = "file"),
  tar_target(lods, {
    lods_raw
    produces("sources/lods/convert.R",
             fd_staging("landing", "lods", "landings.parquet"),
             fd_staging("landing", "lods", "catch.parquet"))
  }, format = "file"),

  # Precedence merge of agf and lods (curate/plans/007): agf where it exists,
  # lods elsewhere. Also where the hid -> pid port join happens, once, for
  # both sources.
  tar_target(landing, {
    aflagrunnur; lods; port
    produces("curate/landing.R",
             fd_curated("landing", "landings.parquet"),
             fd_curated("landing", "catch.parquet"))
  }, format = "file"),

  tar_target(stk, {
    vessel_ais_key; stk_trail_raw
    produces("sources/stk/convert.R", fd_staging("ais", "stk"))
  }, format = "file"),

  # STK's own port events (I in / U out), one row per ping, tagged from STK and the polygons alone (plan 011
  # Phase 2, plan 014). Which events a port call trusts is the flow's decision (port_call).
  tar_target(stk_event, {
    stk; shapes; stk_hid_pid
    produces("sources/stk/event.R", fd_staging("ais", "stk_event.parquet"))
  }, format = "file"),

  # ── Vessel trail ────────────────────────────────────────────────────────────
  # The four-layer model: merge measured positions, remove whacky points,
  # interpolate within trips, derive voyages and tie them to logbook trips.
  #
  # The logger positions are interpolated from this chain's output, so they are a
  # frozen input (sensor_gps above), not a target of it: no cycle. They join the
  # feed union as provider gps (plan 014); only recorded positions cut voyages.

  tar_target(ais_ping_union, {
    vessel_ais_key; vessel_identity; sensor_gps; stk_trail_raw; astd_staged; astd_b_staged; emodnet_raw
    produces("curate/ais_ping_union.R", fd_staging("ais", "ping_union"))
  }, format = "file"),

  # L2: whacky-point removal, its own stage rather than fused into trip building
  tar_target(ais_ping_clean, {
    ais_ping_tag
    produces("curate/ais_ping_clean.R", fd_staging("ais", "ping_clean"))
  }, format = "file"),

  tar_target(ais_ping_tag, {
    ais_ping_union; shapes; area_h3
    produces("curate/ais_ping_tag.R", fd_staging("ais", "ping_tagged"))
  }, format = "file"),

  tar_target(ais_voyage, {
    ais_ping_clean; port_call
    produces("curate/ais_voyage.R",
             fd_curated("ais", "ping"),
             fd_curated("ais", "voyage.parquet"))
  }, format = "file"),

  # ── Curation ────────────────────────────────────────────────────────────────
  # staging/ → curated/. Where cross-source decisions live.

  # Precedence, recorded once in curate/decisions/: afli where it exists, then
  # fs_afladagbok through its dump end, then adb beyond it.
  tar_target(logbook, {
    afli; afli_depth_units; afli_end_longitude; fs_afladagbok; adb; adb_lon_sign
    aflaskeyti; aflaskeyti_coordinates; aflaskeyti_local_time; aflaskeyti_trip; aflaskeyti_weight
    produces("curate/logbook.R",
             fd_curated("logbook", "trip.parquet"),
             fd_curated("logbook", "station.parquet"),
             fd_curated("logbook", "fishing_sample.parquet"),
             fd_curated("logbook", "catch.parquet"))
  }, format = "file"),

  # L4 of the vessel-trail model: tie logbook trips to AIS port-to-port
  # voyages. The deliverable the trail data exists for - AIS voyages carried no
  # logbook key at all before this. Additive: its own table, improved times as new
  # columns, curated/logbook/trip.parquet untouched.
  tar_target(trip_voyage, {
    logbook; ais_voyage
    produces("curate/link_trip_voyage.R",
             fd_curated("link", "trip_voyage.parquet"))
  }, format = "file"),

  # One row per (logbook station, phase): when the vessel is busy with it (plan 010).
  tar_target(station_window, {
    logbook; gear_window; logbook_gear
    produces("curate/station_window.R", fd_curated("logbook", "station_window.parquet"))
  }, format = "file"),

  tar_target(lid_map, {
    logbook; landing; gear
    produces("curate/link_lid_map.R",
             fd_curated("logbook", "lid_map.parquet"))
  }, format = "file"),

  # Correction, not part of the adapter: each station's gear, the landing's where it names one (decision 066,
  # plan 014 3j; was adb's alone), adb's own read through its crosswalk (plan 034).
  tar_target(logbook_gear, {
    logbook; lid_map; landing; gear; adb_gear_code
    produces("curate/corrections/logbook_gear.R", fd_curated("logbook", "gear.parquet"))
  }, format = "file"),

  # The catch as caught (whole weight), per (station, species): joins the trail on (.sid, schema).
  tar_target(catch_by_species_station, {
    logbook
    produces("curate/catch_by_species_station.R",
             fd_curated("logbook", "catch_by_species_station.parquet"))
  }, format = "file"),

  tar_target(catch_by_species_trip, {
    logbook; lid_map; landing
    produces("curate/catch_by_species_trip.R",
             fd_curated("logbook", "catch_by_species_trip.parquet"))
  }, format = "file"),

  # ── Checks ──────────────────────────────────────────────────────────────────
  # Cross-source disagreement. These REPORT: they emit a table into
  # curated/check/ and correct nothing. Reasoning from landings back onto the vid
  # assignment closes the AIS → vid → logbook → AIS cycle AGENTS.md warns about,
  # so a reviewed conclusion re-enters through overrides/ as an input.
  #
  # The vessel key's own checks build the key and run with it in the `once` project.

  # Port calls (plan 011 Phase 3; stays until decision 147): elapsed time at a port, from polygon, gap and (2017+)
  # event evidence.
  tar_target(port_call, {
    ais_ping_clean; shapes; stk_event; port_radius
    produces("curate/port_call.R",
             fd_curated("ais", "port_call.parquet"))
  }, format = "file"),

  tar_target(check_port_call_logbook, {
    port_call; logbook; landing
    produces("curate/checks/port_call_logbook.R",
             fd_curated("check", "port_call_logbook.parquet"))
  }, format = "file"),

  # The residue of the shared-voyage problem after the port calls, before vs after (plan 011 §6).
  tar_target(check_voyage_sharing, {
    trip_voyage; ais_voyage; logbook
    produces("curate/checks/voyage_sharing.R",
             fd_curated("check", "voyage_sharing.parquet"))
  }, format = "file"),

  # The product (plan 011 Phase 5): every fix with its voyage, station and logbook trip, by year-month.
  # The fix nearest each recorded event time of a station (TODO 54, decision 088).
  tar_target(station_event, {
    ais_voyage; station_window; logbook
    produces("curate/link_station_event.R",
             fd_curated("link", "station_event.parquet"))
  }, format = "file"),

  # The gear of each voyage, for the fixes no logbook window holds (plan 013 item 3).
  tar_target(voyage_gear, {
    ais_voyage; trip_voyage; logbook; logbook_gear; landing; gear; gear_window
    produces("curate/voyage_gear.R", fd_curated("ais", "voyage_gear.parquet"))
  }, format = "file"),

  tar_target(ais_trail, {
    ais_voyage; station_window; trip_voyage; logbook_gear; station_event; voyage_gear; vessel; vessel_year; vessel_class
    produces("curate/ais_trail.R",
             fd_curated("ais", "trail"), fd_curated("ais", "trail_match"))
  }, format = "file"),

  # The catch on the fixes, per catch unit and approach (plan 013 item 2, decision 100).
  tar_target(ais_catch, {
    ais_trail; station_window; logbook; lid_map; landing
    produces("curate/ais_catch.R", fd_curated("ais", "catch"))
  }, format = "file"),

  tar_target(check_trail_agreement, {
    ais_trail
    produces("curate/checks/trail_agreement.R",
             fd_curated("check", "trail_agreement.parquet"))
  }, format = "file"),

  # The track's tow boundaries scored against the spring survey's recorded tows (TODO 60, decision 104).
  tar_target(check_survey_tow_times, {
    ais_trail; gear_window
    produces("curate/checks/survey_tow_times.R",
             fd_curated("check", "survey_tow_times.parquet"))
  }, format = "file"),

  # How the landed weight compares with the logged, per species, year and logbook system (decision 104).
  tar_target(check_landed_logged, {
    logbook; lid_map; landing
    produces("curate/checks/landed_logged.R",
             fd_curated("check", "landed_logged.parquet"))
  }, format = "file"),

  # The vessels at sea that land nothing and keep no logbook: aquaculture, whale watching, other (plan 013 item 6).
  tar_target(check_vessel_activity, {
    ais_voyage; landing; logbook
    produces("curate/checks/vessel_activity.R",
             fd_curated("check", "vessel_activity.parquet"))
  }, format = "file"),

  # Every link the flow makes, tested against the records' own times, every record counted (after decision 154).
  tar_target(check_allocation_audit, {
    logbook; lid_map; landing; logbook_gear; gear; ais_voyage; port_call; trip_voyage; station_window; voyage_gear
    ais_trail; ais_catch
    produces("curate/checks/allocation_audit.R",
             fd_curated("check", "allocation_audit.parquet"))
  }, format = "file"),

  # Logbook stations that find a fix in the trail, by year and gear (plan 011 Phase 5).
  tar_target(check_trail_sid_coverage, {
    ais_trail; station_window
    produces("curate/checks/trail_sid_coverage.R",
             fd_curated("check", "trail_sid_coverage.parquet"))
  }, format = "file")
)
