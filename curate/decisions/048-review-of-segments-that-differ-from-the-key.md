# 048 - Review of the segments that differ from the key

*2026-09-29. The review asked for in plan 009 phase 3, done on evidence alone (the ODS is not a judge). Analysis by Claude (AI-assisted); each verdict is a rule applied identically to every segment, and the maintainer decides what enters the key.*

## Method

The segment table has 3060 segments; **118 differ from the current key** (2,280,776 pings, 1.3 % of all pings) or fill a mobile-id the key gave no vid. For each, in the segment's own window: how well the table's vid and the key's vid each match the mobile-id's STK pings (decision 045's method: the nearest-in-time ping of the vessel's own other-provider AIS, within 6 h, counted within 2 km; at least 100 matched pings needed), whether the registry lets each vid exist then, and what logbook and landings show. Rules: **accept** where the table's vid is confirmed by its own track and the key's vid is not; **read by hand** where both fit, or neither can be tested, or the table's vid fits only part; **reject** where only the key's vid fits; a registry or logbook assignment is accepted only where the key's vid did not exist then.

## Result

|verdict                                                                    | segments|   pings|
|:--------------------------------------------------------------------------|--------:|-------:|
|accept: the table's vid fits its track; the key's vid has no track to test |       22| 1098387|
|read by hand: the table's vid fits only partly                             |       11|  467299|
|flag: new match without a track or a dated holder                          |       15|  348048|
|accept (new match): the vid's own AIS track confirms it                    |        9|  108149|
|accept: the key's vid did not exist then (registry lifetime)               |        8|  104624|
|read by hand: no track, and both vids existed                              |        5|   71548|
|REJECT: the key's vid fits its track, the table's does not                 |        1|   54498|
|flag: no evidence of its own, borrowed from a neighbour - a person decides |       13|   27444|
|accept (new match): dated registry/logbook holder, no AIS to check         |       34|     779|

## Accepted where the key names another vid (track confirms, or the key vid did not exist then)

|    mid| key vid| table vid|from       |to         |  pings|source   |track fit, table vid |track fit, key vid |
|------:|-------:|---------:|:----------|:----------|------:|:--------|:--------------------|:------------------|
| 101759|    1473|      2815|2011-07-22 |2024-12-20 | 216954|physical |99%                  |-                  |
| 101439|    2227|      2904|2007-06-01 |end        | 210009|physical |100%                 |-                  |
| 103094|    2727|      2941|2019-06-08 |end        | 184667|physical |99%                  |-                  |
| 103749|    2523|      2946|2017-06-21 |end        | 166814|physical |99%                  |-                  |
| 101100|    2770|      3036|2023-05-10 |end        |  92541|registry |-                    |-                  |
| 101084|    2903|      2212|2022-07-11 |end        |  86490|physical |94%                  |-                  |
| 100290|    1359|      2914|2007-06-12 |end        |  84501|physical |100%                 |-                  |
| 111702|    2870|      3038|2021-11-01 |end        |  31721|physical |90%                  |-                  |
| 101081|    2067|      2937|2017-02-28 |2022-10-31 |  30116|physical |89%                  |-                  |
| 100739|    1371|      3010|2022-09-16 |end        |  15481|physical |99%                  |-                  |
| 101049|    1585|      3060|2025-05-26 |end        |  13885|physical |93%                  |-                  |
| 100099|    1402|      2980|2019-06-07 |end        |  11127|physical |98%                  |-                  |
| 101350|    2197|      2916|2016-05-23 |end        |   8740|registry |87%                  |-                  |
| 100170|     120|      3034|2023-02-11 |end        |   8485|physical |100%                 |-                  |
| 100111|    1195|      2975|2019-06-13 |2023-03-06 |   6772|physical |99%                  |-                  |
| 122712|    2923|      3042|2024-04-10 |end        |   6147|physical |99%                  |-                  |
| 101059|    2862|      7819|2017-08-19 |end        |   4821|registry |36%                  |-                  |
| 100170|     120|      2928|2017-01-07 |2023-02-10 |   3841|physical |99%                  |-                  |
| 101146|     168|      2664|2016-05-12 |end        |   3508|physical |96%                  |-                  |
| 101016|    1063|      3057|2025-06-18 |end        |   3455|registry |-                    |-                  |
| 100602|    7070|      1827|2024-05-21 |end        |   3405|logbook  |7%                   |37%                |
| 100111|    1195|      3024|2023-03-07 |end        |   2867|physical |92%                  |-                  |
| 100645|    2188|      3049|2024-09-04 |end        |   2424|physical |98%                  |-                  |
| 101334|    2889|      3055|2025-05-18 |end        |   1969|registry |93%                  |-                  |
| 100645|    2188|      2593|2016-08-01 |2024-09-03 |   1659|physical |99%                  |-                  |
| 103284|    2964|       151|2007-06-15 |2014-10-23 |    392|registry |-                    |-                  |
| 100263|    1159|      2798|2016-07-20 |2020-08-31 |    210|registry |100%                 |-                  |
| 100656|    2949|      1170|2007-07-08 |2015-03-20 |      6|registry |-                    |-                  |
| 100606|    2909|      1264|2010-01-12 |2011-07-05 |      3|registry |-                    |-                  |
| 101081|    2067|      3045|2014-05-03 |2017-02-27 |      1|registry |-                    |-                  |

