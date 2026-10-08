# Why the usual attrition drivers matter: an I/O psychology research brief

**Project:** IBM HR Analytics Employee Attrition (Kaggle `pavansubhasht/ibm-hr-analytics-attrition-dataset`)
**Author:** Ellis (research). **Date:** 8 Oct 2026. **Status:** literature only.

> This brief contains **no results from the IBM dataset**. Everything below comes from published research. It explains why each driver *should* matter and maps each dataset column to a research construct, so that whatever Rowan's analysis finds can be read against the literature. The machine-readable map is in `variable_construct_map.csv`. The tie-in to Rowan's actual findings is a separate file, `interpretation.md`.

**How to read the numbers.** Where I quote an effect size, it is a meta-analytic correlation between a predictor and *actual* voluntary turnover (leaving coded 1, staying 0). A meta-analysis pools many studies. "ρ" (rho) means the correlation after the authors' statistical corrections, and "r1" in Griffeth et al. (2000) means the correlation corrected for measurement error in the predictor. A negative sign means more of the predictor goes with less leaving. For scale, a correlation of about .20 is a modest effect: real and repeatable, but it explains only about 4% of the variance in who leaves. I quote only numbers I read in the source itself; each is labelled with its source and table.

---

## 1. The major turnover frameworks

**Voluntary turnover** means an employee choosing to leave. It is different from dismissals, layoffs, and retirement, though the IBM `Attrition` flag does not tell us which kind of departure each case was.

**March & Simon (1958), *Organizations*.** This is usually treated as the first formal theory of turnover. People stay while what the organization gives them (pay, status, interesting work) outweighs what they have to give it (effort, time). Two forces drive leaving: the **perceived desirability of movement**, which is mostly job satisfaction, and the **perceived ease of movement**, which is mostly available job alternatives. Rubenstein et al. (2018, introduction) summarise it as "the desire to leave (i.e., job satisfaction) and the ease of leaving (i.e., job alternatives)". Almost every later model is an elaboration of these two ideas. The IBM data contain plenty of "desirability" variables (satisfaction ratings, pay, overtime) but no direct measure of "ease" such as outside offers or the local labour market. That gap matters when reading any result.

**Mobley (1977): intermediate linkages.** Mobley argued that dissatisfaction does not lead straight to quitting. Instead it starts a chain: thinking of quitting, then weighing the expected value of searching and the cost of quitting, then intending to search, searching, comparing alternatives with the current job, intending to quit, and finally quitting. The practical point is that **satisfaction is a distal cause**: its effect runs through intentions and job search, so it will always look weaker than intentions do. Mobley, Griffeth, Hand & Meglino (1979) widened this into a model with individual, organizational and labour-market variables. Tett & Meyer (1993), a meta-analytic path analysis, found that turnover intentions and withdrawal cognitions "mediate nearly all of the attitudinal linkage with turnover", and that satisfaction and commitment each add independently to predicting intentions.

**Price (1977) and Price & Mueller (1981): the causal-model tradition.** Price's *The Study of Turnover* (1977) catalogued organizational determinants of turnover. Price & Mueller (1981) then tested a causal model on 1,091 registered nurses in seven hospitals, followed over time. The determinants with the largest total effects on turnover were "intent to stay, opportunity, general training, and job satisfaction" (abstract). This structural tradition is one reason features such as family ("kinship") responsibilities and promotional chances still appear as standard predictors in the meta-analyses (e.g., Griffeth et al., 2000, Tables 1–2).

**Hom & Griffeth (1995), *Employee Turnover*, and Griffeth, Hom & Gaertner (2000).** Hom & Griffeth's book pulled the field together with a large meta-analysis. Griffeth et al. (2000) updated it and is still the most cited single summary of predictor sizes. Their headline: the strongest predictors are the steps closest to leaving. Quit intentions had r1 = .38, the best predictor apart from job-search methods (p. 480). Organizational commitment (r1 = −.23) predicted turnover better than overall job satisfaction (r1 = −.19), and perceived alternatives predicted it only modestly (r1 = .12) (pp. 479–480). Cotton & Tuttle (1986) was the earlier meta-analysis this line of work built on.

**Lee & Mitchell (1994): the unfolding model.** This model broke with the "dissatisfaction leads to search leads to quitting" sequence. Many departures start with a **shock**: a specific, jarring event such as an unsolicited job offer, a spouse's relocation, a pregnancy, a merger, or being passed over. A shock can trigger a pre-existing plan ("script") to leave with no search at all. It can also expose a mismatch between the job and the person's values or goals ("image violation"). The 1994 paper describes four distinct decision paths. Later refinements split one of them, giving five (paths 1, 2, 3, 4a, 4b), and Lee, Mitchell, Wise & Fireman (1996) tested the model with nurses who had recently quit. Only some of the paths involve dissatisfaction. The implication for analysts is that **satisfied people quit too**, and a survey snapshot will miss shock-driven exits.

