# METHOD: top predictors of attrition (IBM HR Analytics), classification tree

Status: v0.2, revised after Quinn's review (`analysis/qa_log.md`, APPROVED WITH FIXES). Not signed off yet. The project brief is `BRIEF.md` (written by GG). Per the brief, Iris starts the write-up only after Quinn signs off. v0.2 changes only text: the tree was not refit and no reproduced result changed.
Script: `analysis/attrition_tree.R`. Run it from the project root with `Rscript analysis/attrition_tree.R`. The output is deterministic.
Engine: R 4.5.0, rpart 4.1.24, pROC 1.18.5, rpart.plot 3.1.5, jsonlite 1.9.1.

## 1. Question
From `BRIEF.md`: what are the top predictors of employee attrition in the IBM HR Analytics training set, and why are they top predictors? The brief asks for recursive partitioning, a JMP-style tree. Restated here: which employee attributes best predict attrition (Attrition = Yes), and why? Here "why" means which split rules separate leavers from stayers, in which direction, and by how much. The user asked for predictive patterns, meaning segments defined by combinations of attributes, not just a ranked list. A JMP-style recursive-partitioning tree gives both.

## 2. Data source and verification
- File: `data/WA_Fn-UseC_-HR-Employee-Attrition.csv`. This is the canonical file name of Kaggle dataset `pavansubhasht/ibm-hr-analytics-attrition-dataset`. Kaggle requires a login, so I took the file from a public mirror that needs none.
- Source URL (downloaded verbatim): https://raw.githubusercontent.com/TheAlgorithms/Jupyter/master/machine_learning/Support_Vector_Machine/WA_Fn-UseC_-HR-Employee-Attrition.csv
- Data source per `BRIEF.md`: Kaggle `pavansubhasht/ibm-hr-analytics-attrition-dataset`, an open dataset.
- **Current SHA-256 of `data/WA_Fn-UseC_-HR-Employee-Attrition.csv`:** `d11789e1db393cd1d985ca41a0e73a1d405543fb2c0d540a3b4f7d723bca92f7` (226,503 bytes, no BOM).
- **Hash history:** v0.1 recorded `e9f55fbf0a5c058306225d131311e135379d82ad0c94c33738ec75b9a179db9c` (226,506 bytes). That was the file as downloaded, which begins with a 3-byte UTF-8 BOM (EF BB BF). The mirror still hashes to that value.
  - At 3:31:05 PM PT on Oct 8, 2026, after the v0.1 run, the BOM was stripped in place. The inode is unchanged, and the file's birth time is still my 3:27 PM PT copy.
  - Apart from those 3 bytes, the content is byte-identical: `tail -c +4 <mirror copy> | cmp` against the current file shows no difference. Line endings are unchanged (LF).
  - The script reads with `fileEncoding = "UTF-8-BOM"`, which handles both versions. Quinn reran the script on the current file and got byte-identical `metrics.json`, `tree_rules.txt`, `tree_splits.csv`, `tree_leaves.csv` and `single_split_scan.csv` (`qa_log.md` §0). Results are unaffected.
  - Who stripped the BOM cannot be told from the files. There is no git repository, no shell history, and no script in the project that writes this file. All readers only read it.
- Cross-check: after parsing, the file is identical cell for cell, with the same column order, to two independent copies:
  - IBM's own copy: https://raw.githubusercontent.com/IBM/employee-attrition-aif360/master/data/emp_attrition.csv
  - https://raw.githubusercontent.com/PacktPublishing/Statistics-for-Machine-Learning/master/Chapter04/WA_Fn-UseC_-HR-Employee-Attrition.csv
  - The byte-level differences are only the BOM and line endings.
- Checks (enforced by `stopifnot` in the script):
  - 1,470 data rows and 35 columns.
  - Attrition, Age, OverTime, MonthlyIncome, JobRole, and YearsAtCompany are all present.
  - 0 missing values. EmployeeNumber is unique.
  - Attrition: Yes = 237, No = 1,233, so the overall rate is 16.12%.

## 3. Exclusions (documented before fitting)
| Column | Reason |
|---|---|
| EmployeeNumber | Row identifier |
| EmployeeCount | Constant (1 unique value) |
| Over18 | Constant (1 unique value) |
| StandardHours | Constant (1 unique value) |
| DailyRate, HourlyRate, MonthlyRate | **Excluded per Ellis.** They cannot be read as pay. For context, their correlations with MonthlyIncome are 0.008, −0.016, and 0.035, and with each other 0.032 or less in absolute value. **MonthlyIncome is the only compensation variable.** |

- Nothing derived from Attrition is used.
- 27 predictors remain:
  - 7 categorical, entered as factors: BusinessTravel, Department, EducationField, Gender, JobRole, MaritalStatus, OverTime.
  - The rest are numeric. Ordinal 1-4 survey scales and Education/JobLevel are kept as numbers, so splits are thresholds.

