# QA log: IBM HR attrition

## 2026-10-08 (PT) Method review: attrition tree draft

Reviewer: Quinn (QA/methods). Under review: Rowan's `findings_draft.md`, `METHOD.md` v0.1, `metrics.json`, `tree_rules.txt`, `tree.png`, `attrition_tree.R` and the data in `data/`.
I didn't edit any of Rowan's files. My reruns went into `/tmp/qa_attr/`. The QA scripts and their outputs are copied to `analysis/qa/` (`qa_checks.R`, `qa_checks2.R`, `*.out`).

**Verdict: APPROVED WITH FIXES.** Every number reproduces exactly. The problems are in framing and interpretation, not arithmetic. Iris should get nothing until the fixes below are made. After that, she gets only the "Surviving findings" list at the end.

### 0. Inputs and provenance
- **There's no BRIEF.md** in `projects/ibm-hr-attrition/`, and `research/` is empty. I reviewed against the draft's own stated question ("top predictors of attrition and why, as segments").
  - **Update 3:37 PM PT:** GG has since written `BRIEF.md` (mtime 3:35:27 PM PT, sha256 `8df100bb…4946`), and Ellis's research files are now in `research/`. I checked against the brief in the "Method review: Ellis interpretation" entry below (§0). It doesn't change this verdict or the fixes above. It adds two requirements: recommendations must be framed as suggestions, not tested interventions, and the classifier must not be presented as a precise prediction.
- **Fictional data: handled.** The draft header ("fictional IBM teaching dataset") and METHOD §8 both say so. For Iris, every headline and the title must carry it too (see fixes). The body text is written in the present tense about "employees", so an executive skimming it could miss the caveat.
- **Data file changed after the run (content unaffected).** `data/WA_Fn-UseC_-HR-Employee-Attrition.csv` was last modified at 3:31 PM PT, after Rowan's outputs (3:29–3:30 PM PT). Its SHA-256 is now `d11789e1…a92f7`, not the `e9f55fbf…db9c` recorded in METHOD §2. The only difference is that the UTF-8 BOM is gone. After stripping BOM and CR characters, the file is identical line for line to the public mirror named in METHOD (and that mirror still hashes to `e9f55fbf…`). I don't know who stripped the BOM. Rerunning Rowan's script on the current file gives **byte-identical** `metrics.json`, `tree_rules.txt`, `tree_splits.csv`, `tree_leaves.csv` and `single_split_scan.csv`. METHOD's hash and BOM statement need updating, though.

### 1. Reproduction (Rowan's script rerun in /tmp, plus independent checks)
All checked values match exactly:

| Claim | Reproduced | Note |
|---|---|---|
| 1,470 rows, 237 leavers (16.12%), 0 missing values, 27 predictors | ✓ | Train 1,029 (166 leavers, 16.13%) / test 441 (71, 16.10%) |
| Settings: cp 0.01, minsplit 20, minbucket 7, maxdepth 5, stratified 70/30, seed 20261008 | ✓ | Script matches METHOD. 15 splits, 16 leaves |
| Root OverTime: 30.5% vs 10.4% | ✓ | **Full data** (416 / 1,054) |
| OT & income < $2,475: 69.6% (n = 69) vs 22.8% (n = 347) | ✓ | **Full data**, which includes the 50 training rows the cutpoint was optimized on (see §1b) |
| Single vs married/divorced 38.7% vs 14.1% | ✓ | **Train only** |
| Importance %: 21.7 / 11.2 / 8.8 / 8.5 / 8.4 / 8.0 / 4.9 / 4.7 | ✓ | Surrogate-inclusive (see §2b) |
| Bootstrap root (500 refits): OT 44.4%, income 30.6%, TWY 15.4% | ✓ | Refits use the training set |
| Test AUC 0.670 [0.605, 0.737] | ✓ | 2,000 stratified bootstrap draws. DeLong CI [0.602, 0.738] |
| 5×10-fold CV AUC 0.699 (SD 0.058) | ✓ | Mean fold AUC. Pooled out-of-fold AUC is 0.682–0.705 by repeat |
| Test balanced accuracy 0.618 | ✓ | **Threshold = training base rate 0.1613 (p ≥ thr)**: sensitivity 0.338, specificity 0.897, 62 of 441 flagged. At 0.5 it's 0.578 |
| Income r: JobLevel 0.95, TWY 0.77 | ✓ | Also Age 0.50, YearsAtCompany 0.51. JobLevel explains 92.5% of income variance |
| Every Single employee has StockOptionLevel 0 | ✓ (470/470) | But the reverse doesn't hold: 161 married/divorced employees also have SOL 0 (see §2c) |

**Discrepancy in a claim (not a number): "the 1-SE rule prunes to the root."** That's true only for the xval seed Rowan used (min xerror 0.958 at 2 splits). I refit the same tree with 20 other xval seeds. The 1-SE rule kept the **2-split tree (OverTime, then income < $2,475 within overtime)** in 18 of 20, and pruned to the root in 2 of 20 (min xerror 0.87–0.94, at 2 splits in 18/20). The more accurate statement: *cross-validation supports at most the first two splits; nothing below them.*

#### 1b. Where each segment rate comes from, with Wilson 95% CIs
The draft's level-1/2 table uses full data, its Short-version item 4 and level-4 bullet lead with **train** numbers, and the split table gives both. Train-only rates are optimistic because the splits and cutpoints were chosen on those same rows. **Test rates are the honest estimates.** Full-data rates are acceptable for OverTime (binary, nothing tuned). For tuned cutpoints they mix in the optimized training rows.

| Segment | Train | **Test (honest)** | Full data |
|---|---|---|---|
| OverTime = Yes | 90/302 29.8% | **37/114 32.5% [24.6, 41.5]** | 127/416 30.5% [26.3, 35.1] |
| OverTime = No | 76/727 10.5% | **34/327 10.4% [7.5, 14.2]** | 110/1054 10.4% [8.7, 12.4] |
| OT & income < $2,475 | 36/50 72.0% | **12/19 63.2% [41.0, 80.9]** | 48/69 69.6% [57.9, 79.2] |
| OT & income ≥ $2,475 | 54/252 21.4% | **25/95 26.3% [18.5, 36.0]** | 79/347 22.8% [18.7, 27.5] |
| No OT & income < $1,559 | 7/10 70.0% | **2/8 25.0% [7.1, 59.1]** | 9/18 50.0% [29.0, 71.0] |
| No OT & income ≥ $1,559 | 69/717 9.6% | **32/319 10.0% [7.2, 13.8]** | 101/1036 9.7% [8.1, 11.7] |
| (context) No OT & income < $2,475 | 21/112 18.8% | **7/39 17.9% [9.0, 32.7]** | 28/151 18.5% [13.2, 25.5] |
| (context) No OT & income ≥ $2,475 | 55/615 8.9% | **27/288 9.4% [6.5, 13.3]** | 82/903 9.1% [7.4, 11.1] |
| Better-paid OT, Single | 29/75 38.7% | **12/26 46.2% [28.8, 64.5]** | 41/101 40.6% [31.5, 50.3] |
| Better-paid OT, Married/Divorced | 25/177 14.1% | **13/69 18.8% [11.4, 29.6]** | 38/246 15.4% [11.5, 20.5] |
| …Single & Lab Tech / Sales Exec / Sales Rep | 22/37 59.5% | **10/13 76.9% [49.7, 91.8]** | 32/50 64.0% [50.1, 75.9] |
| …Single & other roles | 7/38 18.4% | **2/13 15.4% [4.3, 42.2]** | 9/51 17.6% [9.6, 30.3] |
| Low-paid OT, RelSat ≥ 3 | 19/32 59.4% | 9/12 75.0% [46.8, 91.1] | 28/44 63.6% |
| Low-paid OT, RelSat < 3 | 17/18 94.4% | 3/7 42.9% [15.8, 75.0] (reverses) | 20/25 80.0% |
| No OT, Technical Degree | 16/67 23.9% | 3/29 10.3% [3.6, 26.4] (vanishes) | 19/96 19.8% |

Fisher tests on the test set, by split: OverTime p < 0.0001; OT income $2,475 p = 0.003; No-OT income $1,559 p = 0.20; Single vs Married/Divorced p = 0.010; role within single p = 0.005 (n = 13 vs 13); RelSat p = 0.33 (reversed); Technical Degree p = 1.0. That's seven split tests, so the level-3 and level-4 results are suggestive at best (Bonferroni α ≈ 0.007).

### 2. Method issues

**a) Provenance / fictional data.** The draft and METHOD say it (good). Required for Iris: put "fictional (IBM-created) teaching dataset; patterns describe simulated employees, not any real workforce, and say nothing about Intuitive or any employer" in the title or subtitle, and write findings as "in this dataset, …". Also, MaritalStatus, Age and Gender are protected or sensitive characteristics. Add a line that these segments are descriptive only and must not be used to target or make decisions about individuals.

**b) Importance vs root.** Confirmed: rpart `variable.importance` includes surrogate credit (adj × the primary split's improvement). **But the premise that MonthlyIncome's #1 rank comes from surrogate credit taken from JobLevel/TWY is not supported.** Decomposition:
- MonthlyIncome = 28.53 primary + 2.41 surrogate (92% primary). It ranks first because it is the primary split at **two** nodes (node 3: 21.34, node 2: 7.19). Their sum beats OverTime's single root improvement of 15.97. Improvements are summed across nodes, so a variable that splits twice gets credit twice.
- Surrogate credit flows the *other* way, from the income split at node 3 to TWY (adj 0.14, 2.99), Age (1.71) and JobRole (1.28). JobLevel gets zero credit.
- Variables that are mostly or entirely surrogate credit: TotalWorkingYears 100%, StockOptionLevel 100%, Department 100%, Age 51%, EducationField 53%, JobRole 29%, DistanceFromHome 29%.
- **Primary-split-only importance** (refit with maxsurrogate = 0 gives an identical tree): MonthlyIncome 29.6%, OverTime 16.5%, EnvironmentSatisfaction 10.9%, JobRole 8.7%, DistanceFromHome 8.3%, MaritalStatus 6.6%, Age 6.4%, NumCompaniesWorked 4.1%, EducationField 3.1%, RelationshipSatisfaction 2.9%, JobInvolvement 2.9%. TWY and StockOptionLevel drop to 0.
- Bootstrap top-5 frequency using primary-only importance: OverTime 95.0%, MonthlyIncome 88.8%, JobRole 39.0%, DistanceFromHome 33.6%, Age 26.8%, StockOptionLevel 26.2%, TWY 23.8%, EnvironmentSatisfaction 19.8%.
- The draft's own explanation ("splits twice at level 2 and also gets surrogate credit") is right, but should say the surrogate part is small (2.4 of 30.9). EnvironmentSatisfaction's 4th place is from two level-5 splits in nodes of 43 and 29. That's an artifact; it shouldn't be in any ranked list for Iris.

**c) Confounding.**
- *Low pay vs junior/early career.* These can't be cleanly separated. Of 220 employees under $2,475, 210 (95.5%) are JobLevel 1, and 10 are JobLevel 2. Median age is 30 vs 36, median TWY 5 vs 10, median tenure 3 vs 6 years. 46% are under 30 and 40% have ≤ 3 working years.

  | Low income × JobLevel | 1 | 2 | 3 | 4 | 5 |
  |---|---|---|---|---|---|
  | < $2,475 | 210 | 10 | 0 | 0 | 0 |
  | ≥ $2,475 | 333 | 524 | 218 | 106 | 69 |

  The association is not *only* career stage, though. Within JobLevel 1, under $2,475 is 35.7% [29.5, 42.4] (75/210) vs 20.4% [16.4, 25.1] (68/333). Within JobLevel 1 with overtime it's 72.7% (48/66) vs 37.8% (34/90). The gap persists within TWY ≤ 3 / > 3 and age < 30 / ≥ 30 strata. In a descriptive logistic model with OverTime, JobLevel 1, log TWY, Age and log tenure, "< $2,475" has OR 1.78 [1.18, 2.68] (LR p = 0.006). That's still observational, synthetic data, so it **must not be read as pay causing attrition**. The right wording is "lowest-paid, mostly entry-level (JobLevel 1) employees".
- *Single vs StockOptionLevel 0.* This is one-directional. Every Single employee has SOL 0 (470/470), so being single and having no stock options **cannot be separated for single employees**. But 161 married/divorced employees also have SOL 0. Within better-paid overtime (full data): Single (all SOL 0) 40.6% (41/101) vs Married/Divorced with SOL 0 25.6% [14.9, 40.2] (11/43) vs Married/Divorced with SOL ≥ 1 13.3% [9.3, 18.7] (27/203). So part of the "single" gap travels with "no stock options". The draft's "**or equivalently** no stock options" and "interchangeable" are wrong in one direction, and the segment needs to be labeled "single (all of whom have no stock options)". This is a known artifact of the synthetic data.
- *The "lab tech / sales" role group* within single, better-paid overtime is mostly Sales Executives (full data: 32 Sales Exec, 13 Lab Tech, 5 Sales Rep).

**d) Cutpoint stability ($2,475).** OverTime was the root in 222 of 500 bootstrap refits. In 185 of those 222 (83%), the overtime branch split next on MonthlyIncome (otherwise JobLevel 18, JobRole 6, Age 5, MaritalStatus 4, other 4). Distribution of that income cutpoint (n = 185): min $2,422, 5% $2,461, 25% $2,475, **median $2,494**, 75% $2,964, 90% $3,932, max $4,012. 54% fall in $2,400–2,500 and 61% within ±$100 of $2,475, but **37% (68/185) fall above $2,700**, in two clusters, ~$2,780–2,840 (21) and ~$3,200–4,010 (47), near the JobLevel 1 pay range *(corrected 3:38 PM PT: I first wrote "second mode at roughly $2,900–4,000 (~37%)". Only 25% are ≥ $2,900.)* (JobLevel 1 incomes run $1,009–4,968). A single-variable check (the best income split among training overtime rows, 500 bootstraps) gives the same picture: median $2,494, IQR $2,475–2,964, 52% in $2,400–2,500. Across all nodes, income cutpoints span $1,412–19,793. **Conclusion:** "a low-income threshold around $2,500" is reasonably stable as a lower bound, but the exact $2,475 shouldn't be presented as precise. Present it as "under about $2,500/month (lowest ~15% of earners)" and note that refits sometimes put it at ~$2,800 or ~$3,200–4,000.

**e) Weak model and benchmark (context only).**
- **Logistic regression** on the same 27 predictors and the same split gets a **test AUC of 0.863 [0.814, 0.908]** vs the tree's 0.670 (DeLong difference 0.19 [0.12, 0.26], p < 1e-7). 5×10-fold CV on Rowan's folds: **0.838 (SD 0.045)** vs the tree's 0.699. At the same base-rate threshold, logistic balanced accuracy is 0.762 (sensitivity 0.72, specificity 0.81). The tree leaves most of the ranking signal unused. The signal is spread additively across many variables, which a depth-5 tree on 1,029 rows can't capture. So the draft's line that "most leavers are in large, low-risk groups that a tree can't separate" is misleading: *this* tree doesn't separate them, but the data does better. 39 of the 71 test leavers sit in the two largest low-risk leaves (nodes 16 and 24).
- **The 2-split tree** (OverTime + OT income < $2,475) has a **test AUC of 0.669 [0.608, 0.732]**, identical to the full 15-split tree's 0.670 (DeLong p = 0.97). On test, the 13 deeper splits add nothing. In CV, a depth-2 tree scores 0.636 vs 0.699 for the full setting, so the evidence on deeper splits is mixed and weak at best. OverTime alone: test AUC 0.657, CV 0.651.
- **Segments that hold up in test:** (1) OverTime, strong. (2) Income < $2,475 within overtime, strong (test 63.2% vs 26.3%, p = 0.003), and it's the only split below the root that CV supports. (3) Single within better-paid overtime, which replicates directionally (46.2% vs 18.8%, p = 0.010) but isn't supported by CV pruning and is confounded with SOL 0. (4) Lab tech / sales within that group, which replicates directionally but on 13 vs 13 test rows. **Don't hold up:** no-OT income < $1,559 (n = 8 in test, p = 0.20), Technical Degree, the RelationshipSatisfaction reversal, JobInvolvement, both EnvironmentSatisfaction splits, both DistanceFromHome splits (one reverses), and NumCompaniesWorked (test 16.7% vs 19.3%, reversed).

**f) findings_draft.md language.**
- Train-led headline numbers: Short-version item 4 ("38.7% vs 14.1% … in training") and the level-4 bullet ("59.5% (n = 37, training)"). Lead with test rates and n.
- Item 2 uses the full-data 69.6% (n = 69). That's acceptable if labeled, but add test 63.2% (12/19) [41.0, 80.9] and note the cutpoint was tuned on training rows.
- No CIs anywhere, and the deep-leaf rates come with small n. Add Wilson CIs to every rate Iris might use.
- "Low monthly income … **matters** most for people on overtime" and "the strongest second factor" read as causal. Use "the attrition gap by income is largest among overtime workers (69.6% vs 22.8%; without overtime 18.5% vs 9.1%)".
- "the tree finds **real** high-risk segments" overstates it. Only the first two splits are CV-supported.
- "a tree can't separate": contradicted by the benchmark (see §2e).
- "or equivalently no stock options" / "interchangeable": wrong direction (see §2c).
- "The 1-SE rule would prune to the root": seed-specific (see §1).
- "Employees who work overtime leave about three times as often" is accurate (2.9× full data, 3.1× test), but needs "in this fictional dataset" and "overtime may mark understaffed or junior roles; this doesn't show overtime causes leaving".
- Executive misread risks: the importance table (ranks EnvironmentSatisfaction 4th from noise) and the "Second view" table use train-only rates. Neither should go to Iris as-is.

