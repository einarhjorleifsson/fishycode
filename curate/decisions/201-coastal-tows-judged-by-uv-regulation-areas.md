# 201 — Coastal trawl tows are judged against the regulation areas in `uv`, dated by gear; the gillnet speed floor from recorded hauls

*2026-10-23. The maintainer's answer to TODO 34's ask (1) (plan 012) and to the gillnet speed floor decision 198 noted,
asked by Claude (AI) in a status review of the repository. Nothing is measured or built yet; the facts about `uv` below
were read the same day, read-only, from the dump.*

## Chosen

- **Small vessels may tow a fish trawl near the coast in places, by regulation.** A coastal tow is judged against the
  regulation areas valid that day for that gear: `expected` inside an area open to it, `suspect` inside a closed one,
  never a correction.
- **The areas come from `uv`, not a coastline stand-in.** `uv` (dumped, decisions 121, 122) holds 5,948 dated areas
  (`veidisvaedi`, `dags_fra`/`dags_til`) of 20-odd types (regulation areas, lines named by their regulation numbers,
  protected and spawning areas, real-time closures), each linked to gears in `veidisv_veidarf` (the bottom fish trawl
  among them) and drawn from 25,929 points in `hnit`. A read-only measurement comes first: what `uv` holds for bottom
  trawl by date and vessel class, a dated layer of where each gear may fish, the recorded tows scored against it. The
  same layer serves plan 012's step 5, the 12-mile limit. The 5 km stand-in retires when the layer exists.
- **The gillnet speed floor is set from recorded hauls.** The declared gillnet range starts at 0 kn, so a stopped
  gillnetter passes the voyage rule (decision 198). Its lower bound is set from the speeds of recorded gillnet hauls
  (such as their 5th percentile), with the share of hauls it would lose reported.
