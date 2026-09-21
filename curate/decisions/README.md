# Decision records — index

Where work goes when it leaves `TODO.md`. That file holds only what is **not done
yet**; once an item is finished it is deleted from there and recorded here, or in
`../corrections/` if it is a data defect. Git history says *when*.

This index exists because the registry is otherwise only browsable by opening
every file, and because a deleted TODO item leaves no trace of having existed.

**Invariant:** every `.md` in this directory has a row here. Checkable:

```r
setdiff(list.files("curate/decisions", "^[0-9]+.*[.]md$"),
        stringr::str_match(readLines("curate/decisions/README.md"), "\\((\\d{3}-[^)]+)\\)")[,2])
```

| # | record | what it settles |
|---|---|---|
| 000 | [restructuring](000-restructuring.md) | why this repo supersedes `logbooks` and `fishydata_2024-2026`, and the two committed boundaries |
| 001 | [file migration](001-file-migration.tsv) | where every script from the two predecessors landed |
| 002 | [missing GEBCO raster](002-missing-gebco-raster.md) | `area_h3` cannot be rebuilt; the raster was a manual download since cleared |
| 003 | [undeclared dump inputs](003-undeclared-dump-inputs.md) | datasets named `year=YYYY` that were not partitioned |
| 004 | [issue 11, +70 rows](004-issue-11-seventy-extra-rows.md) | three harbours shared one polygon — a copy-pasted coordinate, not a join; measured at 21 AIS-era trips |
| 005 | [harbour geometry is a frozen input](005-harbour-geometry-is-a-frozen-input.md) | STK ships `harborid`, so deriving polygons from it and then using them to tag pings is a cycle; the artifact is frozen and the bootstrap kept as provenance |
| 006 | [absorb kaenugardr](006-absorb-kaenugardr.md) | why the port repo is merged in rather than consumed as an artifact, and what that costs |
| 007 | [hid maps to pid](007-hid-maps-to-pid.md) | `pid` is the standard harbour key across logbooks, landings and AIS; Icelandic `hid` maps onto it |

## Data defects

Not here — `../corrections/`, one `.yml` declaration per defect, paired with a
`.R` implementation where there is one. Each `.yml` carries `id`, `title`,
`status`, `applies_to`, a detection rule and the repair, so that directory is its
own index.

| defect | status |
|---|---|
| `adb_vs_fs_afladagbok` | open — depth units and longitude sign |
| `afli_coords` | parked — incumbent retained |
| `afli_depth_units` | open — fathoms to metres drift, 2010 to mid-2012 |
| `fs_veidiferd_year` | open — corrupt year on one date field |
| `ports_iceland` | fixed — shared polygon, undersized buffers |
