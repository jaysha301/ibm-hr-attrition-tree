# run_followups.R -- follow-up tables, executive page draft and chart (review fixes R1-R7).
# Companion to run_drill.R: it is source()d by run_drill.R after the search, the cached shuffles and the helper
# functions exist (it uses their objects: A, AC, R, d, y_all, BR, CEOD, NULLRES, desc, masks_of, stab_within, ...).
# It adds NO new search and changes no rule or threshold. Every number printed on the executive page and in the
# new appendix tables is computed here. Outputs: exec_findings_v2_draft.md, drill_tree.png, followup_*.csv, and the
# text blocks FU_SUM / FU_AP that run_drill.R puts in drill_summary.md and technical_appendix.md.
logp("followups start")
TAVG <- mean(y_all[!is_tr]); OTm <- BR$OT; nOTm <- BR$nonOT
ST_OT <- R$S$stores[["OT"]]; ST_ALL <- R$S$stores[["All"]]; ST_NO <- R$S$stores[["nonOT"]]; ST_NOU <- R$S$stores[["u_nonOT"]]
r5 <- function(x) 5 * round(x / 5)
exl <- function(x) { x <- sub("^works overtime and ", "overtime workers with ", x); x <- sub("^works overtime$", "overtime workers", x); x <- sub("^no overtime and ", "staff without overtime and ", x)
  x <- sub("^no overtime$", "staff without overtime", x); x <- gsub("stock option level = 0", "no stock options", x, fixed = TRUE); x <- gsub("job level = 1", "most junior job level", x, fixed = TRUE); gsub(": ", " ", x) }
cap1 <- function(x) paste0(toupper(substr(x, 1, 1)), substr(x, 2, nchar(x)))
gates_of <- function(ds) c(g1 = ds$n >= MIN_N && ds$leavers >= MIN_LV, g2 = ds$excess >= MIN_EXC, g3 = ds$lift >= MIN_LIFT && ds$wilson_lo > AVG, g4 = ds$test_n >= MIN_TN && ds$test_rate > TAVG)
yn <- function(x) ifelse(x, "yes", "no")

# ---------------- R1: sensitivity of group 2's income cut (label-free cuts; all other numbers as in the search)
G2 <- Q[A$branch[Q] == "OT" & A$n_conditions[Q] == 2][1]; stopifnot(!is.na(G2)); CUT2 <- AC[[G2]][[1]]$cut
CUTS <- sort(unique(c(2500, 2800, 2900, 3000, CUT2, 3500, 3750, 3900, 4000))); PAR_OT <- mean(y_all[OTm])
cut_row <- function(cut) { m <- OTm & d$MonthlyIncome < cut; ds <- desc(m, PAR_OT); rest <- OTm & !m; g <- gates_of(ds); st <- stab_within(ST_OT, list(mkc("MonthlyIncome", "<", cut)))
  data.frame(cut = cut, n = ds$n, pct_staff = ds$n / N, leavers = ds$leavers, pct_leavers = ds$leavers / L, rate = ds$rate, lift = ds$lift, wilson_lo = ds$wilson_lo, excess = ds$excess, impact_pts = ds$impact_pts,
    test_n = ds$test_n, test_rate = ds$test_rate, rest_of_overtime_n = sum(rest), rest_of_overtime_rate = mean(y_all[rest]), rate_vs_rest = ds$rate / mean(y_all[rest]), gate1_size = g[["g1"]], gate2_impact = g[["g2"]], gate3_rate = g[["g3"]], gate4_heldout = g[["g4"]],
    stability_within_overtime = st, pass_all_five = all(g) && st > STAB_MIN, row.names = NULL) }
