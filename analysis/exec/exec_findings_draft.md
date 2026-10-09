# Who leaves most: overtime workers (IBM's fictional HR teaching data, not real employees)

*QA-cleared by Quinn, Oct 9, 2026.* Every number on this page is computed by `run_exec.R`; detail is in `technical_appendix.md`.

## Executive summary
In IBM's fictional dataset of 1,470 employees, 16% left. One large group clears every check: **overtime workers**. They are 28% of staff but 54% of everyone who left. Lower pay and early career also go with leaving, but they are shown below as context, not as a separate pattern. Nothing here shows what causes people to leave.

## What
Overtime workers (416 people, 28% of staff) left at 31%, about three times the rate of staff without overtime (10%). They account for 54% of everyone who left.

## So What
Overtime is the clearest place to look first. As an illustration, not a forecast: if overtime workers left at the company average, overall attrition would fall from about 16% to about 12%, roughly 60 fewer leavers.

## Not What
This does not show that overtime causes leaving; overtime may mark busy or understaffed roles. Fictional teaching data, not a real workforce. Not a basis for decisions about individuals.

## Context: pay and career stage
Lower-paid staff (roughly the bottom third of earners, under about $3,000-$4,000 a month) leave more often, about 27% vs 11% for everyone else, wherever the pay line is drawn in that range. But 95% of them are in the most junior job level, so this is one picture of pay and career stage together, and the data cannot say which matters. Most of their extra leaving is among those who also work overtime: lower-paid staff without overtime leave at about the company average (16%), against 8% for better-paid staff without overtime. Not a separately cleared pattern.

## Left out because too small to act on
Several smaller groups, each under 100 people, are left out as too small to act on; see the appendix.

## Large, but not cleared
Some other groups are large and leave more often: people with no stock options; short tenure (under 2 years at the company); a new manager (under 1 year); frequent business travel; low environment satisfaction. But these did not hold up consistently when we re-ran the analysis on reshuffled versions of the data. Several of them overlap with overtime workers or lower-paid, junior staff (for some, about half or more); frequent travel and low environment satisfaction are largely different people. Groups defined by age or marital status are not used for decisions about individuals.

## Caveats
- **Fictional data.** IBM made this dataset for teaching. The people in it are simulated, so it describes no real workforce.
- **Nothing here is causal.** The groups describe who left more, not why.
- **Pay goes with job level.** Lower pay and junior job level overlap heavily and can't be cleanly separated.
- **Not for decisions about individuals.** Age, gender and marital status are descriptive only and must not be used for decisions about individuals.
- **Snapshot timing.** Tenure and survey answers were recorded at the same time as whether people left, so they may not come before leaving.
