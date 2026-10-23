# 189 — Plan 037's last asks answered: the never-loaded sent records staged, flagged and accounted; TODO 108, 113 and 114 folded into phase 2; decision 098 holds

*2026-10-23. The maintainer's answers to plan 037 §7 f, g and h, asked by Claude (AI) in a status review of the
repository. The counts below were measured by Claude the same day, read-only, on the store's `staging/afli_sent` of
2026-10-22 (decision 180); not yet checked by a person. Nothing was built.*

## f. The sent records Oracle never loaded

**The question, clarified for the maintainer:** these records are in the dump. They are in the messages table
`fs_afli.afladagb_xml_mottaka`, the XML as each app sent it (`raw/oracle/fs_afli/`). Oracle's loader turned the
messages into the `rafr_` tables and from there into `afli`; for these records it never did, most of them because it
could not read their record id or the receipt named no vessel (plan 037 §2.1). So they exist in the sent layer only.

**Measured:** 14,759 stations staged with `loaded = FALSE`, 168 vessels, 2001-2022 (most in 2008-2011 and 2014),
14,536 with catch, 142.8 kt as logged. 2,890 (31.7 kt) fall on a vessel-day the curated logbook already holds, likely
copies; about 11,650 (111 kt) on vessel-days it holds nothing, and 7,771 of all with catch have a landing by the same
vessel within 0-3 days: candidates for hauls that never reached Oracle's logbook. 10 carry a date in 2096-2099.

**Chosen:** the latest version of each sent record is staged, as built; the never-loaded ones keep the flag, stay out
of the logbook, and are each classed (a copy of a held haul, a missing haul, unexplained) before admission is decided
class by class. TODO 118 carries the account, beside the hauls Oracle loaded but never moved.

## g. TODO 108, 113 and 114 folded into phase 2

The sent record's positions, tow times, soak and closing times (108), afli's end depth (113) and the whole weight on
gutted catch (114) are phase 2's work. Their checks move into TODO 115, which closes them with that phase. The two
items paused for plan 037 (113, 114) are no longer parked items of their own.

## h. The other items of §8

Linked to plan 037's phases as they stand, not folded: each keeps its own check, and plan 038 §8 orders them.

## Decision 098 holds in phase 2

When phase 2 reads the sent layer into the logbook, the hauls Oracle loaded but never moved to `afli.stofn` (23,513,
and 3,182 deleted) are staged but not admitted until TODO 118 classes each one: decision 098's rule (not admitted,
since they overshoot the landing and are mostly resubmissions) stands unless a later decision overturns it on that
account. The audit of 2026-10-23 had found the sent layer would otherwise reverse it silently.

## Left

Every ask of plan 037 is answered. TODO 115 no longer waits on the maintainer: its next step is phase 1 (the precedence
table, the provenance column, consumers reading the whole weight by name), built and traced kilogram by kilogram as
plan 037 §6 says; the store builds remain the maintainer's go.
