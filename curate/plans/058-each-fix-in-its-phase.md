# 058 — Each fix in its phase: a hidden semi-Markov model over each gear's A to J sequence, with the models already tried as its parts, fast enough for the whole trail

**status:** executed — written 2026-10-31 at the maintainer's request; its steps run the same day as a study in a
session of their own (`$FISHYDATA/archive/2026-11-01-phase-model/`); asks a-f (§6) answered by decision 270; nothing
built in the flow, which stays plan 057's (TODO 72) · **2026-10-31** · **see:** decision 270, plan 057 (§3.7 and ask k, which this
plan works out), plan 013 items 9 and 10 (TODO 72), decisions 078, 103, 148 and 232, `docs/flow_fishing.qmd`,
`docs/grammar.qmd` (the A to J protocol), fishymodel (`~/R/Pakkar/fishymodel`: `fm_gaussian()`, the binary clustering,
the step and step-and-turn HMMs)

Drafted with AI assistance (Claude) on 2026-10-31. The direction, a hidden-state model with the A to J sequence as its
guide, the weight on speed of execution, and the question whether the models tried so far have variants that join them
"all in one", are the maintainer's. The search and the design are Claude's. No person has checked them.

**Measured** (by Claude, 2026-10-31): the 2019 trail holds 52.3 M fixes (the whole trail 580.6 M); the packages at hand
(`moveHMM`, `EMbC` and `TMB` installed; `LaMa`, `hmmTMB`, `mhsmm`, `momentuHMM`, `depmixS4` not); the numbers quoted
from plan 057's scoping and the stacked profiles (the study `$FISHYDATA/archive/2026-10-31-tow-scoping/`).
**Assumed:**
- that the literature says what its abstracts and package pages say: §1 was read from search results, not from the
  papers in full;
- that one model per gear and length class holds across vessels, which step 4 measures.

## 0. Where this stands

- **The direction** (the maintainer, 2026-10-31), on plan 057 §3.7: "now on the hidden state model - that is where I
  thought we were heading with this ... but then you have to think about speed of execution here. and then also if the
  models that were explored before - are there variants of those, so kind of state-space and fancy xxxx (whatever the
  model) all in one."
- **What was tried:**
  - in plan 057's scoping (2023 survey tows, 4-min fixes): a speed rule, a Gaussian mixture, a pooled 4-state HMM
    (`moveHMM`) and a self-organizing map. The map on speed, its spread and the turn placed both ends of a survey tow
    within 10 min for 71 %. The HMM placed them for 1 %: one of its states, towing speed with erratic turning,
    swallowed whole runs of tows. Its fit took about 5 ms a fix, about 48 h for a year;
  - in fishymodel: the mixture, the binary clustering (EMbC) and two HMMs, benched in decision 103 on speed alone.
    Their HMM functions want equally spaced fixes.
- **What the stacks give** (the report for an MFRI colleague, the study's `report/`): each gear's sequence of phases,
  their speeds, turning and lengths, by length class. In 2019 (fixes every 2.3 min) the logged times agree with the
  track within a minute or two for:
  - the bottom trawls' D and E;
  - the static gears' E and I.

  They disagree in four places:
  - the purse seine's `t1`;
  - the Danish seine's `t2`;
  - the small gillnetters' `t1`;
  - the midwater trawl, at both times.
- **Ground truth:** Hafriti's D and E on the survey tows (2019, and 2026 at 2.3 min). The commercial logged times are
  ground truth where the stack shows them right. Decision 078's labelled pot data (one vessel at 60 s: setting,
  hauling, not fishing) add a set and a haul.

## 1. One model, the others as its parts

The models tried so far are not rivals of a hidden-state model: each can be one of its layers.

- **The sequence layer:** which phase follows which, and for how long. The gear's A to J table gives the order: a
  left-to-right chain with a loop from J to the next A, per gear. Each refinement is a known extension:
  - durations made explicit: a hidden semi-Markov model, which Joo et al. (2013) found the best of the sequential and
    discriminative models on observed Peruvian purse seine trips;
  - time between fixes taken as it comes: a continuous-time chain, the transition over a gap of `dt` = exp(Q dt), so
    no resampling. The fishymodel and Irish HMMs resample or drop irregular trips (decision 078);
  - transitions depending on covariates (gear, length class, time of day, depth);
  - a level above: trip, ground, station, phase, as a hierarchical model, if the commercial tows' back-to-back sequence
    needs it.
