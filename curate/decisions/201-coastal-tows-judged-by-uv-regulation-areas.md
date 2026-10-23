# 201 — Coastal trawl tows are judged against the regulation areas in `uv`, dated by gear; the gillnet speed floor from recorded hauls

*2026-10-23. The maintainer's answer to TODO 34's ask (1) (plan 012) and to the gillnet speed floor decision 198 noted,
asked by Claude (AI) in a status review of the repository. Nothing is measured or built yet; the facts about `uv` below
were read the same day, read-only, from the dump.*

*Amended later the same day: the maintainer says proper shapefiles of the regulation areas and the shoreline will be
available soon. The layer is built from them when they come, not from `uv` now; `uv`'s dated areas may serve as the
history the shapefiles lack. The judgement of coastal tows and the gillnet floor stand as chosen below.*

## What `uv` holds in shapes (read the same day, read-only, at the maintainer's request)

- **A history, not the current rules:** 5,948 areas whose start dates run 1970-2020; none starts after 2020-09-15, so
  `uv` was kept to 2020. Mostly real-time closures (3,932, 1976-2020, all expired); 571 regulation areas and 224
  repealed ones, 172 protected areas, 98 Danish-seine areas, 31 lines named by their regulation numbers (2000-2019),
  and smaller sets (herring, capelin, nephrops and lumpfish areas, aquaculture sites, others).
- **For trawling:** 2,406 areas linked to a bottom, shrimp or nephrops trawl (1,705 closures, 148 protected areas, 317
  regulation areas, ...). 122 carry no end date, which cannot be trusted: 81 of them are typed repealed.
- **Geometry:** corner points only, no shoreline. Most areas have 4 corners (median 4, at most 38), rings not closed;
  45 areas have no points and 208 points are 0, 0. Coordinates are degrees, minutes and hundredths of a minute
  (650700 = 65° 07.00′ N): the last two digits pass 59 on 11-13 % of points, so they are not seconds. No stored Oracle
  code builds polygons from them.

So the shapefiles are needed for the current rules and the shoreline; `uv` can give the dated history for past tows,
the trawl closures above all, once its zero points and end dates are cleaned.

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