**Mitchell, Holtom, Lee, Sablynski & Erez (2001): job embeddedness.** This model asks why people **stay**, not why they leave. Embeddedness is the web that holds someone in place, both on the job and off it (in the community). It has three parts: **links** (ties to people, teams and groups), **fit** (compatibility with the job, organization and community), and **sacrifice** (what they would give up by leaving). The authors found embeddedness predicted both intent to leave and actual turnover "over and above job satisfaction, organizational commitment, job alternatives and job search" (abstract). Lee et al. (2004) found off-the-job embeddedness predicted voluntary turnover in their sample while on-the-job embeddedness did not. Jiang, Liu, McKay, Lee & Mitchell (2012) meta-analysed 65 samples (N = 42,907): both kinds of embeddedness related negatively to turnover intentions and actual turnover after controlling for satisfaction, affective commitment and alternatives (abstract).

**Holtom, Mitchell, Lee & Eberly (2008)** and **Hom, Lee, Shaw & Hausknecht (2017)** review these trends: more individual differences, more relational context such as leader–member exchange, more focus on staying, and attention to *change over time* in attitudes. Hom, Mitchell, Lee & Griffeth (2012) add that leavers and stayers differ in whether the choice feels voluntary: there are "enthusiastic" and "reluctant" leavers and stayers.

**Rubenstein, Eberly, Lee & Mitchell (2018): the current benchmark meta-analysis.** *Correction to the task brief:* this paper appeared in **Personnel Psychology** (vol. 71, pp. 23–65; online 2017), not the Journal of Management. It meta-analyses **57 predictors across 1,800 effect sizes** (introduction). Unless noted otherwise, the ρ values in Section 2 come from its Table 2. Two of its practical conclusions are relevant here. First, pay matters, and its correlation with turnover has grown since 2000, but "many other predictors more readily controlled by managers can be more important than pay". Second, the results "corroborate the notion that often, 'employees quit bosses, not jobs'" (Practical implications section).

---

## 2. The drivers: mechanism, evidence, and IBM variable

### 2.1 Job satisfaction (`JobSatisfaction`)
**Definition.** How much a person likes their job, either overall or in facets such as pay, the work itself, and co-workers.
**Mechanism.** Dissatisfaction makes leaving more desirable (March & Simon). It sets off the withdrawal chain of thinking about quitting, searching, and intending to quit (Mobley, 1977). Most of its effect passes through intentions (Tett & Meyer, 1993).
**Evidence.** Rubenstein et al. (2018): ρ = −.28 (k = 174 samples, N = 107,625). Griffeth et al. (2000): overall job satisfaction r1 = −.19.
**IBM note.** This is a single 1–4 rating with no published item wording. Single-item measures weaken attitude–turnover links (Tett & Meyer, 1993, name single- vs multi-item scales as a moderator).

### 2.2 Organizational commitment (no direct IBM measure; nearest are `JobInvolvement` and `EnvironmentSatisfaction`)
**Definition.** Psychological attachment to the organization. The standard three-part model (Meyer & Allen, 1991) separates **affective** commitment (wanting to stay), **normative** commitment (feeling obliged to stay) and **continuance** commitment (needing to stay because leaving costs too much).
**Mechanism.** Attachment makes leaving feel like a loss. Continuance commitment draws on Becker's (1960) idea of **side bets**, the investments a person would forfeit by leaving, such as seniority, pensions, or unvested equity.
**Evidence.** Rubenstein et al. (2018): ρ = −.29 (k = 129), almost the same as satisfaction, and the authors suggest treating the two as one overall job attitude. Griffeth et al. (2000): r1 = −.23. Meyer, Stanley, Herscovitch & Topolnytsky (2002) found all three forms negatively related to withdrawal and turnover, and perceived organizational support had the strongest positive correlation with affective commitment (ERIC abstract).
**IBM note.** The dataset has no commitment scale. Do not relabel any IBM variable as "commitment".

### 2.3 Overtime and workload (`OverTime`)
**Definition.** Workload is the amount of work required, "mostly measures of hours worked or how hard and fast an individual works" (Rubenstein et al., 2018, Table 1).
**Mechanism.** It can cut both ways:
- Long hours drain time and energy. They raise strain and exhaustion (Rubenstein: stress/exhaustion ρ = +.21) and cause time-based conflict with family life (Greenhaus & Beutell, 1985).
- But workload can also act as a **challenge stressor**, a demand that feels like growth. Podsakoff, LePine & LePine (2007) found that challenge stressors were generally related to *lower* turnover. **Hindrance stressors** (red tape, role ambiguity, obstacles) were related to *higher* turnover, partly through lower satisfaction and commitment.
**Evidence.** The surprise is the sign. Rubenstein et al. (2018) found workload ρ = **−.10** (k = 21): more workload went with slightly *less* turnover overall. They suggest high workload may be "only problematic for those who must also devote significant portions of their time to other roles". In Griffeth et al. (2000), role overload had r1 = +.10, but from only 5 samples.
**IBM note.** `OverTime` is a yes/no flag with no hours, pay premium, or voluntariness recorded. The literature would not predict a large overtime effect by itself. If one appears, the likely explanations are hindrance-type overtime (unpaid, unchosen) or overtime combined with other strain (see 2.4 and 2.6).

