# Fictional IBM teaching dataset (simulated employees): reading Rowan's attrition patterns against the literature

> **Revised to Quinn's review (APPROVED WITH FIXES, E1–E8; `analysis/qa_log.md`, "Method review: Ellis interpretation").**
> - **The data are fictional.** This is IBM's teaching dataset of **simulated employees**: "This is a fictional data set created by IBM data scientists" (Kaggle data card). Nothing here describes IBM's real workforce or any real employer.
> - **The literature links are illustrative only.** Every link to research below is **consistent with (illustrative only)**. Fictional data cannot confirm or replicate the literature.
> - **Where the numbers come from.** Rowan's `analysis/findings_draft.md` v0.2 and Quinn's QA log; none were recomputed here.
> - **Sources.** All are verified in `attrition_drivers.md`.

**The clearest pattern.** Overall, 16.1% of the 1,470 simulated employees left. The clearest pattern is **overtime combined with low pay**:
- On the held-out test set, overtime workers paid under about $2,500 a month left at 63% (12 of 19; 95% CI 41–81%). Better-paid overtime workers left at 26% (25 of 95; CI 18.5–36.0%).
- On the full data, which includes the rows the cut was chosen on, the same comparison is 69.6% (n=69) against 22.8% (n=347).

## Pay: really pay, or career stage?

At the tree's cut, the test set shows a clear gap. Employees under $2,475 a month left at 32.8% (19 of 58; CI 22.1–45.6%), against 13.6% (52 of 383; CI 10.5–17.4%) above it. On the full data, the same cut gives 34.5% (76 of 220) against 12.9% (161 of 1,250).

The cut is best described as "under about $2,500". The exact $2,475 is where this tree happened to split, not a stable threshold.

Research suggests two reasons pay could matter, both **consistent with this pattern (illustrative only)**:
- **Inducements.** Pay is the core inducement to stay, the side of March & Simon's (1958) balance that the organization controls.
- **Equity.** People who feel under-rewarded relative to what they put in are motivated to restore the balance, and leaving is one way to do that (Adams, 1965).

Meta-analytically, pay is a real but modest predictor of turnover (ρ = −.17; Rubenstein et al., 2018).

**Pay cannot be separated from career stage here.** Income moves with JobLevel (r=0.95) and TotalWorkingYears (r=0.77), and 95% of the under-$2,475 group is at JobLevel 1 (Quinn). In this dataset, low income **largely overlaps with, and can't be cleanly separated from,** being early in one's career. It is not the same thing: within JobLevel 1, the lower-paid still leave at 35.7% (75 of 210) against 20.4% (68 of 333). The career-stage reading is also consistent with research (illustrative only):
- early-career employees have fewer side bets and less embeddedness built up (Becker, 1960; Mitchell et al., 2001);
- younger and shorter-tenured employees quit more often (Rubenstein et al., 2018).

Read this pattern as "low-paid, early-career simulated employees leave more", not as evidence that pay alone causes leaving.

## Overtime, and the low-pay group

Overtime holds in the held-out test data: 32.5% of overtime workers left, against 10.4% of the rest. It is not a uniquely stable first split, though. In 500 bootstrap refits, the first split was overtime in 44.4% of trees and income in 30.6%.

**What the overtime flag can and cannot tell us.** OverTime is only a yes/no flag. It records no hours, no premium, and whether the overtime was chosen.

**Two pieces of research would not predict a large overtime effect:**
- **Workload is normally a challenge stressor.** In the framework of Podsakoff, LePine & LePine (2007), workload and time pressure are classed as challenge stressors, not hindrance stressors, and challenge stressors were linked to *lower* turnover. Whether this overtime was felt as a hindrance is unmeasured, and the data cannot test that reading.
- **Workload alone is a weak predictor.** Meta-analytically, it is only weakly related to turnover, and in the slightly protective direction (ρ = −.10; Rubenstein et al., 2018).

When fictional data and the literature disagree like this, the likely explanation is how the synthetic data were generated, not a new finding.

Rubenstein et al. offer one idea, explicitly as speculation for future research: "It may be that a high workload is only problematic for those who must also devote significant portions of their time to other roles". They mean roles such as family, not other work pressures such as low pay. Along the same lines, work–family conflict (Greenhaus & Beutell, 1985) is a consistent-with reading, **illustrative only**: long hours can take time and energy from other roles.

**Overtime plus low pay.** This combination is **consistent with (illustrative only)** March & Simon's (1958) contributions-versus-inducements balance, and with the input-versus-outcome comparison of equity theory (Adams, 1965). Overtime adds to what the employee gives, and low pay lowers what they get. This is a reading, not a tested mechanism. The data do not record whether overtime was paid, chosen, or perceived as unfair.

## Marital status and stock options (exploratory)

> **Exploratory.** This segment is not supported by cross-validation, and the marital/option structure is a known feature of the synthetic data.

All rates in this section are **full data**, inside the better-paid overtime group:

| Group | Left | Rate | 95% CI |
|---|---|---|---|
| Single | 41 of 101 | 40.6% | 31.5–50.3% |
| Married or divorced, no options | 11 of 43 | 25.6% | 14.9–40.2% |
| Married or divorced, with options | 27 of 203 | 13.3% | 9.3–18.7% |

