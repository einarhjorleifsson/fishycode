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
# Two things sit OUTSIDE the graph, on purpose:
#   dump/       extraction from Oracle and vendor archives. Needs credentials and
#               a server, writes immutable raw/, and is run on its own schedule.
#   curate/corrections/afli_coords.R
#               a bootstrap cycle — see the note above the AIS section.
# products/ are consumers of the sweep and are run on demand, not on every build.

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

# Helper: source a script, then return the files it is contracted to produce.
# Declaring the outputs here rather than inside the scripts keeps the contract
# visible in one place.
# encoding = "UTF-8" is not optional: the scripts carry Icelandic gear and port
# names (veidarfaeri, Grasleppunet, ...). Without it a subprocess whose locale is
# not UTF-8 reads the bytes as Latin-1 and the script fails to parse.
produces <- function(script, ...) {
  source(script, encoding = "UTF-8")
  c(...)
}

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

  tar_target(harbour, produces(
    "reference/ports/harbours.R",
    fd_curated("reference", "harbour.parquet")), format = "file"),

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

  # Country codes, maritime identification digits, call-sign prefixes. Declared
  # late: this script was producing three inputs vessel_ais_key needs while not
  # being a target at all, so the graph reported ready and would have failed.
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

  # NOT a registry: a fitted model with residual error (>100-ping threshold,
  # a 2028-12-24 sentinel, 124 vids whose mobile-ids overlap). Wrong vid
  # assignment is a known error class, and as of 2026-09-22 the two checks below
  # measure it rather than this comment merely asserting it. It emits
  # entity_class and basis as well as vid — see curate/plans/003, decisions 012
  # and 013.
  tar_target(vessel_ais_key_cascade, {
    lookups; vessel; vessel_identity
    produces("reference/vessels/ais_key_cascade.R",
             fd_curated("vessel", "vessel_ais_key_cascade.parquet"))
  }, format = "file"),

  # The key the pipeline consumes, built from the segment table (plan 009 phase 5, decision 053). The
  # cascade above is its input and the segment table's: they cannot be one target.
  tar_target(vessel_ais_key, {
    check_ais_key_segments; vessel_ais_key_cascade; vessel; vessel_identity
    produces("reference/vessels/ais_key.R",
             fd_curated("vessel", "vessel_ais_key.parquet"),
             fd_curated("vessel", "vessel_ais_device.parquet"))
  }, format = "file"),


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

  # The annual ship register: the call sign per vessel per year, 2007-2022. Dates the holder of a call sign
  # for the segment table (decision 049).
  tar_target(skipaskra, {
    produces("sources/skipaskra/annual_call_sign.R",
             fd_staging("skipaskra", "annual_call_sign.parquet"))
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


  # ── Vessel trail ────────────────────────────────────────────────────────────
  # The four-layer model: merge measured positions, remove whacky points,
  # interpolate within trips, derive voyages and tie them to logbook trips.
  #
  # The bootstrap cycle that used to sit here is GONE. It existed because the
  # afli logger's positions were approximated from the merged track BEFORE the
  # merge, then folded back into it. Deriving them downstream instead
  # (curate/logbook_sensor_gps.R) breaks it, so the whole chain is now declarable.

  tar_target(ais_ping_union, {
    vessel_ais_key; vessel_identity
    produces("curate/ais_ping_union.R", fd_staging("ais", "ping_union"))
  }, format = "file"),

  # L2: whacky-point removal, its own stage rather than fused into trip building
  tar_target(ais_ping_clean, {
    ais_ping_tag
    produces("curate/ais_ping_clean.R", fd_staging("ais", "ping_clean"))
  }, format = "file"),

  # L3: supply lon/lat for the logger GPS by interpolating the merged track onto
  # its timestamps, bounded by voyage. Sits downstream of the merge, which is what
  # removes the old bootstrap cycle. Depends on ais_trip rather than
  # ais_ping_clean: the voyages have to exist before anything can be bound by them.
  tar_target(logbook_sensor_gps, {
    ais_trip; logbook
    produces("curate/logbook_sensor_gps.R", fd_curated("logbook", "sensor_gps"))
  }, format = "file"),

  tar_target(ais_ping_tag, {
    ais_ping_union; shapes; area_h3
    produces("curate/ais_ping_tag.R", fd_staging("ais", "ping_tagged"))
  }, format = "file"),

  tar_target(ais_trip, {
    ais_ping_clean; harbour_stay
    produces("curate/ais_trip.R",
             fd_curated("ais", "ping"),
             fd_curated("ais", "trip.parquet"))
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

  # L4 of the vessel-trail model: tie logbook trips to AIS harbour-to-harbour
  # voyages. The deliverable the trail data exists for - AIS voyages carried no
  # logbook key at all before this. Additive: its own table, improved times as new
  # columns, curated/logbook/trip.parquet untouched.
  tar_target(trip_voyage, {
    logbook; ais_trip
    produces("curate/link_trip_voyage.R",
             fd_curated("link", "trip_voyage.parquet"))
  }, format = "file"),

  # Cleaned AIS + the GPS logger as one track, unique on (vid, time) (plan 010 §5).
  # After the interpolation, never before it: the logger positions come from the AIS track.
  tar_target(ais_ping_trail, {
    ais_trip; logbook_sensor_gps
    produces("curate/ais_ping_trail.R", fd_curated("ais", "ping_trail"))
  }, format = "file"),

  # One row per (logbook station, phase): when the vessel is busy with it (plan 010).
  tar_target(station_window, {
    logbook; gear_window; adb_gear
    produces("curate/station_window.R", fd_curated("logbook", "station_window.parquet"))
  }, format = "file"),

  tar_target(lid_map, {
    logbook; landing; gear
    produces("curate/link_lid_map.R",
             fd_curated("logbook", "lid_map.parquet"))
  }, format = "file"),

  # Correction, not part of the adapter: adb's gear, read from the matched landing (decision 066).
  tar_target(adb_gear, {
    logbook; lid_map; landing; gear
    produces("curate/corrections/adb_gear.R", fd_curated("logbook", "adb_gear.parquet"))
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
  # They depend on vessel_ais_key, which makes them run after any rebuild of it —
  # which is the point. A check that is not in the graph is a check nobody runs.

  tar_target(check_ais_key_registry, {
    vessel_ais_key_cascade; vessel
    produces("curate/checks/ais_key_registry.R",
             fd_curated("check", "ais_key_registry.parquet"))
  }, format = "file"),

  # The invariant: a mobile-id with a vessel has a vessel for its whole period, no ping unassigned.
  # Finds every ping outside a period (and the ODS's negative-vid drops) and proposes a fill.
  tar_target(check_ais_key_coverage, {
    vessel_ais_key
    produces("curate/checks/ais_key_coverage.R",
             fd_curated("check", "ais_key_coverage.parquet"))
  }, format = "file"),

  # Silences in a mobile-id where a human-style reading (time-speed profile, position,
  # registry) says the vessel changed - the splits the manual ODS made by hand, and the
  # ones it did not. See the script header and decision 047.
  tar_target(check_ais_key_split_candidates, {
    vessel_ais_key_cascade; vessel; vessel_identity
    produces("curate/checks/ais_key_split_candidates.R",
             fd_curated("check", "ais_key_split_candidates.parquet"))
  }, format = "file"),

  # The whole key, row by row, against witnesses that never read it (other-provider AIS
  # by MMSI, logbook, landings). Long-running by design: it is a ledger, not a test.
  tar_target(check_ais_key_audit, {
    vessel_ais_key_cascade; landing; logbook; check_ais_key_registry; check_ais_key_split_candidates
    produces("curate/checks/ais_key_audit.R",
             fd_curated("check", "ais_key_audit_ledger.parquet"),
             fd_curated("check", "ais_key_audit_discrepancy.parquet"),
             fd_curated("check", "ais_key_audit_w1.parquet"),
             fd_curated("check", "ais_key_audit_lb_hits.parquet"),
             fd_curated("check", "ais_key_audit_lb_n.parquet"))
  }, format = "file"),

  # The segment table: every mobile-id tiled, a vid for every stretch, no ping unassigned. Plan 009
  # phase 2. The manual ODS is not a judge of it.
  tar_target(check_ais_key_segments, {
    vessel_ais_key_cascade; vessel_identity; skipaskra; check_ais_key_audit; check_ais_key_split_candidates
    produces("curate/checks/ais_key_segments.R",
             fd_curated("check", "ais_key_segments.parquet"))
  }, format = "file"),

  # Mobile-ids heard with two vessels at once, kept as a table: companions, vessels in company,
  # a shared MMSI, and the cases where AIS is inconsistent. A candidate case example for fishyweb.
  tar_target(check_ais_key_twins, {
    check_ais_key_segments; vessel
    produces("curate/checks/ais_key_twins.R",
             fd_curated("check", "ais_key_twins.parquet"))
  }, format = "file"),

  # The vessel-first view: is every Icelandic vessel the registry, Hreidar or an MMSI say existed in the
  # STK era represented by a mobile-id, and do its mobile-ids report when the vessel is active?
  tar_target(check_ais_key_vessel_recall, {
    check_ais_key_segments; check_ais_key_audit; vessel; landing; logbook
    produces("curate/checks/ais_key_vessel_recall.R",
             fd_curated("check", "ais_key_vessel_recall.parquet"))
  }, format = "file"),

  # Each discrepancy mid read as eras: which vid when, what the key says, whether the
  # registry allows it. Proposals only; a person decides and it enters through overrides/.
  tar_target(check_ais_key_resolution, {
    check_ais_key_audit; check_ais_key_split_candidates; vessel; vessel_identity
    produces("curate/checks/ais_key_resolution.R",
             fd_curated("check", "ais_key_resolution.parquet"))
  }, format = "file"),

  # Both checks read curated/landing/landings.parquet (agf + lods, curate/
  # plans/007 §2/§7), extended from agf-only 2026-09-26 - see each script's
  # own header for why lods is worth including despite AIS itself starting
  # later than lods does.
  tar_target(check_ais_key_landings, {
    vessel_ais_key_cascade; vessel; landing
    produces("curate/checks/ais_key_landings.R",
             fd_curated("check", "ais_key_landings.parquet"))
  }, format = "file"),

  # Reused Icelandic call signs, checked from the raw STK side rather than off
  # the finished key - see the script header for why that catches more than
  # check_ais_key_landings does.
  # STK harbour events, one row per ping, tagged (plan 011 Phase 2). Reads the
  # cleaned track for the neighbour test and the current polygons for the position
  # test, so it does not wait for the outdated AIS chain to be rebuilt.
  tar_target(check_stk_event, {
    stk; ais_ping_clean; shapes; stk_hid_pid
    produces("curate/checks/stk_event.R",
             fd_curated("check", "stk_event.parquet"))
  }, format = "file"),

  # Stays (plan 011 Phase 3): elapsed time at a harbour, from polygon, gap and (2017+) event
  # evidence. Retags the cleaned pings against the current polygons itself, so it does not wait
  # for the chain rebuild; nothing consumes it until Phase 4.
  # The departure radius per harbour (decision 060), measured from the tagged events.
  tar_target(harbour_radius, {
    shapes; check_stk_event
    produces("reference/ports/harbour_radius.R",
             fd_curated("reference", "harbour_radius.parquet"))
  }, format = "file"),

  # Harbour class per harbour and year from the STK I->U stays (TODO 33); reviewed overrides enter by file.
  tar_target(harbour_class_overrides, "overrides/harbour_class.csv", format = "file"),
  tar_target(harbour_class, {
    shapes; stk; check_stk_event; harbour_class_overrides
    produces("reference/ports/harbour_class.R",
             fd_curated("reference", "harbour_class.parquet"))
  }, format = "file"),

  tar_target(harbour_stay, {
    ais_ping_clean; shapes; check_stk_event; harbour_radius; harbour_class
    produces("curate/harbour_stay.R",
             fd_curated("ais", "harbour_stay.parquet"))
  }, format = "file"),

  tar_target(check_harbour_stay_logbook, {
    harbour_stay; logbook; landing
    produces("curate/checks/harbour_stay_logbook.R",
             fd_curated("check", "harbour_stay_logbook.parquet"))
  }, format = "file"),

  # The residue of the shared-voyage problem after the stays, before vs after (plan 011 §6).
  tar_target(check_voyage_sharing, {
    trip_voyage; ais_trip; logbook
    produces("curate/checks/voyage_sharing.R",
             fd_curated("check", "voyage_sharing.parquet"))
  }, format = "file"),

  # The product (plan 011 Phase 5): every fix with its voyage, station and logbook trip, by year-month.
  tar_target(ais_trail, {
    ais_ping_trail; station_window; trip_voyage
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
  }, format = "file"),

  tar_target(check_ais_key_reused_callsign, {
    vessel_ais_key_cascade; vessel; landing
    produces("curate/checks/ais_key_reused_callsign.R",
             fd_curated("check", "ais_key_reused_callsign.parquet"))
  }, format = "file")
)