**g) Exclusions and leakage.**
- The ID and the 3 constants are clearly justified (verified as 1 unique value each). DailyRate, HourlyRate and MonthlyRate are justified and were pre-specified: correlations with income are |r| ≤ 0.035, their univariate AUCs are 0.545 / 0.495 / 0.512, and refitting with them included leaves the top levels unchanged (test AUC 0.674 vs 0.670; DailyRate picks up importance 6.84 in deep splits).
- **No leakage**: no predictor is derived from Attrition.
- Timing caveat (synthetic, so it can't be verified): tenure-type fields (YearsAtCompany, YearsInCurrentRole, YearsWithCurrManager, YearsSinceLastPromotion) and the satisfaction surveys come from a single snapshot. For leavers they may describe the time of exit, and short-tenure groups mechanically show more exits. None of these is in the CV-supported part of the tree, so the headline is unaffected. Add one line to the limitations.

### 3. Fixes for Rowan (required before anything goes to Iris)
1. In findings_draft.md, lead every segment rate with the **test** rate, n and Wilson CI (table in §1b). Label any full-data rate as full data and any train rate as train. Remove train-only rates from headline bullets.
2. Replace "the 1-SE rule would prune to the root" with: "Cross-validation supports at most the first two splits (OverTime, then income < ~$2,500 within overtime). With Rowan's xval seed the 1-SE rule pruned to the root; across 20 other xval seeds it kept these 2 splits in 18." Say explicitly that everything below level 2 is exploratory.
3. Add the benchmark: logistic test AUC 0.863 [0.814, 0.908], CV 0.838 vs the tree's 0.670 / 0.699. Delete "a tree can't separate" and say the tree describes only part of the signal. Note that the 2-split tree matches the full tree on test (0.669 vs 0.670).
4. Correct the stock-option wording: "every single employee has no stock options (but 161 married/divorced employees also have none). For single employees the two can't be separated." Add the SOL 0 married/divorced rate (25.6%, n = 43).
5. Importance: add the primary-only column as a % share and the primary-only bootstrap top-5 numbers. State that income's surrogate credit is only 2.4 of 30.9 and that its lead comes from splitting at two nodes. Drop EnvironmentSatisfaction, Age, DistanceFromHome, TWY and StockOptionLevel from any "top predictors" ranking. Describe TWY/JobLevel/age/tenure as one early-career cluster.
6. Present the income cutpoint as "under about $2,500/month" with the bootstrap spread (median $2,494, IQR $2,475–2,964, second mode ~$3,000–4,000). Add the JobLevel crosstab and the line "95% of this group is JobLevel 1; pay and career stage can't be cleanly separated; no causal claim".
7. Remove the causal and overconfident phrasing listed in §2f.
8. Put the fictional-data caveat in the title/subtitle and every headline. Add the protected-characteristics caution and the snapshot-timing limitation.
9. Update METHOD §2: the hash and "starts with a BOM" no longer match the file in `data/` (the BOM was stripped at 3:31 PM PT; content identical). Record the current hash, or restore the file and say which. Also fix METHOD §8's "Bootstrap refits change the root variable about 56% of the time", which is accurate but should say "the root isn't OverTime in 56% of refits; 31% income, 15% TWY".
10. Optional: the "Second view" (single-split scan) is train-only. Keep it in METHOD/appendix only.

### 4. Iris-ready surviving findings (after the fixes above)
All of these describe a **fictional IBM-created teaching dataset (1,470 simulated employees, 237 leavers, 16.1%)**. They're descriptive, not causal, and don't apply to any real employer.
1. **Overtime marks the biggest difference in attrition.** Employees on overtime left at 30.5% (127/416, 95% CI 26.3–35.1%) vs 10.4% (110/1,054, 8.7–12.4%), about 3×. The held-out test set agrees: 32.5% (n = 114) vs 10.4% (n = 327). Caveat: overtime may mark understaffed or junior roles rather than cause leaving.
2. **The highest-risk group is overtime workers who are among the lowest paid (under about $2,500/month).** On the held-out test set, 63% left (12 of 19, CI 41–81%) vs 26% of better-paid overtime workers (25 of 95, CI 19–36%). On all data it's 69.6% (48/69) vs 22.8% (79/347). This group is almost entirely entry-level (95% JobLevel 1, median age 30), so low pay and early career can't be cleanly separated, and this doesn't show pay causes attrition. Without overtime the income gap is much smaller: 18.5% vs 9.1% on all data. The exact $2,475 cutpoint shifts between refits, so say "about $2,500".
3. **Early-career markers travel together.** Low income, JobLevel 1, few total working years, short tenure and younger age carry overlapping signal (income vs JobLevel r = 0.95, vs total working years r = 0.77). Which one the model picks first changes from refit to refit: OverTime is the first split in 44% of 500 refits, income in 31%, total working years in 15%.
4. **Exploratory only (label it as such, or leave it out):** among better-paid overtime workers, single employees left more on the test set, 46% (12/26, CI 29–65%) vs 19% (13/69, CI 11–30%). Every single employee in this dataset has no stock options, so "single" and "no stock options" can't be told apart. Within that group, lab technician and sales roles (mostly Sales Executives) were higher still, but on only 13 vs 13 test employees (77% vs 15%). Cross-validation doesn't support these deeper splits.
5. **How much the tree explains:** it's a coarse segmentation, not a predictor. Held-out AUC is 0.67 (CI 0.61–0.74). At a 16% threshold it catches 34% of leavers and correctly clears 90% of stayers. A simple regression on the same data ranks people much better (AUC 0.86), so these segments capture only part of what distinguishes leavers.
   - Not for Iris: importance percentages, EnvironmentSatisfaction, DistanceFromHome, RelationshipSatisfaction, JobInvolvement, EducationField, NumCompaniesWorked and the no-overtime < $1,559 group. None holds up on the test set.

---

## 2026-10-08 (PT) Method review: Ellis interpretation

Reviewer: Quinn. In scope: `research/interpretation.md` (DRAFT), `research/attrition_drivers.md` (literature brief) and `research/variable_construct_map.csv`. I didn't edit any of them. Extra checks: `analysis/qa/qa_checks3.R` / `.out`.

**Versions reviewed** (the file was edited live, five versions between 3:35 and 3:38 PM PT; this verdict applies to the last one):
- `interpretation.md`: **final reviewed version mtime 3:38:05 PM PT, sha256 `c6460cc8…c769a`, 9,880 bytes.** Earlier versions seen: 3:35:41 (`2ba61915…`), 3:36:46 (`ba717a0a…`), 3:37:22.
- `attrition_drivers.md` and `variable_construct_map.csv`: mtime 3:33:12 PM PT (unchanged).
- `BRIEF.md`: mtime 3:35:27 PM PT, sha256 `8df100bb…4946`.

**Verdict for interpretation.md (3:38:05 PM PT version): APPROVED WITH FIXES.** The literature brief is accurate and carefully sourced (§4). Every citation I checked is real and says what's claimed. Most problems inherited from Rowan's draft are now fixed. What remains is interpretive overreach in five places: the hindrance-stressor reading, the "absent / not established predictors" section, the stock-option "actionable" claim, recommendations framed as following from the results, and an outdated caveat. These are text fixes, but they need a re-check before Iris uses the interpretation.

### 0. Against BRIEF.md
- **Question:** "top predictors … and why are they top predictors". Both senses of "why" are covered: statistical (Rowan's splits, METHOD §6) and substantive (Ellis's literature). ✓
- **Deliverable 4** asks for a narrative with "sourced I/O research on why they matter, and recommendations", plus the out-of-scope rule "Recommendations are suggestions from the findings and the research, not tested interventions." interpretation.md's header "**Recommendations that follow from these results**" and the phrase "the literature-supported lever" don't meet that. ✗ (fix E5)
- **"Do not present a weak classifier as a precise prediction."** Both the draft and the interpretation say segmentation, not prediction. ✓
- **Rate fields:** DailyRate, HourlyRate and MonthlyRate are excluded and labeled as not pay in all three files. ✓
- **Not in the brief:** it never says the data are fictional. It also says "Everything in this project may be public" (public repo and app). So the fictional-data caveat and the sensitive-characteristics caution must ship in every public artifact (README, app, summary). GG should add one line to BRIEF.md.
- **"Training set" wording:** in the brief, "training set" means the Kaggle file (all 1,470 rows). That's not Rowan's 70% training split. Write-ups should say "the Kaggle file" to avoid the clash.
- **For Soup (app):** the brief asks the app to show "variable importance for all predictors at the current node". It should say whether surrogate credit is included. rpart's default includes it. I believe JMP's Column Contributions count only the splits actually made, but Soup should confirm that before matching it.

### 1. Inherited problems from Rowan's v0.1 numbers (status at 3:38:05 PM PT)
| Inherited item | Where in interpretation.md | Status | Correction |
|---|---|---|---|
| Single vs married 38.7/14.1 (train) | Marital section | **Fixed.** Replaced with the one-way 40.6/25.6/13.3 | Still missing n, CI and "full data" labels: 41/101 [31.5, 50.3], 11/43 [14.9, 40.2], 27/203 [9.3, 18.7]. Note that the differences aren't statistically clear: single vs married/divorced with no options p = 0.09; options vs none p = 0.06 (Fisher). Test-set version: 46.2% (12/26) / 30.0% (3/10) / 16.9% (10/59) |
| Lab tech/sales 59.5/18.4 (train) | Job-role section | **Fixed.** Leads with test 76.9% (10/13) [49.7, 91.8] vs 15.4% (2/13) [4.3, 42.2], train labeled, "a lead, not a finding" | Matches my reproduction exactly (Fisher p = 0.005) ✓ |
| Full-data 69.6% without the test rate | Opening line | **Fixed.** Leads with test 63% (12/19, 41–81%) vs 26% (25/95); 69.6% labeled full data including the rows the cut was chosen on | ✓ (could add the CI 18.5–36% for the 26%) |
| Seed-specific 1-SE claim | Not used | n/a | Job-role section correctly says CV supports two splits ✓ |
| Importance ranking (EnvSat, Age, Distance, TWY) | "Did not hold up" | **Shares removed** ✓ | The surrounding claim is still wrong (see §2d) |
| Single = stock options "equivalence" | Marital section | **Fixed.** One-way, "not interchangeable" ✓ | — |
| "A tree can't separate" | Not used | n/a | Caveat should add the benchmark (logistic AUC 0.86) |
| Exact $2,475 cutpoint | Opening and pay section | **Fixed.** "Under about $2,500" ✓ | — |
| **Train-only 35.2% (n = 165) vs 12.5%** | Pay section | **Labeled as training, but shouldn't be there.** It comes from `single_split_scan.csv` (MonthlyIncome ≥ $2,488: 864 at 12.5% vs 165 at 35.2%, training rows, cut chosen on those rows) | **Replace it** with the honest all-employee contrast at the tree's cut. Test: under $2,475 32.8% (19/58, CI 22.1–45.6%) vs 13.6% (52/383, 10.5–17.4%). Full data: 34.5% (76/220) vs 12.9% (161/1,250) |
| "Overtime is the most stable split" | Overtime section | **Fixed.** Now "not a uniquely stable first split: overtime 44.4%, income 30.6% of 500 refits" | **Judgment:** "most stable split" was wrong as a statement about the root (44%). It would be fair to say overtime is the most consistently *used* variable: it's in the primary-split top 5 in 95% of refits, and it's the clearest split on test (p < 0.0001). The current wording is fine |
| "Caveat: … a single draft tree that Quinn has not reviewed" | Caveat | **Outdated** | Update to "reviewed; only the first two splits are CV-supported" and add the benchmark |

### 2. Interpretive overreach (remaining)
a) **Hindrance stressor (factual framing problem).** The text says overtime acts as a "hindrance stressor … (Podsakoff et al., 2007)". In the challenge–hindrance framework Podsakoff et al. use, *workload and time pressure are classed as challenge stressors* (hindrances are role ambiguity, red tape, hassles), and challenge stressors were negatively related to turnover. That matches Rubenstein's workload ρ = −.10. So the framework, if anything, predicts the opposite of the IBM pattern. Recommendation 1 ("reducing hindrance demands") inherits the problem. Fix: say that in this framework workload is normally a challenge stressor, that whether IBM's overtime is felt as a hindrance is unmeasured, and that the data can't test the reading.

b) **"Stronger than the meta-analyses would lead one to expect."** Overtime vs attrition here is φ = 0.25, against workload ρ = −.10. Ellis's own brief (§4.5) says that when the fictional data and the literature disagree, "the likely explanation is how the data were generated, not new science". The interpretation should say that here instead of reaching for Rubenstein's moderator. That moderator is also paraphrased inaccurately. Rubenstein wrote "It may be that a high workload is only problematic for those who must also devote significant portions of their time to other roles", which is speculation framed as a future-research idea, about *other roles* (family), not "other pressures" like low pay.

c) **Fictional data treated as evidence.** The caveat at the bottom is good ("not evidence that the mechanisms operate in these data"), but it sits at the end. It's missing from the title and opening, and the body uses "fits the oldest framework most directly" and "the mechanism is…". The fictional-data label belongs in the title and opening. Every link to the literature should read "consistent with (illustrative only)". Fictional data can't confirm or replicate the literature.

d) **"Did not hold up / variables that are absent": wrong for this dataset.** Age, distance and environment satisfaction failed *as deep tree splits*. That doesn't make them "not established predictors in this dataset", and job satisfaction isn't "missing". Evidence (`qa_checks3.out`):
- **Job satisfaction:** full-data attrition by level 1/2/3/4 is 22.8 / 16.4 / 16.5 / 11.3%. Test: level 1 22.8% (18/79) vs levels 2–4 14.6% (53/362).
- **Environment satisfaction:** level 1 25.4% vs 13.5–15.0% for levels 2–4. Test: 26.1% (23/88) vs 13.6% (48/353).
- **Age:** under 30, 30.0% (30/100) vs 12.0% (41/341) in test. Age belongs to the early-career cluster.
- **Logistic model on training data:** JobSatisfaction, EnvironmentSatisfaction, JobInvolvement, RelationshipSatisfaction, DistanceFromHome and NumCompaniesWorked are all p < 0.001; WorkLifeBalance p = 0.03.

These variables carry *additive* signal that a shallow tree doesn't capture, which is why logistic AUC is 0.86 vs the tree's 0.67. Rewrite as "not supported as tree splits; they show bivariate/additive associations consistent in direction with the literature (illustrative only)". Drop the single-item and LMX "explanations" for a gap that's a model artifact, or keep them only as general measurement notes.

e) **Pay vs career stage.** Handled well ("low-paid, early-career employees leave more … does not show pay alone causes leaving"). ✓ Recommendation 2 ("Audit pay for entry-level employees who work overtime … felt inequity") rests on a causal pay mechanism the data can't separate from career stage. It needs the caveat inline, and should be framed as a suggestion.

f) **Stock options "actionable".** "Stock options still separate leavers once marital status is held roughly constant" and "This one is actionable" overstate it:
- n = 43 vs 203, p = 0.06, full data.
- The segment isn't CV-supported, and the whole marital/option structure is a known artifact of the synthetic data.
- StockOptionLevel 0–3 is undocumented, so "unvested equity" and vesting are assumptions.
- Sengupta et al. (2007) is workplace-level share ownership (UK WERS 1998), and found share ownership *not* associated with commitment. The chain "raises continuance commitment (Meyer & Allen) … golden handcuffs (Sengupta)" mixes a theory claim with a source that partly runs against it.

Rewrite as "consistent with a side-bet reading; can't be tested here". Drop "actionable" and recommendation 4's equity/vesting half, or label it a literature-only suggestion.

g) **Protected characteristics.** Marital status is labeled not actionable, and "never targeted by marital status" is good. ✓ Add that age and gender are also descriptive only. Age appears in the "did not hold up" section without that note.

h) **Interpreting segments that don't hold up.** Job role is labeled a lead ✓. The marital mechanisms paragraph interprets an exploratory, non-CV-supported segment at length. Shorten it and label it exploratory at the top of the section.

i) **Griffeth's procedural-fairness quote** (recommendation 2): verified on p. 480, but the source says "*Conceivably*, just procedures have as much—if not more—to do with…". That's speculation flagged by the authors, not a finding. Keep "may", and say it's a conjecture in the source.

### 3. Construct mapping (variable_construct_map.csv / brief §2)
Generally careful: RelationshipSatisfaction and YearsWithCurrManager are explicitly not read as LMX, the "no commitment measure" warning is there, and the rate fields are excluded. Overclaims to fix:
- **General:** every attitude field is a single 1–4 item with no published wording and **unknown, unestimable reliability**. In a synthetic file the values are generated, so the map is construct *labeling*, not measurement validation. Say so once at the top. Borrowing meta-analytic ρ from multi-item scales sets expectations; it doesn't validate the IBM field.
- **OverTime:** a yes/no flag (StandardHours is a constant 80; no hours, premium or voluntariness), so it's a proxy for workload/demands. The "hindrance vs challenge stress" label assumes a classification the framework would usually give the other way (§2a). "Long hours cause strain" is causal wording for a binary flag. If JD-R language is wanted, overtime is a job demand. JD-R isn't cited anywhere in Ellis's files, so add a source (e.g., Demerouti et al., 2001) if it's used.
- **MonthlyIncome = "Pay level":** should read "pay level, confounded with job level". JobLevel explains 92.5% of income variance, and 95% of the under-$2,475 group is JobLevel 1. Within-level pay variation is the only part that's "pay" as distinct from career stage.
- **EnvironmentSatisfaction → climate (ρ = −.24):** the climate ρ comes from k = 8 samples (N = 2,711) of climate measures. A single undocumented 1–4 "environment satisfaction" item is a facet-satisfaction rating of unknown referent. Don't attach the climate ρ to it as if it measured climate.
- **JobSatisfaction / JobInvolvement:** single items mapped to multi-item constructs. Tett & Meyer (1993) do list single- vs multi-item scales as a moderator (abstract verified), but the abstract doesn't give the direction. "Single-item measures weaken attitude–turnover links" isn't verifiable from what I could access. Soften it to "differ by" unless Ellis checks the full text.
- **WorkLifeBalance as "the mirror image of conflict":** balance and conflict aren't simple reverses (balance also covers enrichment and fit). Say "related to (inverse of) conflict".
- **PercentSalaryHike → "distributive and procedural pay fairness":** a single-year raise percentage can't measure procedural fairness, and is only a weak proxy for salary growth. Drop "procedural".
- **StockOptionLevel → "unvested equity / side bet":** the level coding is undocumented and vesting is unknown. "Deferred-compensation level (coding undocumented)" is defensible; "unvested equity" isn't.
- **DistanceFromHome → commute:** units are undocumented, and distance isn't travel time (Santelli & Grissom measured minutes, with district exit only at 40+ minutes). Treat it as a weak proxy.

