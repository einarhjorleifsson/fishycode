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

tar_option_set(
  packages = c("tidyverse", "duckdbfs", "ramb", "whack", "geo",
               "sf", "nanoparquet", "duckdb")
)

# produces() and frozen_input() are in R/source_script.R, shared with _targets_once.R.
# source_script() sources with encoding = "UTF-8", which is not optional: the scripts
# carry Icelandic gear and port names (veidarfaeri, Grasleppunet, ...), and a
# subprocess whose locale is not UTF-8 reads them as Latin-1. It also clears what the
# script leaves behind - objects, options, attached packages - so one target cannot
# change the next. Build with tar_make_isolated() (R/tar_make_isolated.R): one session
# per target, because a one-session tar_make() swelled to 111 GB (decision 073).

list(

  # ── Reference ───────────────────────────────────────────────────────────────
  # Slow-moving lookups. Everything downstream depends on some of these.

  tar_target(dictionary, produces(
    "reference/dictionary.R",
    fd_curated("reference", "dictionary.parquet")), format = "file"),

  tar_target(gear, produces(
    "reference/gear/mapping.R",
    fd_curated("reference", "gear.parquet")), format = "file"),

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

  tar_target(ports_all, {
    ports_iceland
    produces("reference/ports/ports_all.R",
             fd_staging("ports", "ports_all.gpkg"),
             fd_curated("reference", "port_geometry.parquet"))
  }, format = "file"),

  tar_target(port, {
    ports_iceland
    produces("reference/ports/harbour_codes.R",
             fd_curated("reference", "port.parquet"))
  }, format = "file"),

  tar_target(port_code, produces(
    "reference/ports/port_code.R",
    fd_curated("reference", "port_code.parquet")), format = "file"),

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

  tar_target(vessel, produces(
    "reference/vessels/registry.R",
    fd_curated("vessel", "vessel.parquet")), format = "file"),

  # vid -> what the hull was called, and when. The vid is the keel; mmsi, cs and
  # uid are attributes of it at a time. Consumed by ais_key.R's lifetime flag and
  # by curate/ais_ping_union.R, which resolves the MMSI-keyed commercial feeds
  # through it. See curate/decisions/015.
  tar_target(vessel_identity, {
    vessel
    produces("reference/vessels/identity.R",
             fd_curated("vessel", "vessel_identity.parquet"))
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

  # ── Source adapters ─────────────────────────────────────────────────────────
  # raw/ → staging/<source>/. Mutually independent, so tar_make(workers = 4)
  # runs them in parallel. Each must emit the four-table grammar.

  tar_target(afli, {
    dictionary; gear; gear_window; port
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

  tar_target(fs_afladagbok, {
    dictionary; gear; gear_window; port
    produces("sources/fs_afladagbok/convert.R",
             fd_staging("fs_afladagbok", "trip.parquet"),
             fd_staging("fs_afladagbok", "station.parquet"),
             fd_staging("fs_afladagbok", "fishing_sample.parquet"),
             fd_staging("fs_afladagbok", "catch.parquet"))
  }, format = "file"),

  tar_target(adb, {
    dictionary; gear
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

  tar_target(aflagrunnur, {
    produces("sources/aflagrunnur/convert.R",
             fd_staging("landing", "agf", "landings.parquet"),
             fd_staging("landing", "agf", "catch.parquet"))
  }, format = "file"),

  tar_target(lods, {
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
    vessel_ais_key
    produces("sources/stk/convert.R", fd_staging("ais", "stk"))
  }, format = "file"),

  # STK's own port events (I in / U out), one row per ping, tagged from STK and the polygons alone (plan 011
  # Phase 2, plan 014). Which events a stay trusts is the flow's decision (port_stay).
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
    vessel_ais_key; vessel_identity; sensor_gps
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
    ais_ping_clean; port_stay
    produces("curate/ais_voyage.R",
             fd_curated("ais", "ping"),
             fd_curated("ais", "voyage.parquet"))
  }, format = "file"),

  # ── Curation ────────────────────────────────────────────────────────────────
  # staging/ → curated/. Where cross-source decisions live.

  # Precedence, recorded once in curate/decisions/: afli where it exists, then
  # fs_afladagbok through its dump end, then adb beyond it.
  tar_target(logbook, {
    afli; afli_depth_units; fs_afladagbok; adb; adb_lon_sign
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
  # plan 014 3j; was adb's alone).
  tar_target(logbook_gear, {
    logbook; lid_map; landing; gear
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

  # Stays (plan 011 Phase 3): elapsed time at a port, from polygon, gap and (2017+) event evidence.
  tar_target(port_stay, {
    ais_ping_clean; shapes; stk_event; port_radius
    produces("curate/port_stay.R",
             fd_curated("ais", "port_stay.parquet"))
  }, format = "file"),

  tar_target(check_port_stay_logbook, {
    port_stay; logbook; landing
    produces("curate/checks/port_stay_logbook.R",
             fd_curated("check", "port_stay_logbook.parquet"))
  }, format = "file"),

  # The residue of the shared-voyage problem after the stays, before vs after (plan 011 §6).
  tar_target(check_voyage_sharing, {
    trip_voyage; ais_voyage; logbook
    produces("curate/checks/voyage_sharing.R",
             fd_curated("check", "voyage_sharing.parquet"))
  }, format = "file"),

  # The product (plan 011 Phase 5): every fix with its voyage, station and logbook trip, by year-month.
  tar_target(ais_trail, {
    ais_voyage; station_window; trip_voyage
    produces("curate/ais_trail.R",
             fd_curated("ais", "trail"), fd_curated("ais", "trail_match"))
  }, format = "file"),

  tar_target(check_trail_agreement, {
    ais_trail
    produces("curate/checks/trail_agreement.R",
             fd_curated("check", "trail_agreement.parquet"))
  }, format = "file"),

  # Logbook stations that find a fix in the trail, by year and gear (plan 011 Phase 5).
  tar_target(check_trail_sid_coverage, {
    ais_trail; station_window
    produces("curate/checks/trail_sid_coverage.R",
             fd_curated("check", "trail_sid_coverage.parquet"))
  }, format = "file")
)