The differences are **not statistically clear** (Fisher's exact test):
- single vs married or divorced with no options: p = 0.09;
- options vs no options, among married or divorced: p = 0.06.

**How the two variables overlap.** All 470 single employees have StockOptionLevel 0, and so do 161 married or divorced employees. Being single therefore cannot be separated from having no options. The reverse does not hold, so the two variables are not interchangeable.

**Two readings, consistent with (illustrative only) the literature:**
- **Marital status:** **off-the-job embeddedness**, the community and family ties that make moving costly (Mitchell et al., 2001). Married employees quit slightly less in the meta-analysis (ρ = −.10; Rubenstein et al., 2018).
- **Stock options:** a **side-bet** reading (Becker, 1960), in which options are something that would be given up by leaving. This is consistent with the pattern but **cannot be tested here**. StockOptionLevel 0–3 is undocumented, so nothing is known about what the levels mean or how options vest.

**Descriptive only.** Marital status, age and gender are descriptive only. Rubenstein et al. (2018) write that "due to equal employment opportunity concerns, we cannot advise organizations to select individuals based on their age, marital status, or how many children they have." That quote does not cover gender. Gender is descriptive only by this team's own rule, and nothing here should be used to target anyone.

## Job role: a lead, not a finding

On the held-out test set, inside the single, better-paid overtime group, the job roles split sharply:
- Laboratory Technicians, Sales Executives and Sales Representatives left at 76.9% (10 of 13; Wilson 95% CI 49.7% to 91.8%).
- Other roles left at 15.4% (2 of 13; CI 4.3% to 42.2%).

The training rates, labeled as training because the split was chosen on those rows, were 59.5% (22 of 37) and 18.4% (7 of 38).

This split sits deeper than the two splits cross-validation supports (overtime, then low income within overtime). Each side is only 13 test employees. Roles differ in outside job options and career paths, which feed the *ease of movement* (March & Simon, 1958; Trevor, 2001); that is a consistent-with reading only. **Treat it as a lead to check, not a finding.**

## Variables not supported as tree splits

Age, distance from home, environment satisfaction and job satisfaction were **not supported as tree splits**: they either failed as deep splits or did not split at all. They do show bivariate or additive associations, in the direction the literature would expect (illustrative only). Quinn's checks:

- **Job satisfaction.** Full-data attrition by level 1–4 is 22.8 / 16.4 / 16.5 / 11.3%. On the test set, level 1 is 22.8% (18 of 79) against 14.6% (53 of 362) for levels 2–4.
- **Environment satisfaction.** Level 1 is 25.4%, against 13.5–15.0% for levels 2–4. On the test set it is 26.1% (23 of 88) against 13.6% (48 of 353).
- **Age.** On the test set, employees under 30 left at 30.0% (30 of 100), against 12.0% (41 of 341). Age belongs to the early-career cluster with income, job level and experience, and is descriptive only.
- **Logistic model on the training split.** JobSatisfaction, EnvironmentSatisfaction, JobInvolvement, RelationshipSatisfaction, DistanceFromHome and NumCompaniesWorked are all p < 0.001, and WorkLifeBalance is p = 0.03.

This additive signal helps explain why a logistic model reaches a test AUC of about 0.86, against the tree's 0.67. A shallow tree does not capture many small effects that add up.

**Measurement note.** The attitude fields are single, undocumented 1–4 items.

## Suggestions (from the literature, illustrated by fictional data; not tested interventions)

These are not results and do not come from testing any intervention.

1. **Look at unchosen overtime among lower-paid, early-career staff as a workload question.**
   - **Basis:** time-based work–family conflict is one consistent-with reading (Greenhaus & Beutell, 1985).
   - **Caveat:** in Podsakoff et al.'s (2007) framework, workload is normally a challenge stressor linked to *lower* turnover. Whether overtime is experienced as a burden would need to be asked, not assumed.
2. **Consider a pay audit for lower-paid employees who work overtime, including how raises are allocated.**
   - **Caveat:** in these data income is confounded with job level, so pay cannot be separated from career stage.
   - **Basis:** felt inequity of inputs against outcomes is linked to exit (Adams, 1965). Griffeth et al. (2000) suggest that fair reward procedures *may* matter as much as the amounts. That point is the authors' own conjecture (they wrote "Conceivably"), not a finding.
3. **Make early-career progression visible.**
   - **Caveat:** low income here is inseparable from low level and little experience.
   - **Basis:** research links low salary growth to exits (Trevor et al., 1997) and stalled careers to lower attachment, mostly measured as turnover intentions (Yang et al., 2019).
4. **Consider stay interviews, offered to everyone in a whole group (for example, all overtime workers).**
   - **How:** never target them by marital status, age or gender.
   - **Basis:** research suggests that embeddedness (links, fit and sacrifice) helps explain staying beyond satisfaction (Mitchell et al., 2001). Employees' reported reasons for staying differ by performance level and job type (Hausknecht et al., 2009).

## Caveat

**Fictional data.** This is a **fictional IBM teaching dataset of simulated employees**. Its patterns illustrate method and say nothing about IBM or any real employer. The literature links above are consistent-with readings (illustrative only), not evidence that any mechanism operates in these data.

**Status of the tree.** Quinn has reviewed Rowan's draft. Cross-validation supports only the first two splits: overtime, then low income within overtime.

**Prediction vs. description.** The tree's test AUC is 0.670 (bootstrap 0.605 to 0.737). A logistic benchmark reaches a test AUC of 0.863 (CI 0.814 to 0.908). The tree is for describing segments, not for prediction. Deeper splits rest on small groups.

**Excluded fields.** DailyRate, HourlyRate and MonthlyRate were excluded because their meaning is undocumented.
