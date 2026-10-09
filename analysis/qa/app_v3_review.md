# App v3 review pack: one cleared finding, minimum group size

Branch `app-v3` (from main `cb0bd72`). **Not deployed.** The live app is still v2 (`e3da329`). For Quinn to check before redeploy.

Why: the v2 headline group (overtime and under about $2,500, 69 people) fails the standing rule (at least 100 employees and 24 leavers). The only group that clears every check is OverTime = Yes (`analysis/exec/candidates.csv`, id `ot_yes`, `pass_all` TRUE).

## 1. What changed

| Area | Before (v2) | Now (v3) |
|---|---|---|
| Headline | "Overtime workers earning under about $2,500 a month: 69.6% left (all 1,470, in-sample)", CI, held-out 63.2% (12 of 19) | "Overtime workers are 28% of staff but 54% of leavers: 30.5% left vs 10.4% of everyone else", then 416 people, 127 of the 237, 1.9x the company average, impact illustration. No CI or jargon |
| Findings panel / banner | "Validated findings (Quinn): OverTime; then income under about $2,500 within OverTime" | "Cleared finding: overtime." plus the highlight rules in one sentence; pay and career stage "context only" |
| Starting view | root split, then split of the higher-rate child (69 people) | root split only (OverTime), cleared node selected |
| Accent | validated leaves at or above 32% | only a node that is validated AND big enough AND at or above the highlight rate |
| Slider default | 32% (2x) | 25% (smallest whole % at or above 1.5x of 16.1%) |
| New control | none | "Smallest group to act on (employees)", default 100, with "100 employees = 6.8% of staff" and the 24-leaver floor |
| Too-small groups | no concept | dashed outline, "too small to act on" line in the box, hover tip, tap sheet, context menu, card, importance pop-up, custom-split preview, legend, leaf table, CSV; never accented or headlined; no impact figure |
| Node card / pop-up / menus | n, share of data, points vs overall | n, share of employees, share of leavers, multiple of the company rate, impact illustration |
| Model fit | "This 11-group tree ranks rows with AUC 0.746 on the data it was grown on"; comparison "held-out test AUC of the analysis tree was 0.670 (logistic regression 0.863)" | "In-sample AUC (this tree on all 1,470 rows): 0.746" (computed per tree); "The analysis tree scored 0.670 on the held-out test set (a different measure from the in-sample number above)." Metric card renamed "In-sample AUC" |
| Context | none | collapsed "Context: pay and career stage (not a finding)", numbers computed from the data |
| Removed | `HELD_OUT_TEXT` (69-person group), `validated_group`, secondary exploratory headline line (90.3%, n = 31) | |
| Kept | fictional-data banner (short mobile text "Synthetic IBM teaching dataset. Not real people."), sensitive-characteristics caution (About, README), in-sample caveats, primary-split-only importance label, mobile sheet, desktop menu, importance pop-up | |

`R/partition.R`, `data/`, `tests/smoke.R`: unchanged (empty diff against `cb0bd72`).

## 2. How the thresholds apply (node vs end group)

- `R/presentation.R::node_assess()` evaluates **every non-root node**, split nodes included. OverTime = Yes is a split node as soon as the tree is grown deeper, so the accent follows the node, not "leaves only".
- `too_small` = n under the size control (default 100) **or** leavers under 24 (`ceiling(10% x 237)`, `thresholds.json` rule1_size). The root is never too small.
- `cleared` = not too small AND status "cleared" AND rate at or above the highlight slider (default 25%). Status "cleared" is `validation_status()`: bundled IBM data and the path is exactly `OverTime = Yes`. OverTime = No is "comparison group" (never accented); everything else is "exploratory".
- Exploratory **leaves** that are big enough and at or above the slider keep v2's dark outline ("Big enough and above X%, but not validated"). On the default full tree there are none, because every high-rate leaf is too small.
- The held-out direction test and the bootstrap stability test are not recomputed in the app. They are the typed-in facts behind "validated" (section 4). Raising the size control above 416 turns the finding off, because a group that small floor-fails is "too small", never highlighted. Raising the highlight rate above 30.5% does the same. The headline then says "No group highlighted" and gives the rules.
- Uploaded data: nothing can be validated, so nothing is accented; the headline is the highest-rate big-enough group, labelled exploratory, in dark text.

## 3. Verified numbers (all on the full 1,470 rows)

| Figure | Value | Computed from data | Source file |
|---|---|---|---|
| Employees / leavers | 1,470 / 237 (16.1%) | yes | `exec_results.json` (n, leavers, company_rate 0.161224) |
| OverTime = Yes | 416 people, 28.3% of staff | yes | `candidates.csv` ot_yes: n, pct_employees |
| Leavers in group | 127 of 237 = 53.6% | yes | ot_yes: leavers, pct_all_leavers |
| Rate | 30.5% vs 10.4% (OverTime = No: 110 of 1,054) | yes | ot_yes: rate, rate_outside; ot_no |
| Multiple of company rate | 1.89x (shown 1.9x) | yes | ot_yes: lift |
| Impact | (127 - 416 x 237/1470) / 1470 = 4.077 points, shown "about 4.1" | yes | ot_yes: impact_pp_to_avg 4.0776 (uses the rounded 0.1612; the app uses the exact rate; both round to 4.1) |
| Too-small examples | OverTime and income under $2,475: 69 people, 48 leavers | yes | `candidates.csv` ot_inc2475 |
| Pay context (cut $3,500) | 472 lower-paid left at 27% vs 11%; 95% in job level 1; no overtime: 16% (lower-paid) vs 8% (better-paid) | yes | `pay_bands.csv` (3500 row), `exec_findings_draft.md`; thresholds `context` |
| Floors | 100 employees = 6.8% of staff; 24 leavers | yes | `thresholds.json` rule1_size |

