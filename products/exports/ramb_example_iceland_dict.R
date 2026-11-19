# ramb_example_iceland_dict.R — the data dictionary's hand-written entries for products/exports/ramb_example_iceland.R:
# what each table and column is. The builder adds the ranges, examples and values from the data and checks that every
# column it writes has an entry here and no entry is left over. Defines dict_tables(); sourced, never run alone.

dict_tables <- function(P1, P2, AREA, NATIONAL, MARGIN_H, CAP_D, months, gear) {
  col <- function(name, type, description, ...) c(list(name = name, type = type, description = description), list(...))
  gid_values <- function() as.list(setNames(sprintf("%s (%s)", gear$name, ifelse(is.na(gear$gear), "no ICES code", gear$gear)),
                                            gear$gid))
  vid <- col("vid", "number(id)", "The vessel or ship, anonymised: 1 to n in random order, the same in every table; not a register number or an MMSI.")
  provenance <- paste0(
    "**Cite:** none yet: Marine and Freshwater Research Institute, Iceland (MFRI), unpublished.\n\n",
    "**Licence:** none: not released. A release needs an agreed basis with MFRI, with Fiskistofa for the logbooks and ",
    "landings, and with each AIS feed's provider (README.md).\n\n")
  changes <- function(x) paste0("**Changes:** ", x, " (fishycode `products/exports/ramb_example_iceland.R`).")
  census <- sprintf(paste(
    "The census, %s to %s, in two tiers, as a national institute holds its data.",
    "**national**: every vessel registered in the north-west's home districts (%s) that was active in the period,",
    "with everything in its window: the period, widened until every voyage and logbook trip overlapping it is whole,",
    "at most %d days beyond it, then %d hours more each side.",
    "**other** and **unmatched**: every other register vessel, and every MMSI of PAME's feeds no register vessel matches,",
    "with a ping in the area %.1f-%.1f W, %.1f-%.1f N in the period (or, for a register vessel, a landing at a port in",
    "it): their pings inside the area and the period only, cut at both edges, and the other vessels' landings in the",
    "area's ports."),
    format(P1), format(as.Date(P2) - 1), paste(NATIONAL, collapse = ", "), CAP_D, MARGIN_H,
    -AREA[["xmax"]], -AREA[["xmin"]], AREA[["ymin"]], AREA[["ymax"]])
  basis <- "How the value was obtained: recorded, derived, reconstructed, synthesised, or none (no source has it)."
  national_only <- function(x) paste(x, "The national fleet's only.")

  list(
    iceland = list(
      name = "iceland",
      label = "Icelandic vessel tracks (AIS and VMS), every feed, before any cleaning",
      description = paste(
        "Each row is a position report from one of the feeds that hold Icelandic waters, as the feed delivered it:",
        "copies of one report in several feeds, impossible positions, reports in the same second, gaps, harbour stays",
        "and positions on land are all kept. One file a month of the period:",
        paste(sprintf("`iceland_%s.parquet`", months), collapse = ", "),
        "(a national vessel's pings before the period with the first month, after it with the last)."),
      details = paste0(provenance, changes(paste(
        "fishydata's merged feeds (`staging/ais/ping_union`), before the feeds are put on one clock and before any flag;",
        "for the unmatched MMSIs PAME's feeds as staged (`staging/ais/astd`, `astdB`), class B's not-available codes made",
        "empty; the MMSI and IMO left out, the vessel renumbered; the GPS loggers' positions left out, as fishydata puts",
        "them back on the cleaned track (they are the flow's, not a feed's)")), "\n\n", census),
      columns = list(
        vid,
        col("time", "datetime", "Time of the report as the feed gives it, UTC. The feeds' clocks may differ by seconds to minutes; STK's VMS reports are stamped by their unit.", time_zone = "UTC"),
        col("lon", "number(quantity)", "Longitude, as reported.", units = "degrees east"),
        col("lat", "number(quantity)", "Latitude, as reported.", units = "degrees north"),
        col("speed", "number(quantity)", "Speed over ground as reported; empty where the feed carries none (ASTD, EMODnet).", units = "knots"),
        col("heading", "number(quantity)", "True heading as reported; STK's AIS stream carries none after 2010-06-09.", units = "degrees"),
        col("cog", "number(quantity)", "Course over ground as reported.", units = "degrees"),
        col("provider", "enum", "The feed.", values = list(
          stk = "STK, the Icelandic Coast Guard's vessel monitoring system: AIS from its coastal network, the reports of its own VMS units, and its port arrivals; Icelandic vessels only",
          emodnet = "an extract of 2017 AIS around Iceland delivered to fishydata as EMODnet's, Icelandic vessels only (no speed)",
          astd = "PAME's Arctic Ship Traffic Data, every ship (no speed; none in July 2017: the month was never delivered)",
          astdB = "PAME's archive of class B AIS, every ship")),
        col("stream", "enum", "STK's stream, told by the position's grid (no column of STK's says it): ais (AIS, a ten-thousandth of a minute), centiminute (VMS-like units, a hundredth of a minute), ungridded (STK's own units); empty for the other feeds."),
        col("io", "enum", "I on an STK port arrival kept as a report; empty otherwise.", values = list(I = "an arrival in port, as STK recorded it")),
        col("speed_basis", "enum", "How the speed was obtained: recorded, or none (the feed has none).")
      )
    ),
    iceland_trips = list(
      name = "iceland_trips",
      label = "Icelandic logbook trips",
      description = paste(
        "Each row is a fishing trip of a national vessel as the logbook declares it, every trip overlapping the",
        "vessel's window; departure and return are dates only in 2017's logbooks."),
      details = paste0(provenance, changes(paste(
        "fishydata's logbook trips (`curated/logbook/trip.parquet`), the trips renumbered; a record entered twice kept",
        "and flagged (`twin`)")), "\n\n", census),
      columns = list(
        col("trip_id", "number(id)", "The trip, numbered anew in the order of vessel and time.", constraints = list("primary_key")),
        vid,
        col("source", "enum", "The logbook system.", values = list(afli = "MFRI's logbook database", aflaskeyti = "the ERS catch reports")),
        col("T1", "datetime", "Departure as declared: a date (midnight) in afli, its first fishing day; may be well after the vessel left port.", time_zone = "UTC"),
        col("T2", "datetime", "Return as declared: a date (midnight) in afli, the day of landing, not a time of arrival.", time_zone = "UTC"),
        col("T1_basis", "enum", basis),
        col("T2_basis", "enum", basis),
        col("pid1", "string", "Departure port (iceland_harbours.pid) as declared; afli declares none."),
        col("pid2", "string", "Return port (iceland_harbours.pid) as declared."),
        col("twin", "enum", "A trip entered twice: duplicate (the copy; leave it out of every sum), kept (the original), same_time (another trip at the same time, kept); empty for the rest."),
        col("twin_of", "number(id)", "For a duplicate, the trip it copies."),
        col("n_crew", "number(count)", "Crew, as declared.")
      )
    ),
    iceland_hauls = list(
      name = "iceland_hauls",
      label = "Icelandic logbook hauls, with their total catch",
      description = paste(
        "Each row is a station of a logbook trip in iceland_trips: a tow, a set, a haul, or for some gears and vessels",
        "one record for a day. Most give a date and a duration, not clock times. The catch is the total over species."),
      details = paste0(provenance, changes(paste(
        "fishydata's logbook stations with their times, gear and catch (`curated/logbook/{station,fishing_sample,gear}`,",
        "the user tables' whole weight), the hauls and trips renumbered, the catch summed over species")), "\n\n", census),
      columns = list(
        col("haul_id", "number(id)", "The haul, numbered anew within its trip's order.", constraints = list("primary_key")),
        col("trip_id", "number(id)", "Its trip (iceland_trips.trip_id)."),
        vid,
        col("source", "enum", "The logbook system, as in iceland_trips."),
        col("date", "datetime", "The fishing date as logged; empty for some records.", time_zone = "UTC"),
        col("t1", "datetime", "Gear deployment starts (a static gear's set); empty where the logbook app filled in a placeholder (t1_placeholder).", time_zone = "UTC"),
        col("t2", "datetime", "Gear deployment ends.", time_zone = "UTC"),
        col("t3", "datetime", "Gear retrieval starts (a tow's start for a trawl; a static gear's haul).", time_zone = "UTC"),
        col("t4", "datetime", "Gear retrieval ends.", time_zone = "UTC"),
        col("t1_placeholder", "boolean", "TRUE where the logged set time was the app's placeholder (the haul start less 270 or 1,710 minutes): the logbook knows no soak there."),
        col("time_basis", "enum", "How t1-t4 were obtained, aflaskeyti only: reconstructed (moved from local time to UTC) or recorded."),
        col("duration_m", "number(quantity)", "The duration the record gives (a tow's time, a jig's hours), as recorded, even above the gear's plausible maximum.", units = "minutes"),
        col("duration_source", "enum", "data (a recorded duration), times (made from t1-t4), or implausible (above the gear's plausible maximum: a flag, the value stays)."),
        col("lon1", "number(quantity)", "Start longitude.", units = "degrees east"),
        col("lat1", "number(quantity)", "Start latitude.", units = "degrees north"),
        col("lon2", "number(quantity)", "End longitude.", units = "degrees east"),
        col("lat2", "number(quantity)", "End latitude.", units = "degrees north"),
        col("lon1_basis", "enum", paste("How the start position was obtained.", basis)),
        col("lon2_basis", "enum", paste("How the end position was obtained.", basis)),
        col("sq", "number(id)", "MFRI's statistical square (afli)."),
        col("ssq", "number(id)", "Its sub-square, 0-4."),
        col("area", "number(id)", "afli's area code (skiki): a named inshore or shrimp ground, the only place of some inshore hauls."),
        col("z1", "number(quantity)", "Start depth.", units = "metres"),
        col("z2", "number(quantity)", "End depth.", units = "metres"),
        col("gid", "enum", "The gear as logged, MFRI's gear id.", values = gid_values()),
        col("gid_landing", "enum", "The gear of the linked landing, where the landing names one.", values = gid_values()),
        col("gid_used", "enum", "The gear to use: the landing's where its kind differs from the logbook's or the logbook has none, else the logbook's.", values = gid_values()),
        col("gid_basis", "enum", "recorded (the logbook's gear) or reconstructed (the landing's)."),
        col("gear", "enum", "The ICES gear code of gid (OTB bottom otter trawl, also for the shrimp trawl; LLS longline; GNS set gillnet; LHM, LHP hand and pole lines; SDN Danish seine; DRB dredge; FPO pots)."),
        col("gear_code", "string", "The gear and its target as one code, XXX_YYY."),
        col("station_type", "enum", "What the row covers: operation (one tow, set or haul) or event (one record for a day), read from the vessel's own pattern."),
        col("effort_count", "number(count)", "What fishes at once: hooks, nets, jigs, traps, or the trawls or dredges of a towed gear."),
        col("effort_count_basis", "enum", basis),
        col("effort_count_unit", "enum", "What effort_count counts."),
        col("g_mesh", "number(quantity)", "Mesh size, as logged.", units = "mm"),
        col("g_width", "number(quantity)", "Gear width, as logged (a dredge's width).", units = "m"),
        col("g_height", "number(quantity)", "Gear height, as logged (a gillnet's height).", units = "meshes or m, as logged"),
        col("g_length", "number(quantity)", "Gear length, as logged (a seine's rope, a gillnet's total length).", units = "m"),
        col("rig", "enum", "How a towed gear is rigged where the skipper's remark says (twin trawl, pair trawl)."),
        col("mishap", "enum", "What went wrong with the haul, from the skipper's remark; the haul and catch stay as recorded."),
        col("deleted", "boolean", "TRUE where the source marks the record deleted (afli); kept as it is."),
        col("twin", "enum", "A haul entered twice, as for trips: duplicate (the copy), kept, same_time; empty for the rest."),
        col("twin_of", "number(id)", "For a duplicate, the haul it copies."),
        col("catch_kg", "number(quantity)", "Total catch of the haul, whole (round) weight over every species, released fish left out; empty where the logbook gives no catch, and for a duplicate (never counted twice).", units = "kg"),
        col("catch_n_flagged", "number(count)", "How many of the haul's species rows fishydata flags as extreme or contradicted; their weights are in catch_kg as recorded."),
        col("catch_flags", "string", "The flags' rules, where any.")
      )
    ),
    iceland_landings = list(
      name = "iceland_landings",
      label = "Icelandic landings by gear and species",
      description = paste(
        "Each row is a landing's landed weight of one species by the gear it names: a national vessel's every",
        "landing in its window or linked to its trips, wherever it landed, and another register vessel's landings in",
        "the area's ports in the period, as a port state records them. Landings by vessel, gear, port and species are",
        "public in Iceland (Fiskistofa)."),
      details = paste0(provenance, changes(paste(
        "fishydata's landings (`curated/landing/{landings,catch}`), the landings renumbered, the weight summed by gear",
        "and species over the landing system's own detail (stock, state); Fiskistofa's harbour code left out")),
        "\n\n", census),
      columns = list(
        col("landing_id", "number(id)", "The landing, numbered anew; with gid and sid, the row's key."),
        vid,
        col("source", "enum", "The landings system: agf (Fiskistofa's, from 2007-09) or lods (its predecessor, kept in parallel)."),
        col("date", "date", "Landing date."),
        col("pid", "string", "Landing port (iceland_harbours.pid)."),
        col("gid", "enum", "The gear the landing names, MFRI's gear id; sea angling (19) is known from the landings alone.", values = gid_values()),
        col("sid", "number(id)", "The species, MFRI's code (iceland_species.sid)."),
        col("catch_kg", "number(quantity)", "Landed weight of the species, ungutted equivalent. Never add it to the logbook's catch.", units = "kg")
      )
    ),
    iceland_trip_landing = list(
      name = "iceland_trip_landing",
      label = "Links between the logbook trips and the landings",
      description = paste(
        "Each row links a national vessel's logbook trip to a landing, by the declarations' match: vessel, landing",
        "date and port, in steps from exact to loose, one landing to a trip where the match is unambiguous. One",
        "landing may close several trips."),
      details = paste0(provenance, changes(paste("fishydata's match of the declarations (`curated/logbook/lid_map.parquet`,",
        "`curate/link_lid_map.R`), renumbered; the further landings fishydata's flow joins by the AIS track are its",
        "answers, left out")), "\n\n", census),
      columns = list(
        col("trip_id", "number(id)", "The trip (iceland_trips.trip_id)."),
        col("landing_id", "number(id)", "The landing (iceland_landings.landing_id)."),
        col("match_type", "enum", "The step of the match that made the link, from exact (vessel, date and port) to looser keys."),
        col("n_trips", "number(count)", "How many trips the landing closes.")
      )
    ),
    iceland_vessels = list(
      name = "iceland_vessels",
      label = "The vessels and ships of the Icelandic census, by tier",
      description = paste(
        "Each row is a vessel or ship of the census. The national fleet has its register's measures; the other",
        "register vessels their flag, length and type; the unmatched MMSIs what PAME's feeds and the MMSI say of them."),
      details = paste0(provenance, changes(paste(
        "fishydata's vessel tables (`curated/vessel/vessel_year.parquet` for power and length, the register's history",
        "for tonnage and home district, as of the middle of the period), PAME's ship category, tonnage class and class B",
        "length, and an MMSI's kind and flag from its layout and maritime identification digits (ITU's); name, call",
        "sign, MMSI, IMO and registration left out")), "\n\n", census),
      columns = list(
        c(vid, list(constraints = list("primary_key"))),
        col("tier", "enum", "Which part of the census.", values = list(
          national = "registered in the north-west: pings, logbook and landings in full, wherever it went",
          other = "another register vessel: pings inside the area and the period, and its landings in the area's ports",
          unmatched = "an MMSI of PAME's feeds no register vessel matches (a foreign ship, an Icelandic MMSI never linked, an aid to navigation, a malformed number): pings inside the area and the period")),
        col("flag", "string", "The flag state: the register's, or an unmatched MMSI's from its maritime identification digits; ISO 3166 alpha-3 where the name matches (ISL for Iceland), else the country's name as ITU's table gives it."),
        col("kw", "number(quantity)", national_only("Engine power."), units = "kW"),
        col("kw_basis", "enum", "Where kw came from."),
        col("loa", "number(quantity)", "Length overall: the register's, or an unmatched class B ship's as its AIS reports it.", units = "m"),
        col("loa_basis", "enum", "Where loa came from: the register's sources, or ais."),
        col("gt", "number(quantity)", national_only("Gross tonnage (brúttótonn)."), units = "GT"),
        col("gt_class", "enum", "An unmatched ship's gross-tonnage class, as PAME gives it."),
        col("home_district", "enum", national_only("The district letters of the vessel's registration (ÍS, BA, SH, ...), the region of its home port.")),
        col("usage", "string", "The register's usage type, in Icelandic (Fiskiskip a fishing vessel, ...), as printed; empty where the register gives none."),
        col("mclass", "number(id)", national_only("The register's usage category code.")),
        col("ship_category", "enum", "An unmatched ship's category, as PAME gives it (cruise ships, general cargo ships, fishing vessels, ...); empty where it reported on class B only."),
        col("mmsi_kind", "enum", "What an unmatched MMSI is, by its layout (ITU-R M.585), read before the MMSI was dropped; empty for a register vessel.", values = list(
          ship = "nine digits led by a known maritime identification digit (MID)",
          aid_to_navigation = "99 and a MID: a buoy or light broadcasting AIS",
          other_station = "a coast station (00), a craft of a parent ship (98), a SAR aircraft (111) or a distress device (97)",
          invalid = "not nine digits, or led by no known MID"))
      )
    ),
    iceland_harbours = list(
      name = "iceland_harbours",
      label = "Harbour polygons for the Icelandic tracks",
      description = paste(
        "Each row is a polygon of a port, from the lists fishydata tags pings with: every port that comes within",
        "0.05 degrees of a ping, and every port the records name. A port may have several polygons, one from each list;",
        "a few are points."),
      details = paste0(
        "**Cite:** fishydata's port layer, compiled by MFRI from its own drawing, OpenStreetMap and other lists.\n\n",
        "**Licence:** none yet: the polygons from OpenStreetMap are ODbL; the rest are MFRI's (README.md).\n\n",
        changes("the polygons of `staging/aux/ports.fgb` near the pings"), "\n\n", census),
      columns = list(
        col("pid", "string", "The port, fishydata's id."),
        col("port", "string", "The port's name."),
        col("source", "string", "The list the polygon is from."),
        col("priority", "number(ordinal)", "The list's rank where polygons overlap, 1 first."),
        col("geometry", "geometry", "The port's polygon (or point), DuckDB GEOMETRY, longitude and latitude on WGS 84.")
      )
    ),
    iceland_species = list(
      name = "iceland_species",
      label = "The species of the Icelandic landings",
      description = "Each row is a species named in iceland_landings, with its names and codes.",
      details = paste0(
        "**Cite:** MFRI's species list, as fishydata curates it (`curated/reference/species.parquet`).\n\n",
        "**Licence:** none yet (README.md).\n\n",
        changes("the species of the landings, six of the list's columns")),
      columns = list(
        col("sid", "number(id)", "The species, MFRI's code.", constraints = list("primary_key")),
        col("name", "string", "Its Icelandic name."),
        col("name_en", "string", "Its English name."),
        col("name_sci", "string", "Its scientific name."),
        col("fao_3a", "string", "Its FAO 3-alpha code."),
        col("worms_id", "number(id)", "Its WoRMS AphiaID.")
      )
    ),
    iceland_coast = list(
      name = "iceland_coast",
      label = "Iceland's coast: land and skerries",
      description = paste(
        "Each row is a polygon of land (the mainland or an island) or of a skerry, from IS 50V, for the land test of",
        "the pings and for maps."),
      details = paste0(
        "**Cite:** IS 50V, Náttúrufræðistofnun Íslands (natt.is), strandlína flákar, as of 2024-04-18.\n\n",
        "**Licence:** open data of natt.is (IS 50V); cite as above.\n\n",
        changes(paste("the layer whole as fetched to `raw/external/is50v/strandlina_flakar.json`, its class",
                      "(eyjarsker) as kind, the other fields left out"))),
      columns = list(
        col("kind", "enum", "land (the mainland and the islands) or skerry."),
        col("geometry", "geometry", "The polygon (MULTIPOLYGON), DuckDB GEOMETRY, longitude and latitude on WGS 84.")
      )
    )
  )
}