A further 43 new matches (108,928 pings) give a vid to a mobile-id the key left empty and are accepted: nine on a track, the rest on a dated registry or logbook holder; they are tiny (mostly a few pings).

## For a person: read by hand, and the one rejection

|    mid| key vid| table vid|from       |to         |  pings|source   |track fit, table vid |track fit, key vid |
|------:|-------:|---------:|:----------|:----------|------:|:--------|:--------------------|:------------------|
| 103750|    2022|      2487|2011-07-11 |2019-04-30 |  54498|physical |2%                   |95%                |
| 102182|    6806|      6712|2007-06-01 |2023-07-20 |  30847|logbook  |-                    |29%                |
| 124654|    7804|      7316|2021-05-11 |end        |  23735|logbook  |29%                  |-                  |
| 100831|    6192|      6147|2022-04-04 |end        |  14086|logbook  |4%                   |53%                |
| 100416|    6116|      6072|2015-03-13 |2018-07-16 |   2860|logbook  |12%                  |42%                |
| 101014|    1023|      3003|2007-06-01 |end        |     20|registry |-                    |-                  |
| 100137|    2847|      1136|2007-06-01 |2013-10-31 | 145697|physical |32%                  |-                  |
| 101967|    2892|      2730|2007-06-01 |2017-03-27 | 102015|physical |19%                  |-                  |
| 103072|    2219|      2943|2018-10-18 |end        |  82578|physical |54%                  |-                  |
| 101280|    1849|      1985|2007-06-06 |2016-12-31 |  70350|physical |44%                  |55%                |
| 100010|     472|      2328|2018-06-21 |end        |  23051|physical |63%                  |-                  |
| 103007|    2699|      2110|2021-01-12 |end        |  16652|physical |61%                  |-                  |
| 112543|    3857|      2730|2021-02-05 |end        |  12036|physical |73%                  |-                  |
| 139705|    7850|      3025|2020-10-19 |end        |   4919|physical |50%                  |47%                |
| 101779|    2842|      2593|2007-06-03 |2017-03-31 |   3979|physical |72%                  |-                  |
| 100645|    2188|      2310|2008-01-21 |2016-07-31 |   3072|physical |67%                  |-                  |
| 143852|    1511|      1500|2024-12-01 |end        |   2950|physical |47%                  |-                  |

## Flagged: no evidence of its own

