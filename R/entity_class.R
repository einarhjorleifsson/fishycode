# entity_class.R — what kind of thing is behind an STK mobile-id.
#
# Input:  loid and glid as STK ships them, plus the reviewed override table
#         (overrides/stk_nonvessel_names.csv)
# Output: a two-column data frame — entity_class and basis — one row per input
#
# STK ships no entity type. `mobile.parquet` is mid, loid, glid and nothing else,
# and the two id fields are a mixed bag: an Icelandic vid, a call sign, an MMSI, a
# harbour name, or the literal string "unkown". Roughly a quarter of the pings in
# the trail come from something that is not a vessel at all — shore relays, net
# buoys, aquaculture pens, navigational aids — and until this function existed that
# knowledge lived inside a `type` string that happened to contain the word "fixed".
#
# Nothing here assigns a vid. This answers only "is it a vessel, and if not, what",
# so that an unassigned mobile-id can be read as correctly excluded rather than as
# a coverage gap.

# Classes ------------------------------------------------------------------------
# vessel        a ship, whether or not it has been matched to a vid
# child_vessel  MMSI 98x — a tender or auxiliary craft of a parent vessel
# shore_station a fixed installation ashore, including MMSI 00x coast stations
# net_relay     a shore relay carrying another station's traffic ("..._NET_")
# aquaculture   a fish-farming pen
# institute     a research installation
# navaid        MMSI 99x — a navigational aid
# buoy          a drifting or moored buoy named as such
# beacon        MMSI 970/972/974/8xx — SART, man-overboard, EPIRB, handheld VHF
# aircraft      MMSI 111x — SAR aircraft
# unknown       nothing in either field says what this is
#
# Basis ---------------------------------------------------------------------------
# Per AGENTS.md, every inferred value carries one.
# recorded      the field itself declares it — an MMSI's own number range, or an
#               identifier that resolves to a registered vessel
# reconstructed a pattern rule inferred it from the name
# synthesised   only the hand-reviewed override list says so

# The override table is a reviewed *input*, not a computed output: a nine-character
# truncated Icelandic place name is not derivable from anything, so a human decided
# each row. Read it once and pass it in; do not re-read per call.
read_stk_overrides <- function(path = "overrides/stk_nonvessel_names.csv") {
  o <- utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")
  stopifnot(all(c("value", "legacy_group", "entity_class") %in% names(o)))
  o
}

# A call sign is a vessel saying so. Shape first, then allocation: 4-7 characters,
# upper-case letters and digits only, at least one letter, and an ITU prefix that
# is actually allocated. Ten of the 711 prefixes are a single character (2 B F G I
# K M N R W), which is why this tries two characters and then one — the cascade's
# own rule at ais_key.R:378 tests only two and cannot see a French or British call
# sign at all.
#
# The shape test is what keeps the shore stations out: STK truncates its station
# names to nine characters, so they sit outside the 4-7 window almost without
# exception. Of the 246 reviewed override names, four match the shape and all four
# are matched by the override table first.
.looks_like_callsign <- function(x, cs_prefix) {
  ok <- !is.na(x) & nchar(x) %in% 4:7 &
    grepl("^[A-Z0-9]+$", x) & grepl("[A-Z]", x)
  ok & (substr(x, 1, 2) %in% cs_prefix | substr(x, 1, 1) %in% cs_prefix)
}

# MMSI number ranges are an international allocation, so a 9-digit id that parses
# as one *states* its own kind. ramb::rb_mmsi_category implements the ranges; this
# maps its wording onto the class vocabulary above.
.mmsi_entity_class <- function(x) {
  cat9 <- ramb::rb_mmsi_category(x)
  dplyr::case_when(
    cat9 == "vessel"                                       ~ "vessel",
    cat9 == "Child vessel"                                 ~ "child_vessel",
    cat9 == "Navigational aid"                             ~ "navaid",
    cat9 == "coast station"                                ~ "shore_station",
    cat9 == "SAR aircraft"                                 ~ "aircraft",
    cat9 %in% c("Search and Rescue Transponders",
                "Man overboard",
                "406 MHz EPIRBs fitted with an AIS transmitter",
                "Handheld VHF transceiver")                ~ "beacon",
    .default = NA_character_)
}