### 4. Citations (spot-check, 3:36–3:38 PM PT)
- **All 42 DOIs in attrition_drivers.md resolve** (Crossref and doi.org) to the stated authors, title, journal, volume and pages. Cotton & Tuttle's `10.5465/amr.1986.4282625` is an alias that redirects to Crossref's `10.2307/258331`. Fine, but the canonical DOI is cleaner. The books (March & Simon 1958, Price 1977, Hom & Griffeth 1995) have no DOI and I didn't check them.
- **Griffeth, Hom & Gaertner (2000), JoM 26(3) 463–488.** Checked against the full text (public PDF): overall job satisfaction ρ1 −.19 (k = 67) ✓; commitment −.23 ✓; quit intentions .38, "excepting job search methods" ✓; pay ρ1 −.09 ✓; pay satisfaction −.07 ✓; alternatives .12 ✓; "modest … restricted pay variance" ✓; p. 480 procedural quote ✓, but it's conjecture (§2i).
- **Rubenstein, Eberly, Lee & Mitchell (2018), Personnel Psychology 71(1) 23–65 (online 2017).** Checked against Table 2 in a public PDF copy: 57 predictors and 1,800 effect sizes ✓. All quoted ρ values match: pay −.17 (k = 55), workload −.10 (k = 21), job satisfaction −.28 (k = 174), age −.21, marital −.10, sex .00, tenure −.20 / −.27, children −.20, climate −.24 (k = 8), leadership −.24, embeddedness −.26, work–life conflict +.19 (k = 7), stress/exhaustion +.21, job involvement −.19, peer relations −.14, rewards offered −.28. The quotes "more readily controlled by managers", "employees quit bosses, not jobs" and "cannot advise organizations to select individuals based on their age, marital status…" are verbatim ✓. The "workload only problematic…" line is a speculative future-research remark (§2b). Ellis's correction of the journal (Personnel Psychology, not JoM) is right.
- **Podsakoff, LePine & LePine (2007):** the abstract matches what the brief says (challenge → lower turnover, hindrance → higher) ✓. The interpretation's application of it is the problem (§2a).
- **Abstracts verified as described:** Gerstner & Day (1997) (LMX–actual turnover not significant) ✓; Mitchell et al. (2001) (incremental over satisfaction, commitment, alternatives and search) ✓; Jiang et al. (2012) (65 samples, N = 42,907) ✓; Eisenberger et al. (2002) ("completely mediated") ✓; Trevor, Gerhart & Boudreau (1997) (5,143; "extremely high turnover"; promotions positive once salary growth is controlled) ✓; Tett & Meyer (1993) (intentions mediate "nearly all"; single vs multi-item moderator; direction not in the abstract) ✓/partial; Santelli & Grissom (2024) (transfers; district exit at 40+ minutes) ✓; Sengupta et al. (2007) (workplace-level; turnover lower; commitment not associated) ✓ with the caveat in §2f; Yang, Niven & Johnson (2019) (72 sources, 1977–2017; mostly turnover *intentions*) ✓; Price & Mueller (1981) (1,091 nurses, seven hospitals, four largest total effects) ✓.
- **Not checked beyond existence and metadata:** Brown (1996), Williams et al. (2006) "240 samples", Judge & Watanabe quote, Benson et al. (2004) details, Lee et al. (2004), Meyer et al. (2002) POS detail, Ng & Feldman (2009), Dulebohn et al. (2012) detail, Hausknecht et al. (2009), Kossek & Ozeki (1998), Allen et al. (2000), Zimmerman (2008), Barrick & Zimmerman (2005). Allen, Shore & Griffeth (2003) is in the reference list but never cited in the text.
- **JD-R:** not cited in any of Ellis's files, so there's nothing to verify. Add a source if JD-R framing is used.
- **No fabricated or mis-cited references found.**

