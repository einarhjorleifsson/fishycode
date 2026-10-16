# 110 — Two registration numbers in the landings are divers, not vessels

*2026-10-16. Written by Claude (AI-assisted); the identification of 8009 is the maintainer's, from the public ship
register on mbl.is. Found while checking which vessels agf's views drop (decision 109's server dumps). TODO 67.*

## What was found

Two registration numbers in `agf.aflagrunnur` land with gear 23, "Kafari" (diver), and are in neither MFRI's vessel
registry (the `vessel` schema, matched on `registration_no`) nor `curated/vessel/vessel.parquet`:

| number | landings | catch | period | gear |
|---|---|---|---|---|
| 8009 | 13 | 1.9 t: sea urchins 666 kg, scallops 586 kg, ocean quahog 494 kg, blue mussels 119 kg | 2025-05-13 to 2025-09-01 | all "Kafari" |
| 8008 | 142 | 11.7 t: scallops 11.4 t, sea urchins 343 kg | 2017-05-23 to 2022-04-19 | 140 "Kafari"; 2 "Annað – Hvað" (other) with no weight |

- **8009 is a diver.** The public register (mbl.is, `skipaskra/skip/8009`) lists it in útgerðarflokkur "Kafarar"
  (divers), ÍS 0, "Tegund ekki á skrá, aldur óþekktur" (no vessel type, age unknown); the name field holds a
  person's name. A diver gets a registration number so that the landings can be recorded.
- **8008 is very likely one too:** all its catch is landed as "Kafari", and the register has no page for it (not
  found), so it is probably no longer registered. Not confirmed.
- fishycode's curated landings carry both as `vid`: 8008 on 139 landing rows, 8009 on 13.

Gear 23 also appears on ten registered vessels, one landing each with almost no weight (a support boat on a dive, or
a miscoded gear), and on the landings' placeholder `-100` (2 landings, 52 t, 2020-2022). The two neighbouring numbers
suggest the register keeps a series for divers near 8000; only these two were seen.

## What it means

A diver's registration is a person, not a hull: there is no AIS track to find and no vessel row to expect. It is
right that neither vessel registry holds them. In fishycode their landings, about 14 t, have a `vid` with no vessel,
so a check that looks for vessels that land but are never heard on AIS (`curate/checks/ais_key_landings.R`,
`landed_but_no_ais`; TODO 24) would count them as missed vessels unless they are told apart.

Nothing marks them yet (TODO 67).

## Why it surfaced

agf's views `aflagrunnur_v` and `aflagrunnur_v2` look vessels up in the Directorate's UFS tables, which stopped
growing after the 2020 split, and drop the landings of every vessel they do not know: 121 numbers in all. Of those,
MFRI's own registry knows 118 by registration number (its `vessel_id` is an internal key, never the registration
number). The three it lacks are the landings' placeholders `-15` and `-401`, and 8009.
