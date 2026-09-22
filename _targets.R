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

  tar_target(area_h3, produces(
    "reference/geo/h3_index.R",
    fd_curated("reference", "area_h3.parquet")), format = "file"),

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
  tar_target(vessel_ais_key, {
    lookups; vessel; vessel_identity
    produces("reference/vessels/ais_key.R",
             fd_curated("vessel", "vessel_ais_key.parquet"))
  }, format = "file"),


  # ── Source adapters ─────────────────────────────────────────────────────────
  # raw/ → staging/<source>/. Mutually independent, so tar_make(workers = 4)
  # runs them in parallel. Each must emit the four-table grammar.

  tar_target(afli, {
    dictionary; gear; port
    produces("sources/afli/convert.R",
             fd_staging("afli", "trip.parquet"),
             fd_staging("afli", "station.parquet"),
             fd_staging("afli", "fishing_sample.parquet"),
             fd_staging("afli", "catch.parquet"),
             fd_staging("afli", "aggregate.parquet"))
  }, format = "file"),

  tar_target(fs_afladagbok, {
    dictionary; gear; port
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
             fd_staging("adb", "catch.parquet"))
  }, format = "file"),

  tar_target(aflagrunnur, {
    port
    produces("sources/aflagrunnur/convert.R",
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
    ais_ping_clean
    produces("curate/ais_trip.R",
             fd_curated("ais", "ping"),
             fd_curated("ais", "trip.parquet"))
  }, format = "file"),


  # ── Curation ────────────────────────────────────────────────────────────────
  # staging/ → curated/. Where cross-source decisions live.

  # Precedence, recorded once in curate/decisions/: afli where it exists, then
  # fs_afladagbok through its dump end, then adb beyond it.
  tar_target(logbook, {
    afli; fs_afladagbok; adb
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

  tar_target(lid_map, {
    logbook; aflagrunnur; gear
    produces("curate/link_lid_map.R",
             fd_curated("logbook", "lid_map.parquet"),
             fd_curated("logbook", "trip.parquet"))
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
    vessel_ais_key; vessel
    produces("curate/checks/ais_key_registry.R",
             fd_curated("check", "ais_key_registry.parquet"))
  }, format = "file"),

  tar_target(check_ais_key_landings, {
    vessel_ais_key; vessel; aflagrunnur
    produces("curate/checks/ais_key_landings.R",
             fd_curated("check", "ais_key_landings.parquet"))
  }, format = "file")
)
