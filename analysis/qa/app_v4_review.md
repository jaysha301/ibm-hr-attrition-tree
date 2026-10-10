# App v4 review (branch app-v4), for Quinn

Prepared Oct 10, 2026. **Not deployed.** Live app is v3.1 (`a3417de`, main `664c348`). v4 aligns the app with the Quinn-approved v9 narrative (6506bc9) and Rowan's guidance. The split engine `R/partition.R` and the 7 regression snapshots are unchanged.

## 1. What changed

| Area | v3.1 (live) | v4 |
|---|---|---|
| Findings | one cleared finding, "pay and career stage as context only" | **Cleared finding: overtime (including its lower-paid, mostly junior subgroup)**, with a nested sub-callout, plus **Worth watching (not a cleared finding): newer staff** |
| Headline banner | eyebrow "Cleared finding", headline unchanged | same headline (28% of staff, 54% of leavers, 30.5% vs 10.4%); eyebrow "Cleared finding: overtime (including its lower-paid, mostly junior subgroup)"; no CI, no exact cut |
| Findings panel | one-line note | a panel with a cleared block (rule line + nested sub-callout in accent tint) and a gray "worth watching" block with the v9 wording |
| Junior subgroup | not shown | shown as a **range** (earning under roughly $3,000 to $3,500 a month; about 115 to 130 people, 8% to 9% of staff; about 55% left; about 2.7 to 2.9 times the rest of overtime (about 20%); close to 30% of everyone who left) with "part of the overtime finding, not added to it". No exact cut in any headline; **no separate illustration** |
| Overtime node card, tap sheet, context menu | stats, illustration | same, plus the nested sub-callout (card) and one line "Includes its lower-paid, mostly junior subgroup ... not added to it" (menus) |
| Exact-cut node ($2,475, 69 people) | "too small to act on" | still "too small to act on", never accented; its card, sheet and menu add "Inside the overtime group ... not added to it", and point to the range in the panel |
| Worth watching | not shown | gray, **no accent**: dotted outline, "worth watching" node label, pill, card note, sheet/menu flag, leaf-table Note, node CSV status, legend entry, panel block. A node gets it only if it is **exactly** the staff with YearsAtCompany of 1 or less (215 people). In the default tree there is no such node, so it appears in the panel and legend only |
| Pay context box | "Context: pay and career stage (not a finding)", $3,500 cut | "Context: one career-stage picture (not a finding)", v9 wording (97% in job level 1; overtime job level 1: 156 people, 53%, vs 260 at higher levels, 17%), numbers from the data |
| Rule used in About and the highlight default | analysis/exec/thresholds.json (1.5x, default 25%) | analysis/exec2/thresholds.json: 100 employees and 24 leavers, 15 people above the company rate, 1.25x with Wilson lower end above the company rate, held-out check, stability inside the branch. Highlight default now 1.25x = **21%** (see judgment call 3) |
| About | "The one cleared finding" wording, "Why overtime is the one cleared finding" | "Cleared finding: overtime (including its lower-paid, mostly junior subgroup)", "Worth watching" paragraph, "How the overtime finding was cleared (technical detail)" including why the subgroup is a range |
| Legend | cleared / exploratory / too small | adds "Worth watching, not a cleared finding" (dotted gray swatch); cleared item now says "overtime" |
| README | v3 | v4 text, new typed-number table rows |

Unchanged on purpose: the size flag and "Too small to act on" (100 employees and 24 leavers), the minimum-group-size control, the fictional-data banner, the age/gender/marital-status caution, share of staff / share of leavers / multiple of the company rate, the illustration (cleared group only), mobile bottom sheet and desktop menu, importance pop-up, CSV exports.

Files: `R/presentation.R`, `app.R`, `www/app.js`, `www/app.css`, `tests/check_typed_numbers.R`, `README.md`, this doc, `docs/screenshots/v4_*`. Not touched: `R/partition.R`, `tests/smoke.R`, `tests/regression_snapshot.R`, `data/`.

