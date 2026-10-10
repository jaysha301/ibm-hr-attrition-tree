# exec2: deeper drill-down (impact-based rule)

**Status: the executive page is QA-cleared by Quinn, Oct 9, 2026 (review fixes R1-R7 applied).** Written after the CEO viewed the app and asked for deeper drilling than the overtime split (the earlier, QA-cleared run is untouched in `../exec/`). Fictional IBM teaching data; nothing causal.

**Rule (final, confirmed by Quinn):** `thresholds.json`, written 2026-10-09 15:28:43 PDT before the final run (SHA-256 `5d267be65408`): 100+ people and 24+ leavers; 15+ people above the company rate; rate at least 1.25x the company rate with the Wilson lower end above it; same direction in the held-out 30% with 30+ test people; stability inside the group's own branch (500 refits, >50%, similar cut). Judged against the company average and the parent branch. Every tree and cut is derived on the 70% training split only.

**Read first:** `drill_summary.md` (plain language for Quinn), then `exec_findings_v2_draft.md` (executive page draft), then `technical_appendix.md`.

| File | What it is |
|---|---|
| `run_drill.R` | the generator; reads `thresholds.json`; deterministic (seed 20261008) |
| `run_followups.R` | companion script, sourced by `run_drill.R`: follow-up tables after Quinn's review (cut sensitivity, job level 1, the 19 non-overtime combinations, short tenure, parent-branch null), the executive page draft and the chart; no new search |
| `followup_*.csv` | the follow-up tables as CSV |
| `thresholds.json` | the rule parameters, with timestamp and amendment notes |
| `candidates_all.csv` | every tested group with 50+ people: n, % of staff, leavers, % of leavers, full and test rates, lift, Wilson, impact vs company and vs parent branch, stability (within-branch, unpruned, old company-wide), test n, pass/fail per gate, old-rule result |
| `qualifying.csv` | groups passing all five rules, with role (distinct / same people / inside another) |
| `overlap.csv` | pairwise overlap among qualifying groups and the distinct patterns of the other lists |
| `nested_incremental_impact.csv` | incremental impact of nested qualifying groups (never added) |
| `groups_tested_by_branch.csv` | groups tested and passing, by branch |
| `drill_log.md`, `drill_log.csv` | every node with 100+ people that was drilled, with verdict and the stopping rule |
| `tree_full_deep.txt`, `tree_overtime_branch.txt`, `tree_nonovertime_branch.txt` | pruned trees and cp tables (training rows; full-data reference trees below them) |
| `cut_stability.csv`, `best_cuts.csv` | refit cut ranges and the best training-derived cut per variable and branch |
| `ceo_check.csv`, `career_stage_overlap_nonovertime.csv` | the CEO's question: low-experience groups in each branch, overlap and incremental impact |
| `technical_appendix.md` | methods, cp tables, stability, null calibration, rule comparison, old-rule results |
| `drill_summary.md` | plain-language summary for Quinn |
| `exec_findings_v2_draft.md` | executive page, revised after Quinn's review (R1-R4); QA-cleared by Quinn, Oct 9, 2026 |
| `drill_tree.png` | one chart: share who left, overtime finding in the accent colour |
| `logs/` | progress log and cached heavy steps (the real search and each shuffle) |

## How to run
`Rscript analysis/exec2/run_drill.R` from the project root. Heavy steps (the real search with 500 refits per branch, and the 200 + 200 label shuffles) are cached in `logs/cache/` and progress is logged to `logs/progress.log`, so an interrupted run resumes. `DRILL_NOCACHE=1 Rscript analysis/exec2/run_drill.R` recomputes everything without touching the cache (used for the identical-rerun check). Delete `logs/cache/` if the search code or `thresholds.json` changes (the cache key includes the thresholds SHA).

## Headline
2 group(s) clear all five rules out of 17,584 distinct groups tested (77 drilled nodes). See `drill_summary.md`.

