# Interpreting Rowan's draft attrition findings against the literature

> **DRAFT. Rowan's results have not been signed off by Quinn.** Do not send to Iris until QA is done. All numbers below are Rowan's, copied exactly from the list Rowan sent, except the marital-status rates and the job-role test rates and intervals, which are Quinn's. I have not recomputed or added any statistic. I also read `analysis/findings_draft.md`; it agrees with that list, with no conflicting numbers. Sources are the ones verified in `attrition_drivers.md`. The marital-status and stock-option paragraph was revised to Quinn's review: the overlap is one way, and the two are not interchangeable. The rates in that paragraph are Quinn's (40.6%, 25.6%, 13.3%), not Rowan's earlier two-way split. Job-role rates now lead with Quinn's test rate, n and Wilson interval, with the training rates labeled as training. Importance shares are removed throughout, including for age, distance and environment satisfaction.

**What Rowan found, in one line.** Overall, 16.1% of the 1,470 employees left. The clearest pattern is **overtime combined with low pay**. Overtime workers earning under $2,475 a month left at 69.6% (n=69), against 22.8% for overtime workers at or above that income (n=347). Among everyone, 30.5% of those on overtime left (n=416) against 10.4% of those not on it (n=1,054).

## Pay: really pay, or career stage?

Income under about $2,500 leaves at 35.2% (n=165), against 12.5% above it. In the literature, pay is the core **inducement** to stay: the side of March & Simon's (1958) balance that the organization controls. Under **equity theory**, people who feel under-rewarded relative to what they put in are motivated to restore the balance, and leaving is one way to do that (Adams, 1965). Meta-analytically, pay is a real but modest predictor of turnover (ρ = −.17; Rubenstein et al., 2018).

Rowan's own caveat is the key one, though. Income moves with JobLevel (r=0.95) and TotalWorkingYears (r=0.77), so in this dataset **low income cannot be separated from being early in one's career**. The literature offers career-stage mechanisms too:
- fewer side bets and less embeddedness built up (Becker, 1960; Mitchell et al., 2001);
- the higher quit rates of younger and shorter-tenured employees (Rubenstein et al., 2018).

Read this result as "low-paid, early-career employees leave more". It does not show that pay alone causes leaving.

## Overtime, and why it matters most when pay is low

OverTime is the most stable split. It is the root of the tree, and it holds in the held-out test data (32.5% vs 10.4%). The literature names two mechanisms:
- Long hours take time and energy from other roles (time-based and strain-based **work–family conflict**; Greenhaus & Beutell, 1985).
- They act as a **hindrance stressor** when they feel like an obstacle rather than a stretch, and hindrance stressors are linked to higher turnover (Podsakoff et al., 2007).

This is stronger than the meta-analyses would lead one to expect. Workload on its own is only weakly related to turnover, and in the slightly protective direction (ρ = −.10). Rubenstein et al. (2018) suggest it becomes harmful mainly when combined with other pressures.

The overtime × low-income combination fits the oldest framework most directly. March & Simon (1958) frame staying as a balance of what the employee gives against what they get. Overtime raises the contribution side and low pay lowers the inducement side, so the combination is where the balance is worst. That is the same input-versus-outcome comparison that equity theory describes (Adams, 1965). This is a plausible reading consistent with theory, not a tested mechanism: the dataset does not record whether overtime was paid, chosen, or perceived as unfair.

## Marital status and stock options: a one-way overlap, not the same thing

Inside the better-paid overtime group, Quinn's rates are 40.6% for single employees, 25.6% for married or divorced employees with no stock options, and 13.3% for married or divorced employees with options. All 470 single employees have StockOptionLevel 0, but so do 161 married or divorced employees. The overlap runs only one way. **Being single cannot be separated from having no options**, because no single employee holds any. The reverse is not true, and the two are not interchangeable.