### 2.4 Work–life balance and work–family conflict (`WorkLifeBalance`; also `BusinessTravel`, `OverTime`)
**Definition.** Work–family conflict is "a form of interrole conflict in which the role pressures from the work and family domains are mutually incompatible" (Greenhaus & Beutell, 1985). It comes in three forms:
- **time-based**: hours in one role are unavailable to the other;
- **strain-based**: fatigue or stress from one role spills into the other;
- **behaviour-based**: the behaviour one role demands clashes with the other's expectations.
**Mechanism.** Conflict lowers job and life satisfaction (Kossek & Ozeki, 1998, meta-analysis) and makes a less demanding job elsewhere more attractive.
**Evidence.** Rubenstein et al. (2018): work–life conflict ρ = **+.19** (k = 7). Allen, Herst, Bruck & Sutton (2000) reviewed the work-related, non-work and stress-related consequences of work-to-family conflict. *Correction to the brief:* that paper is in the **Journal of Occupational Health Psychology**, not the Journal of Vocational Behavior.
**IBM note.** `WorkLifeBalance` (1 = Bad to 4 = Best) is a single rating of balance, which is the mirror image of conflict, so expect a negative sign if it matters. `BusinessTravel` is a plausible source of time-based conflict. I found no meta-analysis on business travel and turnover, so that link is an inference from Greenhaus & Beutell, not an established finding.

### 2.5 Tenure, job embeddedness and the unfolding model (`YearsAtCompany`, `TotalWorkingYears`, `YearsInCurrentRole`)
**Definition.** Tenure is years with the current employer.
**Mechanism.**
- Tenure builds links, fit and sacrifice (embeddedness) and side bets (continuance commitment).
- People who are a poor fit tend to leave early, so long-tenured employees are partly a filtered group of good fits.
- In the unfolding model, newcomers are exposed to early shocks and unmet expectations.
**Evidence.** Rubenstein et al. (2018):
- tenure ρ = −.20 (k = 118), or −.27 when one very large outlier study is excluded;
- job embeddedness ρ = −.26 (k = 29);
- met expectations ρ = −.12.

Griffeth et al. (2000): tenure r1 = −.20.
**IBM note.** The tenure variables overlap heavily with one another and with `Age`, `JobLevel` and `MonthlyIncome`. A "tenure effect" in this dataset may really be a career-stage effect.

### 2.6 Pay, pay satisfaction and equity (`MonthlyIncome`, `PercentSalaryHike`, `StockOptionLevel`)
**Mechanism.**
- Pay is the main "inducement" in March & Simon's terms.
- Under **equity theory** (Adams, 1965), people compare their ratio of outcomes to inputs with a reference person. Feeling under-rewarded creates tension that leaving can resolve.
- Pay also anchors off-the-job embeddedness (lifestyle, housing) and signals one's worth (Rubenstein et al., 2018, Discussion).
- Griffeth et al. (2000) add that *procedural* fairness, meaning how rewards are allocated, may matter "as much—if not more" than the amounts (p. 480).
**Evidence.**
- Rubenstein et al. (2018): pay ρ = −.17 (k = 55), stronger than Griffeth's estimate. Rewards *beyond* pay (benefits, career and growth opportunities, training time) were ρ = −.28 (k = 25).
- Griffeth et al. (2000): pay r1 = −.09 and pay satisfaction r1 = −.07 (Table 2). They describe pay effects as "modest" and probably underestimated because of restricted pay variance and the omission of other compensation.
- Williams, McDaniel & Nguyen (2006) meta-analysed 240 samples on the antecedents and outcomes of pay-level satisfaction.
- Trevor, Gerhart & Boudreau (1997), with 5,143 exempt employees: low **salary growth** produced "extremely high turnover" among high performers, while high salary growth predicted low turnover for them (abstract).
**IBM note.**
- `MonthlyIncome` is the only interpretable pay variable.
- `PercentSalaryHike` is the closest thing to salary growth.
- `StockOptionLevel` (0–3) is deferred compensation that works as a side bet or **sacrifice**. Sengupta, Whitfield & McNabb (2007) frame employee share ownership as either a "golden path" or "golden handcuffs".
- `DailyRate`, `HourlyRate` and `MonthlyRate` are not documented by IBM or on the Kaggle page, and are **not interpretable as pay** (see Section 3).
- In most firms, pay rises with job level and experience, so a raw income effect mixes pay with career stage.