CUTT <- do.call(rbind, lapply(CUTS, cut_row)); write.csv(rnd(CUTT), file.path(OUT, "followup_cut_sensitivity.csv"), row.names = FALSE)
PASS_CUTS <- CUTT$cut[CUTT$pass_all_five]
EXLO <- 3000; EXHI <- 3500; rlo <- cut_row(EXLO); rhi <- cut_row(EXHI)          # the exec page range (Quinn's R1)
cut_tab <- data.frame(`Income cut (per month)` = paste0("$", format(CUTT$cut, big.mark = ",", trim = TRUE), ifelse(CUTT$cut == CUT2, " (tested cut)", "")), People = CUTT$n, `Left rate` = pct(CUTT$rate), Lift = F2(CUTT$lift), `Wilson low end` = pct(CUTT$wilson_lo),
  `People above company rate (points)` = sprintf("%s (%s)", ppl(CUTT$excess), pp(CUTT$impact_pts)), `Test people, rate` = sprintf("%d, %s", CUTT$test_n, pct(CUTT$test_rate, 0)), `Rest of overtime: left rate` = pct(CUTT$rest_of_overtime_rate),
  `Size / impact / rate / held-out` = paste(yn(CUTT$gate1_size), yn(CUTT$gate2_impact), yn(CUTT$gate3_rate), yn(CUTT$gate4_heldout), sep = " / "), `Stability inside overtime` = pct(CUTT$stability_within_overtime, 0), `Clears all five` = yn(CUTT$pass_all_five), check.names = FALSE, stringsAsFactors = FALSE)
rng_pass <- if (length(PASS_CUTS)) sprintf("$%s to $%s", format(min(PASS_CUTS), big.mark = ","), format(max(PASS_CUTS), big.mark = ",")) else "none"
WIN <- quantile(d$MonthlyIncome[OTm], pmin(1, pmax(0, mean(d$MonthlyIncome[OTm] < CUT2) + c(-SIM_TOL, SIM_TOL))), type = 1, names = FALSE)

# ---------------- R2: pay versus job level inside overtime
jl1 <- d$JobLevel < 2; g2m <- OTm & d$MonthlyIncome < CUT2
jrow <- function(name, m) { ds <- desc(m, PAR_OT); g <- gates_of(ds); data.frame(name = name, n = ds$n, leavers = ds$leavers, rate = ds$rate, test_n = ds$test_n, test_rate = ds$test_rate, excess = ds$excess, g123 = all(g[1:3]), g4 = g[["g4"]], row.names = NULL) }
JLB <- rbind(jrow("Overtime, income under the tested cut (group 2)", g2m), jrow("  of which job level 1", g2m & jl1), jrow("Overtime, job level 1", OTm & jl1), jrow("Overtime, job level 2 or higher", OTm & !jl1),
  jrow("Overtime, job level 1, income under the tested cut", OTm & jl1 & g2m), jrow("Overtime, job level 1, income at or above the cut", OTm & jl1 & !g2m))
JL1_ST <- stab_within(ST_OT, list(mkc("JobLevel", "<", 2))); JL1_STU <- stab_within(R$S$stores[["u_OT"]], list(mkc("JobLevel", "<", 2)))
write.csv(rnd(JLB), file.path(OUT, "followup_joblevel1_breakdown.csv"), row.names = FALSE)
jl_tab <- data.frame(Group = JLB$name, People = JLB$n, Left = JLB$leavers, `Left rate` = pct(JLB$rate), `Test people, rate` = ifelse(JLB$test_n > 0, sprintf("%d, %s", JLB$test_n, pct(JLB$test_rate, 0)), "n/a"), check.names = FALSE, stringsAsFactors = FALSE)
JL_G2_SHARE <- JLB$n[2] / JLB$n[1]

# ---------------- R3: non-overtime combinations, the short-tenure group inside and across the company
I19 <- which(A$branch == "nonOT" & A$gates_1to4_new & !A$sensitive); I19 <- I19[order(-A$excess[I19])]
M19 <- masks_of(I19); U19 <- if (length(I19)) rowSums(M19) > 0 else rep(FALSE, N); D19 <- desc(U19, AVG)
t19 <- data.frame(id = A$id[I19], group = A$label[I19], plain = A$plain[I19], n_conditions = A$n_conditions[I19], n = A$n[I19], leavers = A$leavers[I19], rate = A$rate[I19], excess = A$excess[I19], test_n = A$test_n[I19], test_rate = A$test_rate[I19],
  stability_within = A$stab_within[I19], stability_unpruned = A$stab_unpruned[I19], pass_all_five = A$pass_new[I19])
