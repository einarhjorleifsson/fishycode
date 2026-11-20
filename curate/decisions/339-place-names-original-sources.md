# 339 — Plan 067 revised: each place name with its original source(s), LMÍ a carrier; the registry and the heimild table in this repo

*2026-11-20. At the maintainer's word ("Yes, revise plan 067", then "Yes, in the repo"). Measured and written by Claude
(AI); no person has checked the counts.*

## What was asked

After decision 338's question on Orkustofnun's names (LMÍ's "Orkustofnun V201404005", ÍSOR's reports of 2008 behind it),
the maintainer: "This is all related to original sourcing. When we say LMÍ we could be more specific, because LMÍ is really
the "gathering point". Care to think a little here. Say this because I would in the end like that each Örnefni has the
original source(s) if at all possible. Which then also begs the quiestion if we are using some kind of a standard template
(yaml, ... whatever) of fields we report for each örnefni." And: "Or at miminum a data.frame".

## What was found

Measured by Claude (plan 067 §0.1): the names list links 22,311 of LMÍ's records, every one with a heimild (IS 50V's
`source_ref`), 4,396 strings; 8,932 records name only an LMÍ case number (`V201404005`, `L10060007`); about 2,300 are traced
to an original (the charts through the Coast Guard's delivery of 2014, LMÍ's general map by sheet and edition, Trackwell's
and Hafrannsóknastofnun's deliveries of 2020, ÍSOR's reports of 2008 through Orkustofnun's of 2014). IS 50V has no other
field naming a source. Three tables already pair a name with what a record says of it, each its own shape
(`marine_name_source`, the gazetteer's `evidence`, plan 081's proposal evidence).

## What was chosen

Plan 067, parked since decision 333, is revised and a proposal again (its §0): a carrier is not a source, and each
attestation records its chain (the original, the carriers, the record), `unknown` where the original is not known; a
registry of sources and of the deliveries that carried them; LMÍ's heimild resolved by a hand-kept table (`stated`,
`traced`, `unknown`); one generated table of attestations, a row per name and record (the data.frame); a name's YAML an
export only, from the tables. Sea names of plan 081's scope first. The draft's readings of text sources and the
gazetteer's place ids stand.

The registry and the heimild table live in this repo (plan 067 ask e, the maintainer: "Yes, in the repo"), holding only
what LMÍ and the sources publish: deliverers, case numbers, published works and their authors as citations. Collectors
and informants a heimild string names stay out of the repo (decision 130): the table keys such a string by its case
number, the string itself read from IS 50V.

## What is next

Ask f (the maintainer asks LMÍ for its register of case numbers, or the bare numbers stay `unknown`) and plan 067 §0.4's
steps: the registry, the heimild table, the attestations for plan 081's names. TODO 193.
