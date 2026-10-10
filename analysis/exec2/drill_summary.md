# Deeper drill-down: which large groups leave more? (IBM HR fictional data)

> **QA-cleared by Quinn, Oct 9, 2026** (executive page; review fixes R1-R7 applied). Rule: `thresholds.json` (written 2026-10-09 15:28:43 PDT, before the final run; SHA-256 `5d267be65408`). Every number here is computed by `analysis/exec2/run_drill.R` (seed 20261008). Fictional data, nothing causal. Detail: `technical_appendix.md`, `drill_log.md`.

## Short answer
- **Search size.** We tested 17,584 different groups (10,845 of them with 100 or more people), drilling into every large group and every group that cleared the checks until no group of 100 or more people produced a clear new pattern inside it (77 groups drilled).
- **Clear patterns: 2.** works overtime: 416 people (28.3% of staff), 127 left (30.5%), 53.6% of all who left; 60 people above the company rate (4.1 points of company attrition) | works overtime and monthly income under $3,221: 122 people (8.3% of staff), 68 left (55.7%), 28.7% of all who left; 48 people above the company rate (3.3 points of company attrition)
- **Why the old rule missed things.** It required 1.5 times the company rate and a company-wide stability check. 651 large groups pass the new size, impact, rate and test-set checks but not the old rate and test checks; 239 pass the old size, 1.5x and held-out gates (before stability) but give fewer than 15 people above the company rate; only the overtime group passes the full old rule.
- **How much to trust the search.** Besides the overtime group itself, the 1 other group(s) clearing all five checks go beyond anything the 200 shuffled searches produced (at most 0 in any shuffle). Groups clearing the first four checks: 3,338 in the real data versus 68 on average (95th percentile 230) when labels are shuffled across everyone, and 673 (95th percentile 753) when shuffled only within overtime status, which keeps the overtime effect. The real count is above the shuffled range, but the real passers overlap heavily, so it is not a count of independent findings.

## 1. Patterns that clear every check

A group clears every check when it has 100+ people and 24+ who left; at least 15 people above the company rate (about 1 point of company attrition); a left-rate at least 1.25 times the company rate with the low end of its uncertainty range above the company rate; the same direction on the held-out 30% of employees (30+ of them); and it held up when we re-ran the analysis on reshuffled versions of the data inside its own branch, at a similar cut.

| Pattern | People | % of staff | Left | % of all who left | People above the company rate (points) | People above its branch's rate (points) | Test-set people and rate |
|---|---|---|---|---|---|---|---|
| works overtime | 416 | 28.3% | 127 (30.5%) | 53.6% | 60 (4.1) | n/a (it is the branch) | 114, 32.5% |
| works overtime and monthly income under $3,221 | 122 | 8.3% | 68 (55.7%) | 28.7% | 48 (3.3) | 31 (2.1) | 32, 59.4% |

- **works overtime and monthly income under $3,221** is mostly inside **works overtime** (100% of its people are also in it); it is a narrower slice, so its numbers are not added to the larger group's.

Counted once, all clear patterns together cover 416 people (28% of staff) and 54% of everyone who left; if they fell to the company average that would be 60 people (4.1 points). Impacts are never added across overlapping groups.
Pay, tenure, experience and job level move together (one career-stage picture), so a pay-based group is one view of career stage, not a separate pattern, and impacts are never added. Groups defined by age, gender or marital status are never listed.