## 2. Number sources (every figure comes from these files or the data)

| Figure in the app | Where it comes from |
|---|---|
| Overtime: 416 people, 28%, 127 of 237 leavers (54%), 30.5% vs 10.4%, 1.9x, 4.1 points | computed from the data when the app runs; checked against `analysis/exec2/qualifying.csv` (g00001) by `tests/check_typed_numbers.R` |
| Overtime held-out (114 people, 32.5%), Wilson interval, stability 81.8% of 500 refits | typed in `CLEARED_FINDING`; sources `analysis/exec/candidates.csv`, `analysis/exec2/qualifying.csv` (`stab_within` 0.818) |
| Junior subgroup range (about 115 to 130 people, 8% to 9% of staff, about 55%, 2.7 to 2.9 times, about 20%, close to 30% of leavers, 97% in job level 1) | **computed from the data** at the cuts $3,000 and $3,500 (`junior_range()`); the cut ends and counts are typed in `JUNIOR_RANGE` from `analysis/exec2/followup_cut_sensitivity.csv` (n 114 and 132, leavers 64 and 73); the check script verifies that each built phrase appears in `analysis/exec2/exec_findings_v2_draft.md` |
| Cuts that pass all five checks (2,900 to 3,900); $2,500 = 70 people fails size; $4,000 stability 50%; best cut $3,221 = 122 people, 68 leavers, 55.7% (46.9 to 64.2%) | `JUNIOR_RANGE` from `followup_cut_sensitivity.csv` and `qualifying.csv` (g00305); About, technical detail only |
| Worth watching: 215 people, 15% of staff, 35% left, about 40 people above the company rate, about a third (32%) work overtime | **computed from the data** (`watch_info()`: YearsAtCompany of 1 or less); phrases checked against the exec draft; typed `WATCH_GROUP` (n 215, leavers 75, excess 40.34, held-out 62 people at 43.5%) from `followup_short_tenure.csv` |
| Career-stage context (156 people at 53% vs 260 at 17%) | computed from the data; matches the exec draft |
| Rules: 100, 24, 15 people, 1.25x, 500 refits | `analysis/exec2/thresholds.json`; verified by the check script |
| Wording | v9 narrative (6506bc9) and `exec_findings_v2_draft.md`, used verbatim where it exists ("Worth watching, not a cleared finding", "part of the overtime finding, not added to it", the newer-staff paragraph) |

## 3. Judgment calls (please rule on these)

1. **Junior subgroup as a range, computed from the data, no node.** The only matching tree node is the $2,475 cut (69 people), which stays "too small to act on". The range figures appear in the findings panel, the overtime node card and the About text, not as a tree node. The tap sheet and menu for the overtime node carry one short line. Rowan's "about 55%" is the average of 56.1% ($3,000) and 55.3% ($3,500), rounded to the nearest 5; "close to 30%" is the average of 27.0% and 30.8%; people are rounded to the nearest 5 (114 to 115, 132 to 130). These roundings reproduce the exec draft phrases exactly and the check script enforces it.
2. **Nested callout uses a light accent tint and an accent left bar**, inside the overtime panel and node card only. It is the same accent as the overtime highlight; there is no second accent and no accent on the worth-watching block. If you read "gray with one accent" as stricter, it is one CSS rule (`.nested-callout`).
3. **Highlight default moved from 1.5x (25%) to 1.25x (21%)** to match `analysis/exec2/thresholds.json` (rule3_rate). Effect: the slider default is 21%, the legend and About say 1.25x, and a few more big leaf groups can get the dark "above threshold" outline in an exploratory tree. The accent is still only the overtime finding. The 15-person excess rule is described in About but is not part of the interactive outline (the slider stays a plain rate floor). Previously approved at 25% in your v3 review, so please confirm.
4. **Worth watching is matched on the exact group** (YearsAtCompany of 1 or less, 215 rows) by comparing the node's rows, not by variable name, so a different cut (for example YearsAtCompany < 3) is not marked. A matching node is never outlined as "above threshold" and never becomes the exploratory headline. In the default tree there is no such node, so the marker shows in the panel and legend; I tested the node version with a root custom split on YearsAtCompany < 2 (phone and desktop screenshots 10 to 12).
5. **No illustration for the junior subgroup**, per Rowan; the narrative's "about 13%, 45 to 50 fewer leavers" line is not in the app. The illustration stays on the overtime group only (v3.1 R2), and nodes inside overtime say they are "not added to it".
6. **Non-attrition targets and uploads:** the cleared finding, the nested sub-callout, the worth-watching block and legend entries show only for the bundled data with Attrition = Yes. For another outcome the panel says nothing is cleared; uploads say nothing is validated (as in v3.1).
7. **Stability figure** in About changed from 78.6% (exec thresholds, nodes 1 to 3) to 81.8% (exec2 within-branch rule, `stab_within`), because exec2 is now the governing rule.

