# Attrition patterns in IBM's fictional HR teaching dataset: a classification-tree first read (not real employees)

> **APPROVED (v0.3), wording only, for Iris.** Quinn approved v0.2 and these three wording fixes (Oct 8, 2026, 3:39 PM PT) and does not need to see this file again. Iris may use only the surviving findings in this file. `research/interpretation.md` is not cleared.
> The tree was not refit and no previously reproduced result was changed.

**Opening paragraph.**
- **Question (from `BRIEF.md`):** what are the top predictors of attrition, and why do they rank where they do?
- **Data:** IBM's **fictional** HR teaching dataset (Kaggle `pavansubhasht/ibm-hr-analytics-attrition-dataset`). It has 1,470 simulated employees, 237 of whom left (16.1%). It describes no real workforce and says nothing about Intuitive or any other employer.
- **Supported result:** cross-validation supports only the first two splits of the classification tree; everything deeper is exploratory.
  1. Overtime.
  2. Within overtime, monthly income under about $2,500.
- **Leading segment:** in held-out test data, overtime workers paid under about $2,500 a month left at 63% (12 of 19, 95% CI 41–81%), compared with 26% of better-paid overtime workers (25 of 95, CI 18.5–36%).
- **Caveats:** this group is almost entirely entry-level, so pay cannot be separated from career stage. All patterns here are descriptive associations, not causes.

## Ranking
Only the two cross-validation-supported splits are ranked:
1. **Overtime**, the first split.
2. **Monthly income under about $2,500, within overtime**, the second split.

No other variable is ranked. Importance percentages are deliberately left out of this draft; see METHOD §6 for them and why.

## Findings (in this fictional dataset)
Rates lead with the **held-out test set** (n = 441), shown as rate (left/n, Wilson 95% CI). Full-data and training rates are labelled.

### 1. In this fictional dataset, overtime separates leavers most clearly.
- **Test:** 32.5% of overtime workers left (37/114, CI 24.6–41.5%), compared with 10.4% of others (34/327, CI 7.5–14.2%). That is about 3 times as high.
- **Full data:** 30.5% (127/416, CI 26.3–35.1%) vs 10.4% (110/1,054, CI 8.7–12.4%).
- Overtime is associated with leaving. It may mark understaffed or junior roles; this analysis does not show that overtime causes people to leave.

### 2. In this fictional dataset, the highest-attrition group is overtime workers among the lowest paid (under about $2,500/month).
- **Test:** 63.2% left (12/19, CI 41.0–80.9%), compared with 26.3% of better-paid overtime workers (25/95, CI 18.5–36.0%).
- **Full data:** 69.6% (48/69, CI 57.9–79.2%) vs 22.8% (79/347, CI 18.7–27.5%). This figure includes the training rows the cutpoint was chosen on.
- **Without overtime, the income gap is smaller.**
  - Test: 17.9% (7/39, CI 9.0–32.7%) vs 9.4% (27/288, CI 6.5–13.3%).
  - Full data: 18.5% vs 9.1%.
- **The cutpoint is approximate.**
  - The tree split at $2,475, but in bootstrap refits where the overtime branch split on income, the median cut was $2,494.
  - About 37% landed above $2,700, clustered near $2,800 and $3,200–4,000.
  - So "under about $2,500" (the lowest ~15% of earners) is the honest description, not a precise threshold.
- **Pay cannot be separated from career stage.** Of the 220 employees under $2,475, 210 (95%) are JobLevel 1. Their median age is 30, compared with 36 for everyone else (full data).

  | Income × JobLevel (full data) | 1 | 2 | 3 | 4 | 5 |
  |---|---|---|---|---|---|
  | under $2,475 | 210 | 10 | 0 | 0 | 0 |
  | $2,475 or more | 333 | 524 | 218 | 106 | 69 |

  Within JobLevel 1 alone, the gap persists in the full data: 35.7% (75/210, CI 29.5–42.4%) vs 20.4% (68/333, CI 16.4–25.1%). This is still an association in simulated data. **It does not show that low pay causes attrition.** The accurate label for this group is "lowest-paid, mostly entry-level (JobLevel 1) employees."

### 3. In this fictional dataset, early-career markers travel together.
- Low income, JobLevel 1, few total working years, short tenure and younger age carry overlapping information. In the full data, income correlates r = 0.95 with JobLevel and r = 0.77 with total working years.
- Which marker the tree picks first changes between refits. In 500 bootstrap refits, the first split was overtime in 44.4%, income in 30.6% and total working years in 15.4%.
- Read them as one early-career cluster, not as separate predictors.

### 4. Exploratory only, not supported by cross-validation: in this fictional dataset, single employees among better-paid overtime workers.
- **Single vs married or divorced:**
  - Test: single employees left at 46.2% (12/26, CI 28.8–64.5%), vs 18.8% (13/69, CI 11.4–29.6%) for married or divorced employees.
  - Train only: 38.7% vs 14.1%.
