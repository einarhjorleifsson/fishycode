# 096 — Port codes are not typed

*2026-10-14. The maintainer's decision. Recorded by Claude (AI-assisted). Closes TODO 3c.*

TODO 3c proposed a type on each source port code (`hid`): a place, a processing site, a country, or a sentinel
such as `300 Flutningaskip` or `900 Fiskistofa skráningar`, with a `pid` only where the code is a physical
harbour. The maintainer decided not to specify a type.

The crosswalk stays as decision 007 built it. `hid` is kept beside `pid` in every table, so the source's own code is
never lost.
