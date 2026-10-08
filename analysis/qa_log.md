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

**d) Cutpoint stability ($2,475).** OverTime was the root in 222 of 500 bootstrap refits. In 185 of those 222 (83%), the overtime branch split next on MonthlyIncome (otherwise JobLevel 18, JobRole 6, Age 5, MaritalStatus 4, other 4). Distribution of that income cutpoint (n = 185): min $2,422, 5% $2,461, 25% $2,475, **median $2,494**, 75% $2,964, 90% $3,932, max $4,012. 54% fall in $2,400–2,500 and 61% within ±$100 of $2,475, but there's a **second mode at roughly $2,900–4,000 (~37%)**, near the JobLevel 1 pay range (JobLevel 1 incomes run $1,009–4,968). A single-variable check (the best income split among training overtime rows, 500 bootstraps) gives the same picture: median $2,494, IQR $2,475–2,964, 52% in $2,400–2,500. Across all nodes, income cutpoints span $1,412–19,793. **Conclusion:** "a low-income threshold around $2,500" is reasonably stable as a lower bound, but the exact $2,475 shouldn't be presented as precise. Present it as "under about $2,500/month (lowest ~15% of earners)" and note that refits sometimes put it nearer $3,000–4,000.

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