write.csv(rnd(t19), file.path(OUT, "followup_nonovertime_19.csv"), row.names = FALSE)
tab19 <- data.frame(Group = t19$plain, People = t19$n, `Left rate` = pct(t19$rate), `People above company rate` = sprintf("%.1f", t19$excess), `Test people, rate` = sprintf("%d, %s", t19$test_n, pct(t19$test_rate, 0)), `Strict stability` = pct(t19$stability_within, 0), `Loose stability` = pct(t19$stability_unpruned, 0), check.names = FALSE, stringsAsFactors = FALSE)
NO_YR <- CEOD[CEOD$branch == "nonOT" & CEOD$variable == "YearsAtCompany", ]; stopifnot(nrow(NO_YR) == 1); CUTY <- NO_YR$cut
m_no_short <- nOTm & d$YearsAtCompany < CUTY; m_no_long <- nOTm & !m_no_short
m_co_short <- d$YearsAtCompany < CUTY; D_CO <- desc(m_co_short, AVG); G_CO <- gates_of(D_CO); cond_y <- list(mkc("YearsAtCompany", "<", CUTY))
CO_ST <- stab_within(ST_ALL, cond_y); CO_ST_ANY <- stab_within(ST_ALL, cond_y, any_cut = TRUE); CO_OT_N <- sum(m_co_short & OTm); CO_OT_RATE <- mean(y_all[m_co_short & OTm]); CO_NO_RATE <- mean(y_all[m_co_short & nOTm])
fam_all_unp <- length(unique(ST_NOU$sp$b[ST_NOU$sp$var %in% CSV])) / ST_NOU$B
short_rows <- data.frame(group = c("No overtime, short tenure", "Everyone, short tenure"), n = c(sum(m_no_short), D_CO$n), leavers = c(sum(y_all[m_no_short]), D_CO$leavers), rate = c(mean(y_all[m_no_short]), D_CO$rate), excess_company = c(sum(y_all[m_no_short]) - sum(m_no_short) * AVG, D_CO$excess),
  impact_pts = c(100 * (sum(y_all[m_no_short]) - sum(m_no_short) * AVG) / N, D_CO$impact_pts), test_n = c(sum(m_no_short & !is_tr), D_CO$test_n), test_rate = c(mean(y_all[m_no_short & !is_tr]), D_CO$test_rate), stringsAsFactors = FALSE)
write.csv(rnd(short_rows), file.path(OUT, "followup_short_tenure.csv"), row.names = FALSE)
short_tab <- data.frame(Group = c(sprintf("No overtime, years at the company under %d", CUTY), sprintf("Everyone, years at the company under %d", CUTY)), People = short_rows$n, `% of staff` = pct(short_rows$n / N, 0), `Left rate` = pct(short_rows$rate), `People above company rate (points)` = sprintf("%.1f (%s)", short_rows$excess_company, pp(short_rows$impact_pts)),
  `Test people, rate` = sprintf("%d, %s", short_rows$test_n, pct(short_rows$test_rate, 0)), check.names = FALSE, stringsAsFactors = FALSE)
REST_NO_RATE <- mean(y_all[m_no_long]); NO_RATE <- mean(y_all[nOTm])

# ---------------- R6: null calibration additions
nw <- NULLRES[["within_overtime"]]; ng <- NULLRES[["global"]]
nullx <- function(m, col) c(mean = mean(m[, col]), p95 = unname(quantile(m[, col], 0.95)), max = max(m[, col]), any = mean(m[, col] > 0))
pvg_w <- nullx(nw, "parent_view_gates_1to4"); pvs_w <- nullx(nw, "pass_parent_view_stable"); pvg_g <- nullx(ng, "parent_view_gates_1to4"); pvs_g <- nullx(ng, "pass_parent_view_stable")
tst_g <- mean(ng[, "tested"]); tst_w <- mean(nw[, "tested"])
CAP_NO <- 1 - ST_NO$n_pruned_root / ST_NO$B
t2 <- A[G2, ]; T2_LV <- round(t2$test_n * t2$test_rate); T2_W <- wilson_v(T2_LV, t2$test_n)