- **Stock options:**
  - All 470 single employees in the dataset have no stock options, but so do 161 married or divorced employees. **Being single cannot be separated from having no options.**
  - Within this group (full data), the rates are:
    - Single: 40.6% (41/101, CI 31.5–50.3%).
    - Married or divorced with no options: 25.6% (11/43, CI 14.9–40.2%).
    - Married or divorced with options: 13.3% (27/203, CI 9.3–18.7%).
- **Role, among these single employees:**
  - Test: lab technicians and sales roles (mostly Sales Executives) left at 76.9% (10/13, CI 49.7–91.8%), vs 15.4% (2/13, CI 4.3–42.2%) for other roles.
  - Train only: 59.5% vs 18.4%.
  - These rest on 13 vs 13 test employees.
- **Neither split is supported by cross-validation pruning.** With seven split tests on the test set, they are suggestive at best.

### 5. In this fictional dataset, the tree is a coarse segmentation, not a predictor.
- **Test AUC is 0.670** (bootstrap CI 0.605–0.737). Cross-validated AUC is 0.699 (5 × 10-fold, fold SD 0.058).
- **Balanced accuracy is 0.618 at a threshold of 0.161**, the training base rate. At that threshold the tree flags 33.8% of leavers and correctly clears 89.7% of stayers. At a 0.5 threshold, balanced accuracy is 0.578.
- **The tree uses only part of the signal in the data.** A logistic regression on the same 27 predictors and the same split reaches test AUC 0.863 (CI 0.814–0.908), with cross-validated AUC 0.838.
- **The two supported splits give the full tree's test performance on their own:** a 2-split tree (overtime, then income within overtime) scores test AUC 0.669, vs 0.670 for the full 15-split tree.
- The segments above describe some of what distinguishes leavers. They are not a way to predict individuals.

## Not carried forward
None of these tree splits holds up on the test set. Environment satisfaction, job involvement, and distance from home do show simple associations on the test set; this list is only about the tree splits:
- environment satisfaction
- distance from home
- relationship satisfaction (reverses in test)
- job involvement
- education field
- number of companies worked
- the no-overtime, under-$1,559 group: test 25.0% (2/8, CI 7.1–59.1%)

Importance percentages are also left out.

## Caveats
- **Fictional data.** This is IBM's teaching dataset of simulated employees. The patterns describe that simulation, not any real workforce or employer.
- **Descriptive only.** Age, gender and marital status are sensitive characteristics. The segments here are descriptive and **must not be used to target or make decisions about individuals.**
- **Snapshot timing.** Tenure fields and the survey fields (satisfaction, involvement) are measured at the same snapshot as the outcome. They are not known to come before leaving, and for leavers they may describe the time of exit.
- **No causal claims.** The data are observational and cross-sectional. A split describes who left more, not why they left.
- **Exploratory depth.** Cross-validation supports at most the first two splits (overtime, then income under about $2,500 within overtime).
  - With this analysis's xval seed, the 1-SE rule pruned to the root. Across 20 other xval seeds, it kept these two splits in 18 and pruned to the root in 2.
  - Everything below level 2, in `tree_rules.txt` and `tree.png`, is exploratory.
- **Excluded variables.** DailyRate, HourlyRate and MonthlyRate were excluded on Ellis's advice because they cannot be read as pay. MonthlyIncome is the only pay variable.

## Changes from v0.1 (per `qa_log.md`)
- Every segment now leads with test rates, n and Wilson CIs; train-only rates are labelled and moved out of the lead.
- The 1-SE claim is replaced, and everything below level 2 is now marked exploratory.
- The balanced-accuracy threshold is stated.
- The logistic benchmark and the 2-split tree are added, and the "a tree can't separate" line is removed.
- The stock-option wording is corrected to one-way.
- Importance tables and the train-only single-split table are removed (moved to METHOD only).
- The cutpoint is now "about $2,500", with its bootstrap spread.
- The JobLevel crosstab and the no-causal caveat are added.
- Causal and overconfident wording is removed.
- Fictional-data labels are in the title and every headline; the sensitive-characteristics and snapshot-timing caveats are added.
- Points to `BRIEF.md`.

## Number sources
- Test, full-data and train counts, Wilson CIs, and the JobLevel and stock-option figures: `qa_log.md` §1b and §2c (from `qa/qa_checks*.out`). I independently recomputed every Wilson CI quoted here from those counts (95% Wilson score), and all match.
- AUC, CV, balanced accuracy and bootstrap root frequencies: `metrics.json`.
- 1-SE across 20 seeds, logistic benchmark, 2-split tree and cutpoint spread: `qa_log.md` §1, §2d and §2e.