# A vessel's own identifier wearing a suffix is not the vessel. STK carries the
# auxiliary equipment too - net buoys above all - and it is registered under a made
# up id derived from the ship's: TFBC2 for TFBC, TFMS_2 for TFMS, 1516_2 for vid
# 1516, LAIJ8 for the Norwegian LAIJ. Maintainer, 2026-09-22: "pretty sure these are
# madeup and refer to buoy."
#
# Measured the same day, and the reason this matters: of 78 mobile-ids that a naive
# suffix-stripping match would have handed a vid, 42 were transmitting *while the
# vessel's own mobile-id was also transmitting*. Assigning them would have put a
# buoy's track on a ship that was somewhere else.
# Deliberately narrow: one optional separator and exactly one trailing digit, and
# the remainder must be an identifier the registry actually holds. Wider stripping
# turns V_2166 into V_216 and TFFM_2277 into TFFM_227, which is guesswork; those are
# left unclassified instead.
.looks_like_equipment <- function(x, known) {
  base <- sub("[_ -]?[0-9]$", "", x)
  sep  <- grepl("[_ -][0-9]$", x)          # 1516_2 - the separator does the work
  word <- grepl("[A-Za-z]", base)          # TFBC2  - a call sign, not a number
  # Without one of those two, the rule eats plain vids: 2800 strips to 280, which is
  # itself a registered vessel, and 2,151 mobile-ids on 96 M pings get called buoys.
  !is.na(x) & base != x & nchar(base) > 2 & (sep | word) &
    toupper(base) %in% toupper(known)
}

stk_entity_class <- function(loid, glid,
                             overrides = read_stk_overrides(),
                             cs_prefix = NULL,
                             known_ids = NULL) {
  stopifnot(length(loid) == length(glid))
  lo <- as.character(loid)
  gl <- as.character(glid)

  ov <- stats::setNames(overrides$entity_class, overrides$value)
  ov_gl <- unname(ov[gl])
  ov_lo <- unname(ov[lo])

  mm_gl <- .mmsi_entity_class(gl)
  mm_lo <- .mmsi_entity_class(lo)

  # Patterns, applied to both fields. Icelandic: dufl = buoy, bauja = buoy,
  # kvi = pen, rannsokn = research. The " P" / " B" / "-P" suffixes are how the
  # hand list writes its shore installations, so an unlisted name wearing one is
  # the same kind of thing.
  has <- function(re) grepl(re, gl, ignore.case = TRUE) | grepl(re, lo, ignore.case = TRUE)
  # "_net" plus the hyphen spelling, plus "_NE" left behind when STK truncates a
  # name to nine characters (OW2009_NE, OW2426_NE - six values, no false positives).
  p_net   <- has("[_-]net|[_-]ne$")
  p_kvi   <- has("^kvi|_kvi|sjokvi")
  p_inst  <- has("hafro|rannsokn")
  p_buoy  <- has("dufl|bauja")
  # Space or underscore only. A hyphen is how Norway and the Faroes write a
  # registration mark - N-400-B, SF-5-B - and six matched vessels were classed as
  # shore stations before that was excluded.
  p_shore <- has("ais$|^ais|_ais|ais_") | grepl("[ _][PB]$", gl) | grepl("[ _][PB]$", lo)
  p_cs <- if (is.null(cs_prefix)) rep(FALSE, length(gl)) else
    .looks_like_callsign(gl, cs_prefix) | .looks_like_callsign(lo, cs_prefix)
  p_equip <- if (is.null(known_ids)) rep(FALSE, length(gl)) else
    .looks_like_equipment(gl, known_ids)

  out <- dplyr::case_when(
    # A human looked at these, and that beats every rule below — including the two
    # Icelandic MMSIs the list carries because their number range lies about them.
    !is.na(ov_gl) ~ ov_gl,
    !is.na(ov_lo) ~ ov_lo,
    # The MMSI range is the thing declaring itself; glid first, it is the stronger
    # of the two fields.
    !is.na(mm_gl) & mm_gl != "vessel" ~ mm_gl,
    !is.na(mm_lo) & mm_lo != "vessel" ~ mm_lo,
    # Before every vessel rule: a derived id is the equipment, not the ship.
    p_equip ~ "buoy",
    p_net   ~ "net_relay",
    p_kvi   ~ "aquaculture",
    p_inst  ~ "institute",
    p_buoy  ~ "buoy",
    p_shore ~ "shore_station",
    !is.na(mm_gl) ~ mm_gl,     # vessel-range MMSI, stated outright
    !is.na(mm_lo) ~ mm_lo,
    p_cs    ~ "vessel",        # an allocated call sign, whether or not it matched
    .default = "unknown")

  basis <- dplyr::case_when(
    !is.na(ov_gl) | !is.na(ov_lo)     ~ "synthesised",
    !is.na(mm_gl) | !is.na(mm_lo)     ~ "recorded",
    out == "unknown"                  ~ NA_character_,
    .default = "reconstructed")

  data.frame(entity_class = out, basis = basis, stringsAsFactors = FALSE)
}
