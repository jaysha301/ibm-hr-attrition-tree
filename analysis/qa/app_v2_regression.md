# App v2 regression check (numbers unchanged)

Prepared by Soup for Quinn, Oct 8, 2026 (PT). Branch `app-v2`. Compares the live app (v1, `main` at f2d2a49, app.R as of 3bca5d3) with the v2 redesign.

## Result: IDENTICAL

All 7 snapshot files are byte-identical between v1 and v2 (same SHA-256). `R/partition.R`, the engine that computes every split, count, rate, improvement and metric, is unchanged (`git diff main -- R/partition.R` is empty). v2 only adds presentation code (`R/presentation.R`, `www/`).

| File | v1 vs v2 |
|---|---|
| `snapshot.json` | identical |
| `root_candidates.csv` | identical |
| `overtime_yes_candidates.csv` | identical |
| `two_split_nodes.csv` | identical |
| `auto_tree_nodes.csv` | identical |
| `auto_tree_leaves.csv` | identical |
| `auto_tree_importance.csv` | identical |

**How it was produced.** `Rscript tests/regression_snapshot.R <out_dir>` drives the real Shiny server with `shiny::testServer` and the bundled IBM data under default settings (Gini, minsplit 20, minbucket 7, max depth 5, cp 0.01, 27 default predictors, integers with ≤10 values as categories). Steps: (1) reset to the root; (2) record the root's predictor table; (3) Auto-split the root, select the OverTime = Yes node and record its table; (4) Auto-split it (the two-split view); (5) Grow full tree, then record nodes, leaves, primary-split importance and in-sample metrics at thresholds 0.5 and the base rate. It also re-grows the tree through the engine alone and checks it equals the server result (`engine_matches_server: true`). The same script was run on v1 (before) and v2 (after). Outputs: `analysis/qa/app_v2_regression/v1_before/` and `v2_after/`.

## Match to the approved findings (full-data column)

The app is an in-sample, full-data explorer, so it matches the **full-data** figures in `analysis/findings_draft.md` (v0.3, approved), not the held-out test figures.

| Approved figure (source) | App v1 = v2 | Match |
|---|---|---|
| 1,470 employees, 237 left, 16.1% (`qa_log.md` §1; findings_draft header) | n 1470, Yes 237, 16.1% | ✓ |
| OverTime: 30.5% (127/416) vs 10.4% (110/1,054), full data (`findings_draft.md` line 27) | Yes 127/416 = 30.5%; No 110/1054 = 10.4% | ✓ |
| Within OverTime: income < $2,475 69.6% (48/69) vs 22.8% (79/347), full data (`findings_draft.md` line 32) | 48/69 = 69.6%; 79/347 = 22.8%; cut `MonthlyIncome < 2475` | ✓ |
| Cutpoint $2,475 (`findings_draft.md` line 37; `METHOD.md` §"Income cutpoint") | MonthlyIncome < 2475 | ✓ |

Not comparable by design: the held-out test rates (32.5% vs 10.4%; 63% for 12/19), test AUC 0.670 and CV AUC 0.699 come from Rowan's train/test rpart analysis. The app does not split train/test. Its AUC (0.746 on the full auto tree) is in-sample and labeled as such in the app.

## Key values (v2 = v1)

Root predictor table, top 5 (primary-split improvement; share = importance_pct):

| Variable | Best split | Improvement | Share % | Left n (rate) | Right n (rate) |
|---|---|---|---|---|---|
| OverTime | OverTime in {No} | 24.0830 | 10.45 | 1054 (10.4%) | 416 (30.5%) |
| TotalWorkingYears | TotalWorkingYears < 1.5 | 21.1050 | 9.16 | 92 (48.9%) | 1378 (13.9%) |
| MonthlyIncome | MonthlyIncome < 2802 | 18.5574 | 8.05 | 335 (30.7%) | 1135 (11.8%) |
| JobLevel | JobLevel in {4, 5, 2, 3} | 17.9618 | 7.79 | 927 (10.1%) | 543 (26.3%) |
| YearsAtCompany | YearsAtCompany < 1.5 | 17.7283 | 7.69 | 215 (34.9%) | 1255 (12.9%) |

OverTime = Yes node (n 416), top 5:

| Variable | Best split | Improvement | Share % | Left n (rate) | Right n (rate) |
|---|---|---|---|---|---|
| MonthlyIncome | MonthlyIncome < 2475 | 25.2105 | 12.96 | 69 (69.6%) | 347 (22.8%) |
| JobLevel | JobLevel in {4, 5, 2, 3} | 24.2388 | 12.46 | 260 (17.3%) | 156 (52.6%) |
| JobRole | JobRole in {Research Director, Healthcare Representative, Manufacturing Director, Manager} | 17.1774 | 8.83 | 126 (8.7%) | 290 (40.0%) |
| TotalWorkingYears | TotalWorkingYears < 8.5 | 15.4427 | 7.94 | 183 (45.9%) | 233 (18.5%) |
| StockOptionLevel | StockOptionLevel in {2, 1} | 14.6354 | 7.53 | 205 (17.1%) | 211 (43.6%) |

Full auto tree under defaults: 21 nodes, 11 leaves. Primary-split importance (no surrogates):

| Variable | Improvement | Share % |
|---|---|---|
| MonthlyIncome | 25.2105 | 23.93 |
| OverTime | 24.0830 | 22.86 |
| JobRole | 15.4244 | 14.64 |
| StockOptionLevel | 11.2878 | 10.71 |
| TotalWorkingYears | 9.7373 | 9.24 |
| EnvironmentSatisfaction | 8.9298 | 8.47 |
| TrainingTimesLastYear | 5.4352 | 5.16 |
| YearsAtCompany | 5.2632 | 4.99 |

In-sample metrics at threshold 0.5: accuracy 88.2% (baseline 83.9%), AUC 0.746379, sensitivity 33.8%, specificity 98.6%, Brier 0.099391; TP 80, FN 157, FP 17, TN 1216.

## What changed in v2 that a reviewer should know (display only)

- **Starting view.** v1 opened on the root only. v2 opens on the two-split view: Auto-split the root, then Auto-split the higher-rate child. It uses the same function as the Auto-split button. On the IBM data this is exactly the two validated splits, showing 69.6% (48/69) in the takeaway title. **Reset** still returns to the root.
- **Takeaway title** is computed from the tree: the highest-rate leaf with n ≥ max(20, minbucket). It is labeled "validated split (Quinn)" only when its path is OverTime, optionally followed by MonthlyIncome at the $2,475 cut, on the bundled data; otherwise "exploratory".
- **Highlight**: leaves at or above a user threshold (default about 2× the base rate, 32%) get the single accent color. Display only.
- **Rounding on screen** is unchanged: rates 1 dp, improvement 2 dp, share 1 dp. Exports keep full precision.
- **Importance** remains primary-split only, labeled "Surrogate splits get no credit" in the per-node pop-up, the node preview and the Model fit tab.
- The fictional-data banner and Quinn's validated-findings note are on the main screen.