## 4. Tree settings (pre-specified, not tuned)
- Split: stratified 70/30 by Attrition with seed 20261008. Train n = 1,029 (16.13% Yes); test n = 441 (16.10% Yes, 71 leavers).
- Model: `rpart(Attrition ~ ., method = "class", parms = list(split = "gini"))`. No class weights or altered priors, and equal misclassification loss.
- Complexity control: `cp = 0.01` (rpart default), `minsplit = 20`, `minbucket = 7`, `maxdepth = 5`. I fixed these before looking at any results and did not change them to improve test performance.
  - The resulting tree has 15 splits and 16 leaves, up to depth 5.
  - The cp tables for this tree and for a fuller reference tree (cp = 0.001), with 10-fold cross-validation inside the training set, are printed in `tree_rules.txt` for information only.
- The tree shown (`tree_rules.txt`, `tree.png`) is the training-set tree. It is used for interpretation.

## 5. Performance estimates
- **Held-out test set (n = 441):** (results: AUC 0.670 [bootstrap 0.605, 0.737]; balanced accuracy 0.618 at threshold 0.161, the training base rate, and 0.578 at threshold 0.5)
  - AUC from leaf probabilities, with a 95% CI from 2,000 stratified bootstrap resamples (pROC) and a DeLong CI.
  - Brier score.
  - Mean predicted vs observed attrition rate, as a check of calibration-in-the-large.
  - Sensitivity, specificity, and balanced accuracy at a 0.5 threshold and at the training base rate (0.161).
- **Cross-validation:** 5 × stratified 10-fold on all 1,470 rows with the same fixed setting (seeds 20261009–20261013). I report the mean and SD of fold AUC, pooled out-of-fold AUC for each repeat, mean balanced accuracy at the base-rate threshold, and mean out-of-fold predicted rate vs observed rate.

## 6. How predictors are ranked (three views, read together)
**v0.2 ranking rule (per Quinn).** The draft ranks only the two cross-validation-supported splits: (1) OverTime, then (2) MonthlyIncome under about $2,500 within overtime. Importance percentages are kept out of `findings_draft.md` and anything that goes to Iris.
- They are reported here for the record only, as **primary-split-only** shares, from Quinn's decomposition with a refit using `maxsurrogate = 0`, which gives an identical tree:
  - MonthlyIncome 29.6%
  - OverTime 16.5%
  - EnvironmentSatisfaction 10.9%
  - JobRole 8.7%
  - DistanceFromHome 8.3%
  - MaritalStatus 6.6%
  - Age 6.4%
  - NumCompaniesWorked 4.1%
  - EducationField 3.1%
  - RelationshipSatisfaction 2.9%
  - JobInvolvement 2.9%
- TotalWorkingYears and StockOptionLevel get 0.
- **Why income leads on importance:** surrogate credit is not the reason. Only 2.4 of its 30.9 surrogate-inclusive importance comes from surrogates. It ranks first because it is the primary split at two nodes, and improvements are summed across nodes.
- **Primary-only bootstrap top-5 frequency:** OverTime 95.0%, MonthlyIncome 88.8%, JobRole 39.0%, DistanceFromHome 33.6%, Age 26.8%, StockOptionLevel 26.2%, TotalWorkingYears 23.8%, EnvironmentSatisfaction 19.8%.
- **Never ranked as top predictors:** EnvironmentSatisfaction (two tiny level-5 splits), Age, DistanceFromHome, TotalWorkingYears and StockOptionLevel.
- The single-split scan (view 3 below) uses training data only. It stays in this METHOD file and is not used in the draft.

The three views used in v0.1:
1. **rpart variable importance.** For each variable, this adds up the goodness-of-split improvement over the splits where it is the primary split, plus credit from surrogate splits. A variable can rank high without appearing in the tree if it closely mimics a split that does.
2. **Split view:**
   - Every split at levels 1–5, with its rule, the n and attrition rate in the node, and the n and rate on each side, in training. The same rule is applied to the held-out test rows to see whether the gap holds up (`tree_splits.csv`).
   - The level-1/2 rules are also applied to all 1,470 rows (`metrics.json → full_data_level1_2_rules`).
   - Leaves are listed with their full path (`tree_leaves.csv`).
3. **Single-split scan, the JMP "Candidates" view.** For each predictor alone, it finds the best single binary Gini split on training data and records its improvement and the rate on each side (`single_split_scan.csv`). This shows the predictors that the tree hides because a correlated variable won the split.

**Stability.** I refit the same setting on 500 bootstrap resamples of the training set and recorded how often each variable is the root split and how often it is in the top 5 by importance. Tree structure is known to be unstable, so this guards against over-reading a single tree.