The three-way split still leaves two readings, and neither replaces the other:
- **Marital status is not only a stand-in for having no options.** Single employees leave at 40.6%, against 25.6% for married or divorced employees who also have no options. The mechanism, if this gap is real, is **off-the-job embeddedness**: marriage brings community links and family ties that make moving costly (Mitchell et al., 2001). Married employees quit slightly less in the meta-analysis (ρ = −.10; Rubenstein et al., 2018). This is not something an employer can act on. Rubenstein et al. explicitly advise against using marital status in personnel decisions.
- **Stock options still separate leavers once marital status is held roughly constant.** Among married or divorced employees in this group, those with options leave at 13.3%, against 25.6% for those with none. The mechanism is a **financial stake**: unvested equity is a side bet that would be lost by leaving (Becker, 1960), which raises continuance commitment (Meyer & Allen, 1991) and the **sacrifice** part of embeddedness (Mitchell et al., 2001). This is the "golden handcuffs" view of employee share ownership (Sengupta et al., 2007). This one is actionable, through who receives equity and how it vests. It cannot be checked for single employees, because none of them have options.

## Job role: a lead, not a finding

On the held-out test set, inside the single, better-paid overtime group, Laboratory Technicians, Sales Executives and Sales Representatives left at 76.9% (10 of 13; Wilson 95% CI 49.7% to 91.8%), against 15.4% in other roles (2 of 13; CI 4.3% to 42.2%). The training rates, labeled as training because the split was chosen on those rows, were 59.5% (22 of 37) and 18.4% (7 of 38). This split sits deeper than the two splits cross-validation supports, overtime and then low income within overtime, and each side is only 13 test employees. Roles differ in outside job options and career paths, and both feed the *ease of movement* (March & Simon, 1958; Trevor, 2001). **Treat it as a lead to check, not a finding.**

## What did not hold up, and what is missing

**Variables that did not hold up.** Age, distance from home and environment satisfaction **do not hold up in test**. They are **not established predictors in this dataset**, even though the literature would have predicted all three: age ρ = −.21 and climate ρ = −.24 (Rubenstein et al., 2018), and longer commutes predicted teacher turnover (Santelli & Grissom, 2024).

**Variables that are absent.** Two drivers the literature would expect are missing:
- **Job satisfaction**, the most-studied predictor (ρ = −.28), does not appear in the tree.
- **Time with the current manager** (YearsWithCurrManager) does not appear in the tree either. Rowan's single-variable scan does show higher attrition among people with a very new manager, so the signal seems to be absorbed by other variables rather than missing entirely.

I cannot source an explanation for either gap in this dataset and do not offer one. Two published facts set expectations:
- Single-item attitude measures tend to show weaker links to turnover (Tett & Meyer, 1993).
- Manager-relationship *quality* (LMX) predicts intentions to quit more clearly than actual leaving (Gerstner & Day, 1997). YearsWithCurrManager measures only how *long* the relationship has lasted.

Whether either fact applies here is unknown.

## Recommendations that follow from these results

1. **Reduce unchosen overtime among lower-paid staff first.** That is where the draft shows the highest attrition, and reducing hindrance demands and time-based conflict is the literature-supported lever (Podsakoff et al., 2007; Greenhaus & Beutell, 1985).
2. **Audit pay for entry-level employees who work overtime, including how raises are allocated.** Felt inequity of inputs against outcomes motivates exit (Adams, 1965), and the fairness of reward procedures may matter as much as the amounts (Griffeth et al., 2000).
3. **Make early-career progression visible.** Because low income here is inseparable from low level and little experience, clear promotion paths and salary growth are the matching levers. Low salary growth drives exits (Trevor et al., 1997), and stalled careers lower attachment (Yang et al., 2019).
4. **Run stay interviews with better-paid overtime workers, and review equity eligibility and vesting for early-tenure staff.** These target the embeddedness and side-bet mechanisms behind the pattern above: single employees all lack options, while options still separate leavers among married or divorced staff (Mitchell et al., 2001; Hausknecht et al., 2009; Becker, 1960). The interviews should be offered to everyone in the group, never targeted by marital status (Rubenstein et al., 2018).

## Caveat

This is a **fictional teaching dataset**: the Kaggle and IBM description reads, "This is a fictional data set created by IBM data scientists". Its patterns illustrate method and say nothing about IBM's actual employees. The results come from a single **draft** classification tree that Quinn has not reviewed. Its test AUC is a modest 0.670 (bootstrap 0.605 to 0.737), so it is useful for describing segments, not for predicting who will leave. Several of its splits rest on small groups. DailyRate, HourlyRate and MonthlyRate were excluded as uninterpretable. The links above to the research literature are plausible readings of the patterns, not evidence that the mechanisms operate in these data.