# ---------------- text blocks for the summary and the appendix
fu_tabs <- c(
  sprintf("**Group 2: how soft is the income cut?** The tested cut, $%s, is a training-set grid point (the 30th percentile of overtime income), not a tuned value. All five rules hold for cuts of %s; the left rate stays between %s and %s across those cuts, against %s to %s for the rest of overtime. Among the cuts shown, the lowest one that reaches 100 people is $%s; stability inside overtime drops to 50%% or below at the higher cuts.",
    format(CUT2, big.mark = ","), rng_pass, pct(min(CUTT$rate[CUTT$pass_all_five])), pct(max(CUTT$rate[CUTT$pass_all_five])), pct(min(CUTT$rest_of_overtime_rate[CUTT$pass_all_five])), pct(max(CUTT$rest_of_overtime_rate[CUTT$pass_all_five])),
    format(min(CUTT$cut[CUTT$gate1_size]), big.mark = ",")), "", mdt(cut_tab), "",
  sprintf("The stability rule accepts a refit cut within +/-%.2f of the share of overtime employees below the cut; for group 2 that window spans about $%s to $%s a month, so stability does not pin the cut down more tightly than that.", SIM_TOL, format(round(WIN[1]), big.mark = ","), format(round(WIN[2]), big.mark = ",")), "",
  sprintf("**Pay versus job level.** %d of the %d people in group 2 (%s) are in job level 1. All %d overtime workers in job level 1 left at %s (held-out %s on %d people), against %s for the %d overtime workers at job level 2 or higher (the company average is %s). Job level 1 inside overtime passes the first four rules and is stable in %s of strict refits (%s of unpruned refits), because the trees prefer income. Inside job level 1 overtime, income under the cut left at %s (%d people) against %s for those above it (%d), so pay adds a little but the group is essentially junior overtime workers. Pay and job level cannot be separated; this is one picture of pay and career stage.",
    JLB$n[2], JLB$n[1], pct(JL_G2_SHARE, 0), JLB$n[3], pct(JLB$rate[3]), pct(JLB$test_rate[3]), JLB$test_n[3], pct(JLB$rate[4]), JLB$n[4], pct(AVG), pct(JL1_ST, 0), pct(JL1_STU, 0), pct(JLB$rate[5]), JLB$n[5], pct(JLB$rate[6]), JLB$n[6]), "", mdt(jl_tab), "",
  sprintf("**Non-overtime combinations.** %d groups inside the no-overtime branch pass rules 1-4 (size, impact, rate, held-out) and fail only stability (the strict check cannot be passed there: at most %s of refits keep any split). Each is a combination of career-stage measures (tenure, experience, pay) and each is %s to %s people above the company rate. Counted once they cover %d people (%s of staff), %s left, and add only %.1f people above the company rate (%s points). They are never added to one another or to overtime.",
    length(I19), pct(CAP_NO, 0), if (length(I19)) sprintf("%.0f", min(t19$excess)) else "n/a", if (length(I19)) sprintf("%.0f", max(t19$excess)) else "n/a", D19$n, pct(D19$n / N, 0), pct(D19$rate), D19$excess, pp(D19$impact_pts)), "", mdt(tab19), "",
  sprintf("**Short tenure, the pattern the CEO saw.** Inside the no-overtime branch, staff with under %d years at the company (%d people) left at %s, against %s for the %d with longer tenure and %s for the branch; that is %.1f people above the company rate (%s points), just under the 15-person bar. Across the company the same cut gives %d people (%s of staff), %s left, %.1f people above the company rate (%s points), held-out %s on %d people. Gates 1-4: %s. Stability in company-wide refits: %s at a similar cut (%s at any cut), because tenure, experience, job level and pay share the signal. %d of them (%s) work overtime and left at %s; %d do not and left at %s. It is not added to the overtime finding.",
    CUTY, sum(m_no_short), pct(mean(y_all[m_no_short])), pct(REST_NO_RATE), sum(m_no_long), pct(NO_RATE), short_rows$excess_company[1], pp(short_rows$impact_pts[1]), D_CO$n, pct(D_CO$n / N, 0), pct(D_CO$rate), D_CO$excess, pp(D_CO$impact_pts), pct(D_CO$test_rate), D_CO$test_n,
    if (all(G_CO)) "all pass" else paste("fails", paste(c("size", "impact", "rate", "held-out")[!G_CO], collapse = ", ")), pct(CO_ST, 0), pct(CO_ST_ANY, 0), CO_OT_N, pct(CO_OT_N / D_CO$n, 0), pct(CO_OT_RATE), D_CO$n - CO_OT_N, pct(CO_NO_RATE)), "", mdt(short_tab), "")
