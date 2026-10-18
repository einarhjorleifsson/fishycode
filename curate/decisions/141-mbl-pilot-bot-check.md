# 141 — The mbl pilot: the vessel pages sit behind a bot check; the 2022 images are still served by their id

*2026-10-18. The pilot of plan 030 step 2, run on the maintainer's go ("Go for the mbl pilot: run dump/vessels/mbl.R
with DRY_RUN <- FALSE on vids 78, 1977, 2184, 2757 and 9810"); run, diagnosis and this record by Claude
(AI-assisted).*

## Found

- **Every page refused.** `dump/vessels/mbl.R` asked for the pages of vids 78, 1977, 2184, 2757 and 9810, 4 s apart,
  and got none. One `curl` request for vid 1977's page shows why: HTTP 403 from Cloudflare, with
  `cf-mitigated: challenge`. mbl.is now asks a script to pass a bot check, which it did not in 2022.
  - The check was not passed, and will not be: getting past bot detection is not done here.
  - So what the pages hold today (their fields, the number of images in a gallery, any caption or credit) is unknown.
- **The images are still served.** Three photos the 2022 logs record and the folder lacks (vids 1039, 1043 and 1047)
  answer HTTP 200, `image/jpeg`, from `static.mbl.is/generic/sax/skipamyndir/<id>.jpg`. Each has exactly the byte
  count the 2022 log gives, and there is no bot check on that host. Only headers were requested.
- **The pilot's output** is `raw/external/mbl/2026-10-18/`: `pages.csv` with the five failures, and empty `html/` and
  `jpg/`. It is kept as the pilot's record.

## Changed

`dump/vessels/mbl.R`:
- it records a page's HTTP status in `pages.csv` ("HTTP 403, bot check"), where the first version recorded
  "cannot open the connection";
- a run stops after `MAX_FAILS` (10) pages in a row fail other than by 404. Without the stop, a whole run would have
  spent about 11 hours failing page after page.

Checked offline, with the network stubbed:
- a dry run sends nothing;
- the loop, the manifests and resume work;
- twenty 404s in a row do not stop a run, and three bot checks in a row do (`MAX_FAILS = 3`).

## What it means for plan 030

- **A new scrape of the register is closed** while the bot check stands. New vessels and newer photos since 2022
  cannot be found by a script.
- **The rest of the 2022 photo set can most likely be fetched again.** The logs give the image id of all 2,120
  downloads, the 1,589 missing from `raw/external/skipaskra/jpg/` among them (about 370 MB at the logged sizes). Each
  could be fetched by its URL into that folder under its 2022 name, and its byte count checked against the log. The
  index (`mbl_photo`) would then grow on its next build.
- **That is the maintainer's call** (plan 030 ask b, as revised).
  - It is about 1,600 requests to mbl's image host.
  - mbl has put a bot check on its pages, which signals that it does not want automated access to the site, even
    though the image host has none.
  - Asking Morgunblaðið first is an option.