### 2.7 Relationship with the manager: LMX and supervisory support (`YearsWithCurrManager`; partly `RelationshipSatisfaction`)
**Definition.** **Leader–member exchange (LMX)** is the quality of the one-to-one relationship between a manager and an employee (Gerstner & Day, 1997). **Perceived supervisor support** is the belief that one's supervisor values one's contributions and cares about one's well-being.
**Mechanism.** A high-quality relationship brings resources, support and inclusion, which raise satisfaction and commitment. A supervisor is also the organization's most visible agent. Eisenberger et al. (2002) found that supervisor support raised perceived organizational support, and that organizational support "completely mediated" a negative relationship between supervisor support and turnover (abstract).
**Evidence.** Rubenstein et al. (2018), leadership (mostly leadership style and LMX): ρ = −.24 (k = 42). Griffeth et al. (2000): LMX r1 = −.23, but from only 3 samples (N = 161). The important caveat is from Gerstner & Day (1997): LMX was significantly related to turnover *intentions*, but "the relationship between LMX and actual turnover was not significant" (abstract). Dulebohn et al. (2012) found that leader variables explained the most variance in LMX quality, which suggests that relationship quality is something managers can work on.
**IBM note.** The dataset does **not** measure relationship quality with the manager. `YearsWithCurrManager` is only the length of the relationship. `RelationshipSatisfaction` is undocumented: the Kaggle page gives only the 1–4 labels and does not say whether it refers to the manager, co-workers or anyone else. Do not read it as LMX.

### 2.8 Job involvement (`JobInvolvement`)
**Definition.** The degree to which a person identifies psychologically with their job.
**Mechanism.** People who define themselves through their job have more to lose by leaving it. Brown (1996) found involvement strongly related to job attitudes but not to behavioural outcomes.
**Evidence.** Rubenstein et al. (2018): ρ = −.19 (k = 19). Griffeth et al. (2000): r1 = −.10.

### 2.9 Environment and relationship satisfaction (`EnvironmentSatisfaction`, `RelationshipSatisfaction`)
**Definition.** These are facet satisfactions. The closest constructs are organizational climate and co-worker relations.
**Evidence.** Rubenstein et al. (2018): climate ρ = −.24 (k = 8); peer/group relations ρ = −.14 (k = 24); organizational support ρ = −.19 (k = 16).
**Mechanism.** A supportive environment raises perceived organizational support. Rhoades & Eisenberger (2002) linked fairness, supervisor support, and rewards and job conditions to perceived organizational support, and that support in turn to lower withdrawal. Co-worker ties are also **links** in the embeddedness model.
**IBM note.** Both are single, undocumented items.

### 2.10 Promotion opportunities and career plateau (`YearsSinceLastPromotion`, `YearsInCurrentRole`, `JobLevel`)
**Definition.** A **career plateau** is the point where further upward movement (a hierarchical plateau) or new challenge in the work itself (a job-content plateau) is unlikely (Ference, Stoner & Warren, 1977).
**Mechanism.** A stalled career suggests the organization does not value the person. Yang, Niven & Johnson's (2019) review of 72 studies found that plateaued employees report lower satisfaction and commitment and higher turnover *intentions*, explained by a perceived lack of organizational support (abstract).
**Evidence.** Griffeth et al. (2000): promotional chances r1 = −.12. Promotions are not simply protective, though. Trevor et al. (1997) found that "once salary growth was controlled, promotions positively predicted turnover", most strongly for poor performers. A promotion also raises a person's market value.
**IBM note.** `YearsSinceLastPromotion` can be long simply because tenure is long. Interpret it alongside `YearsAtCompany`.