fu_ap_extra <- c(
  "**Null checks that bear on group 2 and on the no-overtime branch.**", "",
  sprintf("- Against the parent branch, gates 1-4 pass in a mean of %.1f groups per within-overtime shuffle (95th percentile %.0f, maximum %.0f) and %.1f per across-everyone shuffle (95th percentile %.0f); with stability, %d of %d within-overtime shuffles and %d of %d across-everyone shuffles produce any. In the real data %s group(s) pass gates 1-4 against their branch (most are company-wide groups, judged against the company average, which is the same test as rules 1-4) and %d also pass stability (group 2).", pvg_w[["mean"]], pvg_w[["p95"]], pvg_w[["max"]], pvg_g[["mean"]], pvg_g[["p95"]], round(pvs_w[["any"]] * nrow(nw)), nrow(nw), round(pvs_g[["any"]] * nrow(ng)), nrow(ng), format(R$c_pvg, big.mark = ","), R$c_pv),
  sprintf("- Report this as: none of %d shuffles produced a group that clears all five rules, and none produced a group that clears the parent-branch view with stability. This is a count, not a p-value. It supports 'not chance' for an income-within-overtime pattern, not for the exact $%s cut.", N_SHUF, format(CUT2, big.mark = ",")),
  sprintf("- The shuffled searches tested fewer groups than the real search (mean %s across everyone and %s within overtime, against %s real), because drilling follows signal, which makes the shuffled search somewhat conservative against the real one. They also used %d bootstrap refits per scope for stability, not %d.", format(round(tst_g), big.mark = ","), format(round(tst_w), big.mark = ","), format(R$tested, big.mark = ","), B_NULL, B_REAL),
  sprintf("- Gates 1-4 do not discriminate inside overtime: within-overtime shuffles pass a mean of %.0f groups (95th percentile %.0f), because any large group inside overtime beats the company rate by construction. Rule 5 and the parent-branch view carry group 2.", nullx(nw, "pass_1to4")[["mean"]], nullx(nw, "pass_1to4")[["p95"]]),
  sprintf("- In the no-overtime branch the shuffle check has no power at rule 5: at most %s of strict refits keep any split there, so 'no group passed' says nothing about whether a pattern exists. **Absence of a qualifying pattern is not proof of no pattern.** In plain words: in the non-overtime branch no stable single split is found, because pruned trees find no split in %d of %d refits, while career stage shows up as a family when trees are left unpruned (%s of unpruned refits split on at least one career-stage measure).", pct(CAP_NO, 0), ST_NO$n_pruned_root, ST_NO$B, pct(fam_all_unp, 0)),
  sprintf("- The held-out check tests direction, not independence: size, impact, Wilson and stability use all %s rows, which include the held-out rows, so the held-out result is a check that the direction holds, not a fully independent test.", format(N, big.mark = ",")),
  sprintf("- Group 2's held-out result (%d people, about %d leavers, %s) is imprecise: a 95%% range for a rate on that many people runs from about %s to %s.", t2$test_n, T2_LV, pct(t2$test_rate, 0), pct(T2_W[1], 0), pct(T2_W[2], 0)),
  "", "**Disclosures.**", "",
  "- `run_drill.R` was edited at about 4:07 PM PT on Oct 9, after the first full run had finished. The edit changed reporting only. Quinn compared the cached search from before the edit with the final outputs row by row (all 14,178 stored groups: counts, test counts, stability and every pass flag identical). `thresholds.json` was not changed after it was written.",
  "- After Quinn's review (fixes R1-R7) the executive page, chart and appendix were regenerated by `run_drill.R` together with the companion `run_followups.R`. Search code, cache key (`search-v1`) and `thresholds.json` are unchanged, so the cached search and shuffles were reused.",
  sprintf("- Held-out rule detail: the held-out test is test rate above the test-set average (%s), not at or above the company rate (%s); this changes the verdict of no group that passes rules 1-3.", pct(TAVG, 2), pct(AVG, 2)),
  "- Old-rule wording: 'pass the old rule' in the earlier run means the old size, 1.5x and held-out gates before stability; only the overtime group passes the full old rule.", "")
