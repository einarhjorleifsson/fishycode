# 186 — ramb's pkgdown reference index lists the twelve new names of decision 147 (TODO 91 closed)

*2026-10-23. Claude's status review of the day picked this as a quick win, and the maintainer asked for it to be
started. The edit, the checks and this record are by Claude (AI-assisted) and have not been checked by a person. ramb is
committed at 8a0ae92 and pushed to GitHub the same day on the maintainer's word ("yes, push ramb"). Nothing in
fishycode's code changed, and nothing needs rebuilding. Closes TODO 91, plan 032's last open end (decisions 147, 149).*

## Found

- ramb's `_pkgdown.yml` reference index still listed the twelve old names of decision 147, and none of the new ones.
  The old names are exported warning aliases documented on one internal page (`ramb-renamed`, `@keywords internal`),
  so pkgdown does not require them in the index. The twelve new topics were missing, and `pkgdown::check_pkgdown()`
  stopped on them ("12 topics missing from index").
- The articles session that TODO 91 waited on had already committed its work (ramb 76359c0), and ramb's tree was clean.
  The patch once named in the TODO was not on disk. `.rb_renamed_from` in ramb's `R/renamed.R` is the map from old to
  new names.

## Done

- In `_pkgdown.yml`, each old name was replaced in place by its new name from `.rb_renamed_from`, so each keeps its
  section and order:
  - step 1: `rb_create_port_calls`, `rb_create_voyages`, `rb_add_voyages` and `rb_add_logbook_trip`;
  - step 2: `rb_create_record_windows`, `rb_create_record_stretches`, `rb_add_record` and `rb_create_record_pings`;
  - steps 4-6: `rb_add_fishing`, `rb_add_effort` and `rb_add_catch_units`;
  - the tools: `rb_add_timestamp`.
- The internal page of old names stays out of the index, as before. Only `_pkgdown.yml` changed. NEWS.md has no
  bullet, because the package itself is unchanged; the articles' commit 76359c0 set that precedent.

## Checked (by Claude, pkgdown 2.2.1, ramb at 8a0ae92)

- `pkgdown::check_pkgdown()`: no problems found.
- All 77 exports in `NAMESPACE` have a help topic:
  - the 65 not on the internal page are each listed in the index by name, including `rb_add_trip_time()`
    (2026.10.22.1), which was already there;
  - the 12 on the internal page are the old aliases.

  No name is listed twice, and the index lists no name that is not a topic.
- `pkgdown::build_site()` builds: 88 reference pages, and each of the twelve new names is linked once from the
  reference index. The examples' run reports 12 warnings near `rb_calc_duration`. They were not traced: no example
  changed.
- The built site is not tracked. ramb's `.gitignore` holds `docs/`, and its `AGENTS.md` says the site's output is not
  committed. The site's address is `heima.hafro.is/~einarhj/ramb` (`_pkgdown.yml`); publishing it was not part of this.

## Open

- **The published site** shows the new index once it is rebuilt from 8a0ae92 and published.
- The aliases and their internal page are removed at ramb's next release, under its rule of one release of aliases. That
  is not part of this decision.