### 2.11 Training (`TrainingTimesLastYear`)
**Mechanism.** Training is a reward and a sign of investment (Rubenstein's "rewards offered" includes training time, ρ = −.28 for that whole category). But training that is useful elsewhere also raises employability. Benson, Finegold & Mohrman (2004) found that tuition reimbursement *reduced* turnover while employees were enrolled. After a graduate degree, turnover *rose* unless the person was promoted.
**Evidence.** Price & Mueller (1981) list general training among the four determinants with the largest total effects.
**IBM note.** This variable is a count of sessions, with no information on content or transferability.

### 2.12 Commute (`DistanceFromHome`)
**Mechanism.** A long commute is a daily cost and strain, and a source of time-based conflict. It also weakens off-the-job embeddedness, because home is further from the workplace community.
**Evidence.** Santelli & Grissom (2024, AERA Open) used administrative records for teachers. Longer one-way commutes predicted transferring schools, and the longest commutes (40+ minutes) predicted leaving the district (abstract). I found no meta-analysis of commute and turnover, so treat this as supporting evidence rather than an established effect size.
**IBM note.** The units are undocumented.

### 2.13 Business travel (`BusinessTravel`)
**Mechanism.** Frequent travel takes time from family and personal roles (time-based work–family conflict; Greenhaus & Beutell, 1985) and adds fatigue (strain-based conflict).
**Evidence.** I found no verified turnover meta-analysis. This is a construct mapping only.

### 2.14 Age and marital status as life-stage proxies (`Age`, `MaritalStatus`)
**Mechanism.** These are not causes in themselves. They stand in for life stage:
- Younger workers have fewer side bets and more options, and Rubenstein et al. note they may hold higher expectations of employers.
- Married employees have more off-the-job links and community ties (embeddedness), and family responsibilities raise the cost of moving. Griffeth et al. (2000) meta-analyse this as "kinship responsibilities".

**Evidence.** Rubenstein et al. (2018):
- age ρ = −.21 (k = 121), significantly stronger than Griffeth's earlier estimate;
- marital status (married = 1) ρ = −.10 (k = 27);
- number of children ρ = −.20.

Ng & Feldman (2009) re-examined the age–turnover relationship in a dedicated meta-analysis. **Ethics note:** Rubenstein et al. state that "due to equal employment opportunity concerns, we cannot advise organizations to select individuals based on their age, marital status, or how many children they have." Use these variables to *understand* who leaves, never to decide whom to hire or invest in.

### 2.15 Prior job mobility (`NumCompaniesWorked`)
**Mechanism.** Past behaviour predicts future behaviour. Some people may have a lasting tendency to change jobs: Ghiselli's "hobo syndrome". Frequent movers also have well-practised search skills and networks, so they find it easier to leave.
**Evidence.** Judge & Watanabe (1995), using a national longitudinal sample of young workers, found "turnover depends on the number of times an individual has left his or her job in the past" (abstract). Barrick & Zimmerman (2005) found that prehire biographical data, including longer tenure in the previous job and knowing people already in the organization, predicted lower voluntary turnover.
**IBM note.** The count does not separate career-building moves from short, failed stints.

### 2.16 The remaining columns
- **Performance (`PerformanceRating`).** The relationship with turnover can be curved: low and high performers leave more than average performers, especially when salary growth is low (Trevor et al., 1997). Rubenstein et al. (2018) give ρ = −.08, or −.21 without one outlier study. **IBM note:** in the file this variable takes only the values 3 and 4, so its range is severely restricted and it is unlikely to show much.
- **`Education`.** Rubenstein et al. (2018): ρ = +.04, with a confidence interval that includes zero. Education matters to turnover mainly through ease of movement (alternatives).
- **`EducationField`, `JobRole`, `Department`.** These capture occupation and labour market. Ease of movement depends on both general job availability and individual attributes (Trevor, 2001), and occupations differ in their outside options. Alternatives: Rubenstein ρ = +.23; Griffeth r1 = .12.
- **`Gender`.** Rubenstein et al. (2018): sex ρ = .00. Griffeth et al. (2000): women's quit rate is "similar to that of men's" (r1 = −.03).
- **`JobLevel`.** Hierarchical level, closely tied to pay, career stage and plateau (2.6, 2.10).

### 2.17 What the dataset does not contain
The dataset has no measures of:
- turnover intentions or job search, the strongest proximal predictors (Rubenstein: withdrawal cognitions ρ = .56, job search ρ = .40);
- perceived alternatives;
- organizational commitment;
- LMX quality;
- justice or fairness;
- shocks;
- personality. Zimmerman (2008) found emotional stability best predicted intentions to quit, while conscientiousness and agreeableness best predicted actual turnover.

A model built on IBM's columns therefore leaves out the predictors the literature rates highest. That alone caps how well any model can predict.

---

## 3. Columns that should be dropped or flagged

| Column | Status | Why |
|---|---|---|
| `DailyRate`, `HourlyRate`, `MonthlyRate` | **Exclude** | Neither the Kaggle data card nor IBM's original Watson Analytics description (as quoted in the `modeldata` documentation) defines them, so they are **not interpretable as pay**. `MonthlyIncome` is the pay variable. |
| `EmployeeCount` | Constant (always 1) | No variance. |
| `Over18` | Constant (always "Y") | No variance. |
| `StandardHours` | Constant (always 80) | No variance. |
| `EmployeeNumber` | Identifier | Not a predictor. |
| `PerformanceRating` | Keep, flag | Only the values 3 and 4 occur, so the range is restricted. |
| `RelationshipSatisfaction` | Keep, flag | The target of the rating (manager, co-workers or anyone else) is not documented. |

(The constants and the 3/4 range were checked directly in `data/WA_Fn-UseC_-HR-Employee-Attrition.csv`. These are data descriptions, not findings.)

---

## 4. What these effects are NOT

1. **They are modest.** The best-studied attitudes correlate with actual turnover at roughly −.2 to −.3:
   - job satisfaction: Griffeth r1 = −.19; Rubenstein ρ = −.28;
   - organizational commitment: Griffeth r1 = −.23; Rubenstein ρ = −.29.

   Even the strongest single attitude accounts for under 10% of the variance in who leaves. Most individual drivers in Section 2 are smaller (|ρ| ≈ .10–.20). A model built from these variables should be expected to rank people only moderately well.
2. **Many leavers are satisfied.** The unfolding model (Lee & Mitchell, 1994) shows that shocks and pre-existing plans lead people to quit without any build-up of dissatisfaction. A satisfaction rating taken before a shock cannot see it coming.
3. **Intentions ≠ behaviour.** Several drivers predict intentions much better than actual leaving. LMX predicts turnover intentions but was not significantly related to actual turnover in Gerstner & Day (1997). Career plateau evidence is mostly about intentions (Yang et al., 2019).
4. **Cross-sectional, self-reported data cannot show causation.** The IBM file is one snapshot: attitudes and attrition status are recorded together, with no clear timing. A link between low satisfaction and leaving could reflect dissatisfaction causing exit, people who have already decided to go rating their job lower, or a third factor such as career stage driving both. Correlated predictors (income, job level, age, tenure) will swap credit in any model.
5. **The dataset is fictional.** The Kaggle page and IBM's original Watson Analytics description both say: "This is a fictional data set created by IBM data scientists." (Kaggle data card, checked 8 Oct 2026; quoted identically in the R `modeldata` package documentation for `attrition`.) It has 1,470 rows. **Any pattern in it illustrates method; it says nothing about IBM's real workforce,** and it cannot confirm or refute the literature. If the data and the literature disagree, the likely explanation is how the data were generated, not new science.

---

## 5. Recommendation templates (conditional, not findings)

Use one of these only if the corresponding predictor actually appears in Rowan's results.

- **If `OverTime` emerges as a top predictor:** the literature supports cutting unchosen overtime and redesigning workload, starting with demands that block progress rather than stretch people. Hindrance stressors raise turnover while challenge stressors do not (Podsakoff et al., 2007), and high workload seems to drive leaving mainly when it competes with other life roles (Rubenstein et al., 2018; Greenhaus & Beutell, 1985).
- **If manager-related variables (`YearsWithCurrManager`, `RelationshipSatisfaction`) emerge:** the literature supports training managers to build high-quality one-to-one relationships (LMX) and visible support. Leader variables explain more of the variation in LMX quality than follower or contextual variables (Dulebohn et al., 2012), and supervisor support is linked to lower turnover through perceived organizational support (Eisenberger et al., 2002). Expect clearer effects on intentions than on actual exits (Gerstner & Day, 1997).
- **If tenure, marital status or other embeddedness proxies emerge:** the literature supports stay interviews, structured conversations that ask current employees why they stay, and then strengthening those links, fit and sacrifices. Embeddedness predicts turnover beyond satisfaction and commitment (Mitchell et al., 2001; Jiang et al., 2012), and Hausknecht, Rodda & Howard (2009) show that employees' reported reasons for staying differ by performance level and job type.
- **If `MonthlyIncome` or `PercentSalaryHike` emerges:** the literature supports a pay-equity audit covering both pay levels and how raises are allocated. Felt inequity motivates exit (Adams, 1965), procedural fairness of reward allocation may matter as much as the amount (Griffeth et al., 2000), and low salary growth drives out high performers in particular (Trevor et al., 1997).
- **If `YearsSinceLastPromotion`, `JobLevel` or `YearsInCurrentRole` emerges:** the literature supports clear, published promotion and development paths, plus job-content growth for people who cannot move up. Plateaued employees report lower attachment through perceived lack of support (Yang et al., 2019). Development without a next step can backfire: turnover rose after employees finished degrees unless they were promoted (Benson et al., 2004).

---

## 6. References (all verified on 8 Oct 2026)

I checked each reference against a publisher or index record (Crossref, OpenAlex, JSTOR, SAGE, Wiley, APA PsycNet, or a library catalogue). Numbers were quoted only from the two papers I read in full (Griffeth et al., 2000; Rubenstein et al., 2018), plus figures stated in abstracts.

- Adams, J. S. (1965). Inequity in social exchange. *Advances in Experimental Social Psychology, 2*, 267–299. https://doi.org/10.1016/S0065-2601(08)60108-2
- Allen, D. G., Shore, L. M., & Griffeth, R. W. (2003). The role of perceived organizational support and supportive human resource practices in the turnover process. *Journal of Management, 29*, 99–118. https://doi.org/10.1177/014920630302900107
- Allen, T. D., Herst, D. E. L., Bruck, C. S., & Sutton, M. (2000). Consequences associated with work-to-family conflict: A review and agenda for future research. *Journal of Occupational Health Psychology, 5*, 278–308. https://doi.org/10.1037/1076-8998.5.2.278
- Barrick, M. R., & Zimmerman, R. D. (2005). Reducing voluntary, avoidable turnover through selection. *Journal of Applied Psychology, 90*, 159–166. https://doi.org/10.1037/0021-9010.90.1.159
- Becker, H. S. (1960). Notes on the concept of commitment. *American Journal of Sociology, 66*, 32–40. https://doi.org/10.1086/222820
- Benson, G. S., Finegold, D., & Mohrman, S. A. (2004). You paid for the skills, now keep them: Tuition reimbursement and voluntary turnover. *Academy of Management Journal, 47*, 315–331. https://doi.org/10.2307/20159584
- Brown, S. P. (1996). A meta-analysis and review of organizational research on job involvement. *Psychological Bulletin, 120*, 235–255. https://doi.org/10.1037/0033-2909.120.2.235
- Cotton, J. L., & Tuttle, J. M. (1986). Employee turnover: A meta-analysis and review with implications for research. *Academy of Management Review, 11*, 55–70. https://doi.org/10.5465/amr.1986.4282625
- Dulebohn, J. H., Bommer, W. H., Liden, R. C., Brouer, R. L., & Ferris, G. R. (2012). A meta-analysis of antecedents and consequences of leader-member exchange. *Journal of Management, 38*, 1715–1759 (online 2011). https://doi.org/10.1177/0149206311415280
- Eisenberger, R., Stinglhamber, F., Vandenberghe, C., Sucharski, I. L., & Rhoades, L. (2002). Perceived supervisor support: Contributions to perceived organizational support and employee retention. *Journal of Applied Psychology, 87*, 565–573. https://doi.org/10.1037/0021-9010.87.3.565
- Ference, T. P., Stoner, J. A. F., & Warren, E. K. (1977). Managing the career plateau. *Academy of Management Review, 2*, 602–612. https://doi.org/10.5465/amr.1977.4406740
- Gerstner, C. R., & Day, D. V. (1997). Meta-analytic review of leader–member exchange theory: Correlates and construct issues. *Journal of Applied Psychology, 82*, 827–844. https://doi.org/10.1037/0021-9010.82.6.827
- Greenhaus, J. H., & Beutell, N. J. (1985). Sources of conflict between work and family roles. *Academy of Management Review, 10*, 76–88. https://doi.org/10.2307/258214
- Griffeth, R. W., Hom, P. W., & Gaertner, S. (2000). A meta-analysis of antecedents and correlates of employee turnover: Update, moderator tests, and research implications for the next millennium. *Journal of Management, 26*, 463–488. https://doi.org/10.1177/014920630002600305
- Hausknecht, J. P., Rodda, J., & Howard, M. J. (2009). Targeted employee retention: Performance-based and job-related differences in reported reasons for staying. *Human Resource Management, 48*, 269–288. https://doi.org/10.1002/hrm.20279
- Holtom, B. C., Mitchell, T. R., Lee, T. W., & Eberly, M. B. (2008). Turnover and retention research: A glance at the past, a closer review of the present, and a venture into the future. *Academy of Management Annals, 2*, 231–274. https://doi.org/10.5465/19416520802211552
- Hom, P. W., & Griffeth, R. W. (1995). *Employee turnover*. Cincinnati, OH: South-Western. ISBN 978-0-538-80873-6.
- Hom, P. W., Lee, T. W., Shaw, J. D., & Hausknecht, J. P. (2017). One hundred years of employee turnover theory and research. *Journal of Applied Psychology, 102*, 530–545. https://doi.org/10.1037/apl0000103
- Hom, P. W., Mitchell, T. R., Lee, T. W., & Griffeth, R. W. (2012). Reviewing employee turnover: Focusing on proximal withdrawal states and an expanded criterion. *Psychological Bulletin, 138*, 831–858. https://doi.org/10.1037/a0027983
- Jiang, K., Liu, D., McKay, P. F., Lee, T. W., & Mitchell, T. R. (2012). When and how is job embeddedness predictive of turnover? A meta-analytic investigation. *Journal of Applied Psychology, 97*, 1077–1096. https://doi.org/10.1037/a0028610
- Judge, T. A., & Watanabe, S. (1995). Is the past prologue? A test of Ghiselli's hobo syndrome. *Journal of Management, 21*, 211–229. https://doi.org/10.1177/014920639502100203
- Kossek, E. E., & Ozeki, C. (1998). Work–family conflict, policies, and the job–life satisfaction relationship. *Journal of Applied Psychology, 83*, 139–149. https://doi.org/10.1037/0021-9010.83.2.139
- Lee, T. W., & Mitchell, T. R. (1994). An alternative approach: The unfolding model of voluntary employee turnover. *Academy of Management Review, 19*, 51–89. https://doi.org/10.2307/258835
- Lee, T. W., Mitchell, T. R., Wise, L., & Fireman, S. (1996). An unfolding model of voluntary employee turnover. *Academy of Management Journal, 39*, 5–36. https://doi.org/10.2307/256629
- Lee, T. W., Mitchell, T. R., Sablynski, C. J., Burton, J. P., & Holtom, B. C. (2004). The effects of job embeddedness on organizational citizenship, job performance, volitional absences, and voluntary turnover. *Academy of Management Journal, 47*, 711–722. https://doi.org/10.2307/20159613
- March, J. G., & Simon, H. A. (1958). *Organizations*. New York, NY: Wiley.
- Meyer, J. P., & Allen, N. J. (1991). A three-component conceptualization of organizational commitment. *Human Resource Management Review, 1*, 61–89. https://doi.org/10.1016/1053-4822(91)90011-Z
- Meyer, J. P., Stanley, D. J., Herscovitch, L., & Topolnytsky, L. (2002). Affective, continuance, and normative commitment to the organization: A meta-analysis of antecedents, correlates, and consequences. *Journal of Vocational Behavior, 61*, 20–52. https://doi.org/10.1006/jvbe.2001.1842
- Mitchell, T. R., Holtom, B. C., Lee, T. W., Sablynski, C. J., & Erez, M. (2001). Why people stay: Using job embeddedness to predict voluntary turnover. *Academy of Management Journal, 44*, 1102–1121. https://doi.org/10.2307/3069391
- Mobley, W. H. (1977). Intermediate linkages in the relationship between job satisfaction and employee turnover. *Journal of Applied Psychology, 62*, 237–240. https://doi.org/10.1037/0021-9010.62.2.237
- Mobley, W. H., Griffeth, R. W., Hand, H. H., & Meglino, B. M. (1979). Review and conceptual analysis of the employee turnover process. *Psychological Bulletin, 86*, 493–522. https://doi.org/10.1037/0033-2909.86.3.493
- Ng, T. W. H., & Feldman, D. C. (2009). Re-examining the relationship between age and voluntary turnover. *Journal of Vocational Behavior, 74*, 283–294. https://doi.org/10.1016/j.jvb.2009.01.004
- Podsakoff, N. P., LePine, J. A., & LePine, M. A. (2007). Differential challenge stressor–hindrance stressor relationships with job attitudes, turnover intentions, turnover, and withdrawal behavior: A meta-analysis. *Journal of Applied Psychology, 92*, 438–454. https://doi.org/10.1037/0021-9010.92.2.438
- Price, J. L. (1977). *The study of turnover*. Ames, IA: Iowa State University Press.
- Price, J. L., & Mueller, C. W. (1981). A causal model of turnover for nurses. *Academy of Management Journal, 24*, 543–565. https://doi.org/10.2307/255574
- Rhoades, L., & Eisenberger, R. (2002). Perceived organizational support: A review of the literature. *Journal of Applied Psychology, 87*, 698–714. https://doi.org/10.1037/0021-9010.87.4.698
- Rubenstein, A. L., Eberly, M. B., Lee, T. W., & Mitchell, T. R. (2018). Surveying the forest: A meta-analysis, moderator investigation, and future-oriented discussion of the antecedents of voluntary employee turnover. *Personnel Psychology, 71*, 23–65 (online 2017). https://doi.org/10.1111/peps.12226
- Santelli, F. A., & Grissom, J. A. (2024). A bad commute: Travel time to work predicts teacher turnover and other workplace outcomes. *AERA Open, 10*. https://doi.org/10.1177/23328584241287792
- Sengupta, S., Whitfield, K., & McNabb, B. (2007). Employee share ownership and performance: Golden path or golden handcuffs? *International Journal of Human Resource Management, 18*, 1507–1538. https://doi.org/10.1080/09585190701502620
- Tett, R. P., & Meyer, J. P. (1993). Job satisfaction, organizational commitment, turnover intention, and turnover: Path analyses based on meta-analytic findings. *Personnel Psychology, 46*, 259–293. https://doi.org/10.1111/j.1744-6570.1993.tb00874.x
- Trevor, C. O. (2001). Interactions among actual ease-of-movement determinants and job satisfaction in the prediction of voluntary turnover. *Academy of Management Journal, 44*, 621–638. https://doi.org/10.2307/3069407
- Trevor, C. O., Gerhart, B., & Boudreau, J. W. (1997). Voluntary turnover and job performance: Curvilinearity and the moderating influences of salary growth and promotions. *Journal of Applied Psychology, 82*, 44–61. https://doi.org/10.1037/0021-9010.82.1.44
- Williams, M. L., McDaniel, M. A., & Nguyen, N. T. (2006). A meta-analysis of the antecedents and consequences of pay level satisfaction. *Journal of Applied Psychology, 91*, 392–413. https://doi.org/10.1037/0021-9010.91.2.392
- Yang, W.-N., Niven, K., & Johnson, S. (2019). Career plateau: A review of 40 years of research. *Journal of Vocational Behavior, 110*, 286–302. https://doi.org/10.1016/j.jvb.2018.11.005
- Zimmerman, R. D. (2008). Understanding the impact of personality traits on individuals' turnover decisions: A meta-analytic path model. *Personnel Psychology, 61*, 309–348. https://doi.org/10.1111/j.1744-6570.2008.00115.x

**Dataset source:** IBM HR Analytics Employee Attrition & Performance, Kaggle (pavansubhasht), https://www.kaggle.com/datasets/pavansubhasht/ibm-hr-analytics-attrition-dataset. The "fictional data set" statement is also in the R `modeldata::attrition` documentation, https://modeldata.tidymodels.org/reference/attrition.html.