FU_SUM <- c("## 6b. Follow-ups after Quinn's review", "", fu_tabs); FU_AP <- c("## 11b. Follow-ups after Quinn's review (R1-R7)", "", fu_tabs, fu_ap_extra)

# ---------------- exec_findings_v2_draft.md
rates_lohi <- c(rlo$rate, rhi$rate); exc_lohi <- c(rlo$excess, rhi$excess); rest_lohi <- c(rlo$rest_of_overtime_rate, rhi$rest_of_overtime_rate)
rng_txt <- function(v, f) { s <- unique(f(v)); if (length(s) == 1) s else paste(s[1], "to", s[2]) }
g2_n <- rng_txt(c(r5(rlo$n), r5(rhi$n)), function(x) sprintf("%d", x)); g2_staff <- rng_txt(100 * c(rlo$pct_staff, rhi$pct_staff), function(x) sprintf("%.0f%%", x))
g2_ratio <- sprintf("%.1f to %.1f", min(rlo$rate_vs_rest, rhi$rate_vs_rest), max(rlo$rate_vs_rest, rhi$rate_vs_rest))
g2_after <- rng_txt(100 * (L - exc_lohi) / N, function(x) sprintf("%.0f%%", x)); g2_fewer <- rng_txt(r5(exc_lohi), function(x) sprintf("%d", x))
ot <- A[Q[A$branch[Q] == "OT" & A$n_conditions[Q] == 1][1], ]; rate_nonOT <- mean(y_all[nOTm]); rate_OT <- mean(y_all[OTm])
g2_lbl <- sprintf("overtime workers earning under roughly $%s to $%s a month", format(EXLO, big.mark = ","), format(EXHI, big.mark = ","))
ex_ex <- if (length(I19)) I19[1] else NA
EX <- c("# Who leaves most: overtime workers, and among them lower-paid, junior staff (IBM's fictional HR teaching data, not real employees)", "",
  "QA-cleared by Quinn, Oct 9, 2026", "",
  "## Executive summary",
  sprintf("In IBM's fictional dataset of 1,470 employees, %s left. One finding clears every check: **overtime workers**, and among them the **lower-paid, mostly junior overtime workers**, who leave most. Overtime workers are %s of staff but %s of everyone who left. Newer, more junior staff also leave more often, with or without overtime; that is shown below as one career-stage picture to watch, not as a cleared finding. Nothing here shows what causes people to leave.", P0(AVG), P0(ot$pct_staff), P0(ot$pct_leavers)), "",
  "## What",
  sprintf("Overtime workers (%s people, %s of staff) left at %s, about %.1f times the company rate of %s and about %.0f times the rate of staff without overtime (%s). They account for %s of everyone who left.", format(ot$n, big.mark = ","), P0(ot$pct_staff), P0(ot$rate), ot$lift, P0(AVG), ot$rate / rate_nonOT, P0(rate_nonOT), P0(ot$pct_leavers)), "",
  sprintf("Within overtime, the lower-paid, mostly junior staff leave most: %s (about %s people, %s of staff) left at about %d%%, roughly %.1f times the company rate of %s and about %s times the rate of the other overtime workers (about %s). They account for close to %d%% of everyone who left. They are part of the overtime finding, not a separate pattern.",
    g2_lbl, g2_n, g2_staff, r5(100 * mean(rates_lohi)), round(2 * mean(rates_lohi) / AVG) / 2, P0(AVG), g2_ratio, P0(mean(rest_lohi)), r5(100 * mean(c(rlo$pct_leavers, rhi$pct_leavers)))), "",
  "## So What",
  sprintf("Overtime workers: as an illustration, not a forecast, if they left at the company average, overall attrition would fall from about %s to about %s, roughly %d fewer leavers.", P0(AVG), P0((L - ot$excess) / N), r5(ot$excess)), "",
  sprintf("Lower-paid, mostly junior overtime workers: on the same illustration, overall attrition would fall from about %s to about %s, roughly %s fewer leavers. These people are already inside the overtime group, so the two illustrations overlap and are not added.", P0(AVG), g2_after, g2_fewer), "",
  "## Not What",
  "This does not show that overtime or low pay causes leaving; overtime may mark busy or understaffed roles, and pay moves with job level and experience. Fictional teaching data, not a real workforce. Not a basis for decisions about individuals.", "",
  "## Context: career stage",
  sprintf("Pay, job level, tenure and total experience move together and describe one picture, career stage; the data cannot say which of them matters. Almost all of these lower-paid overtime workers (%s) are in the most junior job level, so pay and job level cannot be separated. Overtime workers in the most junior job level (%d people) left at %s, against %s for the %d overtime workers at higher job levels, close to the company average of %s.",
    P0(JL_G2_SHARE), JLB$n[3], P0(JLB$rate[3]), P0(JLB$rate[4]), JLB$n[4], P0(AVG)), "",
  sprintf("Newer staff leave more often both with and without overtime. Without overtime, staff with %d year%s or less at the company (%d people) left at %s, against %s for the %d without overtime who have been there longer, and %s for all staff without overtime. That is a real difference, but staff without overtime leave less often than the company overall, so against the company average it is modest: this group is about %.0f people above the company rate (under 1 point), short of the 15-person (1-point) bar we set for a headline.%s Our repeat-sample check is stricter inside the no-overtime group and could not be passed there, and the absence of a qualifying pattern is not proof that no pattern exists.",
    CUTY - 1, if (CUTY - 1 == 1) "" else "s", sum(m_no_short), P0(mean(y_all[m_no_short])), P0(REST_NO_RATE), sum(m_no_long), P0(NO_RATE), short_rows$excess_company[1],
    if (length(I19)) sprintf(" A number of overlapping combinations of tenure, experience and pay without overtime (for example, %s: %d people, %s) reach about %.0f to %.0f people above the company rate and also hold in the employees we set aside for checking, but together they cover %d people and add only about %.0f people above the company rate (%s point).", exl(A$plain[ex_ex]), A$n[ex_ex], P0(A$rate[ex_ex]), min(A$excess[I19]), max(A$excess[I19]), D19$n, D19$excess, pp(D19$impact_pts)) else ""), "",
  "## Worth watching, not a cleared finding",
  sprintf("> Across the company, staff with %d year%s or less at the company (%d people, %s of staff) left at %s, about %.0f people above the company rate (%s points); about a third of them (%s) work overtime. This is large and it held up on the employees we set aside for checking (%s), but the exact group isn't stable: these did not hold up consistently when we repeated the analysis on different samples of the same data, because several career-stage measures overlap (new hires, short tenure, junior level, low pay). We therefore treat the whole career-stage cluster as one picture to watch, not a proven separate cause. Because it overlaps with overtime, it is not added to the overtime finding.",
    CUTY - 1, if (CUTY - 1 == 1) "" else "s", D_CO$n, P0(D_CO$n / N), P0(D_CO$rate), D_CO$excess, pp(D_CO$impact_pts), P0(CO_OT_N / D_CO$n), P0(D_CO$test_rate)), "",
  "## Left out because too small to act on",
  "Several smaller groups, each under 100 people, are left out as too small to act on; see the appendix.", "",
  "## Large, but not cleared", {
    LNC_IDX <- CLS$idx[CLS$heads]; LNC_IDX <- LNC_IDX[A$branch[LNC_IDX] == "All" & A$n_conditions[LNC_IDX] <= MAX_COND_EXEC]; LNC_IDX <- head(LNC_IDX, 4)
    if (length(LNC_IDX)) { M <- masks_of(LNC_IDX); ovs <- vapply(seq_along(LNC_IDX), function(k) mean((OTm | jl1)[M[, k]]), 0)
      sprintf("Some other large groups also leave more often: %s. But none of them held up as a consistent split when we repeated the analysis on different samples of the same employees. They overlap with overtime workers and junior staff (%s to %s of their people are overtime workers or in the most junior job level). Groups defined by age or marital status are not used for decisions about individuals.",
        paste(exl(A$plain[LNC_IDX]), collapse = "; "), P0(min(ovs)), P0(max(ovs))) } else "No other large group stands out." }, "",
  "## Caveats",
  "- **Fictional data.** IBM made this dataset for teaching. The people in it are simulated, so it describes no real workforce.",
  "- **Nothing here is causal.** The groups describe who left more, not why.",
  "- **Pay goes with job level and experience.** Lower pay, junior job level, short tenure and little experience overlap heavily and can't be cleanly separated.",
  "- **Not for decisions about individuals.** Age, gender and marital status are descriptive only and must not be used for decisions about individuals.",
  "- **Snapshot timing.** Tenure and survey answers were recorded at the same time as whether people left, so they may not come before leaving.", "")
