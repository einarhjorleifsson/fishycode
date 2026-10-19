# Reading map: shared instructions

Read one ICES report, or one part of one, and write a structured reading map. Work in four steps:
1. Read this file.
2. Read the input file once, whole: one Read call with `allow_large: true`.
3. Write the YAML once, in a single Write call.
4. Reply in at most three lines.

Do not re-read pages, check your work, or read any other file; the parent checks the rows. Do not use the web. Keep
your thinking short: the file you write is the work.

## Context
A book for the members of ICES WGSFD and WKSSFGEO consolidates the groups' thinking on fishing effort and catch from
vessel tracks (VMS, AIS) and records (logbooks, landings), with an R package (ramb) as the code. Its centre is a flow
diagram with eight rows: vessel, ping, trip, record, gear, fishing, effort, catch. Each row has boxes, which are its
sources, best first. The map decides the book's chapters and cites the reports by page. Report what the report says;
do not judge it.

## Input text
- Each page opens with `===== PDF page N · printed page P =====`.
- Padding, contents lines, numeric table bodies, reference lists and participant lists are removed. Table captions
  remain.
- If the input is one part of a report, fill `report` only with what that part shows, and leave the rest as "". Rows
  cover only that part; the parts are merged afterwards.

## Output structure
Put every string in double quotes, escaping inner quotes, so the file parses.

```yaml
report:
  id: "<given>"
  file: "<given>"
  part: "<given, e.g. \"1 of 2, PDF pages 1-72\", or \"whole\">"
  title: "..."
  series: "as printed, e.g. \"ICES Scientific Reports 1:53\""
  year: 0000
  meeting: "dates and place, as printed"
  set_out_to_do: "2-3 sentences"
  terms_of_reference:
    - {id: "a", summary: "one sentence", pages: "..."}
  data_call: {summary: "the ICES VMS and logbook data call as described here, or \"not described\"", pages: "..."}
  outputs:
    - {summary: "one sentence", pages: "..."}
topics:
  - topic: "2-6 words, the report's own terms"
    step: "vessel | ping | trip | record | gear | fishing | effort | catch | none"
    box: "for a row with a step: a diagram box (list below), or \"other\"; for step none: \"\""
    theme: "from the list below, or a new short lowercase label"
    kind: "method | definition | finding | recommendation | request | data-call | product | plan | decision | context"
    pages: "printed page(s), e.g. \"12\" or \"12-14\""
    pdf_pages: "PDF index(es) from the same markers"
    summary: "ONE sentence, in your own words"
    terms: ["the report's own words, each a word or short phrase"]
code:
  - name: "as named in the report"
    what: "package | script | function | algorithm | workflow | format | service"
    language: "R | Python | SQL | other | not stated"
    where: "repository or URL as printed, or \"not given\""
    does: "one sentence"
    formats: ["data formats it reads or writes, e.g. EFLALO, TACSAT"]
    limits: "computing or storage limits the report mentions, or \"\""
    pages: "..."
    pdf_pages: "..."
vocabulary:
  - {term: "verbatim", meaning: "paraphrased", pages: "..."}
notes: "anything the structure could not hold"
```

## Diagram boxes, by row
- vessel: "own track / feeds agree", "register / dated MMSI", "logbook or landing", "continuity / same device"
- ping: "invalid", "placeholder", "duplicate", "second feed", "impossible", "port"
- trip: "declared trip", "voyage from port stays", "link and reconcile"
- record: "haul with t1-t4", "haul with positions", "period x area", "trip as one record", "two-way"
- gear: "logbook record", "landing declaration", "licence / gear register", "predicted from the track"
- fishing: "haul window", "phases (dense track)", "track model", "speed range of the gear"
- effort: "pressure (gear size)", "kW-hours", "hours"
- catch: "haul", "period x area", "trip or landing", "several trips / weekly landing"

## Themes to reuse
Coin a new short lowercase label only when none fits.
- high-resolution data
- uncertainty
- workflow and code
- data coverage
- data quality of submissions
- small-scale fisheries
- data access and governance
- logbooks and electronic reporting
- data call
- seabed pressure and impact
- ais
- computing and storage
- ports and harbours
- products and users
- gear and activity classification
- c-squares and gridding
- group organisation
- marine spatial planning
- track gaps
- recommendations to ICES

## Kinds
- method: a way of doing something
- definition: what a term or quantity means
- finding: something measured or observed
- recommendation: what the group recommends
- request: received from others, or made of them
- data-call: describes or changes the data call
- product: an output
- plan: intended work
- decision: something the group decided
- context: background, priority, linkages

## Rules
- Paraphrase. Never take 8 words in a row from the text. Verbatim text appears only as terms.
- No personal names or e-mail addresses. Author-year citations of papers are fine.
- One row per distinct topic at each place it is treated. When the executive summary and the main text both treat a
  topic, cite the main text.
- Cover the whole input, annexes included.
- `code`: every piece of code, software, data format or computing service the report describes, uses or asks for,
  one row each.
- `vocabulary`: at most 25 entries, the terms a reader new to the group most needs.
- Pages come from the markers.

## Reply
At most three lines: the output path, and the counts of topic rows, code rows and vocabulary entries.