Impact formula in code: `impact_points(yes, n, y) = 100 * (yes - n * mean(y)) / length(y)`. Shown only for groups that are not too small and above the company average. It is never summed.

## 4. Typed-in numbers (not read from `analysis/` at run time)

All live in `R/presentation.R`. `tests/check_typed_numbers.R` compares each with `candidates.csv`, `thresholds.json` and `analysis/METHOD.md` (all 20 checks pass; 19 value comparisons plus the METHOD.md AUC line).

| Constant | Used for | Source |
|---|---|---|
| `CLEARED_FINDING` (test 37 of 114 = 32.5%, CI 24.6-41.5; other side 34 of 327 = 10.4%; test overall 16.1%; stability 78.6% of 500 refits; Wilson 26.3-35.1) | About tab, "technical detail" only (not the headline) | `candidates.csv` ot_yes, ot_no |
| `RULE_MIN_N` 100, `RULE_LEAVER_SHARE` 0.10, `RULE_MIN_LIFT` 1.5 | floors, slider default, findings note | `thresholds.json` |
| `HELD_OUT_AUC` 0.670, `HELD_OUT_AUC_TEXT` | Model fit tab | `analysis/METHOD.md` (held-out test set, AUC 0.670) |
| `PAY_CONTEXT_CUT` 3500 | context box | `thresholds.json` context |

## 5. Tests

- `tests/regression_snapshot.R`: all 7 files **byte-identical** to `analysis/qa/app_v2_regression/v1_before/` and `v2_after/` (SHA-256 first 16: importance 39a5f006736069b7, leaves 70ccecbcd602679f, nodes 5b899a1ef389f510, overtime_yes_candidates e8dcf733d349be1c, root_candidates 854c6d242e7dc260, snapshot.json 49be88b9ecbb299b, two_split_nodes eab2a60e429812ff). `engine==server TRUE`.
- `tests/smoke.R`: passes (OverTime improvement 24.08; 11 leaves; in-sample AUC 0.746).
- `tests/check_typed_numbers.R`: passes.
- Server-logic checks (`testServer`): default, full tree, size 500, highlight 40%, size NA / 0 / 5000 / 100.5, custom split on a too-small node, a non-attrition target, node CSV export.
- Browser checks (Chromium headless; desktop 1440x900, iPhone 13 touch 390x844; also 320, 768, 1024, 1280): no page-level horizontal scroll, no legend overflow, tap and long-press sheets open and cancel, right-click menu opens, importance pop-up opens, 14 dashed nodes on the full tree, exactly one accent node (node 3). No JavaScript errors except the two local-only 404s from the Debian R packages (crosstalk `strftime-min.js`, DT bootstrap5 css); the shinyapps.io builds do not have them.
- Default model-fit AUC for the starting 2-group tree is 0.651; the 11-group full tree is 0.746. The 0.670 held-out figure is a different tree and measure, which the page says.

## 6. Judgment calls for Quinn

1. **Impact line is hidden for too-small groups**, and shown for any other group above the company average (including exploratory ones, with an "Exploratory" pill). `thresholds.json` says the impact is for cleared groups on the executive page; the app is an explorer, so it shows the illustration for big exploratory groups too. If you want it for the cleared group only, it is one condition in `impact_sentence()`.
2. **Slider default moved from 32% (2x) to 25% (1.5x)**, to match the rule. It is the smallest whole percent at or above 1.5 x 16.12%.
3. **Leaver floor for uploaded data** is 10% of that file's events (`leaver_floor()`), which equals 24 on the IBM data.
4. About-tab technical detail still names the 69-person group as the example of "too small"; the headline, panel, tags and README no longer do.
5. The OverTime = No node is tagged "Comparison group", not "validated".

## 7. Screenshots (`docs/screenshots/`, local app, not the live site)

Desktop 1440x900: `v3_desktop_01_default.png`, `v3_desktop_01_default_full.png`, `v3_desktop_02_context_menu_cleared.png`, `v3_desktop_03_full_tree.png`, `v3_desktop_04_context_menu_too_small.png`, `v3_desktop_05_importance_popup.png`, `v3_desktop_06_node_card_too_small.png`, `v3_desktop_07_control.png`, `v3_desktop_08_model_fit.png`, `v3_desktop_09_about.png`.

Phone 390x844: `v3_mobile_01_default.png`, `v3_mobile_01_default_full.png`, `v3_mobile_02_action_sheet_cleared.png`, `v3_mobile_03_full_tree.png`, `v3_mobile_04_action_sheet_too_small.png`, `v3_mobile_05_importance_popup.png`, `v3_mobile_06_control.png`, `v3_mobile_07_longpress_sheet.png`.

## 8. Deploy (only after Quinn clears it and the user says go)

From the repo root after merging `app-v3` (credentials come from `SHINYAPPS_TOKEN` and `SHINYAPPS_SECRET`; never print them):

```
Rscript -e 'rsconnect::setAccountInfo(name="jaysha301", token=Sys.getenv("SHINYAPPS_TOKEN"), secret=Sys.getenv("SHINYAPPS_SECRET")); rsconnect::deployApp(appDir=".", appName="ibm-hr-attrition-tree", account="jaysha301", appFiles=c("app.R","R/partition.R","R/presentation.R","www/app.css","www/app.js","data/WA_Fn-UseC_-HR-Employee-Attrition.csv"), forceUpdate=TRUE, launch.browser=FALSE)'
```