Nested groups, incremental impact (the inner group's people are already counted in the outer group, so these are never added):

| Inner group | Outer group | Inner people | Share of outer group | Left rate inner | Left rate outer | Left rate of the rest of the outer group | Extra people above the outer group's rate | Extra points |
|---|---|---|---|---|---|---|---|---|
| works overtime and monthly income under $3,221 | works overtime | 122 | 29% | 55.7% | 30.5% | 20.1% (294 people) | 31 | 2.1 |

**Groups tested, by branch** (a group is counted once; the branch is the one it was first defined in):

| Branch | Distinct groups tested | With 100+ people | Pass rules 1-3 | Pass rules 1-4 | Pass rules 1-5 |
|---|---|---|---|---|---|
| whole company (groups not split by overtime first) | 6,868 | 4,850 | 2,303 | 2,273 | 0 |
| overtime branch | 4,133 | 1,765 | 1,196 | 1,046 | 2 |
| no-overtime branch | 6,583 | 4,230 | 19 | 19 | 0 |

## 2. The CEO's question: no-overtime staff with less experience

Inside the no-overtime group (1,054 people, 110 left, 10.4%). Each group below uses a cut chosen on the training 70% only and is then checked on the held-out 30%.

| Group | People | % of branch | % of all who left | Left rate (branch average) | Times branch rate | People above branch rate | People above company rate (points) | Test people, rate | Held up in refits (strict / loose) | % in job level 1 | % in lower-paid group |
|---|---|---|---|---|---|---|---|---|---|---|---|
| no overtime and job level = 1 | 387 | 37% | 25.7% | 15.8% (10.4%) | 1.51 | 21 | -1 (-0.1) | 118, 18% | 1% / 1% | 100% | 95% |
| no overtime and monthly income under $4,230 | 421 | 40% | 25.7% | 14.5% (10.4%) | 1.39 | 17 | -7 (-0.5) | 131, 15% | 0% / 2% | 87% | 100% |
| no overtime and total working years: 7 or less | 370 | 35% | 24.9% | 15.9% (10.4%) | 1.53 | 20 | -1 (-0.0) | 121, 21% | 0% / 1% | 74% | 74% |
| no overtime and years at the company: 1 or less | 146 | 14% | 15.6% | 25.3% (10.4%) | 2.43 | 22 | 13 (0.9) | 41, 34% | 10% / 30% | 63% | 65% |
| no overtime and years in current role: 1 or less | 208 | 20% | 17.3% | 19.7% (10.4%) | 1.89 | 19 | 7 (0.5) | 58, 26% | 0% / 1% | 56% | 58% |
| no overtime and years since last promotion: under 1 year | 410 | 39% | 21.5% | 12.4% (10.4%) | 1.19 | 8 | -15 (-1.0) | 128, 10% | n/a / n/a | 46% | 50% |
| no overtime and years with current manager: 1 or less | 238 | 23% | 20.3% | 20.2% (10.4%) | 1.93 | 23 | 10 (0.7) | 73, 25% | 3% / 21% | 53% | 53% |

Career stage as a family (tenure, experience, job level and pay together): at least one of them is chosen as a split in 20% of the strict re-runs inside the no-overtime group and 89% of the looser ones, against 89% of the strict company-wide re-runs; each single variable scores lower because the correlated variables share the signal.
In 500 re-runs inside the no-overtime group, the strict version of the analysis (cross-validated pruning) found no split at all in 371 of 500, so no group inside it can reach the 50% bar (at most 26%); the looser check (unpruned shallow trees) is reported next to it. Years at the company, loose check: 36% of refits split on it; cut median 1.5 (middle half 1.5 to 2.5).

**What the short-experience groups add beyond job level 1 and lower pay** (never summed; the groups overlap):

| Group | People outside job level 1 and lower pay | Left rate there | People above branch rate there | Extra people above branch rate when added to job level 1 + lower pay | Rate among job level 2+ members |
|---|---|---|---|---|---|
| no overtime and total working years: 7 or less | 86 | 10.5% | 0 | 0.0 | 9% (98 people) |
| no overtime and years at the company: 1 or less | 49 | 14.3% | 2 | 1.9 | 15% (54 people) |
| no overtime and years in current role: 1 or less | 84 | 11.9% | 1 | 1.2 | 12% (92 people) |
| no overtime and years since last promotion: under 1 year | 198 | 7.6% | -6 | -5.7 | 8% (221 people) |
| no overtime and years with current manager: 1 or less | 106 | 12.3% | 2 | 1.9 | 12% (112 people) |

Union, counted once: the no-overtime groups above that are clear against their own branch's rate (no overtime and job level = 1; no overtime and monthly income under $4,230; no overtime and total working years: 7 or less; no overtime and years at the company: 1 or less; no overtime and years in current role: 1 or less; no overtime and years with current manager: 1 or less) together cover 642 people (44% of staff) and 85 of the 110 people who left from that branch; they left at 13.2% versus 10.4% for the branch, so combined they are a broad, modestly higher-than-average group, not a sharp one. The overlap table is in the appendix (section 8).

**The same check inside the overtime group** (416 people, 30.5% left):

| Group | People | % of branch | % of all who left | Left rate (branch average) | Times branch rate | People above branch rate | People above company rate (points) | Test people, rate | Held up in refits (strict / loose) | % in job level 1 | % in lower-paid group |
|---|---|---|---|---|---|---|---|---|---|---|---|
| works overtime and job level = 1 | 156 | 38% | 34.6% | 52.6% (30.5%) | 1.72 | 34 | 57 (3.9) | 42, 55% | 20% / 22% | 100% | 94% |
| works overtime and monthly income under $4,187 | 163 | 39% | 34.2% | 49.7% (30.5%) | 1.63 | 31 | 55 (3.7) | 43, 53% | 47% / 44% | 90% | 100% |
| works overtime and total working years: 7 or less | 152 | 37% | 30.4% | 47.4% (30.5%) | 1.55 | 26 | 47 (3.2) | 46, 48% | 1% / 1% | 76% | 75% |
| works overtime and years at the company: 4 or less | 174 | 42% | 31.6% | 43.1% (30.5%) | 1.41 | 22 | 47 (3.2) | 46, 50% | 0% / 1% | 59% | 61% |
| works overtime and years in current role: 2 or less | 206 | 50% | 35.4% | 40.8% (30.5%) | 1.34 | 21 | 51 (3.5) | 59, 47% | 0% / 2% | 54% | 56% |
| works overtime and years since last promotion: under 1 year | 171 | 41% | 24.9% | 34.5% (30.5%) | 1.13 | 7 | 31 (2.1) | 53, 36% | 0% / 0% | 42% | 46% |
| works overtime and years with current manager: 1 or less | 101 | 24% | 20.3% | 47.5% (30.5%) | 1.56 | 17 | 32 (2.2) | 27, 56% | 0% / 0% | 55% | 56% |

## 3. Supported on the full data only (not cleared)

These pass size, impact and rate on all employees but fail the held-out check, the stability check, or have too few people in the test set. There are 3,336 such groups (180 more where the test set is too small to confirm); most are variants of a few patterns, so only the distinct ones are shown (largest effect first).

| Pattern | People | Left rate | People above the company rate | People above its branch rate | Test people, rate | Held up in refits (strict / loose) | Variants folded into it (same or mostly the same people) |
|---|---|---|---|---|---|---|---|
| works overtime and monthly income under $13,964 | 377 | 32.9% | 63 | 9 | 106, 35% | 0% / 0% | 967 |
| stock option level = 0 and total working years: 15 or less | 488 | 28.5% | 60 | 60 | 154, 30% | 0% / n/a | 46 |
| job level = 1 and job involvement: 3 or less | 485 | 28.0% | 58 | 58 | 144, 29% | 0% / n/a | 177 |
| stock option level = 0 and job satisfaction: 3 or less | 440 | 28.4% | 54 | 54 | 143, 27% | 0% / n/a | 2 |
| years in current role: 2 or less and monthly income under $4,883 | 444 | 28.2% | 53 | 53 | 131, 34% | 0% / n/a | 165 |
| years at the company: 4 or less and total working years: 8 or less | 398 | 29.4% | 53 | 53 | 117, 37% | 0% / n/a | 29 |
| stock option level = 0 and years in current role: 3 or less | 363 | 30.6% | 52 | 52 | 122, 33% | 0% / n/a | 16 |
| job level = 1 and job satisfaction: 3 or less | 376 | 30.1% | 52 | 52 | 110, 32% | 0% / n/a | 7 |
| stock option level = 0 and training times last year: 4 or less | 551 | 25.6% | 52 | 52 | 178, 26% | 0% / n/a | 34 |
| monthly income under $4,227 and stock option level: 1 or less | 494 | 26.5% | 51 | 51 | 151, 27% | 0% / n/a | 21 |

**Test set too small to confirm** (fewer than 30 people in the held-out group; not cleared):

| Pattern | People | Left rate | People above the company rate | People above its branch rate | Test people, rate | Held up in refits (strict / loose) | Variants folded into it (same or mostly the same people) |
|---|---|---|---|---|---|---|---|
| works overtime and monthly income under $3,221 and job involvement: 3 or less | 109 | 59.6% | 47 | 32 | 27, 67% | 0% / 0% | 19 |
| works overtime and job level = 1 and total working years: 7 or less | 115 | 54.8% | 44 | 28 | 29, 55% | 0% / 0% | 4 |
| works overtime and job level = 1 and salary hike %: 13 or more | 111 | 55.0% | 43 | 27 | 27, 59% | 0% / 0% | 1 |
| works overtime and job level = 1 and training times last year: 3 or less | 124 | 50.8% | 43 | 25 | 28, 54% | 0% / 0% | 0 |
| works overtime and stock option level = 0 and distance from home (miles): 4 or more | 121 | 51.2% | 42 | 25 | 25, 52% | 0% / 0% | 1 |
| works overtime and total working years: 9 or less and stock option level = 0 | 100 | 58.0% | 42 | 27 | 25, 72% | 0% / 0% | 0 |

**Clear against their own branch only** (career-stage groups, at most three conditions; not cleared because they do not hold up as splits):

| Pattern | People | Left rate | People above the company rate | People above its branch rate | Test people, rate | Held up in refits (strict / loose) | Variants folded into it (same or mostly the same people) |
|---|---|---|---|---|---|---|---|
| works overtime and total working years: 15 or less and years at the company: 8 or less | 247 | 40.5% | 60 | 25 | 71, 42% | 0% / 0% | 63 |
| works overtime and job level = 1 | 156 | 52.6% | 57 | 34 | 42, 55% | 20% / 22% | 48 |
| monthly income under $4,227 and job level = 1 | 515 | 27.0% | 56 | 56 | 151, 28% | 0% / n/a | 347 |
| works overtime and monthly income under $5,747 | 243 | 38.7% | 55 | 20 | 62, 47% | 0% / 2% | 12 |
| years in current role: 2 or less and monthly income under $4,883 | 444 | 28.2% | 53 | 53 | 131, 34% | 0% / n/a | 107 |
| years at the company: 4 or less and total working years: 8 or less | 398 | 29.4% | 53 | 53 | 117, 37% | 0% / n/a | 36 |
| works overtime and years in current role: 2 or less and monthly income under $13,194 | 189 | 43.4% | 52 | 24 | 57, 49% | 0% / 0% | 36 |
| years at the company: 2 or less and monthly income under $9,985 | 307 | 32.2% | 50 | 50 | 86, 43% | 0% / n/a | 47 |
| works overtime and years with current manager: 2 or less and monthly income under $13,194 | 187 | 42.2% | 49 | 22 | 53, 47% | 0% / 0% | 19 |
| total working years: 7 or less and monthly income under $4,999 | 459 | 26.6% | 48 | 48 | 140, 30% | 0% / n/a | 52 |

## 3b. Deeper groups (three or more conditions)

5,074 groups with three or more defining conditions (counting the overtime split as one) and 100+ people were tested. 1092 pass size, impact and rate on all employees, 945 of those also pass the held-out check, 0 qualify, and 147 have too few held-out people to confirm.
8 drilled nodes had three or more defining conditions; deepest: 5 conditions.

Distinct deeper patterns passing size, impact and rate on all employees (largest effect first):

| Pattern | People | Left rate | People above the company rate | People above its branch rate | Test people, rate | Held up in refits (strict / loose) | Variants folded into it (same or mostly the same people) |
|---|---|---|---|---|---|---|---|
| works overtime and years at the company: 8 or less and job level: 3 or less | 279 | 38.0% | 61 | 21 | 81, 40% | 0% / 0% | 174 |
| works overtime and job level: 3 or less and companies worked for before: 1 or more | 316 | 34.5% | 58 | 13 | 93, 35% | 0% / 0% | 13 |
| works overtime and total working years: 15 or less and monthly income under $8,564 | 276 | 36.6% | 57 | 17 | 78, 41% | 0% / 0% | 47 |
| works overtime and job level: 4 or less and stock option level: 1 or less | 331 | 32.6% | 55 | 7 | 93, 34% | 0% / 0% | 21 |
| works overtime and years in current role: 2 or less and education level: 4 or less | 200 | 41.5% | 51 | 22 | 58, 48% | 0% / 0% | 23 |
| works overtime and monthly income under $5,747 and years at the company: 1 or more | 233 | 36.5% | 47 | 14 | 56, 41% | 0% / 0% | 8 |
| works overtime and years with current manager: 2 or less and education level: 4 or less | 199 | 39.7% | 47 | 18 | 55, 45% | 0% / 0% | 7 |

## 4. Too small to act on

1733 groups leave at 1.25 times the company rate or more but have fewer than 100 people (or fewer than 24 who left). The largest distinct ones:

| Pattern | People | Left rate | People above the company rate | People above its branch rate | Test people, rate | Held up in refits (strict / loose) | Variants folded into it (same or mostly the same people) |
|---|---|---|---|---|---|---|---|
| works overtime and monthly income under $2,909 and companies worked for before: 1 or more | 91 | 63.7% | 43 | 30 | 26, 65% | n/a / n/a | 14 |
| works overtime and total working years: 7 or less and monthly income under $3,722 | 98 | 58.2% | 41 | 27 | 24, 58% | n/a / n/a | 11 |
| works overtime and total working years: 9 or less and years at the company: 3 or less | 97 | 57.7% | 40 | 26 | 27, 67% | n/a / n/a | 8 |
| works overtime and monthly income under $3,221 and education level: 3 or less | 93 | 59.1% | 40 | 27 | 24, 67% | n/a / n/a | 0 |
| works overtime and monthly income under $3,221 and years since last promotion: 1 or less | 89 | 60.7% | 40 | 27 | 25, 60% | n/a / n/a | 2 |
| works overtime and monthly income under $3,221 and years in current role: 2 or less | 90 | 60.0% | 39 | 27 | 25, 68% | n/a / n/a | 7 |

## 5. Old rule versus new rule

Old rule (earlier run, `analysis/exec/thresholds.json`): 100+ people, 1.5 times the company rate, same direction in the test set, company-wide stability at the top three levels of the tree. It cleared one pattern: overtime. The new rule replaces the 1.5 times floor with an impact test (15+ people above the company rate) plus a 1.25 times floor and an uncertainty check, and measures stability inside the group's own branch.
Applied to the same 9,745 groups: both rules admit 2687 on the size, rate and test-set checks; the new rule admits 651 the old one did not (rate between 1.25 and 1.50 times the company rate); 239 pass the old size, 1.5x and held-out gates (before stability) but not the new ones (239 of them give fewer than 15 people above the company rate; 0 fail the uncertainty check); only the overtime group passes the full old rule. After stability, the new rule clears 2 and the old rule 1 of these groups.

Qualifying patterns and what the old rule said about them:

| Pattern | Rate vs company | Old rule: rate floor 1.5 | Old rule: company-wide stability | Old rule overall | New rule |
|---|---|---|---|---|---|
| works overtime | 1.89 | passes | 82% (passes) | admitted | admitted |
| works overtime and monthly income under $3,221 | 3.46 | passes | 40% (filtered out) | filtered out | admitted |

Large groups the new size, impact and test checks admit that the old rate floor (1.5 times) filtered out, before the stability check (distinct patterns):

| Pattern | People | Left rate | People above the company rate | People above its branch rate | Test people, rate | Held up in refits (strict / loose) | Variants folded into it (same or mostly the same people) |
|---|---|---|---|---|---|---|---|
| job level: 3 or less and years in current role: 2 or less | 625 | 24.0% | 49 | 49 | 189, 29% | 0% / n/a | 61 |
| monthly income under $4,883 and stock option level: 1 or less | 612 | 23.7% | 46 | 46 | 182, 26% | 0% / n/a | 28 |
| stock option level = 0 and training times last year: 2 or more | 578 | 24.0% | 46 | 46 | 183, 26% | 0% / n/a | 22 |
| years with current manager: 2 or less and monthly income under $10,388 | 604 | 23.7% | 46 | 46 | 173, 29% | 0% / n/a | 34 |
| total working years: 9 or less and stock option level: 1 or less | 600 | 23.7% | 45 | 45 | 180, 26% | 0% / n/a | 25 |
| total working years: 9 or less and years with current manager: 3 or less | 561 | 24.1% | 45 | 45 | 171, 28% | 0% / n/a | 2 |
| monthly income under $4,883 and years with current manager: 5 or less | 580 | 23.8% | 44 | 44 | 169, 28% | 0% / n/a | 3 |
| years at the company: 4 or less and total working years: 1 or more | 569 | 23.9% | 44 | 44 | 164, 27% | 0% / n/a | 14 |

Groups the old rule admitted on rate and test that the new impact rule does not (examples):

| Pattern | People | Left rate | Lift | People above the company rate |
|---|---|---|---|---|
| works overtime and years in current role: 2 or less and years at the company: 3 or more | 102 | 30.4% | 1.89 | 15 |
| no overtime and total working years: 7 or less and years with current manager: under 1 year | 106 | 30.2% | 1.87 | 15 |
| no overtime and years at the company: 1 or less and monthly income under $4,768 | 103 | 30.1% | 1.87 | 14 |
| no overtime and job level = 1 and years with current manager: under 1 year | 103 | 30.1% | 1.87 | 14 |
| no overtime and years at the company: 2 or less and companies worked for before: 1 or less | 101 | 29.7% | 1.84 | 14 |
| years with current manager: 1 or less and environment satisfaction = 4 | 101 | 29.7% | 1.84 | 14 |

## 6. How much to trust the search

With labels shuffled across everyone (200 shuffles), 68.4 groups per shuffle pass rules 1-4 on average (95th percentile 230); the real data has 3338. With labels shuffled only within overtime status (this keeps the overtime effect and removes everything else), the average is 672.9 (95th percentile 753).
Passing all five rules: real data 2 group(s) (including the overtime group itself); shuffled across everyone, 0% of shuffles produce any (maximum 0); shuffled within overtime status, excluding the overtime group itself, 0% of shuffles produce any (maximum 0).
Besides the overtime group itself, the 1 other group(s) clearing all five checks go beyond anything the 200 shuffled searches produced (at most 0 in any shuffle). Groups clearing the first four checks: 3,338 in the real data versus 68 on average (95th percentile 230) when labels are shuffled across everyone, and 673 (95th percentile 753) when shuffled only within overtime status, which keeps the overtime effect. The real count is above the shuffled range, but the real passers overlap heavily, so it is not a count of independent findings.

## 6b. Follow-ups after Quinn's review

**Group 2: how soft is the income cut?** The tested cut, $3,221, is a training-set grid point (the 30th percentile of overtime income), not a tuned value. All five rules hold for cuts of $2,900 to $3,900; the left rate stays between 53.4% and 59.0% across those cuts, against 17.9% to 20.9% for the rest of overtime. Among the cuts shown, the lowest one that reaches 100 people is $2,900; stability inside overtime drops to 50% or below at the higher cuts.

| Income cut (per month) | People | Left rate | Lift | Wilson low end | People above company rate (points) | Test people, rate | Rest of overtime: left rate | Size / impact / rate / held-out | Stability inside overtime | Clears all five |
|---|---|---|---|---|---|---|---|---|---|---|
| $2,500 | 70 | 68.6% | 4.25 | 57.0% | 37 (2.5) | 19, 63% | 22.8% | no / yes / yes / no | 20% | no |
| $2,800 | 98 | 59.2% | 3.67 | 49.3% | 42 (2.9) | 27, 56% | 21.7% | no / yes / yes / no | 34% | no |
| $2,900 | 105 | 59.0% | 3.66 | 49.5% | 45 (3.1) | 30, 60% | 20.9% | yes / yes / yes / yes | 56% | yes |
| $3,000 | 114 | 56.1% | 3.48 | 47.0% | 46 (3.1) | 31, 58% | 20.9% | yes / yes / yes / yes | 68% | yes |
| $3,221 (tested cut) | 122 | 55.7% | 3.46 | 46.9% | 48 (3.3) | 32, 59% | 20.1% | yes / yes / yes / yes | 68% | yes |
| $3,500 | 132 | 55.3% | 3.43 | 46.8% | 52 (3.5) | 34, 59% | 19.0% | yes / yes / yes / yes | 67% | yes |
| $3,750 | 143 | 54.5% | 3.38 | 46.4% | 55 (3.7) | 38, 58% | 17.9% | yes / yes / yes / yes | 64% | yes |
| $3,900 | 146 | 53.4% | 3.31 | 45.3% | 54 (3.7) | 39, 56% | 18.1% | yes / yes / yes / yes | 60% | yes |
| $4,000 | 151 | 53.0% | 3.29 | 45.0% | 56 (3.8) | 40, 55% | 17.7% | yes / yes / yes / yes | 50% | no |

The stability rule accepts a refit cut within +/-0.10 of the share of overtime employees below the cut; for group 2 that window spans about $2,657 to $4,187 a month, so stability does not pin the cut down more tightly than that.

**Pay versus job level.** 118 of the 122 people in group 2 (97%) are in job level 1. All 156 overtime workers in job level 1 left at 52.6% (held-out 54.8% on 42 people), against 17.3% for the 260 overtime workers at job level 2 or higher (the company average is 16.1%). Job level 1 inside overtime passes the first four rules and is stable in 20% of strict refits (22% of unpruned refits), because the trees prefer income. Inside job level 1 overtime, income under the cut left at 57.6% (118 people) against 36.8% for those above it (38), so pay adds a little but the group is essentially junior overtime workers. Pay and job level cannot be separated; this is one picture of pay and career stage.

| Group | People | Left | Left rate | Test people, rate |
|---|---|---|---|---|
| Overtime, income under the tested cut (group 2) | 122 | 68 | 55.7% | 32, 59% |
| of which job level 1 | 118 | 68 | 57.6% | 31, 61% |
| Overtime, job level 1 | 156 | 82 | 52.6% | 42, 55% |
| Overtime, job level 2 or higher | 260 | 45 | 17.3% | 72, 19% |
| Overtime, job level 1, income under the tested cut | 118 | 68 | 57.6% | 31, 61% |
| Overtime, job level 1, income at or above the cut | 38 | 14 | 36.8% | 11, 36% |

**Non-overtime combinations.** 19 groups inside the no-overtime branch pass rules 1-4 (size, impact, rate, held-out) and fail only stability (the strict check cannot be passed there: at most 26% of refits keep any split). Each is a combination of career-stage measures (tenure, experience, pay) and each is 15 to 17 people above the company rate. Counted once they cover 415 people (28% of staff), 18.6% left, and add only 10.1 people above the company rate (0.7 points). They are never added to one another or to overtime.

| Group | People | Left rate | People above company rate | Test people, rate | Strict stability | Loose stability |
|---|---|---|---|---|---|---|
| no overtime and total working years: 5 or less and years at the company: 2 or less | 127 | 29.1% | 16.5 | 43, 42% | 0% | 0% |
| no overtime and years with current manager: under 1 year and monthly income under $4,978 | 122 | 29.5% | 16.3 | 34, 44% | 0% | 1% |
| no overtime and years at the company: 2 or less and monthly income under $4,876 | 172 | 25.6% | 16.3 | 49, 39% | 0% | 1% |
| no overtime and years at the company: 4 or less and stock option level = 0 | 185 | 24.9% | 16.2 | 65, 29% | 0% | 3% |
| no overtime and total working years: 6 or less and years at the company: 2 or less | 142 | 27.5% | 16.1 | 47, 38% | 0% | 0% |
| no overtime and years at the company: 2 or less and job satisfaction: 3 or less | 168 | 25.6% | 15.9 | 49, 35% | 0% | 0% |
| no overtime and monthly income under $4,876 and years at the company: 1 or less | 107 | 30.8% | 15.7 | 30, 43% | 0% | 1% |
| no overtime and job level = 1 and stock option level = 0 | 182 | 24.7% | 15.7 | 58, 28% | 1% | 1% |
| no overtime and total working years: 7 or less and years at the company: 2 or less | 159 | 25.8% | 15.4 | 48, 38% | 0% | 0% |
| no overtime and years at the company: 2 or less and monthly income under $5,484 | 184 | 24.5% | 15.3 | 49, 39% | 0% | 1% |
| no overtime and years with current manager: under 1 year and job level: 3 or less | 166 | 25.3% | 15.2 | 46, 37% | 0% | 0% |
| no overtime and total working years: 5 or less and years with current manager: 1 or less | 104 | 30.8% | 15.2 | 38, 39% | 0% | 0% |
| no overtime and years at the company: 2 or less and stock option level = 0 | 117 | 29.1% | 15.1 | 38, 37% | 0% | 10% |
| no overtime and years with current manager: 1 or less and monthly income under $10,686 | 204 | 23.5% | 15.1 | 56, 32% | 0% | 0% |
| no overtime and years at the company: 2 or less and monthly income under $4,768 | 167 | 25.1% | 15.1 | 49, 39% | 0% | 1% |
| no overtime and years at the company: 2 or less and years since last promotion: 1 or less | 167 | 25.1% | 15.1 | 47, 32% | 0% | 0% |
| no overtime and years with current manager: under 1 year and monthly income under $6,334 | 136 | 27.2% | 15.1 | 36, 42% | 0% | 1% |
| no overtime and monthly income under $4,230 and years with current manager: under 1 year | 105 | 30.5% | 15.1 | 30, 43% | 0% | 0% |
| no overtime and years with current manager: under 1 year and total working years: 16 or less | 155 | 25.8% | 15.0 | 44, 39% | 0% | 0% |

**Short tenure, the pattern the CEO saw.** Inside the no-overtime branch, staff with under 2 years at the company (146 people) left at 25.3%, against 8.0% for the 908 with longer tenure and 10.4% for the branch; that is 13.5 people above the company rate (0.9 points), just under the 15-person bar. Across the company the same cut gives 215 people (15% of staff), 34.9% left, 40.3 people above the company rate (2.7 points), held-out 43.5% on 62 people. Gates 1-4: all pass. Stability in company-wide refits: 8% at a similar cut (9% at any cut), because tenure, experience, job level and pay share the signal. 69 of them (32%) work overtime and left at 55.1%; 146 do not and left at 25.3%. It is not added to the overtime finding.

| Group | People | % of staff | Left rate | People above company rate (points) | Test people, rate |
|---|---|---|---|---|---|
| No overtime, years at the company under 2 | 146 | 10% | 25.3% | 13.5 (0.9) | 41, 34% |
| Everyone, years at the company under 2 | 215 | 15% | 34.9% | 40.3 (2.7) | 62, 44% |


## 7. Caveats

- **Fictional data.** IBM made this dataset for teaching; it describes no real workforce.
- **Nothing here is causal.** Groups describe who left more, not why.
- **Pay and career stage cannot be separated.** Pay, job level, tenure and experience (which also tracks age) move together; they are one career-stage picture, so impacts are never added.
- **Age, gender and marital status** are descriptive only: groups defined by them are tested and counted but never headlined.
- **Snapshot timing.** Tenure and survey fields were recorded at the same time as whether people left, so they may not come before leaving.
- **Cuts are chosen on the training 70% and checked on the test 30%**, but size, impact and the uncertainty range use all 1,470 people, so they still reflect cuts picked from the data.