- **The emission layer:** what a fix looks like in each phase. The alternatives, each one of the earlier models:
  - parametric: speed (gamma) and turn (von Mises), as `moveHMM` and fishymodel's HMMs;
  - a mixture per phase: the Gaussian mixture as the emission (GMM-HMM);
  - the self-organizing map's node as a discrete observation: the map makes the vocabulary and the chain reads it in
    order. A SOM followed by an HMM on movement tracks has been done (zebrafish, 2011);
  - a classifier's per-fix phase probability, divided by the phase's prior, as a scaled likelihood: the hybrid HMM and
    neural network of speech recognition (Bourlard and Morgan, 1994), proposed for fishing by Joo et al. (2013) and
    built for animals as an HMM with an LSTM;
  - EMbC's binary partitions (speed high or low, turn high or low) as a four-letter observation.
- **The observation layer (state-space):** the fix is not the vessel.
  - **First, a robust emission:** single fixes at 7 to 10 kn in mid-tow come from mixed feeds (the eight single tows
    of the 2026 survey show them). A robust emission, a mixture with an outlier part, or an error state, is the cheap
    answer.
  - **Only if that fails, a full state-space model:** a continuous-time switching movement model with position error,
    as `aniMotum` fits for animals.
- **The logbook layer:** a logged time is an observation of its transition, with an error model by gear and period:
  tight where the stack agrees, wide where it does not, absent where nothing is logged (plan 057 §3.7). The flow's
  windows then come out of the same model as the phases.
- **Discriminative sequence models** are comparators, not the main line: a conditional random field, or CNN and LSTM
  networks as Global Fishing Watch uses (one model for fishing, one for a longline's set, haul and transit). They need
  labels, which the logged times can give; they are opaque and need a GPU stack we do not run.

## 2. Speed of execution

**The budget** (plan 057 §5): the whole trail (580.6 M fixes) in under an hour, a year (2019: 52.3 M) in minutes.

**Fit once, apply everywhere.** Parameters are estimated once per gear and length class, on a sample of 1 to 5 M fixes,
or set from the stacked profiles. That costs minutes, and is redone only when the method changes. Applying them is one
forward-backward pass per vessel-year:
- its cost is the number of fixes times the transitions per fix;
- a semi-Markov chain written as an expanded HMM (Langrock and Zucchini, 2011) has a few dozen states per gear, but a
  sparse transition matrix, so a fix costs some hundred operations;
- in compiled code that is about 10^8 fixes per core-minute, in parallel over vessel-years.

The pooled HMM's 5 ms a fix was its fitting (`moveHMM`'s numerical optimisation over all the data), not its
application.

**The pipeline:**
1. features per fix in DuckDB, lazily (plan 057 §3.1);
2. the forward-backward in compiled code, per vessel-year;
3. the phases and their probabilities written back as parquet.

**Software:**
- `LaMa` (CRAN, Koslik): the forward algorithm in C++, with hidden semi-Markov, continuous-time and state-space
  variants and an `RTMB` link, said to be 10-20 times faster than plain numerical estimation;
- `hmmTMB` (CRAN, Michelot): flexible emissions and covariates on TMB, semi-Markov through constraints;
- `momentuHMM`: flexible, but wants regular steps;
- `mhsmm`: semi-Markov in C.

The outside-methods rule (decision 234) holds: a package for fitting, pointed to. The apply step is recoded in ramb
only if a package cannot apply fixed parameters at the budget, measured as a ratio (fresh process, a warm-up, three
repeats).

## 3. Ground truth and scoring

**Ground truth:**
- the survey's D and E (2019 and the 2026 spring survey);
- 2019's commercial bottom-trawl D and E (`t3` = `t2` + the logged duration, sharp in the stack);
- the static gears' E and I;
- decision 078's pot labels.

**Each model layer is scored on:**
- both ends within 2, 5 and 10 min;
- the calibration of its intervals: of the 90 % intervals, the share that hold the recorded time;
- per-fix agreement with the phases the logged times fix;
- time per million fixes.