## 7. Why this answers "top predictors and why"
- The importance and the single-split scan show **which** variables carry signal.
- The split rules show **how**: the threshold or category, which side has more leavers, how large the gap is, and how many people are affected.
- The nested paths show **patterns**: for example, overtime combined with low income, rather than each attribute alone. Only the first two levels are CV-supported; deeper patterns are exploratory.
- The test-set and bootstrap checks show which patterns are robust and which are artifacts of small nodes.

## 8. Limitations
- **Fictional data.** IBM created this dataset for teaching; the employees are simulated, not real. Its patterns may not reflect any real workforce, and it can't speak to Intuitive or any real employer.
- **Observational, cross-sectional data, with no causality.** A split says who left more, not what made them leave. For example, overtime could be a cause, a marker of understaffed roles, or a correlate of junior status.
- **Class imbalance (16% Yes).** Accuracy is misleading here, so AUC and balanced accuracy are reported. Every balanced accuracy is stated with its threshold.
- **Depth supported by cross-validation.** At most the first two splits are supported (OverTime, then income under about $2,500 within overtime). Everything deeper is exploratory.
  - With this analysis's xval seed, the 1-SE rule pruned to the root (minimum xerror 0.958 at 2 splits). Across 20 other xval seeds, Quinn found it kept these 2 splits in 18 and pruned to the root in 2 (`qa_log.md` §1).
  - The v0.1 statement that the 1-SE rule prunes to the root was seed-specific and is withdrawn.
- **The tree uses only part of the signal in the data.**
  - A logistic regression on the same 27 predictors and the same split reaches test AUC 0.863 [0.814, 0.908], with CV 0.838 (SD 0.045). The tree gets 0.670 / 0.699.
  - The 2-split tree matches the full tree on test (AUC 0.669 [0.608, 0.732] vs 0.670) (`qa_log.md` §2e).
  - The data has signal; a shallow tree captures little of it. The tree is a coarse segmentation, not a predictor.
- **Importance is split-based and unstable.** rpart importance includes surrogate credit and depends on which correlated variable wins a split. MonthlyIncome, JobLevel, TotalWorkingYears, Age, and YearsAtCompany partly stand in for one another (correlation of MonthlyIncome with JobLevel is 0.95, with TotalWorkingYears 0.77, with YearsAtCompany 0.51, and with Age 0.50). In 500 bootstrap refits, the root is not OverTime in 55.6% of them: it is MonthlyIncome in 30.6% and TotalWorkingYears in 15.4%.
- **Pay vs career stage.** Of the 220 employees under $2,475, 210 (95%) are JobLevel 1 (crosstab in `findings_draft.md`; `qa_log.md` §2c). Their median age is 30, vs 36 for everyone else. Pay cannot be cleanly separated from career stage.
  - Within JobLevel 1, the income gap persists: 35.7% vs 20.4%. This is still no causal claim.
- **Income cutpoint.** $2,475 is not a precise threshold.
  - In bootstrap refits where the overtime branch split on income, the median cut was $2,494 (IQR $2,475–2,964).
  - About 37% of those refits landed at roughly $2,900–4,000.
  - Report it as "under about $2,500/month".
- **Marital status and stock options overlap one way.** All 470 Single employees have StockOptionLevel 0, but so do 161 married or divorced employees. Being single cannot be separated from having no options; the two are not equivalent.
- **Snapshot timing.** Tenure fields (YearsAtCompany, YearsInCurrentRole, YearsWithCurrManager, YearsSinceLastPromotion) and the survey fields (satisfaction, involvement) are measured at the same snapshot as the outcome. They are not known to precede leaving.
- **Sensitive characteristics.** Age, gender and marital status are descriptive only and must not be used to target or make decisions about individuals.
- **Small deep nodes.** Many splits at levels 4–5 rest on nodes of 8–43 training rows, and several reverse or vanish in the test set. Treat them as hypotheses.
- **Ordinal survey scales are treated as numbers.** Splits on JobInvolvement, EnvironmentSatisfaction, and RelationshipSatisfaction are thresholds on a 1–4 scale.
- **Plot labels round thresholds.** `tree.png` shows integer-valued cut points rounded (for example, "JobInvolvement >= 2" is the same as ">= 1.5" for integer data, and "Age >= 30" is ">= 29.5"). Exact thresholds are in `tree_rules.txt`.
- **The "why" is statistical here.** Ellis's I/O research will add mechanisms from the literature.

## 9. Files
- `analysis/attrition_tree.R`: the full pipeline.
- `analysis/tree_rules.txt`: the printed tree and cp tables.
- `analysis/tree.png`: the tree diagram.
- `analysis/tree_splits.csv`, `analysis/tree_leaves.csv`, `analysis/single_split_scan.csv`: the split, leaf, and single-split tables.
- `analysis/metrics.json`: every number quoted, plus the seed and settings.
- `analysis/findings_draft.md`: revised draft v0.2 for Quinn (not signed off).
- `analysis/qa_log.md`, `analysis/qa/`: Quinn's review and scripts (Quinn's files).
- `BRIEF.md`: the project brief (GG's file).