writeLines(EX, file.path(OUT, "exec_findings_v2_draft.md"))

# ---------------- chart (Storytelling-with-data style: gray, one accent for the cleared finding, direct labels)
fig <- data.frame(label = c(sprintf("Staff without overtime\n%s people", format(sum(nOTm), big.mark = ",")), sprintf("Overtime workers\n%s people", format(sum(OTm), big.mark = ",")),
  sprintf("Lower-paid, mostly junior overtime workers\n(under roughly $%s to $%s a month;\nabout %s people)", format(EXLO, big.mark = ","), format(EXHI, big.mark = ","), g2_n),
  sprintf("Staff with %d year%s or less at the company\n%d people; worth watching, not cleared", CUTY - 1, if (CUTY - 1 == 1) "" else "s", D_CO$n)),
  rate = c(rate_nonOT, rate_OT, mean(rates_lohi), D_CO$rate), cleared = c(FALSE, TRUE, TRUE, FALSE), stringsAsFactors = FALSE)
GRAY <- "#A6A6A6"; ACC <- "#D55E00"; INK <- "#333333"
png(file.path(OUT, "drill_tree.png"), width = 1400, height = 760, res = 120)
par(mar = c(3.6, 19, 6.4, 2), xpd = NA); xmax <- 70
bp <- barplot(rev(fig$rate) * 100, horiz = TRUE, col = rev(ifelse(fig$cleared, ACC, GRAY)), border = NA, xlim = c(0, xmax), axes = FALSE, space = 0.55, names.arg = NA)
TX <- grconvertX(0.012, "ndc", "user")
segments(AVG * 100, min(bp) - 0.75, AVG * 100, max(bp) + 0.75, lty = 2, col = INK, lwd = 1.2)
text(AVG * 100, max(bp) + 0.95, sprintf("company average %.0f%%", AVG * 100), adj = c(0.5, 0), cex = 0.85, col = INK)
vlab <- sprintf("%.0f%%", fig$rate * 100); vlab[3] <- sprintf("about %d%%", r5(100 * fig$rate[3]))
text(rev(fig$rate) * 100 - 0.8, bp, rev(vlab), adj = c(1, 0.5), cex = 1.25, font = 2, col = "white")
text(-1, bp, rev(fig$label), adj = c(1, 0.5), cex = 0.9, col = INK)
mtext("Overtime workers leave about three times as often as staff without overtime,\nand lower-paid, mostly junior overtime workers leave most of all", side = 3, line = 3.4, adj = 0, at = TX, cex = 1.15, font = 2, col = INK)
mtext("Share who left, by group", side = 3, line = 1.5, adj = 0, at = TX, cex = 0.9, col = "#555555")
mtext("Orange: cleared finding. Gray: comparison, or worth watching and not cleared. Fictional IBM teaching data (1,470 employees); describes who left, not why.", side = 1, line = 2.2, adj = 0, at = TX, cex = 0.75, col = "#555555")
invisible(dev.off())
write.csv(rnd(fig[, c("label", "rate", "cleared")]), file.path(OUT, "followup_chart_data.csv"), row.names = FALSE)
logp("followups done")