Every station is placed in one outcome, the unjudgeable included (decision 155's accounting). An agreement rate is a
score, never a pass.

## 4. Steps

A read-only study, `$FISHYDATA/archive/2026-11-01-phase-model/`, in a session of its own. Packages go into a scratch
library, never the user's.

1. **Inventory.** Read fishymodel's track models and decision 078's material: the Irish HMM practice and the pot
   labels. Install `LaMa`, `hmmTMB` and `mhsmm` in the scratch library; note what each takes (irregular time, fixed
   parameters, semi-Markov) and what each costs on 1 M fixes.
2. **Data.** 2019 bottom trawl, groundfish (`OTB_DEF`, the three length classes) and the 2019 and 2026 surveys; features
   per fix as the study's script 08 makes them (speed, turn, `dt`, the speed's spread).
3. **Baselines, scored and timed:** the speed rule, plan 057's map (method E) with its runs, and fishymodel's
   step-and-turn HMM.
4. **The sequence model, layer by layer**, each scored and timed. A layer is kept only if it gains:
   - (a) a left-to-right HMM, parametric emissions;
   - (b) durations (semi-Markov, expanded states);
   - (c) continuous time over the irregular `dt`;
   - (d) emissions from the mixture, then from the map's nodes;
   - (e) an outlier part for the mixed feeds' fixes;
   - (f) the logbook as evidence.
5. **Speed at scale.** The kept model's apply step on all of 2019, timed, and extrapolated to the trail. If it is over
   budget, a compiled forward-backward, its gain measured as a ratio.
6. **A second gear:** the longline, whose sequence opens A to J twice (set, soak elsewhere, haul), to test that the
   topology carries over.
7. **A decision record:** what was kept and why, with the answer to plan 057's ask k.

## 5. What it does not do

It builds nothing in the flow, writes nothing under `curated/` and commits no data. It ranks no package by reputation:
by measure only. It does not take on the CNN or LSTM line unless the sequence model plateaus well short of the survey.

## 6. Asks

Answered by decision 270 (2026-10-31): a as recommended, the apply step a thin ramb step around LaMa if it becomes a
flow step; b LaMa adopted, hmmTMB and mhsmm not; c, d, e and f as recommended, the longline left until a feature tells
hauling from lying. The study also found that the states wanted are the target and its look-alikes, not the letters
A to J (the maintainer, during the study), and that the feeds' clocks must be tested before a speed or turn is derived
(TODO 178).

| | Ask | Recommendation |
|---|---|---|
| a | Where the model lives | prototyped in the study; fitting in fishymodel, beside its HMMs; the apply step in ramb only if it becomes a flow step |
| b | Packages from CRAN in a scratch library (`LaMa`, `hmmTMB`, `mhsmm`) | yes, for the study; adoption decided by step 7 |
| c | Labels from the logged times where the stack shows them right, for the emissions and the scoring: light supervision, against "this has to be unsupervised learning" (plan 057) | yes, as priors and for scoring; the model still runs where nothing is logged |
| d | The years | 2019 to build (plan 057 ask a), the 2026 survey and 2017-2018 to test |
| e | Python or a GPU (JAX, `dynamax`, PyTorch) | no, unless R and C++ miss the budget |
| f | The first gears | bottom trawl, groundfish, then longline |

## References

- Bourlard, H. and Morgan, N. (1994). *Connectionist speech recognition: a hybrid approach.* Kluwer.
- Joo, R., Bertrand, S., Tam, J. and Fablet, R. (2013). Hidden Markov models: the best models for forager movements?
  *PLoS ONE* 8(8): e71246.
- Koslik, J.-O. *LaMa: fast numerical maximum likelihood estimation for latent Markov models.* R package, CRAN.
- Langrock, R. and Zucchini, W. (2011). Hidden Markov models with arbitrary state dwell-time distributions.
  *Computational Statistics and Data Analysis* 55: 715-724.
- McClintock, B. T. and Michelot, T. (2018). momentuHMM: R package for generalized hidden Markov models of animal
  movement. *Methods in Ecology and Evolution* 9: 1518-1530.
- Michelot, T. et al. hmmTMB: hidden Markov models with flexible covariate effects in R. *Journal of Statistical
  Software* 114(5).
- Peel, D. and Good, N. M. (2011). A hidden Markov model approach for determining vessel activity from vessel
  monitoring system data. *Canadian Journal of Fisheries and Aquatic Sciences* 68: 1252-1264.
- Global Fishing Watch: a CNN for fishing per AIS position, and a model for a longline's set, haul and transit
  (project pages).
