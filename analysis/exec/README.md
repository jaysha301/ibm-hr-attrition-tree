# analysis/exec: executive rework (draft for Quinn)

This folder holds a separate executive-focused pass, requested by the CEO via GG. The earlier headline group (overtime and under about $2,500, n = 69) was too small to act on.

- **Earlier files are unchanged.** `analysis/findings_draft.md` (v0.3, approved for Iris) and `analysis/METHOD.md` describe the depth-5 tree analysis, and nothing in them was edited. That analysis remains the reference for the full tree, the logistic benchmark and the original caveats.
- **This folder applies Quinn's merged minimum-sample rule with Quinn's exec-review ruling (F1–F9)** (`thresholds.json`; see `analysis/qa_log.md`, "Review: exec findings under merged minimum-sample rule").
  - Rule 4 is read at nodes 1–3.
  - One pattern is cleared for executives: overtime.
  - Lower pay and career stage appear as context only, with no impact figure.
- **Reproduce:** run `Rscript analysis/exec/run_exec.R` from the project root (seed 20261008). It writes every file here except this README, including `exec_findings_draft.md` and `technical_appendix.md`, so every number in them is computed by the script.
- **Figure:** `exec_tree.png` shows only the overtime split and is not embedded in the executive page.
- **Status:** QA-cleared by Quinn, Oct 9, 2026, after the F1–F9 fixes and four wording edits. The exec page now gives the too-small groups in one sentence; their table is in `technical_appendix.md` §4.