|    mid| key vid| table vid|from       |to         |  pings|source    |track fit, table vid |track fit, key vid |
|------:|-------:|---------:|:----------|:----------|------:|:---------|:--------------------|:------------------|
| 101078|      NA|      2549|2007-06-01 |2016-04-25 | 180676|physical  |25%                  |-                  |
| 101763|      NA|      2500|2007-06-07 |end        |  57915|physical  |31%                  |-                  |
| 100512|      NA|      1599|2007-06-27 |end        |  47278|physical  |19%                  |-                  |
| 103173|    2549|      2500|2007-11-22 |2016-10-25 |  15842|neighbour |-                    |27%                |
| 150520|      NA|      2457|2024-09-27 |end        |  12744|physical  |54%                  |-                  |
| 117324|      NA|      2726|2015-03-31 |end        |  10325|physical  |67%                  |-                  |
| 119842|      NA|      2710|2015-09-11 |end        |   8743|physical  |45%                  |-                  |
| 101223|     971|      2718|2007-06-01 |2017-09-06 |   8219|neighbour |-                    |-                  |
| 140620|      NA|      2500|2021-02-22 |end        |   7464|physical  |43%                  |-                  |
| 117104|      NA|      2726|2015-03-17 |end        |   7010|physical  |73%                  |-                  |
| 131663|      NA|      2726|2018-11-19 |end        |   6442|physical  |63%                  |-                  |
| 128996|      NA|      2726|2018-04-01 |2018-10-31 |   3770|physical  |64%                  |-                  |
| 103934|    2724|      2962|2007-06-01 |2019-09-01 |   2089|neighbour |-                    |-                  |
| 121684|      NA|      1932|2016-03-31 |end        |   1284|physical  |60%                  |-                  |
| 121685|      NA|      1932|2016-03-31 |end        |   1257|physical  |48%                  |-                  |
| 128996|      NA|      2499|2017-11-25 |2018-03-31 |   1186|physical  |58%                  |-                  |
| 128996|      NA|      7386|2019-03-01 |end        |   1027|physical  |55%                  |-                  |
| 128996|      NA|      2499|2018-11-01 |2019-02-28 |    927|physical  |69%                  |-                  |
| 101015|    1052|      3031|2007-08-22 |2022-08-24 |    463|neighbour |-                    |-                  |
| 101025|     127|      3044|2007-06-01 |2024-02-07 |    396|neighbour |-                    |-                  |
| 101103|    1273|      2954|2007-10-15 |2019-07-11 |    391|neighbour |-                    |-                  |
| 100652|    3013|      1204|2019-08-31 |2021-07-22 |     30|neighbour |-                    |-                  |
| 100343|    2992|      1014|2017-09-11 |2021-10-26 |      5|neighbour |-                    |-                  |
| 100163|    2967|      1639|2016-03-15 |2018-05-23 |      4|neighbour |-                    |-                  |
| 103251|    1441|      2948|2012-01-26 |2017-09-06 |      2|neighbour |-                    |-                  |
| 100881|      NA|      2887|2009-02-01 |2014-10-09 |      1|neighbour |-                    |-                  |
| 101089|    2907|      1012|2011-08-23 |2015-12-16 |      1|neighbour |-                    |-                  |
| 103067|    2936|       962|2013-02-07 |2017-06-10 |      1|neighbour |-                    |-                  |

## The systematic finding: evidence over a stretch is being extended over the whole segment

Twelve of the segments above (the 11 "fits only partly" and the rejected mid 103750) have the same shape: the physical witness names a vid for a few months, and the table gives that vid to the whole, often years-long, segment, so the vid's track fits only the part the evidence covers. Mid 100137 gets vid 1136 for 2007-06 to 2013-10 (145,697 pings) on 2013 evidence alone, and its track fits 32 % of the segment; mid 103750 gets vid 2487 for 2011-2019 on six months of 2018-19 evidence, and the key's vid 2022 fits 95 % of it. The honest handling is to give the evidence its own stretch and let the remainder fall back on the key or on continuity. **Proposed fix, not done:** when the evidence covers under half of a long segment, cut the segment at the edge of the evidence and give the unverified remainder the key's vid (or flag it). Until then these 12 segments (about 0.6 M pings) are read by hand, and the accepted rows above are those where the track fits.

## What the maintainer decides

1. Accept the confirmed rows above into the segment table as they stand (they already are).
2. Read the hand and flagged rows; the review app can show them.
3. Decide whether to make the evidence-extent fix before the table replaces the key in `ais_key.R`.