### 5. Fixes for Ellis (interpretation.md; the brief and map need only the §3 edits)
- E1. Put "fictional IBM teaching dataset, simulated employees" in the title and opening. Frame every literature link as "consistent with (illustrative only)", never confirms or replicates. Update the outdated caveat (now reviewed; CV supports two splits; logistic benchmark 0.86).
- E2. Pay section: replace the train-only 35.2% (n = 165) with test 32.8% (19/58, CI 22.1–45.6%) vs 13.6% (52/383, 10.5–17.4%), or drop it.
- E3. Overtime: correct the hindrance framing (workload is a challenge stressor in Podsakoff et al.'s framework; felt hindrance is unmeasured). Replace "stronger than the meta-analyses…" with the brief's own point that the gap is likely about how the data were generated. Quote Rubenstein's moderator accurately ("other roles", speculative).
- E4. Marital/options: add n, CIs and the "full data" label, plus the p ≈ 0.09 / 0.06. Mark the section exploratory (not CV-supported; synthetic artifact). Drop "separate leavers" and "actionable". Fix the Sengupta characterization and the "unvested equity" assumption.
- E5. Retitle the recommendations "Suggestions (from the literature, illustrated by fictional data; not tested interventions)" per BRIEF.md. Rec 1: drop "hindrance demands". Rec 2: inline the pay/career-stage caveat; Griffeth's fairness point is conjecture. Rec 4: drop or relabel the equity/vesting half.
- E6. Rewrite "did not hold up / absent" per §2d: these failed as tree splits but show additive/bivariate associations in the expected direction (job satisfaction, environment satisfaction, involvement, distance; age via the early-career cluster).
- E7. Add "age and gender are descriptive only" alongside the marital-status note.
- E8. Construct-map edits in §3 (OverTime, MonthlyIncome, EnvironmentSatisfaction, WorkLifeBalance, PercentSalaryHike, StockOptionLevel, DistanceFromHome, the single-item and reliability note, Tett & Meyer direction).

### 6. Framing for Iris
- Literature content can go into the narrative only as "why these patterns would matter in real organizations (research), illustrated by a fictional dataset". It's never evidence that the dataset confirms the research, and never evidence about any real employer.
- Use only the patterns in my surviving-findings list: overtime; overtime + lowest pay, mostly entry-level; the early-career cluster. Single/options and job role are exploratory leads only.
- Mechanisms are phrased as "research suggests…", and recommendations as suggestions, not tested interventions (BRIEF.md).
- No recommendations targeted by age, gender or marital status.

---

## 2026-10-08 (PT) Sign-off check: findings_draft v0.2 + METHOD v0.2

Versions reviewed: `findings_draft.md` mtime 3:36:36 PM PT, sha256 `bf059fda…7d83`; `METHOD.md` mtime 3:36:51 PM PT, sha256 `de174944…43fb`. The tree wasn't refit (`metrics.json` and the CSVs are unchanged since 3:29 PM PT).

**Verdict: APPROVED WITH FIXES (minor, text-only; no further method review needed).** Every number checks against my reproduction. All 9 fixes are applied. Three one-line wording edits are below, one of them correcting my own error.

Checked:
- **Fixes 1–9 applied.**
  - Test-first rates with n and Wilson CIs, and train rates labeled and out of the lead ✓.
  - The 20-seed 1-SE statement (18/20 keep 2 splits, 2/20 root) ✓.
  - Benchmark: logistic 0.863 [0.814, 0.908], CV 0.838 (SD 0.045); 2-split tree 0.669 [0.608, 0.732] vs 0.670 ✓.
  - Stock options one-way, 40.6% (41/101) / 25.6% (11/43) / 13.3% (27/203) with the right CIs ✓.
  - Importance is out of the draft; primary-only shares (29.6 / 16.5 / 10.9 / 8.7 / 8.3 / 6.6 / 6.4 / 4.1 / 3.1 / 2.9 / 2.9) and the bootstrap top-5 appear in METHOD §6 only ✓.
  - JobLevel crosstab (210/10/0/0/0; 333/524/218/106/69) and JL1 35.7% (75/210) vs 20.4% (68/333) ✓.
  - Cutpoint median $2,494, IQR $2,475–2,964 ✓.
  - No-causal wording ✓.
  - Fictional data in the title and all five headlines ✓; sensitive-characteristics and snapshot-timing caveats ✓.
- **Numbers:**
  - Test: 32.5% (37/114) [24.6, 41.5]; 10.4% (34/327) [7.5, 14.2]; 63.2% (12/19) [41.0, 80.9]; 26.3% (25/95) [18.5, 36.0]; no-OT under/over $2,475 17.9% (7/39) [9.0, 32.7] / 9.4% (27/288) [6.5, 13.3]; single 46.2% (12/26) / 18.8% (13/69); role 76.9% (10/13) [49.7, 91.8] / 15.4% (2/13) [4.3, 42.2]; under $1,559 25.0% (2/8) [7.1, 59.1].
  - Full data: 30.5 / 10.4 / 69.6 / 22.8 with their CIs.
  - AUC 0.670 [0.605, 0.737]; CV 0.699 (SD 0.058); balanced accuracy 0.618 at 0.161 (sensitivity 33.8%, specificity 89.7%), 0.578 at 0.5; bootstrap root 44.4 / 30.6 / 15.4; lowest ~15% of earners (220/1,470).
  - All ✓.
- **Data hash:** verified. `d11789e1db393cd1d985ca41a0e73a1d405543fb2c0d540a3b4f7d723bca92f7`, 226,503 bytes, no BOM, LF only (0 CRs), inode 812073, birth time 3:27:19 PM PT. `tail -c +4 mirror | cmp` against the current file shows the files are identical, and the mirror starts EF BB BF and hashes to `e9f55fbf…` ✓.

Remaining edits (Rowan):
- R1. **Cutpoint spread, my error carried forward.** Draft §2 and METHOD §8 say "About 37% of those refits landed at roughly $2,900–4,000". It should be "about 37% landed above $2,700 (clusters near $2,800 and $3,200–4,000)". Only 25% are ≥ $2,900. I've corrected qa_log §2d.
- R2. **"Not carried forward: none of the following holds up on the test set"** should read "none of the following **tree splits** holds up on the test set". Environment satisfaction, job involvement and distance do show bivariate/additive associations (e.g., environment satisfaction level 1: test 26.1% (23/88) vs 13.6% (48/353)), which is part of why the logistic benchmark scores 0.86.
- R3. **METHOD §7** still says "The importance and the single-split scan show **which** variables carry signal". That's outdated given §6. Point it to the two CV-supported splits and the primary-only shares (record only).
- Optional: add n to the full-data no-OT contrast (28/151 vs 82/903), and note that the stock-option contrasts aren't statistically clear (p ≈ 0.09 and 0.06).

After R1–R3, findings_draft v0.2 is cleared for Iris, limited to the surviving-findings list (cutpoint wording per R1).

---

## 2026-10-08 (PT) Re-check: Ellis interpretation v2

Versions reviewed (unchanged when I finished):
- `research/interpretation.md`: mtime 3:40:56 PM PT, sha256 `207de0e4…91a9`, 11,615 bytes.
- `research/variable_construct_map.csv`: mtime 3:41:12 PM PT, sha256 `3a705a0d…0529`, 7,840 bytes.
- `research/attrition_drivers.md`: mtime 3:41:23 PM PT, sha256 `3b8ae76a…bdf4`, 42,765 bytes. I diffed it against the 3:33 PM PT version I reviewed: 9 targeted edits, nothing else changed.

**Verdict: APPROVED WITH FIXES (two wording edits, no re-review needed).** All 8 fixes (E1–E8) are applied, and every number matches my reproduction. Two sentences still overclaim, both listed below. Once those are fixed, Iris can use the interpretation, framed as in §6 of my earlier entry.

### Fixes E1–E8
- **E1 (fictional label, illustrative framing, caveat):** ✓
  - The title reads "Fictional IBM teaching dataset (simulated employees)". The opening box quotes the Kaggle card.
  - Literature links are marked "consistent with (illustrative only)": pay, career stage, work–family conflict, March & Simon / equity, marital/options, job role (as "consistent-with reading only"), the non-split variables, and the Suggestions header.
  - The caveat is updated: the tree has been reviewed, CV supports 2 splits, and the logistic benchmark is 0.863 [0.814, 0.908].
- **E2 (pay section):** ✓ The training-only 35.2% is gone. It now gives test 32.8% (19/58) [22.1, 45.6] vs 13.6% (52/383) [10.5, 17.4], and full data 34.5% (76/220) vs 12.9% (161/1,250). All match.
- **E3 (overtime):** ✓ Accurate to the sources.
  - It says workload and time pressure are challenge stressors in Podsakoff et al. (2007), linked to lower turnover, and that felt hindrance is unmeasured.
  - It cites Rubenstein's workload ρ −.10.
  - It says the gap from the literature reflects how the synthetic data were generated.
  - The Rubenstein quote is verbatim (checked against the PDF), labeled as speculation, and correctly says "other roles … not other work pressures such as low pay".
- **E4 (marital/options):** ✓
  - It's marked exploratory and labeled full data.
  - Table: 41/101 40.6% [31.5, 50.3]; 11/43 25.6% [14.9, 40.2]; 27/203 13.3% [9.3, 18.7]. Fisher p = 0.09 and 0.06 (mine: 0.092, 0.061). All match.
  - "Actionable" and "separate leavers" are gone. The side-bet reading is marked "cannot be tested here", and the coding and vesting as undocumented.
  - Sengupta is no longer cited here. It's correctly re-described in the brief (workplace-level, no link to commitment).
- **E5 (Suggestions per BRIEF.md):** ✓
  - Retitled "Suggestions (from the literature, illustrated by fictional data; not tested interventions)", with "These are not results".
  - #1 carries the challenge-stressor caveat. #2 carries the pay/career-stage caveat and labels Griffeth's point as the authors' conjecture ("Conceivably").
  - #4 is offered to a whole group and "never target by marital status, age or gender". No suggestion is aimed at a protected group. The equity/vesting suggestion is dropped.
- **E6 ("did not hold up"):** ✓ Retitled "Variables not supported as tree splits"; it says they failed only as splits but show bivariate/additive associations. Figures match `qa_checks3.out`:
  - Job satisfaction 22.8 / 16.4 / 16.5 / 11.3%; test 18/79 (22.8%) vs 53/362 (14.6%).
  - Environment satisfaction level 1 25.4% vs 13.5–15.0%; test 23/88 (26.1%) vs 48/353 (13.6%).
  - Age under 30, test 30/100 (30.0%) vs 41/341 (12.0%).
  - Logistic p-values: the six variables p < 0.001, WorkLifeBalance 0.03.
  - Other numbers also match: 63% (12/19) [41, 81] vs 26% (25/95) [18.5, 36.0]; 69.6% (n=69) / 22.8% (n=347); 32.5 / 10.4; bootstrap root 44.4 / 30.6; job role 76.9% (10/13) [49.7, 91.8] vs 15.4% (2/13) [4.3, 42.2], training 22/37 and 7/38; 470 / 161; 95% JobLevel 1; AUC 0.670 [0.605, 0.737].
- **E7 (age/gender):** ✓ "Marital status, age and gender are descriptive only" in the marital section; age is also flagged "descriptive only" in the non-split section.
- **E8 (construct map and brief):** ✓
  - The `_NOTE` row explains that the map labels constructs, it doesn't validate measurement: single items, unknown reliability, generated values.
  - Row edits: OverTime (job-demand proxy, "do not label it a hindrance"); MonthlyIncome (confounded with job level); EnvironmentSatisfaction (not a climate measure); JobSatisfaction / JobInvolvement / RelationshipSatisfaction / WorkLifeBalance (single item; balance is not simply the mirror image of conflict); PercentSalaryHike ("procedural" dropped, weak proxy); StockOptionLevel (coding undocumented, untestable); DistanceFromHome (weak proxy, distance isn't travel minutes). Tett & Meyer direction softened to "can differ".
  - The brief gets matching IBM notes, plus a corrected §5 template for overtime.

### Remaining fixes (Ellis, wording only)
- **F1.** Pay section: "In this dataset, **low income is the same thing as being early in one's career**" overclaims in the other direction. The two overlap heavily but aren't identical: within JobLevel 1, under $2,475 is 35.7% (75/210) vs 20.4% (68/333) (qa_log §2c). Change to "low income largely overlaps with being early in one's career and can't be cleanly separated from it".
- **F2.** Marital section: "Rubenstein et al. (2018) advise against using **such characteristics** in personnel decisions" is right for age and marital status, but the source quote ("cannot advise organizations to select individuals based on their age, marital status, or how many children they have") doesn't mention gender. Either quote it exactly, or keep the gender point as the team's own rule, not Rubenstein's.
- **Optional:**
  - "Research suggests two reasons pay **matters**": change to "could matter".
  - "Two pieces of research **cut against a simple 'overtime causes leaving' story**": change to "would not predict a large overtime effect".
  - "This additive signal is **why** a logistic model reaches…": change to "helps explain why".

### The `_NOTE` row in variable_construct_map.csv
- **Nothing in the project reads this file**, including the parts added since my last check: `app.R`, `R/partition.R`, `tests/smoke.R`, `deliverables/build/make_chart.py`, `README.md`. The only mentions are prose references in `attrition_drivers.md` and this log. `read_hr_csv()` and the app only read the attrition data file and user uploads.
- It parses cleanly: R `read.csv` gives 35 × 4, and Python `csv` gives 36 rows, all with 4 fields.
- Its `dataset_variable` value (`_NOTE (applies to all rows)`) matches no data column. Any future join would simply leave it unmatched. Any future code that loops over map rows as dataset columns should filter rows starting with `_`. The file is tracked in the git repo, which will be public.

### Side note
`findings_draft.md` / `METHOD.md` are now v0.3 (mtime 3:40:15 PM PT). I spot-checked my R1–R3: "above $2,700, clustered near $2,800 and $3,200–4,000" is in both files; "None of these tree splits holds up"; and the outdated METHOD §7 importance sentence is gone. v0.3's header says I approved v0.2 plus the three wording fixes. That's accurate per my sign-off entry, which required R1–R3 and no further method review.

## 2026-10-08 (PT) Number check: Iris attrition narrative v1

Versions reviewed (checked 3:46–3:50 PM PT; none changed while I worked):
- `deliverables/attrition_narrative_v1.pdf`: mtime 3:45:37 PM PT, sha256 `5f500a46…22a8`, 138,811 bytes, 2 pages (letter).
- `deliverables/attrition_narrative_v1.docx`: mtime 3:45:36 PM PT, sha256 `e387c897…9675`. Its text matches the PDF word for word.
- `deliverables/attrition_narrative_v1_p1.png` / `_p2.png`: mtime 3:45:38 PM PT (sha256 `f21451cc…fb5fc` / `feec47b7…ddf65`).
- `deliverables/build/make_chart.py` and `chart_attrition_fictional.png`: mtime 3:44:44 PM PT. `build_docx.py`: 3:45:36 PM PT.
- Sources: `findings_draft.md` / `METHOD.md` v0.3 (3:40:15 PM PT); `metrics.json` (3:29:12 PM PT); `tree_rules.txt` (3:29:04 PM PT); `research/interpretation.md` (3:43:18 PM PT, sha256 `14b862be…e1a19`).
- Data sha256 `d11789e1…2bca92f7` ✓ (matches the expected hash).

**Verdict: APPROVED WITH FIXES (wording and labelling only, no re-check of numbers needed).** Every number reproduces (R, seed 20261008, same stratified 70/30 split, same rpart settings). The chart and framing meet the brief. Five small required fixes are listed below.

### Reproduction (all ✓)
- 1,470 / 237 / 16.1%. Test n = 441 (train 1,029).
- Overtime: test 37/114, 32.5% [24.6, 41.5] vs 34/327, 10.4% [7.5, 14.2]. Ratio 3.12, so "about 3 times" ✓.
- Overtime and under $2,475: 12/19, 63.2% [41.0, 80.9] vs 25/95, 26.3% [18.5, 36.0].
- No overtime, at the $2,475 cut, test: 7/39, 17.9% [9.0, 32.7] vs 27/288, 9.4% [6.5, 13.3] ✓ (full data 18.5% / 9.1%).
- Under $2,475: 220/1,470 = 15.0% of the full data (13.2%, 58/441, in the test set). $2,475 sits at the 15th percentile, so "lowest ~15% of earners" ✓ (full data).
- JobLevel crosstab (full data): 210 of the 220 under $2,475 are JobLevel 1. The denominator is the 220 under $2,475, full data. In the test set it is 57 of 58.
- Within JobLevel 1 (full data): 75/210, 35.7% [29.5, 42.4] vs 68/333, 20.4% [16.4, 25.1] ✓. The 333 are JobLevel 1 employees at $2,475 or more, not the whole dataset.
- Cutpoint: split $2,475; ~37% (68/185) of bootstrap income cuts fall above $2,700 (qa_log §2d) ✓. "About $2,500" wording is used throughout ✓.
- Tree test AUC 0.670; logistic regression 0.863 (refit) ✓. At the training base-rate threshold of 0.161, the tree flags 24/71 = 33.8% of test leavers (test-set recall, = `metrics.json` sens 0.338) and clears 89.7% of stayers ✓.

### Chart (PDF-embedded image = build PNG, rescaled)
✓ Three test-set groups. Bars start at 0 and are proportional. Wilson whiskers match the CIs (7.5–14.2, 18.5–36.0, 41.0–80.9). One accent (#C0504D) on overtime under about $2,500, with the rest gray. Direct value labels and n labels ("12 of 19 left" etc.). Takeaway title with "In fictional data". The subtitle says "held-out test set (441 of IBM's 1,470 fictional employees)" and "smallest group has only 19 people". There is no axis, which is acceptable because the values are labelled directly.

### Framing
✓ "Fictional" is in the title, all four headings and the footer. Literature is framed as illustration only. Recommendations are "suggestions, not tested interventions". The age/gender/marital guardrail is present, and the Rubenstein quote covers only age, marital status and children; gender is stated as the team's own rule. Single/stock options and job role appear only as "leads to check, not findings". There are no importance percentages and nothing deeper than the two splits. Pay vs career stage "largely overlaps … not quite the same thing". The tree is described as a coarse description and the logistic regression as stronger. There is no causal language: "because" appears only once, in L67 about entanglement, and is not a causal claim about leaving. Rate fields are excluded (L16).
- I checked `interpretation.md` 3:43 PM PT against my earlier F1/F2. Both are applied (L25 "largely overlaps with, and can't be cleanly separated from"; L69 quote limited to age, marital status and children, with gender as the team's rule). All three optional edits from that entry are also in (L19, L37, L90).
- The quote "many other predictors more readily controlled by managers can be more important than pay" is verbatim per `attrition_drivers.md` L30 ✓.

### Required fixes (Iris)
- **N1. p1 L34–35:** "against 20.4% (68 of 333) across the full dataset" reads as if 20.4% were the whole dataset's rate (that rate is 16.1%). Change to: "within JobLevel 1, those paid under $2,475 still left at 35.7% (75 of 210), against 20.4% (68 of 333) of better-paid JobLevel 1 employees (full data)."
- **N2. p1 L31–32:** the count is full data and unlabelled, while the footer says "test-set unless noted". Change to: "of the 220 employees under $2,475 in the full dataset, 210 are at JobLevel 1."
- **N3. p1 L6 (subtitle):** "Every figure describes 1,470 simulated employees" contradicts the test-set figures (441) and the chart subtitle. Change to: "A narrative summary for HR and business leaders. Every figure describes simulated employees in a dataset IBM created for teaching (1,470 in all; most rates use the 441 held back for testing), not real people and not any real employer."
- **N4. p2 L76–77:** "the strongest signals, such as intentions to leave and outside options (Rubenstein et al., 2018)" is wrong on outside options. In Rubenstein the strongest are withdrawal cognitions (ρ = .56) and job search (ρ = .40); alternatives are ρ = .23 (`attrition_drivers.md` §2.17, L156). Change to: "Real HR files also usually lack what research rates as the strongest signals, intentions to leave and job search (Rubenstein et al., 2018), and rarely record employees' outside job options."
- **N5. p1 top:** remove the "DRAFT, pending QA number check" banner once N1–N4 are made.

### Optional
- O1. p1 L25: add n and CIs: "17.9% (7 of 39; CI 9.0–32.7%) versus 9.4% (27 of 288; CI 6.5–13.3%)".
- O2. p2 L49: change "the kind of overtime likely matters" to "the kind of overtime may matter". The data say nothing about the kind of overtime.
- O3. p2 L74: change "Use better-calibrated models" to "Use stronger, properly validated models". The tree's weakness is discrimination (AUC), and the logistic model's calibration wasn't reported.
- O4. p1 L41: add the one-way nuance: "(every single employee here has no stock options, though many married or divorced employees have none either)".
- O5. p1 L10–12: "practise" ×2 → "practice", to match the US spelling elsewhere.
- O6. p1 L39: "flagged only 33.8% of leavers" → "flagged only 33.8% of test-set leavers (24 of 71)".
- O7. p1 L17: "held up under cross-validation" → "were supported by cross-validation (in 18 of 20 reruns)".

---

## 2026-10-08 (PT) App review: attrition tree v2 (bee19a1)
Reviewer: Quinn (executor), 7:28 PM PT. Branch `app-v2` at bee19a1 vs `main` f2d2a49, working copy `/workspace/projects/ibm-hr-attrition-app-v2`. Soup's files were not edited. (Note: the box clock runs in HST, UTC-10; times here are converted to PT.)

**Verdict: APPROVED WITH FIXES.** The numbers are correct and unchanged from v1. The display overstates in two places (headline label and accent color on exploratory groups).

### 1. Code diff (bee19a1 vs main)
- Unchanged: `R/partition.R` (empty diff: split search, impurity, improvement, auto_grow, used_importance, predict_leaf_prob, classification_metrics, read_hr_csv, column_type, default_predictors), `data/` (CSV SHA-256 d11789e1…92f7 ✓), `tests/smoke.R`, `install.R`.
- `app.R` data loading: `bundled_csv_path()` identical; `dataset()` and `model_data()` identical except `validate` → `shiny::validate`, `out$message` → `conditionMessage(out)`, and a new `bundled` flag.
- Non-UI logic changes (all call the unchanged engine):
  1. `starter_tree()`: default view auto-splits the root, then the higher-rate child (on IBM data = OverTime, then MonthlyIncome < 2475).
  2. `split_best()`: refactor of Auto-split, same call chain as v1 (candidate_splits → first eligible → attach_rows → apply_spec_split), same root-impurity total.
  3. `ctrl()`: null-safe defaults (gini, 20, 7, 5, 0.01) for control inputs.
  4. Undo history (30 states).
  5. `R/presentation.R` (new): `path_conditions`, `headline_leaf` (highest-rate leaf with n ≥ max(20, minbucket)), `flagged_leaves` (rate ≥ slider), `validation_status` (hard-codes OverTime, optionally + MonthlyIncome cut exactly 2475, bundled data only), `node_export_table` (new CSV export).
  6. Highlight slider auto-resets to round(2 × base rate) = 32% on each data/target change.
  7. New `tests/regression_snapshot.R`; new exports (all-nodes CSV, per-node predictor CSV).
- No change to what any split, count, rate, improvement or metric computes.

### 2. Reproduction
- Snapshot SHA-256: all 7 files byte-identical v1_before vs v2_after (snapshot.json 49be88b9…, root_candidates 854c6d24…, overtime_yes_candidates e8dcf733…, two_split_nodes eab2a60e…, auto_tree_nodes 5b899a1e…, auto_tree_leaves 70ccecbc…, auto_tree_importance 39a5f006…).
- I re-ran `tests/regression_snapshot.R` on bee19a1 and on a detached f2d2a49 worktree (removed afterwards): both reproduce Soup's files byte-for-byte; `engine==server TRUE`.
- Independent R (engine functions + raw counts), Wilson 95%:
  - All: 237/1,470 = 16.1% (14.3–18.1).
  - OverTime Yes 127/416 = 30.5% (26.3–35.1); No 110/1,054 = 10.4% (8.7–12.4).
  - OverTime & income < $2,475: 48/69 = 69.6% (57.9–79.2); ≥ $2,475: 79/347 = 22.8% (18.7–27.5). (No incomes between 2,472 and 2,478 in this branch.)
  - Full auto tree: 21 nodes, 11 leaves, in-sample AUC 0.7464; primary-split importance matches (MonthlyIncome 23.9%, OverTime 22.9%, …).
- `tests/smoke.R` passes. App starts headless (`shiny::runApp`, HTTP 200).
- All match findings_draft v0.3 full-data lines and §4 of the method review.

### 3. Against the approved findings
- Approved headline is the **test-set** figure: 63.2% (12/19, CI 41.0–80.9) under "about $2,500"; 69.6% is the full-data, in-sample figure that "includes the training rows the cutpoint was chosen on".
- The app's eyebrow "Highest-rate group · validated split (Quinn)" sits directly above "…under $2,475 a month left at 69.6%". The subline says "48 of 69 … in-sample, fictional data" in small gray. A reader will take 69.6% and the exact $2,475 as the validated result. This overstates: the split is validated, the 69.6% and the $2,475 are not.
- Model fit tab: AUC 0.746 is clearly labelled ("In-sample fit · not a held-out estimate", "on the data it was grown on"). Acceptable; adding the held-out figure is optional.
- `validation_status`: marks validated only for OverTime alone or OverTime=Yes + income cut exactly 2475, bundled data. Both sides of each validated split get the pill (OverTime=No; OverTime=Yes & ≥ $2,475), which is acceptable. Deeper nodes are "Exploratory". ✓

### 4. Display
- Default view (desktop and mobile): mostly gray, one accent (#C2410C), only the 69.6% leaf and its path accented. ✓ Direct labels, takeaway title. ✓
- **Full tree (desktop_05):** the 32% threshold accents 6 exploratory leaves (90.3% n=31, 88.9% n=9, 78.9% n=19, 76.3% n=38, 37.3% n=51, 33.3% n=24) and their branches. The headline becomes "Overtime workers earning under $2,475 a month with EnvironmentSatisfaction: 1, 3 left at 90.3%" with 90.3% in accent. The eyebrow says exploratory, but the accent signals "this matters" on findings the method review rejected (EnvironmentSatisfaction is on the "not for Iris" list). Violates "one accent only for what matters".
- Threshold: legend says "End group at 32% or more"; the reason (≈2× the 16.1% base rate) is not shown.
- Fictional banner: visible on desktop (full text) and mobile (tag "FICTIONAL" + "Synthetic IBM teaching dataset."). Validated-findings note visible on both. ✓
- Causal wording: none found in app.R, presentation.R, app.js. README L20 says "higher-risk branch" (minor).
- Age/Gender/MaritalStatus: available as predictors (as in v1 and the analysis); importance pop-up ranks all 27 as "a search aid, not a validated ranking". No targeting text. But no sensitive-characteristics caution anywhere in the app or README (required by the 2026-10-08 method review §0 for every public artifact; pre-existing gap from v1).
- Importance: primary-split only, labelled in pop-up, preview and Model fit tab. ✓ No deeper splits presented as findings except via the accent/headline issue above.

### Required fixes (Soup)
- **A1. Takeaway for validated groups (app.R `output$takeaway`, ~L700–718).** When `status == "validated"` on bundled data, render:
  - Eyebrow: "Highest-rate group · validated split (Quinn) · rate shown is in-sample"
  - Title: "Overtime workers earning under about $2,500 a month: 69.6% left (all 1,470, in-sample)"
  - Subline: "48 of 69 (95% CI 57.9–79.2%) · 4.3× the 16.1% overall rate · fictional data. Validated figure, held-out test set: 63.2% left (12 of 19, CI 41.0–80.9%). The exact cut here is $2,475; refits vary, so read it as about $2,500."
  - For the OverTime-only node: "Held-out test set: 32.5% (37 of 114, CI 24.6–41.5%) vs 10.4% (34 of 327, CI 7.5–14.2%)."
  - Keep the exact "$2,475" in node boxes, edges, paths and exports.
- **A2. Accent only for validated groups (presentation.R `tree_vis_data` / `flagged_leaves`; app.R `output$takeaway`, `output$node_card`).** Accent fill and accent edges only for leaves with `validation_status == "validated"` and rate ≥ threshold. Exploratory leaves at or above the threshold: gray fill with a dark (#1F2937) 2px border, no accent. Exploratory headline number: INK, not accent. Legend: "Validated group at 32% or more" (accent swatch) and "Exploratory group at 32% or more (not validated)" (dark-border swatch).
- **A3. Explain the threshold (legend + slider label).** Slider label: "Highlight end groups with a rate of at least (default: about 2× the overall rate)". Legend accent item: "Validated group at 32% or more (about 2× the 16.1% overall rate)" (compute from base rate).
- **A4. Sensitive-characteristics caution (About tab "Data" section and README).** Add: "Age, gender and marital status are included only to describe this fictional dataset. Do not use splits on them, or on proxies for them, to select, rate or target real employees."

### Optional
- O1. Model fit takeaway subline: "Deeper trees always look better here. Only the first two splits are validated. For comparison, the held-out test AUC of the analysis tree was 0.670 (logistic regression 0.863)."
- O2. Exploratory headline: replace raw "EnvironmentSatisfaction: 1, 3" with "… (exploratory, in-sample; not validated)" at the end of the title, or keep the headline on the highest-rate *validated* group when one exists and show the exploratory maximum as a secondary line.
- O3. README L20: "higher-risk branch" → "higher-rate branch"; README example headline to match A1.
- O4. Headline minimum n: consider max(30, minbucket) so n=19–31 leaves don't headline; or add the n and a Wilson CI to every headline.
- O5. Mobile banner: append "Not real people." to the short text so the meaning survives truncation.

### Correct
- Engine, data file and data loading unchanged; all 7 snapshots byte-identical and independently reproduced on v1 and v2.
- All key numbers reproduce (16.1%; 30.5% vs 10.4%; 69.6% vs 22.8% at $2,475; AUC 0.746; 21 nodes/11 leaves).
- Default view = the two validated splits; only the 69.6% group accented there.
- Validated/exploratory tagging logic is narrow and correct.
- Model fit tab clearly labelled in-sample.
- Importance primary-split only and labelled; no importance shown as a finding.
- Fictional banner and validated-findings note visible on desktop and mobile; no causal wording.
- Smoke test passes; app starts headless.

## Agreed minimum-sample rule for executive highlights (Quinn + Rowan), Oct 8, 2026 (late evening)
Reason: CEO said the headline group (overtime and under about $2,500, n=69, 4.7% of staff) was too small to act on.
A pattern may be highlighted to executives only if, on the full 1,470 rows:
1. Size: at least 100 employees (about 7%) AND at least 24 leavers (10% of 237).
2. Rate: at least 1.5x the company rate (16.1%), lower end of the 95% Wilson interval above 16.1%, same direction in the held-out test set (at least 30 employees there).
3. Impact: (group leavers - group n x 16.1%) / 1,470, shown in points and people, labelled as an illustration; never summed across overlapping groups.
4. Tree depth cap 3, pruned so every leaf is large enough. Misses are left out or labelled "too small to act on" (appendix only).
Executive page: plain language, no CIs or cross-validation; detail in a technical appendix in the repo.
Status: proposed by Quinn, Rowan's proposal merged (Rowan used 5%/74; Quinn set 100). Awaiting Rowan's revised pattern list for review.

## Review: exec findings under merged minimum-sample rule (Oct 8, 2026, 11:56 PM to 12:05 AM PT)
Reviewer: Quinn (executor). Box clock is PDT (`date` reports PDT), so the times below are already PT; no HST conversion was applied.
**Verdict: APPROVED WITH FIXES.** Every number reproduces exactly. Overtime is cleared. "Lower-paid staff" should **not** be a second cleared pattern: it fails rule 4 when read at the group/top-level, its impact sits almost entirely inside overtime, and it is the same people as JobLevel 1, which fails. It should appear only as plain-language context, with no impact figure. The executive page needs restructuring (What / So What / Not What) and some wording fixes.

### Files reviewed (mtime PT, SHA-256 prefix). None changed during the review.
- analysis/exec/: run_exec.R 11:55:14 PM (21e1c1ee5283), thresholds.json 11:55:14 PM (224e9eae4ce0), exec_tree_rules.txt 11:55:14 PM (ba59af017528), candidates.csv 11:55:28 PM (decfd385c668), overlap.csv 11:55:28 PM (eccfc50638dd), overlap_nonsurvivors.csv 11:55:28 PM (4704914707e3), threshold_sensitivity.csv 11:55:28 PM (7f28e2f36a48), exec_results.json 11:55:28 PM (9c87489f8cef), appendix_tables.md 11:55:28 PM (f1e2f7468da3), exec_tree.png 11:55:28 PM (0b4b01e820dc), exec_findings_draft.md 11:55:37 PM (781f5faa339f), README.md 11:55:59 PM (89bbb05c0558), technical_appendix.md 11:56:05 PM (b7e5519c5c54).
- Reference files: findings_draft.md and METHOD.md 3:40:15 PM; metrics.json 3:29:12 PM.
- Data: SHA-256 d11789e1…a92f7 ✓.

### 1. Reproduction ✓
- Re-ran run_exec.R in a copy (/tmp/qa_exec, about 15 s). All 9 generated outputs are byte-identical to Rowan's (same SHA-256), including the PNG.
- Independent R recompute (analysis/qa/exec_review_check.R → .out): all 39 distinct candidates match on n, leavers, lift, Wilson lower bound, test n and leavers, impact to the average, and impact to the outside rate. The remaining 4 candidates are tree nodes identical to OverTime yes/no.
- Re-applying the rule gives the same verdict as candidates.csv for every candidate.
- Base figures: 1,470 / 237 / 16.12%; test set 441 / 71 / 16.10%.
- Overtime: 416, 127 leavers, 30.5%, lift 1.89, test 37/114, impact 4.08 pts / 59.9 people (5.69 / 83.6 using the outside rate of 10.44%) ✓.
- Lower-paid: 472, 128 leavers, 27.1%, lift 1.68, test 40/140, impact 3.53 / 51.9 (5.20 / 76.4, outside rate 10.92%) ✓. 449/472 are JobLevel 1; median age 31 vs 38 ✓.
- Overlap 132 employees / 73 leavers. Union 756 (51.4%), 182 leavers (76.8%), 24.1%, impact 4.09 / 60.1 ✓. The separate impacts would sum to 111.9 people.
- Boundaries:
  - Training node (overtime and under $2,807) has 99 employees and fails size; it also fails test n (27). Age <25 (97) and overtime and under-30 (94) fail size.
  - Lab tech lift is 1.4848 and fails. SOL0 (1.514), age <33.5 (1.524) and travel (1.545) pass rule 2. All are applied correctly.
- The Wilson check changes no verdict: every group with lift ≥ 1.5 has a lower bound ≥ 20.2%. The agreed rule makes Wilson an appendix check, but thresholds.json and the code use it as a pass condition. Relabel it; no outcome changes.

### 2. Stability (the judgment call)
- Rule 4 as coded is **variable-level**: "MonthlyIncome is a primary split anywhere, at any cut, in any branch." That is why every income band (<2,500, 3,000, 3,500, 4,000) gets the same 52.2%.
- Where the income splits sit across the 500 refits:
  - Anywhere: 52.2%.
  - At nodes 1–3: 45.4%.
  - At the root: 16.8%.
  - Inside the overtime = Yes branch: 27.8% (only there: 27.6%).
  - Inside the no-overtime branch: 0.2%.
  - A company-wide pay split (the root, or both overtime branches): 17.0%.
  - So most of the 52.2% supports overtime × pay (which itself fails, at 43.2%), not company-wide lower pay.
- Pay and job level are substitutes (correlation 0.95). Income or JobLevel is a split in 69.8% of refits, yet JobLevel 1 (543 people, 449 of them shared with lower-paid) fails at 17.8%. The rule therefore treats the same people inconsistently.
- **Fixed-band group-level robustness is strong** (2,000 bootstrap resamples of the full data):

  | Band | Share of resamples with lift ≥ 1.5 | Test rate vs rest |
  |---|---|---|
  | <2,500 | 100% | 32.8 vs 13.6 |
  | <3,000 | 99.7% | 32.1 vs 10.6 |
  | <3,500 | 97.9% | 28.6 vs 10.3 |
  | <3,750 | 93.4% | |
  | <4,000 | 81.0% | 26.6 vs 10.2 |

  - The rate is higher below the cut in 100% of resamples at every band, and training and test agree.
  - Log income alone: OR 0.40 per log unit (p < 1e-13).
- **Confound with JobLevel 1:**
  - Within JobLevel 1: <2,475 gives 35.7% (75/210) vs 20.4% (68/333) ✓ (matches the earlier result). <3,500 gives 28.3% (127/449) vs 17.0% (16/94); in the test set, 29.6% (40/135) vs 16.0% (4/25).
  - Low pay adds modestly beyond JobLevel 1: OR 1.57 (p = 0.07), adjusted for JobLevel 1 as a dummy. Within JobLevel 1, the continuous log income OR is 0.26 (p = 0.0002).
  - Outside JobLevel 1 there are only 23 lower-paid employees, 1 of whom left.
  - Conclusion: "lower-paid" is about 95% a restatement of "lower-paid junior staff". A real pay gradient exists inside JobLevel 1, but pay and career stage cannot be separated.
- **Pay × overtime:**

  | | Low pay (<3,500) | Higher pay |
  |---|---|---|
  | Overtime | 55.3% (73/132) | 19.0% (54/284) |
  | No overtime | 16.2% (55/340) | 7.7% (55/714) |

  - The same ordering holds in training and test.
  - Of the lower-paid group's 51.9 excess leavers over the average, 51.7 are overtime workers. That is why the union impact (60.1) is roughly overtime alone (59.9).
- **Forking paths:** if rule 4 were switched to a group-level bootstrap to rescue lower-paid, JobLevel 1 (95.5%), YearsAtCompany <2, new manager, TWY ≤3, age <30 and the overtime combinations would all clear too (all ≥ 95%). The page would change substantially, so switching the reading after seeing the results is not defensible.
- **Ruling: one cleared pattern (overtime).**
  - Rule 4 is read as **a primary split at nodes 1–3 in more than 50% of refits**. On this reading overtime is at 78.6% and income at 45.4%; no other candidate changes status.
  - Lower pay and career stage go on the executive page as context only. The association is robust, so it should not be hidden, but it is not cleared as a separate pattern and gets no impact figure.

### 3. The $3,500 anchor
- The refit median ($3,473.5) pools mostly within-overtime splits.
- Company-wide (root) income cuts have median $2,516 (IQR $2,442–2,805).
- "About $3,500" is not a precise anchor. The defensible statement is the range: the association holds for any line from about $2,500 to $4,000. Use "lower-paid staff (roughly the bottom third, under about $3,000–$4,000 a month)". Keep the fixed <3,500 band for the numbers, stated in the appendix as a round cut in the middle of the stable range.

### 4. Executive page
- Numbers and rounding ✓.
- Fictional label ✓; no CIs or cross-validation figures ✓; impacts labelled as illustrations ✓; overlap explained ✓; nothing targets age, gender or marital status ✓; small groups handled ✓.
- Problems:
  - (a) No What / So What / Not What structure.
  - (b) "analyses run on resampled data rarely produced them" is technical.
  - (c) "They largely overlap the two groups above" overclaims: frequent travel (51%) and environment satisfaction 1 (46%) are largely different people.
  - (d) "Entry-level staff" is listed as not cleared while lower-paid (95% entry-level) is cleared, which contradicts itself.
  - (e) The headline "about three in four of everyone who left" needs "about half of all staff" beside it.
  - (f) The lower-paid impact reads as a separate lever, but it is almost entirely overtime workers.
  - (g) The page gives two illustrations per group; one is enough for executives.

### 5. Method notes
- The anova (Brier) rate tree is defensible for estimating rates: the split criterion equals Gini for 0/1. It is disclosed.
- The appendix should say plainly that the anova tree was adopted after the class tree pruned to the root.
- The stability shares are somewhat optimistic: bootstrap duplicates fall into both training and validation folds, which keeps more splits.
- The test checks for data-driven cuts (inc_boot, twy_boot, age_boot) and for full-tree nodes are not independent, because the cuts came from full data. This is mitigated for income: the training-only rate is 26.5% vs 11.2%.
- The 43 candidates were chosen with knowledge of the earlier analysis. About 25 pass rules 1–3, so the stability rule is the main guard against multiple comparisons. Disclose this.
- The rule is applied by one function to all 43 candidates, regardless of outcome ✓.

### Required fixes (Rowan): F1–F9 as relayed in Quinn's message. Iris holds until they are in.
- **F1, rule 4 reading.** Primary split at nodes 1–3 in more than 50% of refits. Update thresholds.json, appendix §1 and §5, and candidates.csv: inc_boot and the three bands become "passes size and lift, not stable as a split".
- **F2, page structure.** Restructure the executive page into What / So What / Not What, with overtime as the single cleared pattern.
- **F3, pay context.** Pay and career stage become one context item, with no impact figure (wording in Quinn's reply). Remove "entry-level staff" from the not-cleared list, because it is folded into this item.
- **F4, resampling wording.** Replace "analyses run on resampled data rarely produced them on their own" with "these did not hold up consistently when we re-ran the analysis on reshuffled versions of the data".
- **F5, overlap claim.** Replace "They largely overlap the two groups above" with "Most of them overlap heavily with overtime workers or with lower-paid, junior staff; frequent travel and low environment satisfaction are largely different people".
- **F6, one illustration.** Keep one illustration per cleared group (the company-average one), stated as 16% → about 12%. Move the "everyone outside" version to the appendix.
- **F7, Wilson.** Relabel Wilson as an appendix check, not a pass condition, in thresholds.json, the code comment and appendix §1. No verdict changes.
- **F8, appendix disclosures.**
  - The stability measure is variable-level, not group-level, with the income location breakdown.
  - Root income cuts have a median of about $2,516; the $3,473.5 refit median is dominated by splits inside the overtime branch.
  - The test checks for data-driven cuts and full-tree nodes are not independent.
  - The anova tree was adopted after the class tree pruned to the root.
  - The bootstrap and CV duplicates make stability somewhat optimistic.
  - The 43 candidates were informed by the earlier analysis (multiple comparisons).
  - Add the pay × overtime 2×2 and the JobLevel 1 × pay table.
- **F9, pay wording.** Replace every "under about $3,500" on the executive page with "roughly the bottom third of earners (under about $3,000–$4,000 a month)".

## Number and wording check: Iris exec narrative v3 (Oct 9, 2026, 12:11 to 12:13 AM PT)
Reviewer: Quinn (executor). Times are PT (`TZ=America/Los_Angeles`; this shell's default `date` printed HST, so every time below was converted to PT).

**Verdict: APPROVED WITH FIXES.** Every number matches the cleared page and my R reproduction. Structure, chart and fictional-data label meet the CEO's standards. The fixes are wording: the Rubenstein "overtime is a weak predictor" sentence (Iris's question), two over-firm research sentences, one dropped clause in the pay context, and accent colour on the list numerals. Research paragraph, suggestions and footer sources stay PROVISIONAL until Ellis's re-tie.

### Files reviewed (mtime PT, SHA-256 prefix). Iris's files were not edited.
- deliverables/: attrition_narrative_v3.docx 12:10:53 AM (d8c0e68fb82c), .pdf 12:10:54 AM (860d7c80f791), _p1.png 12:10:55 AM (6058aeb557e1), _p2.png 12:10:55 AM (2ba79f9d026a); build_v3/charts_v3.py 12:09:54 AM (4e413995507b), overtime_chart_v3.png 12:09:55 AM (dac5f707ae64), numbers_strip_v3.png 12:09:55 AM (70f67c759555), build_v3.py 12:10:53 AM (bc6f8eabff14).
- Sources: analysis/exec/exec_findings_draft.md 12:06:58 AM (fa103bb47e26; current version, draft banner gone, "QA-cleared" line present), technical_appendix.md 12:06:58 AM (60797c64e26a), exec_results.json 12:06:58 AM (860b6c1e97c2), candidates.csv 12:06:57 AM (c950dbafa423). research/interpretation.md, attrition_drivers.md, variable_construct_map.csv 4:15:34 PM Oct 8; BRIEF.md 4:18:28 PM Oct 8.
- Data SHA-256 d11789e1…a92f7 ✓.
- PDF and docx text are identical apart from &amp; encoding. PDF: 2 pages, letter.

### 1. Numbers (R reproduction from the CSV) ✓
- 1,470 / 237 / 16.12% → "16%" ✓.
- Overtime 416 (28.30% → "28%"), 127 leavers, 30.53% → "31%"; no overtime 10.44% → "10%"; ratio 2.93 → "about three times" ✓; 53.59% of leavers → "54%" ✓.
- Illustration: (127 − 416 × 0.16122) = 59.93 excess leavers → "roughly 60"; 4.08 points; 16.12% → 12.05% → "about 12%" ✓. Only one illustration, for overtime only, stated twice (summary and So What) with identical figures; no impact figure for pay; nothing summed → no double counting ✓.
- Pay context (<3,500 band): 472 = 32.1% of staff ("roughly the bottom third") ✓; 27.1% vs 10.9% → "27% vs 11%" ✓; 95.1% JobLevel 1 → "95%" ✓; no overtime 16.2% (55/340) vs 7.7% (55/714) → "16%" and "8%" ✓; "most of their extra leaving is among overtime workers" (51.7 of 51.9 excess leavers, earlier entry) ✓. Range check: 26.9% of staff below $3,000, 36.9% below $4,000.
- "Groups of under 100 people were set aside" ✓ (rule also needs 24 leavers; no group is excluded on leavers alone, so OK).

### 2. Executive page ✓ (one wording fix)
- No CIs, cross-validation, AUC, p-values, bootstrap, test-set or lift language anywhere in the PDF, docx or chart text. No hidden comments; docx images carry no alt text (optional).
- Order: summary → What the Data Shows → Why It Matters and What to Do → What Not to Conclude ✓. Takeaway headings ✓.
- Only overtime is highlighted; small groups appear only in a one-line caveat ✓.
- Required fix: the pay context drops the cleared page's "wherever the pay line is drawn in that range", so "under about $3,000–$4,000" reads like a pay band with one rate.

### 3. Chart and number strip ✓ (one style fix)
- Values 28/54 (share) and 10/31 (rate) are correct. Bar lengths are to scale on a 0–100 track. Direct labels, takeaway title, fictional-data subtitle; no axes or gridlines ✓.
- Accent colour (#C2410C) is used on overtime only in the chart and strip; no-overtime is gray; the 16% tile is dark ✓.
- Fix: the numerals "1. 2. 3." of the suggestions list on p2 are in the accent colour. That is not the finding, so make them gray or dark.

### 4. Research paragraph and suggestions (PROVISIONAL until Ellis's re-tie)
- "Overtime is usually only a weak predictor (Rubenstein et al., 2018)": **inaccurate.** Rubenstein measured workload (ρ = −.10, k = 21, slightly *protective*), not overtime. attrition_drivers.md §2.3 treats OverTime only as a proxy for workload. Required fix.
- "demanding work that people experience as a stretch is often linked to staying (Podsakoff et al., 2007)": loose. Podsakoff classes workload and time pressure as challenge stressors by type, not by how people experience them. Challenge stressors were generally linked to lower turnover; hindrance stressors were linked to higher turnover. Required fix.
- "People who feel they give more than they get back are also more likely to go (Adams, 1965)": Adams is theory, not an empirical rate. Soften it.
- "In a real company, what matters is whether overtime is chosen or required, and how long it lasts": stated as fact, but nothing in the sources establishes it. Duration is not in the research files, and whether overtime is chosen is unrecorded (interpretation L35). Required fix.
- Greenhaus & Beutell + Rubenstein (work–life conflict ρ = +.19) for "conflict is linked to leaving" ✓.
- Exec summary "then test lighter workloads in the busiest teams" sits awkwardly with Podsakoff and Rubenstein (workload is not a clear risk), and suggestion 2 does not reflect drivers L208 ("unchosen overtime… demands that block progress rather than stretch people"). Fix both.
- Suggestions are framed as tests, not proven fixes; aimed at teams and at overtime workers as a group; no age, gender or marital-status targeting ✓. Suggestion 3 ("see whether the changes actually reduce leaving") implies a causal read from side-by-side tracking. Optional fix: compare with similar teams.
- Causal language: none in the findings ("shows who left, not why"; "may simply mark busy or understaffed roles") ✓.

### 5. Consistency and typos
- PDF, docx, PNGs and chart agree. No typos found.
- Docx core properties say creator "python-docx" and created 2013 (template default). Optional: set title and author.
- The cleared page's "Large, but not cleared" list and the "snapshot timing" caveat are omitted. That is acceptable for an exec page (optional).

### Required fixes (Iris)
- R1 (p1, Why It Matters, research paragraph): replace "But on its own, overtime is usually only a weak predictor of who leaves (Rubenstein et al., 2018), and demanding work that people experience as a stretch is often linked to staying (Podsakoff et al., 2007)." with "But research measures workload, not overtime itself: across many studies, workload is only weakly related to leaving, and slightly in the protective direction (Rubenstein et al., 2018). Demands such as workload and time pressure are usually classed as 'challenge' demands, which go with lower turnover, unlike obstacles such as red tape and unclear roles, which go with higher turnover (Podsakoff et al., 2007)."
- R2 (p1, same paragraph): replace "People who feel they give more than they get back are also more likely to go (Adams, 1965)." with "Equity theory holds that people who feel they give more than they get back may leave to restore the balance (Adams, 1965); this data does not record how people felt."
- R3 (p2, top): replace "In a real company, what matters is whether overtime is chosen or required, and how long it lasts." with "This data does not record whether overtime was chosen or required, or how long it lasted, and in a real company those are the first things to find out."
- R4 (p1, exec summary): replace "then test lighter workloads in the busiest teams." with "then pilot changes in teams where overtime is heavy and not chosen."
- R5 (p2, suggestion 2): replace the body with "Where overtime is heavy, sustained and not chosen, pilot changes in a few teams first, starting with demands that get in the way (red tape, unclear roles, understaffing) rather than work that stretches people; options include redistributing work, adding staff or adjusting schedules."
- R6 (p1, pay context): after "against 11% for everyone else" insert ", wherever the pay line is drawn in that range". The sentence then reads "…left at about 27%, against 11% for everyone else, wherever the pay line is drawn in that range."
- R7 (p2, suggestions list): set the numerals 1–3 to dark gray (#262626), not the accent colour.

### Optional
- O1: suggestion 3: "…so leaders can compare teams that tried changes with similar teams that did not, before rolling changes out more widely."
- O2: add alt text to the two images and set docx title and author.
- O3: the number strip and chart repeat the same four figures; consider dropping the 28% and 54% tiles or the left chart panel to reduce repetition.

### Correct
All numbers and rounding; single illustration with no double counting; the 'bottom third' and $3,000–$4,000 wording; fictional label in header, title, chart subtitle and caveats; summary-first What / So What / Not What headings; no technical content; no small-group highlights; one accent colour on overtime in the chart; no causal language in the findings; no age, gender or marital-status targeting; suggestions labelled as tests.

**PROVISIONAL until Ellis's re-tie:** the research paragraph (R1–R3), the three suggestions (R4–R5, O1), and the footer source list. Re-check those against Ellis's version; numbers need no re-check unless they change.

## Final check: exec research tie-in + narrative v4 (reviewed as v5 on Quinn's steer), Oct 9, 2026, 8:17 to 8:20 AM PT
Reviewer: Quinn (executor). The box clock reads HST, so every time below has been converted to PT (+3 h). Others' files were not edited.

**Verdicts.**
- (a) Tie-in `research/exec_research_tiein.md`: **APPROVED WITH FIXES.**
- (b) Narrative v4 (12:14 AM PT, pre-tie-in): superseded. It had R1–R7 applied and was correct as it stood.
- (c) Narrative v5, the final version: **APPROVED WITH FIXES** (F1–F7 below, all wording). Numbers, chart, colour and non-technical page all pass.

### Files reviewed (mtime PT, SHA-256 prefix)
- Tie-in: research/exec_research_tiein.md 8:16:20 AM (94a8eeaafe56). Matches commit 20c6ae8 (committed 8:16:25 AM PT); working tree clean.
- v4: .docx 12:14:47 AM (1b2afc435d17), .pdf 12:14:47 AM (3425c4d844b7), _p1/_p2.png 12:14:53 AM. Pre-tie-in: three suggestions and four sources.
- v5: .docx 8:17:56 AM (992b1c9fb717), .pdf 8:17:57 AM (06444c65c1da), _p1.png 8:18:06 AM (70bc85088572), _p2.png 8:18:07 AM (18a374e120dc); build_v5.py 8:17:55 AM; charts_v5.py 8:17:33 AM. Chart and strip PNGs are byte-identical to v4 (73eb897bb328, c445bf8c85f6).
- Sources unchanged since the v3 check: exec_findings_draft.md (fa103bb47e26), exec_results.json (860b6c1e97c2), technical_appendix.md (60797c64e26a). attrition_drivers.md and interpretation.md 4:15:34 PM Oct 8; BRIEF.md 4:18:28 PM Oct 8.

### 1. Numbers ✓
- Tie-in exec text has only 1,470 and 95%. 55%/19% appear only in the do-not-say list ✓.
- v5 numbers are identical to v3/v4 (all checked earlier): 1,470; 16%; 416/28%/31%/10%/about 3x/54%; 16% → about 12%, roughly 60; 27% vs 11%; 95%; 16% vs 8%; under 100 ✓.
- The 55.3/19.0 split is absent from v5 ✓.
- Docx and PDF text are identical (1,076 words). 2 pages, letter.

### 2. Citations (Crossref API + doi.org; abstracts from Crossref/OpenAlex/Semantic Scholar)
All 7 DOIs resolve (302 to the publisher), and author, year, title, journal, volume and pages match:
- Adams 1965, AESP 2, 267–299.
- Greenhaus & Beutell 1985, AMR 10(1), 76–88.
- Griffeth, Hom & Gaertner 2000, JOM 26(3), 463–488.
- Hausknecht, Rodda & Howard 2009, HRM 48(2), 269–288.
- Mitchell et al. 2001, AMJ 44(6), 1102–1121.
- Podsakoff, LePine & LePine 2007, JAP 92(2), 438–454.
- Rubenstein et al. 2018, Pers Psych 71(1), 23–65 (online 30 Mar 2017).

March & Simon 1958, *Organizations*, Wiley NY, was confirmed in the HathiTrust catalog (no DOI).

Claims:
- **Podsakoff:** matches the abstract (hindrance stressors go with more turnover; challenge stressors "generally the opposite") ✓.
- **Mitchell:** matches the abstract (links, fit, sacrifice; predicts voluntary turnover) ✓.
- **Hausknecht:** matches the abstract (reasons differ by performance and hourly vs non-hourly; "job type" is OK) ✓.
- **Adams:** theory of inequity ✓. Leaving as a response to inequity is from the chapter and is not in the abstract, but it is standard. It must stay framed as theory.
- **Greenhaus & Beutell:** no abstract available. Time-based conflict from hours is the paper's content (drivers §2.3/2.4). G&B do not show a link to leaving; that link comes from Rubenstein (work–life conflict ρ +.19). See F5.
- **Rubenstein:** the workload ρ −.10 (k = 21), work–life conflict +.19, age −.21, tenure −.20 and pay −.17 figures and the Table 1 workload definition are from Ellis's full-text read (QA-approved Oct 8). The abstract does not show them, so they were not re-verified here.
- **Griffeth:** "most single factors are modest" is consistent with drivers §1/§2 (r1 mostly ≤ .2). The abstract does not state it.
- **March & Simon:** inducements vs contributions ✓ as theory. It is not "research" that links pay to leaving (F1).

### 3. Wording / v3 fixes in v5
- R1 ✓: workload not overtime, slightly protective, Podsakoff in plain words, no "challenge/hindrance" labels.
- R2 ✗: the tail "this data does not record how people felt" was dropped (F4).
- R3 ✓, R4 ✓ (summary), R5 ✓ (now suggestion 1), R6 ✓, O1 ✓ (suggestion 4).
- R7 ✓: numerals are #262626. The only accent runs in the docx are the title words "Overtime workers"; the chart and strip accent overtime only.
- Non-technical ✓. No CIs, CV, AUC, p, bootstrap, test set, lift or ρ.
- Suggestions target groups and teams, are framed as tests, and do no age/gender/marital targeting ✓, apart from Q1 and Q2 below.

### Rulings on Iris's questions
- **Q1, "starting where overtime meets the lowest pay": yes, a small-sample highlight in disguise.** It points action at the overtime × low-pay combination. That group fails at every cut: 69 (<$2,475) and 99 (<$2,807) fail size, and 132 (<$3,500) fails stability. The 55/19 split is excluded for that reason. Fix F2.
- **Q2, "younger or newer to a company quit more often": accurate as research** (Rubenstein age ρ −.21, tenure −.20). However:
  - It is the only age mention outside the caveats on an exec page whose context is job level, not age.
  - Next to "never target by age" it invites an age reading.
  - The data's context is job level, so tenure is the closer research match.
  - The sentence also credits March & Simon (a theory) as "research" and ends with "causes".
  Fix F1: drop "younger" and cite Rubenstein for pay and tenure.
- **Q3, "far bigger overtime gap than research would predict": the direction is defensible, but "far bigger" overclaims.** In this data the overtime–leaving correlation is phi ≈ +.25, against workload ρ ≈ −.10, so it is larger and of the opposite sign. But this compares unlike things: a yes/no overtime flag in simulated data against a corrected meta-analytic correlation for workload scales. Research makes no prediction about an overtime gap. Fix F3.

### Required fixes (Iris in v5 + Ellis in the tie-in, same wording)
- **F1 (v5 p1 pay context, last sentence; tie-in §2 second sentence):** replace "Research links both to leaving, since pay is a core reason to stay (March & Simon, 1958) and employees who are younger or newer to a company quit more often (Rubenstein et al., 2018), so treat this as one picture, not two separate causes." with "Research finds that both lower pay and being newer to a company go with more leaving (Rubenstein et al., 2018), so treat this as one picture, not two separate explanations."
- **F2 (v5 p2 suggestion 3 heading; tie-in §3 item 3):** replace "Review pay and recognition for overtime effort, starting where overtime meets the lowest pay." with "Review pay and recognition for overtime effort across the overtime group." Keep the body.
- **F3 (v5 p2 research paragraph; tie-in §1):** replace "This fictional data shows a far bigger overtime gap than research would predict: a pointer to where to look, not proof of cause or evidence about any real employer." with "Research on workload would not lead us to expect a gap this large, so treat this fictional result as a pointer to where to look, not proof of cause or evidence about any real employer."
- **F4 (v5 p1/p2 research paragraph; tie-in §1), restoring R2:** "Equity theory holds that people who feel they give more than they get may leave to restore the balance (Adams, 1965); this data does not record how people felt."
- **F5 (v5 research paragraph; tie-in §1):** replace "Long hours can drain time and energy from family life, a conflict linked to leaving (Greenhaus & Beutell, 1985; Rubenstein et al., 2018)." with "Long hours can drain time and energy from family life (Greenhaus & Beutell, 1985), and that kind of conflict is linked to leaving (Rubenstein et al., 2018)."
- **F6 (v5 suggestion 4 "Why"; tie-in §3.4):** replace "Research finds most single drivers of leaving are modest" with "Research finds that most single factors are only modestly related to leaving". "Drivers" is causal.
- **F7 (v5 suggestion 3 "Why"; tie-in §3.3):** replace "People stay while what they get outweighs what they give (March & Simon, 1958), and feeling under-rewarded may prompt people to leave (Adams, 1965)." with "Classic theory holds that people stay while what they get outweighs what they give (March & Simon, 1958), and that feeling under-rewarded can prompt people to leave (Adams, 1965)."

### Optional
- O1: v5 p2: remove the repeated "These are ideas to test, not interventions shown to work." (the lead already says "to test, not proven fixes").
- O2: tie-in §4 "Status in v4" is now stale; say v5.
- O3: add alt text to the two images.

### Correct
- Numbers ✓; 55/19 absent ✓.
- Fictional label in the header, title, chart subtitle, research paragraph and caveats ✓.
- Single illustration labelled not a forecast ✓.
- One accent colour, overtime only; dark-gray numerals ✓.
- Docx = PDF ✓; no typos found.
- 8 sources in the footer match the tie-in ✓.
- Do-not-say list respected, apart from "drivers" (F6) ✓.
- Rubenstein gender rule not mis-cited ✓.

No re-check of numbers is needed after F1–F7. Quinn should spot-check the seven wording swaps in v6.

## Final sign-off: attrition_narrative_v6 (Quinn), Oct 9, 2026, about 8:25 AM PT
Reviewed: deliverables/attrition_narrative_v6.pdf (8:20:21 AM PT) and .docx (8:20:20 AM PT), plus both PNGs.
- F1-F7 wording: all seven present verbatim (text-matched in the PDF). No "younger", "drivers", "lowest pay", "far bigger", or technical terms (confidence, cross-validation, p-value, AUC, bootstrap) on the page.
- Numbers unchanged and all present: 1,470; 16%; 416; 28%; 31% vs 10%; 54%; 12%; ~60; 27% vs 11%; 95%; 16% vs 8%.
- Visual check of both pages: single accent color on overtime only, suggestion numbers dark, fictional label in header, title, chart subtitle and caveats.
Verdict: APPROVED. Cleared for repo and sharing with the user. Unverified-by-abstract citation claims (Greenhaus & Beutell; Rubenstein correlation figures) rest on Ellis's full-text read.

## App review: attrition tree v3 (905de74), Oct 9, 2026, about 12:10 to 12:25 PM PT
Reviewed: branch app-v3, commit 905de74 (jaysha301/ibm-hr-attrition-tree), working copy /workspace/projects/ibm-hr-attrition-app-v3, review doc analysis/qa/app_v3_review.md, 18 v3_* screenshots. Nothing in Soup's files was edited. My scratch scripts: /workspace/quinn_v3/ (check.R, check2.R).

### Verdict: APPROVED WITH FIXES (4 required, all small; Soup can apply them from the wording below without a re-review)

### 1. Code and tests
- `git diff f0b6047 905de74`: R/partition.R, data/ (SHA-256 d11789e1...a92f7 confirmed), tests/smoke.R and tests/regression_snapshot.R are all unchanged (empty diff). Non-UI/non-doc changes: R/presentation.R (new rules, node_assess, impact_points, pay_context, CLEARED_FINDING constants; validation_status narrowed to OverTime = Yes only), app.R (new control, takeaway, legend, node card, exports, About text), www/app.js (menu lines, dashed too-small nodes), www/app.css, new tests/check_typed_numbers.R, README, docs. The remaining 70 or so changed files are deliverables, research, analysis and screenshots merged from main.
- Recomputed the 7 snapshot hashes: all 7 byte-identical to v1_before and v2_after (importance 39a5f006, leaves 70ccecbc, nodes 5b899a1e, overtime_yes_candidates e8dcf733, root_candidates 854c6d24, snapshot.json 49be88b9, two_split_nodes eab2a60e); engine==server TRUE.
- tests/smoke.R passes (OverTime improvement 24.08; 11 leaves; in-sample AUC 0.746). tests/check_typed_numbers.R passes (all typed numbers match candidates.csv, thresholds.json, METHOD.md). App started headless: HTTP 200.

### 2. Numbers (recomputed in R on all 1,470 rows)
- Overtime 416 = 28.3% of staff; 127 of 237 leavers = 53.6%; 30.5% vs 10.4% (110 of 1,054); lift 1.894 (1.9x); about 2.9x the rest. Impact (127 - 416 x 237/1470)/1470 = 4.077 points = 59.9 people. All match exec_findings_draft.md, exec_results.json and the app text.
- In-sample AUC: starting 2-group tree 0.6507 (0.651), full 11-leaf tree 0.7464 (0.746). The Model fit page labels both "in-sample"; the 0.670 held-out figure is labelled a different measure.
- Highlight default: 1.5 x 16.1224% = 24.18%, smallest whole percent at or above = 25. Correct. Leaver floor ceiling(0.1 x 237) = 24. Size default 100 = 6.8% of staff.

### 3. Headline and labels
- Headline: "Overtime workers are 28% of staff but 54% of leavers: 30.5% left vs 10.4% of everyone else", with 416 people, 127 of 237, 1.9x, impact illustration. Plain language, no CI or jargon in the headline or pop-ups; the CIs and bootstrap detail are in the About tab under a "technical detail" heading only. Counts line says "all 1,470 people in this fictional file ... who left, not why". Consistent with the exec page (which rounds to 31% vs 10%).
- Fictional banner present (desktop and phone); age/gender/marital-status caution still in About and README; "validated/cleared" applies only to OverTime = Yes (validation_status).
- Legend, slider label and help text say what the 25% means and that only the cleared group is accented.

### 4. Size control (tested on real nodes of the full tree)
- Boundaries correct: a node is too small if n < floor or leavers < floor. Floor 100: n = 100 passes, 99 fails; leavers 24 passes, 23 fails (tested by setting floors to node counts and count + 1 on 6 nodes). Node 4 (69 people, 48 leavers) passes the leaver floor and fails size, flagged "under 100 employees". A big node (200, 25 leavers) passes both. Reverse case (n over 100, leavers under 24) works by the same condition; no real node in the default tree hits it.
- Default full tree: 14 nodes too small (dashed, never accented), exactly one accent node (node 3, OverTime = Yes), headline = node 3. Node CSV has too_small_to_act_on, status, share_of_positives, times_company_rate and no impact column. Leaf table has a Note column. Leaves CSV has NO too-small flag (fix R4).
- Floor lowered to 20: still only node 3 accented. But nodes 15 (38 people, 76%) and 17 (31 people, 90.3%) now get the dark "above threshold" outline, labelled "Big enough and above 25%", and node 17 shows an impact line (1.6 points). Never accent, but see R3. Floor above 416 or slider above 30.5% turns the finding off (verified).

### 5. Pay and career stage
- No pay finding is accented or cleared. Context box (collapsed, computed from data): 472 lower-paid left at 27% vs 11%; 95% in job level 1; no overtime 16% vs 8%. Matches the exec page; no 55.3/19.0 split; no causal wording; no age/gender/marital targeting. Importance remains primary-split only and labelled so.
- But if a user builds a pay split, the pay group shows an impact line ("3.5 points lower"), contradicting the box's own "No impact figure is given" (fix R2).

### Required fixes
- R1 (R/presentation.R, validation_status): "cleared" is given to OverTime = Yes for ANY target on the bundled data. Reproduced: target Attrition with event "No" and the slider at 60% accents the 416-person OverTime = Yes node as "Cleared finding" (stayers, 69.5%). After `if (!isTRUE(md$bundled)) return("exploratory")` add: `if (!is_attrition_target(md)) return("exploratory")`.
- R2 (R/presentation.R, impact_sentence): show the impact only for the cleared group. Replace the first line `if (isTRUE(a_row$too_small) || is.na(a_row$impact) || a_row$impact < 0.05 || a_row$depth == 0L) return("")` with `if (!isTRUE(a_row$cleared) || is.na(a_row$impact) || a_row$impact < 0.05 || a_row$depth == 0L) return("")`. Reason: thresholds.json says impact is for cleared groups only; non-cleared big groups currently show it (default full tree: node 5 = 1.6 points, node 7 = 2.1; a pay split = 3.5), which can read as a second finding and contradicts the pay context box. Also update README line 21/48 and review-doc call 1 to say "cleared group only".
- R3 (app.R, size control wording): when the control is under the standard 100, say so, and stop calling small groups "big enough". (a) In output$min_group_help, after the existing sprintf, if min_group() < RULE_MIN_N add a second line: "Below the standard floor of 100 employees. Groups this small are exploratory only; do not act on them." (b) Legend, outlined item: "Above 25%, but not validated (exploratory)" instead of "Big enough and above 25%, but not validated (exploratory)". (c) Exploratory headline eyebrow (app.R line 791): "Highest-rate group above the size floor · exploratory, not a cleared finding" instead of "Highest-rate group big enough to act on · exploratory, not validated". (d) Node-card pill "Above threshold" is fine.
- R4 (app.R, download_leaves): add the flag to the leaves CSV so it matches the node CSV and table: content <- function(file) { lv <- leaves_df(); ar <- node_assess(tree_rv(), model_data(), rules()); lv$too_small_to_act_on <- ar$too_small[match(lv$leaf, ar$id)]; utils::write.csv(lv, file, row.names = FALSE) }. (leaves_df keeps the first column named "leaf".)

### Optional
- O1: Importance pop-up "Best split" line for node 3 shows "left n 69 (69.6% left)" with no label; append " (too small to act on)" when n is under the floor.
- O2: Headline note: "Counts are for all 1,470 people in this fictional file (not a forecast). They describe who left, not why."
- O3: Pay context sentence: "(under about $3,500 a month, roughly the bottom third of earners; the pattern holds anywhere from about $3,000 to $4,000)" to match the exec page.
- O4: Too-small node card: show the big rate number in muted gray, and add "Small group: the rate is unreliable." to the small-note.
- O5: Desktop hover tooltip for long rules runs off the right edge (v3_desktop_06); phone full-tree node text is tiny until zoomed (pre-existing).
- O6: About tab still names the 69-person group as the "too small" example; fine as an example, keep.

### Rulings on Soup's calls
1. Impact for big exploratory groups: CHANGE, cleared group only (R2).
2. 25% default: APPROVED (24.18% rounds up to 25; labels correct; only OverTime = Yes accented).
3. Size control above 416 turns the finding off: APPROVED (also true above 30.5% on the slider); headline "No group highlighted" is clear.
4. Uploaded data: nothing validated or accented: APPROVED (bundled flag false). Note R1 for the bundled data with a different target.

### Correct
Engine, data and tests unchanged; 7 snapshots identical; all numbers and AUCs; fictional banner and caution; one accent only on OverTime = Yes (desktop and phone); direct labels, dashed too-small boxes, legend; context box text matches exec page; no technical jargon in the headline; no phone-page horizontal clipping or legend overflow seen in the screenshots; README typed-number table and check script match the analysis files.

## Proposed qualification rule v2 (Quinn to Rowan), Oct 9, 2026, about 2:50 PM PT
Why: CEO (via GG) saw in the app that non-overtime employees with little work experience leave at a high rate, which the exec page did not mention, and asked to drill into large groups in both branches. The old stability test (a company-wide primary split at nodes 1-3) could not see second-level patterns because overtime takes the top node.
Rule v2: Gate A size >=100 employees AND >=24 leavers (never relaxed). Gate B lift >=1.5 OR (lift >=1.25 AND Wilson lower bound > 16.1% AND impact vs company >=1.0 point, about 15 extra leavers). Gate C held-out: same direction, test rate >= company rate, >=30 test employees. Gate D stability within the branch: each defining variable is a primary split at the top of its own branch tree (root or level below) in >50% of 500 refits fit separately on overtime and non-overtime employees. At most 2 conditions per group; candidates only from pruned trees and a pre-listed set.
Guards: rule written to thresholds.json before the run; old rule results and the reason for the change disclosed in the appendix; candidate counts per branch reported; no impact summing across overlapping or nested groups (union and incremental impact instead); no groups defined by age, gender or marital status; "little experience" presented as career stage and overlap with pay/JobLevel 1 reported.
Status: sent to Rowan, awaiting the candidate table and draft exec findings.

## Review: drill-down under qualification rule v2 (Quinn), Oct 9, 2026, about 4:27 to 4:50 PM PT
Reviewed: analysis/exec2/ (Rowan; nothing there was edited). My scratch: /workspace/quinn_v4/ (base.R, c1 to c10.R, boot.R, null_non.R; independent code) and the full rerun in /tmp/q2. Times below are PT (box mtimes are HST, +3 h).
**Verdict: APPROVED WITH FIXES.** The analysis and both clearances are correct and reproduce. The executive draft (exec_findings_v2_draft.md) is NOT cleared until fixes R1 to R4 are made; R5 to R7 are for the chart and appendix.

### 1. Provenance and reproducibility
- Data SHA-256 = d11789e1...a92f7 (matches). thresholds.json SHA-256 5d267be65408... (matches the appendix). Split reproduced: 1,029 train / 441 test (71 leavers); company 237/1,470 = 16.12%, test-set rate 16.10%.
- Timeline (PT): thresholds.json last written 3:28:43 PM; smoke-test outputs (/tmp/exec2_test, TEST_MODE) 3:37 PM; first real search 3:37:30 to 3:37:45; first full run finished 3:53:55; run_drill.R last edited 4:07:43 PM, AFTER the first full run's results existed; cached resume 4:08; final no-cache run (the files in exec2/) finished 4:26:12 PM. So thresholds.json predates every output it governs. Earlier real-label exploratory runs (before 3:15 PM) shaped the amendments (disclosed in thresholds.json; only non-gating items added). The 4:07 PM script edit is not disclosed in the appendix; I compared the 3:37 PM cached search (real_search.rds) with the final candidates_all.csv by group key: n, leavers, test counts, stability, pass_new, pass_old, pass_sens, pass_pv all identical for all 14,178 rows, so the edit only touched reporting (Fix R7).
- Cache: logs/cache holds real_search.rds (full search object, key = thresholds SHA + "search-v1", 3:37 PM) and 200 + 200 tiny null_*.rds files (nine counts per shuffle). The final outputs were produced with DRILL_NOCACHE=1 (progress_nocache.log), which reads no cache.
- My rerun: scratch copy with data, thresholds.json, run_drill.R and analysis/exec/candidates.csv (the script reads it) and NO logs/cache, DRILL_NOCACHE=1, 6 workers, 536 s. (My first attempt stopped because the earlier-run candidates.csv was missing from my copy; I added it and restarted from scratch.) Result: every output file byte-identical to Rowan's (README, best_cuts, candidates_all, career_stage_overlap, ceo_check, cut_stability, drill_log.csv/.md, drill_summary, drill_tree.png, exec_findings_v2_draft, groups_tested_by_branch, nested_incremental_impact, overlap, qualifying, three tree files). The only diff is one line of technical_appendix.md that prints thresholds.json's file mtime (my copy's mtime), as expected.

### 2. Code audit (run_drill.R, 878 lines)
- Leakage: none found. Quantile cut grids (atoms_in) use training rows inside the node (mask & is_tr); trees are grown on training rows only (minbucket 70 = 100 scaled to 70%; the stability refits use minbucket 100 on full branch data as specified); hand-built "best low-side cut" (best_cuts.csv) maximises TRAINING excess only; test rows only enter test_n/test_rate and gate 4. The full-data reference trees are labelled reference only and feed nothing. Group 2's cut $3,221 is the training 30th percentile of overtime income (a label-free grid point), not a label-optimised cut.
- Design notes (not leakage): size, impact, Wilson and the stability refits use full-data rows, which include the test rows, so gate 4 is a check on direction, not a fully independent test; the appendix says so. Gate 4 uses test rate > test-set average (16.10%) rather than >= company rate (16.12%): 3 candidate rows differ, none among groups passing gates 1 to 3, no verdict affected.
- Candidate set: fixed by procedure (branch roots, every single split, pairs of 9 experience/pay variables, every node of three grown trees, then drill children of tree nodes and of qualifiers/supported groups). The drill is adaptive (which nodes get drilled depends on gate results), which is why the shuffled searches test fewer groups (see 6). Drill log: 77 nodes (31 whole company, 17 overtime, 29 no-overtime); all 9 tree nodes with 100+ people are in it; 8 nodes with 3+ conditions, deepest 5.
- Seeds/refits: set.seed(seed+b) inside each refit, so results do not depend on core count. 500 bootstrap refits, rpart anova, cp 0.001, minbucket 100, minsplit 200, 10-fold CV, 1-SE pruning, depth 10 within branch (3 company-wide). "Similar cut" = refit cut within +/-0.10 of the branch share below the cut (a wide window: for group 2 it spans about $2,700 to $4,200).
- My own bootstrap (different seeds, my code): overtime branch no split 15/500 (Rowan 8), MonthlyIncome primary split 68.6% (Rowan 68%); no-overtime branch no split 388/500 (Rowan 371), so the cap is 22 to 26%; career-stage family in no-overtime unpruned refits 90.6% (Rowan 89%), years at the company 41% any cut / 33% similar cut (Rowan 36%); company-wide nodes 1 to 3 OverTime 77.8% (Rowan 82%). "No split in 371 of 500" is correct for the script's seeds and the claim is robust to seed.

### 3. Independent recomputation (all match Rowan)
- Baselines, both cleared groups (overtime 416/127/30.5%, lift 1.89, Wilson 26.3 to 35.1, test 114 at 32.5%, +59.9 people = 4.08 pts; group 2 122/68/55.7%, lift 3.46, Wilson 46.9 to 64.2, test 32 at 59.4%, +48.3 = 3.29 pts vs company, +30.8 = 2.09 pts vs overtime), nested incremental, union 416 / 4.08 pts, the six non-overtime groups (387/15.8%, 370/15.9%, 421/14.5% with test 15.3% fails direction, 208/19.7%, 238/20.2%, 146/25.3%) and union 642 / 85 of 110 / 13.2% (-18.5 people vs company): all match.
- All 14,178 rows of candidates_all.csv: gates 1 to 4 and pass_new re-applied from the row's own columns: 0 inconsistent rows (1,512 age/gender/marital rows excluded from qualifying by rule). Every row's n, leavers, test n and test leavers re-computed from the data by parsing its label: 0 mismatches (14,178 of 14,178); rate, lift, Wilson, excess, impact, parent excess match within rounding. Boundary spot checks (listed rows, all correct): n=99 fails size (27 rows with excess 15+ blocked), n=100 passes; 23 leavers fails, 24 passes; excess 14.98 fails / 15.0+ passes (e.g. YearsAtCompany<10 & NumCompaniesWorked>=4: 14.99 fails); lift 1.2419 fails / 1.2556 passes; test n 29 = "test too small" / 30 passes; Wilson lower bound near 16.1% rows verified.
- Counts: 14,178 stored rows, all keys unique; 10,845 with 100+ people; status table (8,147 / 522 / 2 / 3,336 / 180 / 1,991) matches; pass 1-3 3,518, 1-4 3,338, 1-5 2 (by branch: 6,868 / 4,133 / 6,583 tested; no-overtime 19 pass 1-4); 651 pass the new gates but not the 1.5x floor; 239 pass the OLD gates 1 to 3 (size, 1.5x, test) but not the 15-person gate (wording: they pass old gates BEFORE stability; only 1 group, overtime, passes the full old rule); 3+ condition groups: 5,074 / 1,092 / 945 / 0 / 147. Null counts recomputed from the 400 cached null files: 68.4 / p95 230 (across everyone), 672.9 / p95 753 (within status), 0 passing all five.

### 4. Judgment call (b): group 2 (overtime and income under $3,221), sensitivity of the cut
| Cut | n | rate | test n, rate | gates A,B,C | stability (my refits, similar cut) |
|---|---|---|---|---|---|
| $2,500 | 70 | 68.6% | 19, 63% | size fails | 23% |
| $2,800 | 98 | 59.2% | 27, 56% | size fails | 38% |
| $2,900 | 105 | 59.0% | 30, 60% | pass | 58% |
| $3,000 | 114 | 56.1% | 31, 58% | pass | 68% |
| $3,221 | 122 | 55.7% | 32, 59% | pass | 68% |
| $3,500 | 132 | 55.3% | 34, 59% | pass | 66% |
| $3,750 | 143 | 54.5% | 38, 58% | pass | 61% |
| $4,000 | 151 | 53.0% | 40, 55% | pass | 48% (fails) |
All five gates hold for cuts of about $2,900 to $3,900 (size needs >= about $2,820; stability falls below 50% at about $4,000). Rate stays 53 to 59%, test 55 to 60%, against 17 to 22% for the rest of overtime. Income gradient inside overtime is monotone, not a cliff (quintile rates 62%, 35%, 18%, 24%, 13%).
- The earlier n=69 rejection (cut $2,475 on the full data) sat below the size floor; the substance did not change, the cut was just too low for 100 people. The finding holds in substance.
- CONFOUND: 118 of 122 (97%) are JobLevel 1. All 156 overtime JobLevel 1 workers left at 52.6% (test 54.8%, n=42; passes gates A to C; Rowan's table shows stability 20% because the trees prefer income), versus 17.3% for the 260 overtime workers at job level 2 or higher (about the company average). Inside JobLevel 1 overtime, income < $3,221 is 57.6% (118) vs 36.8% (38 above), so pay adds a little but the group is essentially "junior overtime workers". Pay and job level cannot be separated (consistent with the career-stage rule).
- Group 2 also clears gates 1 to 4 plus stability against its OWN branch (pass_pv; the only such group in the whole search); in 200 within-overtime shuffles none did (see 6).
- View: defensible to feature, as a part of the overtime finding (nested, impact not added), with the cut as a range and the junior caveat. Not a repeat of the n=69 problem: 122 people (114 to 143 across the range), 68 leavers, test n 32 (31 to 38 across the range, about 20 leavers, so the test rate itself is imprecise; say so in the appendix only). Suggested wording is in R1/R2.

### 5. Judgment call (a): gate D in the non-overtime branch, and the CEO's question
- Structural: yes. With cross-validated 1-SE pruning 74% (my seeds 78%) of refits have no split, so no group can exceed 26% (22%). Not a property of any group; it is a property of the rule in a branch with weak, correlated structure. The loose check (unpruned depth-3) shows career stage as a family in about 90% of refits and years at the company 33 to 41%, so it is a fair CONTEXT line. Do not change the rule: changing the gate after seeing 3,336 "supported but unstable" groups is a forking path and would clear hundreds of overlapping groups. Keep "cleared" as is, and report the not-cleared tier honestly (below).
- What the data say about the CEO's pattern (own code): non-overtime staff with 1 year or less at the company: 146 people, 25.3% vs 8.0% for the 908 non-overtime staff with longer tenure (3 times as much) and vs 10.4% branch. REAL inside the branch, but only +13.5 people (0.92 pt) above the company rate: misses the 15-person bar and gate D. 19 two-condition non-overtime groups (all career stage / tenure / pay combinations, e.g. no overtime and total working years <6 and years at the company <3: 127 people, 29%, +16.5, test 42% n=43) pass gates 1 to 4 and fail only stability. Counted once these 19 are 415 people (28% of staff), 18.6% left, only +10 people (0.7 pt) above the company rate. Own-code null: for no-overtime pairs of the 9 career variables (quartile atoms, training cuts), 6 groups pass gates 1 to 4 in the real data and 0 in each of 200 within-status shuffles (mean 0, max 0), so this pattern is not chance; it is simply not clearable under gate D.
- Company-wide short tenure (own code): years at the company 1 or less: 215 people (14.6%), 75 left (34.9%), +40.3 people (2.74 pts), test 43.5% (n=62): passes gates 1 to 3 and 4, fails gate D (12% of company refits split on it, because TotalWorkingYears, JobLevel and income take the splits). 69 of the 215 work overtime (55%) and 146 do not (25%). Similar picture for JobLevel 1 company-wide (543 people, 26.3%, +55.5, test 27.5%), total working years 7 or less (522, 25.1%). So the CEO's pattern does show up at company level as a large career-stage pattern, bigger than group 2 in absolute impact, but it is one correlated cluster that overlaps overtime and pay, not a clean separate finding.
- Honest message to executives: newer, more junior staff leave more both with and without overtime; inside the no-overtime group it is a real and sizeable relative difference (3 times) but modest against the company average and below the 1-point bar; across the company it is large but cannot be separated from job level, pay and experience. The draft currently says "small, each adds fewer than 15" (true for the six single groups, but hides the 19 combinations and the company-wide group) and could read as hiding a real pattern (R3).

### 6. Judgment call (c): null calibration
- Fair for its purpose: labels permuted within train and within test (keeps rates), trees and cuts re-derived on the shuffled training rows, same search. Across-everyone: gates 1 to 4 pass in 96% of shuffles (mean 68), so gates 1 to 4 alone are weak and gate D carries the weight; real 3,338 vs p95 230. Within-status: mean 673 groups pass 1 to 4 (anything large inside overtime beats the company rate by construction), 0 pass all five beyond the overtime root in 200 shuffles. For group 2 the apt version is the parent-branch view: gates 1 to 4 against the branch rate pass in mean 21 groups per within-status shuffle (p95 74) but with stability in 0 of 200; in the real data exactly 1 group (group 2) does. That supports "not chance" for the income-within-overtime pattern. 0 of 200 gives a one-sided 95% upper bound of about 1.5% for the chance rate; say "none of 200", not p=0.
- Caveats: (i) stability in shuffles uses 100 refits, not 500; (ii) the shuffled searches test fewer groups (mean 9,252 across, 6,875 within, vs 17,584 real) because drilling follows signal, which makes the null somewhat conservative toward the real data; (iii) in the no-overtime branch the null has no power at gate 5 (cap 26%), so "0 passes" there means nothing; use my gate 1 to 4 within-status null for no-overtime (0 of 200 vs 6 real); (iv) the 3,338 passers overlap heavily, not 3,338 findings; (v) the null does not address how soft the cut is (see 4).

### 7. Exec draft against the standing rules
OK: non-technical (no CIs, p-values, AUC, bootstrap, cross-validation), What / So What / Not What present, fictional label in title and caveats, no causal claim ("may mark busy or understaffed roles" is hedged), no group defined by age, gender or marital status, nothing under 100 highlighted, impacts labelled as illustrations and marked as not added for the nested pair, all numbers match my recomputation (416, 28%, 31%, 1.9x, 10%, 3x, 54%; 122, 8%, 56%, 3.5x, 1.8x, 29%; 16% to 12% / 60; 16% to 13% / 48; overtime income under $4,187 = 49.7%; years with current manager 238 / 20% vs 10%; "58% to 100% overlap with overtime or junior" = 58, 65, 87, 100%).
Problems: R1 to R4 below. Appendix has: rule-change disclosure with reason (section 1, 9), old-rule results (9), drill log (6 + drill_log files), counts tested (4), null calibration (10), 3+ condition list (6), near misses and CEO table (7), within-branch stability and loose check (5). Missing/weak: R6, R7.

### Required fixes
R1 (group 2 wording: range + junior framing). Title: "Who leaves most: overtime workers, and among them lower-paid, junior staff (IBM's fictional HR teaching data, not real employees)". Executive summary: replace "within them, overtime workers with monthly income under $3,221" with "within them, lower-paid, mostly junior overtime workers". What, second paragraph: "Within overtime, the lower-paid, mostly junior staff leave most: overtime workers earning under roughly $3,000 to $3,500 a month (about 115 to 130 people, 8% to 9% of staff) left at about 55%, roughly 3.5 times the company rate of 16% and about 2.7 times the rate of the other overtime workers (20%). They account for close to 30% of everyone who left." (check: at $3,000 / $3,500: 114 / 132 people, 56% / 55%, 27% / 31% of leavers; others in overtime 20.9% / 19.0%, i.e. 2.6 to 2.9 times). So What: "...if they left at the company average, overall attrition would fall from about 16% to about 13%, roughly 45 to 50 fewer leavers" (46 to 52 across the range). Keep "The second group sits inside the first..." Remove "$3,221" everywhere on the page; the appendix keeps $3,221 as the tested cut with the range table (R6).
R2 (confound sentence, in "Context: career stage", first sentence after "Inside overtime"): "Almost all of these lower-paid overtime workers (97%) are in the most junior job level, so pay and job level cannot be separated. Overtime workers in the most junior job level (156 people) left at 53%, against 17% for the 260 overtime workers at higher job levels, close to the company average of 16%." (Also put in the summary or So What? Not required, but the So What should not imply all overtime workers are at equal risk; the sentence above covers it.)
R3 (rewrite the no-overtime sentence; remove "these groups are small", "each adds fewer than 15", "reshuffled versions"). Replace from "Without overtime, ..." to the end of that paragraph with: "Newer staff leave more often both with and without overtime. Without overtime, staff with 1 year or less at the company (146 people) left at 25%, against 8% for the 908 without overtime who have been there longer, and 10% for all staff without overtime. That is a real difference, but staff without overtime leave less often than the company overall, so against the company average it is modest: this group is about 13 people above the company rate (under 1 point), short of the 15-person (1-point) bar we set for a headline. A number of overlapping combinations of tenure, experience and pay without overtime (for example no overtime, under 6 years of total experience and under 3 years at the company: about 130 people, 29%) reach about 15 to 17 people above the company rate and also hold in the employees we set aside for checking, but together they cover 415 people and add only about 10 people above the company rate (0.7 point). Across the company, staff with 1 year or less at the company (215 people, 15% of staff) left at 35%; about a third of them work overtime and are already part of the overtime finding. Tenure, experience, job level and pay move together and the data cannot separate them, and we could not confirm that any one of them keeps coming out as the main split when we repeat the analysis, so we show newer and more junior staff as context to watch, not as a cleared finding." (Numbers: 146/25.3%/908/8.0%/10.4%/13.5; 127 people, 29.1%, +16.5; 415/+10.1/0.69 pt; 215/34.9%/69 overtime.) Trim to fit the page; the first three sentences and the company-wide sentence are the minimum.
R4: in "Large, but not cleared" replace "But these did not hold up consistently when we re-ran the analysis on reshuffled versions of the data." with "But none of them held up as a consistent split when we repeated the analysis on different samples of the same employees." (the page never shuffles labels; "reshuffled" suggests the null test). Same replacement wherever the phrase occurs (Context paragraph also). Also delete the "DRAFT for Quinn, not cleared" banner and the "run_drill.R / appendix" pointer line before sharing.
R5 (chart drill_tree.png): the "works overtime" bar appears twice (rows 2 and 4), the label "years with current manager: 1 or less" collides with its "20% left" label, bar labels cross the company-average line, and the bar says "$3,221". Fix: one overtime bar, no-overtime bar, then group 2 labelled "overtime, income under roughly $3,000 to $3,500 (122 people tested at $3,221)" or simply "overtime and lower pay (about $3,000 to $3,500 or less)", drop the duplicate, move bar labels outside the bars, and keep orange for cleared only.
R6 (appendix, section 5 or 8): add the cut-sensitivity table from item 4 above (cuts $2,500 to $4,000: n, rate, lift, impact, test, gates, stability) and the JobLevel 1 breakdown (118 of 122; 156 overtime JobLevel 1 at 52.6%; 260 overtime JobLevel 2+ at 17.3%); add the non-overtime result "19 groups pass gates 1 to 4 and fail only stability" with the union (415 / +10) and the company-wide short-tenure group (215 / 34.9% / +40 / test 43.5% / stability 12%); state that gates 1 to 4 do not discriminate inside overtime (within-status shuffles pass a mean of 673) so gate 5 and the parent-branch view carry group 2, and add the parent-branch null (mean 21, p95 74, stability 0 of 200); state that the shuffled searches tested fewer groups (mean 9,252 / 6,875 vs 17,584) and that the no-overtime null has no power at gate 5.
R7 (appendix, disclosure): add "run_drill.R was edited at 4:07 PM PT after the first full run; the search outputs from before and after the edit are identical row for row (checked against the cached search)"; change "239 pass the old rule" (appendix section 9 and drill_summary short answer) to "239 pass the old size, 1.5x and held-out gates but give fewer than 15 people above the company rate; only 1 group (overtime) passes the full old rule"; note the gate 4 detail (test rate > test-set average 16.10%).

### Rulings
(a) Gate D, no-overtime: structurally cannot pass (cap 22 to 26%); keep as is; report the loose check next to it as context (fair line), plus the not-cleared tier in R3/R6. A rule change now would be a forking path (it would be chosen after seeing which groups fail, and would admit 3,336 overlapping groups). The non-overtime pattern is real inside the branch and not chance (own null 0/200 vs 6), but modest at company level, and the exec text should say exactly that.
(b) Group 2: feature it, as part of the overtime finding, as a range ($3,000 to $3,500, supported to about $2,900 to $3,900), with the junior-job-level caveat (R1, R2). Do not present as a separate pay finding.
(c) Null: fair and adequate to say none of 200 shuffles produced a group clearing all five (and none cleared the parent-branch view with stability); it supports "not chance" for group 2's income-within-overtime pattern, not for the exact cut, and it cannot speak to the no-overtime branch.

### Optional
O1 Appendix: report group 2 test-set precision (about 19 leavers of 32; a 95% range of roughly 42% to 74%), appendix only. O2 Add a one-line plain-language note on the exec page that the checks were stricter inside the no-overtime group and could not be passed there. O3 Consider a pre-registered tier "supported, stability not testable" for future runs so this need not be argued post hoc. O4 Stability uses a +/-0.10 share window (about $1,500 wide for group 2); mention it in the appendix.

### What is correct
Provenance (thresholds before outputs, data hash, split), byte-identical full no-cache rerun, no leakage in trees or cuts, all of Rowan's numbers, every verdict in candidates_all.csv, the two cleared groups, nesting handled without summing, 17,584/10,845/77, 651/239, null counts, drill log coverage, chart numbers, no sensitive-variable groups, nothing under 100 highlighted.
Next: when Rowan/Iris send the revised page I will spot-check R1 to R4 and the chart; no new number check needed beyond those quoted above.

## Review: exec research tie-in v2 + narrative v8 (Quinn), Oct 9, 2026, about 5:05 to 5:45 PM PT
Reviewer: Quinn (executor). Box clock is HST, so times below are converted to PT (+3 h). No file of Ellis or Iris was edited. Scratch: /workspace/quinn_v5/.

**Verdicts.** (A) research/exec_research_tiein_v2.md (commit cc2ba19, 5:26:50 PM PT, sha256 b2a043ae7fd6): **APPROVED WITH FIXES** (T1 to T5). (B) attrition_narrative_v8 (.docx 5:31:15 PM, .pdf 5:31:16 PM, p1/p2 png 5:31:17/18 PM PT): **APPROVED WITH FIXES** (V1 to V3, all wording; numbers and chart pass).

### A. Tie-in v2
**Numbers (all re-derived from data/WA_Fn-UseC_-HR-Employee-Attrition.csv and exec2 followups):** 416 / 28.3% / 30.5% vs 10.4% / 53.6% of leavers / 16.1% to 12.0% / 59.9 people; lower-paid overtime at $3,000 to $3,500: 114 to 132 people (7.8% to 9.0% of staff), 56.1% to 55.3%, 27.0% to 30.8% of leavers, 96.5% to 97.0% job level 1, 3.4 to 3.5 times company, 2.7 to 2.9 times rest of overtime (20.9% to 19.0%), 16.1% to 13.0/12.6%, excess 45.6 to 51.7; job level 1 overtime 156 at 52.6%, 260 at higher levels 17.3%; staff with 1 year or less 215 (14.6%), 34.9%, +40.3 people, 2.74 points, test 43.5%, 32.1% overtime; no-overtime 146 at 25.3% vs 908 at 8.0%. All match the exec2 page.
**Range question (Ellis d):** the page's ranges are the ones for the stated cut range $3,000 to $3,500 (114 to 132 people; 27% to 31% of leavers), so "about 115 to 130" and "close to 30%" are consistent. Ellis's 114 to 143 and 27% to 33% are the wider $3,000 to $3,750 span; the whole passing range ($2,900 to $3,900) is 105 to 146 people and 26% to 33%. Nothing needs to change on the page; Ellis should say in her note (d) that the page quotes the $3,000 to $3,500 span. Impact "45 to 50" is rough at the top (51.7); acceptable as "roughly".
**Citations (Crossref API + doi.org, Oct 9, 2026 about 5:10 PM PT):** all 8 DOIs resolve (302 to publisher) and author, year, title, journal, volume, pages match: Adams 1965 AESP 2 267-299; Bauer et al. 2007 JAP 92(3) 707-721; Greenhaus & Beutell 1985 AMR 10(1) 76-88 (Crossref lists first page 76 only); Griffeth et al. 2000 JOM 26(3) 463-488; Hausknecht et al. 2009 HRM 48(2) 269-288; Mitchell et al. 2001 AMJ 44(6) 1102-1121; Podsakoff et al. 2007 JAP 92(2) 438-454; Rubenstein et al. 2018 Pers Psych 71(1) 23-65 (online 2017). March & Simon 1958 is a book with no DOI (catalogue-checked earlier).
**Bauer et al. 2007: verified in the full text** (Portland State repository copy, typeset pages 707-721, journal copyright line). Abstract matches Ellis's wording (70 samples; adjustment = role clarity, self-efficacy, social acceptance; mediated tactics and information seeking effects on satisfaction, commitment, performance, intentions to remain, turnover; "generally supported"). Full text adds: role clarity, self-efficacy and social acceptance are the adjustment measures themselves, not antecedents; role clarity related to all outcomes "except turnover" (path model: not significant); self-efficacy related to turnover (r about -.16, 2 studies, N=272); social acceptance related to all five outcomes including turnover (r about -.16, 4 studies, N=626); information seeking not related to turnover (r -.08, CI includes 0). Newcomers = 13 months or less on a new job. So Ellis's "relate to, never reduce" and "no claim from role clarity alone to leaving" are right, but two sentences misplace role clarity (T1, T3).
**Rubenstein et al. 2018 numbers: confirmed in the same early-online manuscript** (ResearchGate cover "Article in Personnel Psychology, February 2017", 44 pp; read from a third-party copy at psihoprofile.ro and matching ResearchGate search snippets): Table 2 pay k=55 N=177,634 rho -.17; workload k=21 N=82,204 rho -.10 (CI -.13 to -.07; credibility -.18 to -.01); work-life conflict k=7 N=12,107 r .16 rho .19 (CI .14 to .24); tenure k=118 N=669,753 rho -.20 (k=117 without the outlier: -.27); age -.21. Table 1 workload definition ("mostly measures of hours worked or how hard and fast an individual works") and the "only problematic for those who must also devote significant portions of their time to other roles" speculation match. Directional pay finding also in a secondary summary (ScienceForWork, Feb 2018: "small-to-moderate negative"). **Could not verify:** the final typeset 71(1):23-65 tables (Wiley 403 for me too); my confirmation is the same manuscript version as Ellis's, not an independent version. The abstract has no numbers.
**Other claims:** Mitchell 2001 abstract (links, fit, sacrifice; predicts intent to leave and voluntary turnover) supports the stay-related text; that early-tenure staff have had less chance to build them is Ellis's inference (T2). Podsakoff 2007 abstract (hindrance stressors go with more turnover; challenge stressors "generally the opposite"); the examples "red tape, unclear roles" are not in the abstract (full-text; cleared earlier). Hausknecht 2009 abstract (reasons for staying differ by performance and hourly vs non-hourly). Greenhaus & Beutell 1985: no abstract in Crossref/OpenAlex; indexed abstract text (time devoted to one role makes it hard to meet another; strain; behavior; model proposed) supports "long hours can drain time and energy" as a paraphrase of time-based and strain-based conflict; no turnover data, the link to leaving is Rubenstein's work-life conflict row. Not verified: G&B full text; Podsakoff, Mitchell, Hausknecht, Griffeth full texts (abstract-level only, Griffeth full text was checked in an earlier review).
**Wording:** no causal verbs, "consistent with / illustration only" present, equity and March & Simon stated as theory, workload not overtime, "would not lead us to expect a gap this large", no younger/age/gender/marital wording, item 2 suggestions aimed at junior-level overtime workers as a job-level group (156 people), no pay cut, no "lowest pay": they do not reintroduce a small-group highlight and are consistent with the page treating item 2 as part of overtime. Item 3 suggestions are for all new hires and teams. Word counts in the file (126/126/128) are right.
**Required fixes (tie-in; Iris uses the same wording in v8):**
- T1 (item 3 paragraph, second sentence): replace "Research on newcomers finds that how people are brought in matters: structured orientation, finding the information they need, a clear role and feeling accepted by colleagues relate to how well new hires settle, and settling relates to outcomes that include intending to stay and actually staying (Bauer et al., 2007)." with "Research on people in their first year or so finds that a structured start and finding the information they need go with a clearer role and with feeling accepted by colleagues, and that settling in goes with intending to stay and with staying, most clearly where people feel accepted by colleagues (Bauer et al., 2007)." (role clarity is part of settling in, not a cause of it; "matters" is causal; role clarity alone was not linked to leaving.)
- T2 (item 3 paragraph, first sentence; item 2 paragraph, Mitchell sentence): "people newer to a company have had less chance to build the ties, fit and stake that go with staying" becomes "people newer to a company may have had less chance to build the ties to colleagues, fit with the job and what people would give up by leaving that go with staying". Item 2: "People early in their time with a company have had less chance ... fit and stake" becomes "may have had less chance ... fit with the job and what people would give up by leaving". (Mitchell does not study tenure; this is an inference. "Stake" is not plain language.)
- T3 (item 3 suggestion Why lines): 1: "Orientation, information and role clarity relate to newcomer adjustment" becomes "A structured start and getting the information they need go with new hires having a clear role and feeling accepted by colleagues (Bauer et al., 2007)." 2: "newcomer adjustment relates to intending to stay" becomes "settling in goes with intending to stay, and feeling accepted by colleagues goes with staying (Bauer et al., 2007)". ("newcomer adjustment" is jargon.)
- T4 (item 2 suggestion 1 Why): "People weigh what they give against what they get" becomes "Classic theory holds that people weigh what they give against what they get" (earlier F7: theory must be labelled).
- T5 (provenance table, Bauer row, and Sources line): replace "Abstract only ... I could not open the full text to confirm" with "Abstract and full text (Portland State repository copy of the typeset article). Role clarity was not significantly related to turnover; social acceptance and self-efficacy were (small correlations, 2 to 4 studies)." Rubenstein row: add "figures also found in a second host copy of the same early-online manuscript; typeset version still not seen".
**Optional:** O1 say in note (d) which cut range the page uses. O2 say "feeling accepted by colleagues" is the part of settling linked to staying. O3 note Bauer's newcomers were 13 months or less in post, mostly graduate-level samples (86% degree), so it fits "first year" but not every workforce. O4 label the new-hire suggestions "low-cost whatever this pattern turns out to be".
**Length:** Ellis's new text is about 800 words (three paragraphs 380, six-plus suggestions 430). v7 already had 1,320 words on two full pages; v6 had 1,075. Cut: use one overtime paragraph, a 2 to 3 sentence item 2 paragraph (theory plus Rubenstein), a 2 to 3 sentence item 3 paragraph, suggestions as bold lead plus one sentence, no Why lines (Iris did this in v8, see B).

### B. Narrative v8
**Passes:** 2 pages letter; docx text identical to PDF (1,381 words each; only box order differs); chart image identical to v7 (sha256 90647d154d8b3c1d5ef3 in v7 docx, v8 docx and both build dirs), alt text identical; every number in v8 equals v7 (token comparison: only citation years and list numerals differ, plus "90-day", "6-month"); no CI, cross-validation, AUC, p-value, bootstrap, test set, lift, rho, embeddedness, mediation, stressor on the page; single accent color; fictional label in header, title, chart subtitle, caveats; Rubenstein placeholder sentence gone (it appears only in the item 2 paragraph, as intended); footer lists 9 sources, each cited at least once, no others; item 2 Mitchell inference sentence dropped (good); "workload, not overtime", "this data does not record how people felt", "consistent with, illustration only", "Classic theory holds" (theory) kept; item 1 equity sentence dropped (fine, equity is only in item 2 as theory); suggestions are group-level (overtime group, junior job level, all new hires), no age, gender or marital targeting, no pay cut, no small group (156 and 215 people); item 2 is shown as part of overtime and not added; no typos found.
**Summary sentence:** v8 says "Newer staff also leave more often, with or without overtime; we flag that as one career-stage picture to watch, not a cleared finding." It matches the exec2 page sentence in substance (page: "Newer, more junior staff also leave more often, with or without overtime; that is shown below as one career-stage picture to watch, not as a cleared finding"). I cannot confirm it is verbatim to the wording I sent Iris because that exact text is not recorded in this log; the meaning and numbers are right.
**Required fixes:**
- V1 (p1 watch box, research paragraph): apply T1 and T2 (the paragraph is Ellis's unedited text).
- V2 (p2 citations without claims): the one-line Why lines were removed, so Podsakoff (2007), Griffeth (2000), Hausknecht (2009) and Mitchell (2001) now stand next to suggestions without the claim they support, which reads as "research says this works". Podsakoff is cited nowhere else in the text. Fix both: (i) in the "Overtime workers" paragraph after "if anything slightly protective (Rubenstein et al., 2018)." add "Obstacles like red tape and unclear roles go with higher turnover, while stretching demands do not (Podsakoff et al., 2007)."; (ii) replace "These are ideas to test, not proven fixes. Each applies to teams and groups as a whole, never to individuals and never selected by age, gender or marital status." with "These are ideas to test, not proven fixes. Each applies to teams and groups as a whole, never to individuals and never selected by age, gender or marital status. Sources in brackets give research background for each idea; none of them tested the idea itself."; (iii) overtime suggestion 3: after "compare with similar teams that did not change" add "; research finds single factors only modestly related to leaving, so local results decide" before the citation. To keep 2 pages, cut "In this fictional data, the overtime group is large enough to move the overall number." and "Both are illustrations of scale, not forecasts of what any change would achieve." (the summary already says "an illustration, not a forecast"); Iris must re-confirm 2 pages and that docx equals PDF.
- V3 (suggestion 2 of the watch list and tie-in T3 wording): once T3 is applied the Bauer cites in the watch list are supported by the box paragraph; no further change.
**Optional:** add "(156 people)" to "Aimed at junior-level overtime workers as a job-level group"; add "for all new hires, never by personal characteristics" to the "Look into" lead (the p2 sentence covers it but comes after); the watch box splits across p1 and p2 (box top on p1, "Look into" at the top of p2), acceptable but a keep-together would read better if space allows.
**Next:** after Iris and Ellis apply T1 to T5 and V1 to V2, spot-check those swaps in v9; numbers need no further check.

## Final sign-off: attrition_narrative_v9 (Quinn), Oct 9, 2026, about 5:45 PM PT
Reviewed: deliverables/attrition_narrative_v9.pdf (5:35:54 PM PT) and .docx (5:35:53 PM PT), both PNGs; research/exec_research_tiein_v2.md (Ellis, commit adae2dd, T1-T5 applied).
- V1, V2(i)-(iii), required summary sentence, (156 people), "for all new hires, never by personal characteristics": all present verbatim (text-matched in the PDF). Two pages. No technical terms, no exact dollar cut, no 3,221 / 3,338, no "stake".
- Numbers and chart unchanged from v7/v8. Fictional-data label in header, chart subtitle, caveats.
- Research: qualifiers kept (workload not overtime; theory not finding; "this data does not record how people felt"; consistent with / illustration only). Suggestions are group-level, framed as ideas to test.
- Unverified (disclosed in Ellis's file): Rubenstein typeset tables (Wiley 403); Greenhaus & Beutell full text; Mitchell, Podsakoff, Hausknecht checked at abstract level.
Verdict: APPROVED. Cleared for repo and sharing.