## 4. Tests run (on branch app-v4)

- `tests/regression_snapshot.R`: 7 of 7 files byte-identical to `analysis/qa/app_v2_regression/v1_before`; engine == server TRUE; in-sample AUC 0.746379.
- `tests/smoke.R`: ok (OverTime improvement 24.08, 11 leaves, in-sample AUC 0.746).
- `tests/check_typed_numbers.R`: passes (now 40+ checks, including the range ends, pass/fail cuts, worth-watching numbers and the phrase checks against the exec draft).
- Server tests: default panel, card and legend text; node 4 (too small) note; a root split on YearsAtCompany < 2 marks exactly that node (cut 1.5 also matches the same 215 rows, cut 3 does not); Attrition = No shows no cleared finding.
- Headless Chromium (local build) at 1280 desktop and iPhone 13 (390x844) plus widths 320, 768, 1024, 1440: one accent node (3) in every view, 14 dashed too-small nodes in the full tree, no legend overflow, no horizontal scroll, no accent inside the worth-watching block. The only console message is a local 404 for `strftime-min.js` from the local shiny library, which is a local-run artifact (the live v3.1 check had zero console errors); recheck on the live URL after deploy.

## 5. Screenshots (docs/screenshots/)

Desktop: `v4_desktop_01_default(.png, _full)`, `02_findings_panel`, `03_context_menu_cleared`, `04_node_card_cleared_nested`, `05_full_tree`, `06_context_menu_too_small`, `07_node_card_too_small`, `08_control`, `09_importance_popup`, `10_watch_node_tree`, `11_context_menu_watch`, `12_node_card_watch`, `13_about`.
Phone: `v4_mobile_01_default(.png, _full)`, `02_findings_panel`, `03_action_sheet_cleared`, `04_node_card_cleared_nested`, `05_full_tree`, `06_action_sheet_too_small`, `07_control`, `08_importance_popup`, `09_action_sheet_watch`, `10_watch_tree_legend`.

## 6. Deploy command (NOT run; for after Quinn's check)

From the main checkout after merging app-v4 (the env vars SHINYAPPS_TOKEN and SHINYAPPS_SECRET are read from the environment and never printed):

```
Rscript -e 'rsconnect::setAccountInfo(name = "jaysha301", token = Sys.getenv("SHINYAPPS_TOKEN"), secret = Sys.getenv("SHINYAPPS_SECRET")); rsconnect::deployApp(appDir = ".", appName = "ibm-hr-attrition-tree", account = "jaysha301", appFiles = c("app.R", "R/partition.R", "R/presentation.R", "www/app.css", "www/app.js", "data/WA_Fn-UseC_-HR-Employee-Attrition.csv"), forceUpdate = TRUE, launch.browser = FALSE)'
```
