# Executive rework: large, high-attrition, stable groups (IBM HR fictional data).
# Run from project root:  Rscript analysis/exec/run_exec.R
# Every number in analysis/exec/*.md comes from outputs written by this script.
.libPaths(c("~/R/library", .libPaths()))
suppressPackageStartupMessages({library(rpart); library(jsonlite)})
out <- "analysis/exec"

# ------------------------------------------------------------------ thresholds (Quinn's merged final rule)
TH <- list(
  source = "Quinn merged final rule (Oct 8 2026, late evening PT) with Quinn's exec-review ruling F1/F7 (Oct 9 2026, about 12:05 AM PT)",
  counted_on = "full data, 1,470 rows",
  rule1_size = list(min_n = 100, min_leavers = 24),
  rule2_rate = list(min_lift = 1.5, lift_denominator = "company rate 237/1470"),
  rule3_test = list(min_test_n = 30, direction = "group test rate > test-set overall rate"),
  rule4_stability = list(min_share_refits_primary_split = 0.5, n_bootstrap = 500, nodes = 1:3,
    wording = "Stability: across the 500 bootstrap refits (full data, depth <=3, minbucket 100, 10-fold CV, 1-SE pruning), each of the group's defining variables must be a primary split at the root or the level directly below it (nodes 1-3) in more than 50% of refits. Large groups that fail this rule may appear on the executive page only as context, with no impact figure.",
    depth_cap = 3, pruning = "1-SE rule", minbucket_full = 100, cv_folds = 10),
  appendix_checks = list(wilson = list(conf = 0.95, compare_to = 0.1612,
    note = "Reported check only (appendix), NOT a pass condition: is the lower end of the 95% Wilson interval above the company average?")),
  appendix_small_floor = list(min_n = 74, note = "groups under 100 employees that pass the rate rule are labelled 'too small to act on'; a 74 floor is reported as a sensitivity"),
  impact = list(reference_rate = 0.1612, formula = "(group leavers - n * 0.1612) / 1470",
                label = "if the group fell to the company average; an illustration, not a forecast; shown on the executive page only for cleared groups; never summed across overlapping groups",
                appendix_only = "impact at the rate of everyone outside the group"),
  headline = list(max_groups = 4, exclude_sensitive = TRUE,
                  sensitive_vars = c("Age","Gender","MaritalStatus"),
                  same_people_overlap = 0.5,
                  same_people_note = "a passing group is treated as essentially the same people as an already-listed one when >= 50% of its employees are in that group"),
  context = list(pay_band_for_numbers = 3500,
                 pay_band_note = "round cut in the middle of the stable $2,500-$4,000 range, used for context numbers only; the executive text says 'roughly the bottom third of earners (under about $3,000-$4,000 a month)'",
                 bands_reported = c(2500, 2750, 3000, 3250, 3500, 3750, 4000)))
write_json(TH, file.path(out, "thresholds.json"), auto_unbox = TRUE, pretty = TRUE)

SEED <- 20261008
d <- read.csv("data/WA_Fn-UseC_-HR-Employee-Attrition.csv", fileEncoding = "UTF-8-BOM", stringsAsFactors = TRUE)
stopifnot(nrow(d) == 1470)
d <- d[, setdiff(names(d), c("EmployeeNumber","EmployeeCount","Over18","StandardHours","DailyRate","HourlyRate","MonthlyRate"))]
d$Attrition <- factor(d$Attrition, levels = c("No","Yes"))
stopifnot(ncol(d) == 28)
N <- nrow(d); L <- sum(d$Attrition == "Yes"); avg <- L / N

# same stratified 70/30 split as analysis/attrition_tree.R
set.seed(SEED)
idx_tr <- unlist(lapply(split(seq_len(N), d$Attrition), function(ix) sample(ix, round(0.7 * length(ix)))))
is_tr <- seq_len(N) %in% idx_tr
tr <- d[is_tr, ]; te <- d[!is_tr, ]
test_avg <- mean(te$Attrition == "Yes")

wilson <- function(x, n, conf = 0.95) { z <- qnorm(1 - (1 - conf) / 2); p <- x / n
  dd <- 1 + z^2 / n; c0 <- (p + z^2 / (2 * n)) / dd; h <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / dd
  c(lo = c0 - h, hi = c0 + h) }

# ------------------------------------------------------------------ tree: depth 3, minbucket tied to size rule, 1-SE pruned
mb_full <- TH$rule1_size$min_n                       # 100 on full data
mb_tr   <- ceiling(mb_full * nrow(tr) / N)           # scaled to training rows (70)
# Main criterion: a rate (probability) tree, rpart method "anova" on 0/1 attrition. For a binary outcome
# its split criterion equals the Gini criterion, and its cross-validated risk is the Brier score, which
# rewards separating attrition RATES. The misclassification-loss version ("class") is kept for the record:
# with a 16% base rate no 70+-row leaf flips the predicted class, so its 1-SE rule prunes to the root.
METHOD <- "anova"
grow <- function(dat, mb, seed, method = METHOD) { set.seed(seed)
  if (method == "anova") dat$Attrition <- as.numeric(dat$Attrition == "Yes")
  rpart(Attrition ~ ., data = dat, method = method,
        control = rpart.control(cp = 0.001, minbucket = mb, minsplit = 2 * mb, maxdepth = 3, xval = 10)) }
prune_1se <- function(f) { ct <- f$cptable; i <- which.min(ct[, "xerror"])
  thr <- ct[i, "xerror"] + ct[i, "xstd"]; j <- min(which(ct[, "xerror"] <= thr))
  list(fit = prune(f, cp = ct[j, "CP"]), cp = ct[j, "CP"], nsplit = ct[j, "nsplit"]) }
g_tr <- grow(tr, mb_tr, SEED); p_tr <- prune_1se(g_tr); fit <- p_tr$fit
g_full <- grow(d, mb_full, SEED); p_full <- prune_1se(g_full); fit_full <- p_full$fit
g_tr_cls <- grow(tr, mb_tr, SEED, "class"); p_tr_cls <- prune_1se(g_tr_cls)
g_full_cls <- grow(d, mb_full, SEED, "class"); p_full_cls <- prune_1se(g_full_cls)

sink(file.path(out, "exec_tree_rules.txt"))
cat("Rate tree (rpart method=anova on 0/1 Attrition; xerror = cross-validated Brier risk relative to root)\n\nTraining tree (n=", nrow(tr), "), maxdepth 3, minbucket ", mb_tr, " (= 100 scaled to training), minsplit ", 2*mb_tr,
    ", grown at cp 0.001, 10-fold xval (seed ", SEED, "), pruned by 1-SE rule to cp ", signif(p_tr$cp, 4), " (", p_tr$nsplit, " splits)\n\n", sep = "")
print(fit); cat("\ncp table of the grown training tree:\n"); print(g_tr$cptable)
cat("\n\nFull-data tree (n=1470), same settings with minbucket 100, minsplit 200; 1-SE pruned to cp ", signif(p_full$cp, 4), " (", p_full$nsplit, " splits)\n\n", sep = "")
print(fit_full); cat("\ncp table of the grown full-data tree:\n"); print(g_full$cptable)
cat("\n\nFor the record: same settings with method='class' (misclassification loss).\nTraining: 1-SE pruned to", p_tr_cls$nsplit, "splits. cp table:\n"); print(g_tr_cls$cptable)
cat("Full data: 1-SE pruned to", p_full_cls$nsplit, "splits. cp table:\n"); print(g_full_cls$cptable)
sink()

# primary splits of a tree as data.frame(node, var, rule_left, cut)
prim_splits <- function(f, dat) {
  fr <- f$frame; if (nrow(fr) == 1) return(data.frame(node = integer(), var = character(), left = character(), cut = numeric()))
  ids <- as.integer(rownames(fr)); srow <- 1; res <- list()
  for (i in seq_len(nrow(fr))) { if (fr$var[i] == "<leaf>") next
    s <- f$splits[srow, , drop = FALSE]; v <- as.character(fr$var[i])
    if (abs(s[1, "ncat"]) == 1) { cut <- unname(s[1, "index"]); left <- if (s[1, "ncat"] < 0) paste0(v, " < ", cut) else paste0(v, " >= ", cut) }
    else { lv <- levels(dat[[v]]); codes <- f$csplit[s[1, "index"], seq_along(lv)]; cut <- NA
      left <- paste0(v, " in {", paste(lv[codes == 1], collapse = ", "), "}") }
    res[[length(res) + 1]] <- data.frame(node = ids[i], var = v, left = left, cut = cut)
    srow <- srow + 1 + fr$ncompete[i] + fr$nsurrogate[i] }
  do.call(rbind, res) }
ps_tr <- prim_splits(fit, tr); ps_full <- prim_splits(fit_full, d)
# rule string -> logical vector on a data frame
eval_rule <- function(rule, df) {
  if (grepl(" < ", rule, fixed = TRUE)) { v <- sub(" < .*", "", rule); return(df[[v]] < as.numeric(sub(".* < ", "", rule))) }
  if (grepl(" >= ", rule, fixed = TRUE)) { v <- sub(" >= .*", "", rule); return(df[[v]] >= as.numeric(sub(".* >= ", "", rule))) }
  v <- sub(" in \\{.*", "", rule); lv <- strsplit(sub(".*\\{(.*)\\}$", "\\1", rule), ", ", fixed = TRUE)[[1]]
  as.character(df[[v]]) %in% lv }
negate <- function(rule, df) { function(x) !eval_rule(rule, x) }
# build path definitions for every non-root node of a tree
make_node_defs <- function(f, ps) { nd <- list(); if (!nrow(ps)) return(nd)
  sp <- setNames(split(ps, ps$node), as.character(unique(ps$node)))
  sp <- split(ps, ps$node)
  for (n in setdiff(as.integer(rownames(f$frame)), 1L)) {
    path <- list(); m <- n
    while (m > 1) { par <- m %/% 2; r <- sp[[as.character(par)]]
      path <- c(list(list(rule = r$left, var = r$var, neg = (m %% 2 == 1))), path); m <- par }
    nd[[as.character(n)]] <- path }
  nd }
node_defs <- make_node_defs(fit, ps_tr)
node_defs_full <- make_node_defs(fit_full, ps_full)
path_label <- function(path) paste(sapply(path, function(p) if (p$neg) paste0("NOT(", p$rule, ")") else p$rule), collapse = " & ")
path_fun <- function(path) { force(path); function(df) Reduce(`&`, lapply(path, function(p) { x <- eval_rule(p$rule, df); if (p$neg) !x else x })) }

# ------------------------------------------------------------------ bootstrap stability (full data, same settings)
B <- TH$rule4_stability$n_bootstrap; set.seed(SEED)
boot_ps <- vector("list", B); boot_vars <- vector("list", B); boot_top2 <- vector("list", B); boot_root <- character(B); boot_cuts <- list()
for (b in 1:B) {
  bi <- sample(N, replace = TRUE); db <- d[bi, ]
  fb <- prune_1se(grow(db, mb_full, SEED + b))$fit
  psb <- prim_splits(fb, db); boot_ps[[b]] <- psb
  boot_top2[[b]] <- unique(psb$var[psb$node <= 3]);
  boot_vars[[b]] <- unique(psb$var); boot_root[b] <- if (nrow(psb)) psb$var[psb$node == 1] else "<none: pruned to root>"
  if (nrow(psb)) for (k in seq_len(nrow(psb))) if (!is.na(psb$cut[k]))
    boot_cuts[[length(boot_cuts) + 1]] <- data.frame(b = b, node = psb$node[k], var = psb$var[k], cut = psb$cut[k]) }
boot_cuts <- do.call(rbind, boot_cuts)
# Rule 4 (F1): every defining variable must be a primary split at nodes 1-3 in > 50% of refits
stab_share <- function(vars) mean(sapply(boot_top2, function(v) all(vars %in% v)))
stab_any   <- function(vars) mean(sapply(boot_vars, function(v) all(vars %in% v)))   # old reading, reported only
root_tab <- sort(table(boot_root) / B, decreasing = TRUE)
var_freq <- sort(table(unlist(boot_vars)) / B, decreasing = TRUE)
nsplit_tab <- table(sapply(boot_vars, length))
cut_summ <- if (!is.null(boot_cuts)) do.call(rbind, lapply(split(boot_cuts, boot_cuts$var), function(z)
  data.frame(var = z$var[1], n_cuts = nrow(z), q25 = quantile(z$cut, .25), median = median(z$cut), q75 = quantile(z$cut, .75)))) else NULL

# data-driven cutpoints: median bootstrap cut, rounded for plain language
bcut <- function(v) median(boot_cuts$cut[boot_cuts$var == v])
INC_CUT <- round(bcut("MonthlyIncome") / 500) * 500
TWY_CUT <- bcut("TotalWorkingYears"); AGE_CUT <- bcut("Age"); YAC_CUT <- bcut("YearsAtCompany")
# ------------------------------------------------------------------ candidate groups
C <- list()
add <- function(id, label_exec, def, f, vars, source, eligible = TRUE) C[[id]] <<- list(id = id, label_exec = label_exec, definition = def, f = f, vars = vars, source = source, eligible = eligible)
for (n in names(node_defs)) { p <- node_defs[[n]]
  add(paste0("tree_node_", n), NA, path_label(p), path_fun(p), unique(sapply(p, `[[`, "var")),
      paste0("training tree node ", n, " (level ", floor(log2(as.integer(n))), ")")) }
for (n in names(node_defs_full)) { p <- node_defs_full[[n]]
  add(paste0("fulltree_node_", n), NA, path_label(p), path_fun(p), unique(sapply(p, `[[`, "var")),
      paste0("full-data tree node ", n, " (level ", floor(log2(as.integer(n))), "); cutpoint chosen using test rows too, so its test check is not independent")) }
add("ot_yes", "Overtime workers", "OverTime = Yes", function(x) x$OverTime == "Yes", "OverTime", "simple")
add("ot_no", "No overtime", "OverTime = No", function(x) x$OverTime == "No", "OverTime", "simple")
add("inc_boot", paste0("Lower-paid staff (under about $", format(INC_CUT, big.mark = ","), "/month)"), paste0("MonthlyIncome < ", INC_CUT, " (median bootstrap income cut ", bcut("MonthlyIncome"), ", rounded to $500)"),
    function(x) x$MonthlyIncome < INC_CUT, "MonthlyIncome", "simple, data-driven cut")
add("inc_lt2500", "Pay under about $2,500/month", "MonthlyIncome < 2500", function(x) x$MonthlyIncome < 2500, "MonthlyIncome", "band sensitivity (fixed cut; not headline-eligible)", FALSE)
add("inc_lt3000", "Pay under about $3,000/month", "MonthlyIncome < 3000", function(x) x$MonthlyIncome < 3000, "MonthlyIncome", "band sensitivity (fixed cut; not headline-eligible)", FALSE)
add("inc_lt4000", "Pay under about $4,000/month", "MonthlyIncome < 4000", function(x) x$MonthlyIncome < 4000, "MonthlyIncome", "band sensitivity (fixed cut; not headline-eligible)", FALSE)
add("ot_inc_boot", paste0("Overtime workers paid under about $", format(INC_CUT, big.mark = ","), "/month"), paste0("OverTime = Yes & MonthlyIncome < ", INC_CUT),
    function(x) x$OverTime == "Yes" & x$MonthlyIncome < INC_CUT, c("OverTime","MonthlyIncome"), "combination, data-driven cut")
add("twy_boot", "Very little total work experience", paste0("TotalWorkingYears < ", TWY_CUT, " (median bootstrap cut)"), function(x) x$TotalWorkingYears < TWY_CUT, "TotalWorkingYears", "simple, data-driven cut")
add("age_boot", "Younger employees", paste0("Age < ", AGE_CUT, " (median bootstrap cut)"), function(x) x$Age < AGE_CUT, "Age", "simple, data-driven cut")
add("jl1", "Entry-level staff (job level 1)", "JobLevel = 1", function(x) x$JobLevel == 1, "JobLevel", "simple")
add("single", "Single employees", "MaritalStatus = Single", function(x) x$MaritalStatus == "Single", "MaritalStatus", "simple")
add("sol0", "No stock options", "StockOptionLevel = 0", function(x) x$StockOptionLevel == 0, "StockOptionLevel", "simple")
add("age_lt30", "Under 30", "Age < 30", function(x) x$Age < 30, "Age", "simple")
add("age_lt25", "Under 25", "Age < 25", function(x) x$Age < 25, "Age", "simple")
add("yac_lt2", "Under 2 years at the company", "YearsAtCompany < 2", function(x) x$YearsAtCompany < 2, "YearsAtCompany", "simple")
add("yac_le3", "3 years or less at the company", "YearsAtCompany <= 3", function(x) x$YearsAtCompany <= 3, "YearsAtCompany", "simple")
add("twy_le3", "3 years or less of total work experience", "TotalWorkingYears <= 3", function(x) x$TotalWorkingYears <= 3, "TotalWorkingYears", "simple")
add("travel_freq", "Frequent business travellers", "BusinessTravel = Travel_Frequently", function(x) x$BusinessTravel == "Travel_Frequently", "BusinessTravel", "simple")
add("role_salesrep", "Sales representatives", "JobRole = Sales Representative", function(x) x$JobRole == "Sales Representative", "JobRole", "simple")
add("role_labtech", "Laboratory technicians", "JobRole = Laboratory Technician", function(x) x$JobRole == "Laboratory Technician", "JobRole", "simple")
add("role_salesexec", "Sales executives", "JobRole = Sales Executive", function(x) x$JobRole == "Sales Executive", "JobRole", "simple")
add("dept_sales", "Sales department", "Department = Sales", function(x) x$Department == "Sales", "Department", "simple")
add("jobinv1", "Lowest job involvement (1 of 4)", "JobInvolvement = 1", function(x) x$JobInvolvement == 1, "JobInvolvement", "simple")
add("envsat1", "Lowest environment satisfaction (1 of 4)", "EnvironmentSatisfaction = 1", function(x) x$EnvironmentSatisfaction == 1, "EnvironmentSatisfaction", "simple")
add("jobsat1", "Lowest job satisfaction (1 of 4)", "JobSatisfaction = 1", function(x) x$JobSatisfaction == 1, "JobSatisfaction", "simple")
add("wlb1", "Lowest work-life balance (1 of 4)", "WorkLifeBalance = 1", function(x) x$WorkLifeBalance == 1, "WorkLifeBalance", "simple")
add("mgr_new", "New manager (under 1 year)", "YearsWithCurrManager = 0", function(x) x$YearsWithCurrManager == 0, "YearsWithCurrManager", "simple")
add("ncw_ge5", "Five or more previous employers", "NumCompaniesWorked >= 5", function(x) x$NumCompaniesWorked >= 5, "NumCompaniesWorked", "simple")
add("dist_ge10", "Long commute (10+ miles)", "DistanceFromHome >= 10", function(x) x$DistanceFromHome >= 10, "DistanceFromHome", "simple")
add("ot_inc2475", "Overtime and under about $2,500/month (earlier headline)", "OverTime = Yes & MonthlyIncome < 2475", function(x) x$OverTime == "Yes" & x$MonthlyIncome < 2475, c("OverTime","MonthlyIncome"), "earlier tree (v0.3 headline)")
add("ot_jl1", "Overtime and entry-level", "OverTime = Yes & JobLevel = 1", function(x) x$OverTime == "Yes" & x$JobLevel == 1, c("OverTime","JobLevel"), "combination")
add("ot_sol0", "Overtime and no stock options", "OverTime = Yes & StockOptionLevel = 0", function(x) x$OverTime == "Yes" & x$StockOptionLevel == 0, c("OverTime","StockOptionLevel"), "combination")
add("ot_single", "Overtime and single", "OverTime = Yes & MaritalStatus = Single", function(x) x$OverTime == "Yes" & x$MaritalStatus == "Single", c("OverTime","MaritalStatus"), "combination")
add("ot_age30", "Overtime and under 30", "OverTime = Yes & Age < 30", function(x) x$OverTime == "Yes" & x$Age < 30, c("OverTime","Age"), "combination")
add("jl1_sol0", "Entry-level with no stock options", "JobLevel = 1 & StockOptionLevel = 0", function(x) x$JobLevel == 1 & x$StockOptionLevel == 0, c("JobLevel","StockOptionLevel"), "combination")

# ------------------------------------------------------------------ evaluate candidates
rows <- lapply(C, function(g) {
  m <- g$f(d); mt <- g$f(te); y <- d$Attrition == "Yes"; yt <- te$Attrition == "Yes"
  n <- sum(m); x <- sum(y & m); r <- x / n; w <- wilson(x, n, TH$appendix_checks$wilson$conf)
  nt <- sum(mt); xt <- sum(yt & mt); rt <- if (nt) xt / nt else NA; wt <- if (nt) wilson(xt, nt) else c(NA, NA)
  r_out <- sum(y & !m) / sum(!m)
  st <- stab_share(g$vars); sa <- stab_any(g$vars)
  sens <- any(g$vars %in% TH$headline$sensitive_vars)
  elig_h <- g$eligible && !(sens && TH$headline$exclude_sensitive)
  data.frame(id = g$id, source = g$source, definition = g$definition, exec_label = ifelse(is.na(g$label_exec), "", g$label_exec),
    defining_vars = paste(g$vars, collapse = "+"), sensitive = sens, headline_eligible = elig_h,
    n = n, pct_employees = 100 * n / N, leavers = x, pct_all_leavers = 100 * x / L, full_rate = r,
    rate = r, lift = r / avg, wilson_lo = unname(w[1]), wilson_hi = unname(w[2]),
    rate_outside = r_out,
    test_n = nt, test_leavers = xt, test_rate = rt, test_wilson_lo = unname(wt[1]), test_wilson_hi = unname(wt[2]),
    test_overall_rate = test_avg,
    impact_pp_to_avg = 100 * (x - n * TH$impact$reference_rate) / N, impact_people_to_avg = x - n * TH$impact$reference_rate,
    impact_pp_to_outside = 100 * (x - n * r_out) / N, impact_people_to_outside = x - n * r_out,
    wilson_lo_above_avg_check = unname(w[1]) > TH$appendix_checks$wilson$compare_to,
    stability_share = st, stability_anywhere_old_reading = sa,
    pass_r1_size = n >= TH$rule1_size$min_n & x >= TH$rule1_size$min_leavers,
    pass_r2_rate = (r / avg) >= TH$rule2_rate$min_lift,   # Wilson is an appendix check only (F7), not a pass condition
    pass_r3_test = nt >= TH$rule3_test$min_test_n & !is.na(rt) & rt > test_avg,
    pass_r4_stability = st > TH$rule4_stability$min_share_refits_primary_split,
    pass_size_at_74 = n >= TH$appendix_small_floor$min_n & x >= TH$rule1_size$min_leavers,
    stringsAsFactors = FALSE) })
cand <- do.call(rbind, rows); rownames(cand) <- NULL
cand$pass_all <- with(cand, pass_r1_size & pass_r2_rate & pass_r3_test & pass_r4_stability)
cand$pass_all_at_74 <- with(cand, pass_size_at_74 & pass_r2_rate & pass_r3_test & pass_r4_stability)
fails_txt <- with(cand, trimws(gsub(" +", " ", paste(ifelse(!pass_r1_size, "size", ""), ifelse(!pass_r2_rate, "rate", ""),
                                 ifelse(!pass_r3_test, "test", ""), ifelse(!pass_r4_stability, "stability", "")))))
cand$status <- with(cand, ifelse(pass_all, "PASS",
  ifelse(pass_r1_size & pass_r2_rate & pass_r3_test & !pass_r4_stability, "passes size and lift, not stable as a split",
  ifelse(!pass_r1_size & pass_r2_rate, paste0("too small to act on (under 100 employees; fails: ", fails_txt, ")"),
  paste0("fails: ", fails_txt)))))
# duplicate-membership detection (a tree node identical to a simple group)
memb <- sapply(C, function(g) g$f(d))
cand$identical_to <- sapply(seq_along(C), function(i) { same <- which(apply(memb, 2, function(z) all(z == memb[, i])))
  paste(setdiff(names(C)[same], names(C)[i]), collapse = ";") })

simple_ids <- names(C)[!grepl("^(tree_node|fulltree_node)", names(C))]
cand$headline_eligible <- cand$headline_eligible & !(grepl("^(tree_node|fulltree_node)", cand$id) &
  sapply(cand$identical_to, function(z) any(strsplit(z, ";")[[1]] %in% simple_ids)))
# ------------------------------------------------------------------ headline selection, overlap, union
passing <- cand[cand$pass_all, ]
elig <- passing[passing$headline_eligible, ]
elig <- elig[order(-elig$impact_people_to_avg), ]
chosen <- c(); same_as <- list()
for (i in seq_len(nrow(elig))) { id <- elig$id[i]; mi <- memb[, id]
  dup <- NULL
  for (c0 in chosen) if (sum(mi & memb[, c0]) / sum(mi) >= TH$headline$same_people_overlap) { dup <- c0; break }
  if (is.null(dup) && length(chosen) < TH$headline$max_groups) chosen <- c(chosen, id) else same_as[[id]] <- if (is.null(dup)) "cap reached" else dup }
cand$headline <- cand$id %in% chosen
cand$same_people_as <- ""
for (k in names(same_as)) cand$same_people_as[cand$id == k] <- same_as[[k]]

ov_ids <- passing$id
ov <- if (length(ov_ids)) do.call(rbind, lapply(ov_ids, function(a) do.call(rbind, lapply(ov_ids, function(b) {
  both <- sum(memb[, a] & memb[, b])
  data.frame(group_a = a, group_b = b, n_a = sum(memb[, a]), n_b = sum(memb[, b]), n_both = both,
             pct_of_a_in_b = 100 * both / sum(memb[, a]), jaccard = both / sum(memb[, a] | memb[, b]),
             leavers_both = sum(memb[, a] & memb[, b] & d$Attrition == "Yes")) })))) else NULL
near <- cand$id[cand$status == "passes size and lift, not stable as a split" & !grepl("^(tree_node|fulltree_node)", cand$id)]
ov_near <- if (length(chosen) && length(near)) do.call(rbind, lapply(near, function(a) do.call(rbind, lapply(chosen, function(b) {
  both <- sum(memb[, a] & memb[, b])
  data.frame(group = a, survivor = b, n_group = sum(memb[, a]), n_both = both, pct_of_group_in_survivor = 100 * both / sum(memb[, a]),
             leavers_group = sum(memb[, a] & d$Attrition == "Yes"), leavers_both = sum(memb[, a] & memb[, b] & d$Attrition == "Yes")) })))) else NULL
if (!is.null(ov_near)) { cover <- sapply(near, function(a) { u <- apply(memb[, chosen, drop = FALSE], 1, any)
  100 * sum(memb[, a] & u) / sum(memb[, a]) })
  ov_near$pct_of_group_in_any_survivor <- cover[ov_near$group] }
union_stats <- function(ids) { if (!length(ids)) return(NULL); u <- apply(memb[, ids, drop = FALSE], 1, any)
  n <- sum(u); x <- sum(u & d$Attrition == "Yes")
  list(groups = ids, n = n, pct_employees = 100 * n / N, leavers = x, pct_all_leavers = 100 * x / L, rate = x / n,
       impact_pp_to_avg = 100 * (x - n * TH$impact$reference_rate) / N, impact_people_to_avg = x - n * TH$impact$reference_rate) }
U_head <- union_stats(chosen); U_all <- union_stats(ov_ids)

# ------------------------------------------------------------------ threshold sensitivity
sens_tab <- do.call(rbind, lapply(list(c(100, 1.5), c(74, 1.5), c(59, 1.5), c(44, 1.5), c(100, 1.25), c(100, 1.75)), function(p) {
  ok <- with(cand, n >= p[1] & leavers >= 24 & lift >= p[2] & pass_r3_test & pass_r4_stability)
  data.frame(variant = "rule 4 at nodes 1-3", min_n = p[1], min_lift = p[2], n_pass = sum(ok), passing = paste(cand$id[ok], collapse = "; ")) }))
ok_old <- with(cand, pass_r1_size & pass_r2_rate & pass_r3_test & stability_anywhere_old_reading > 0.5)
ok_w <- with(cand, pass_all & wilson_lo_above_avg_check)
sens_tab <- rbind(sens_tab,
  data.frame(variant = "rule 4 old reading (primary split anywhere)", min_n = 100, min_lift = 1.5, n_pass = sum(ok_old), passing = paste(cand$id[ok_old], collapse = "; ")),
  data.frame(variant = "Wilson lower bound > 16.12% added as a pass condition", min_n = 100, min_lift = 1.5, n_pass = sum(ok_w), passing = paste(cand$id[ok_w], collapse = "; ")))
sens_nostab <- with(cand, cand$id[pass_r1_size & pass_r2_rate & pass_r3_test])

# ------------------------------------------------------------------ extra computations (F3, F5, F6, F8)
y <- d$Attrition == "Yes"; ytr <- tr$Attrition == "Yes"; yte <- te$Attrition == "Yes"
PB <- TH$context$pay_band_for_numbers
stopifnot(PB == INC_CUT)                       # the context band is the inc_boot group
lowp <- d$MonthlyIncome < PB; ot <- d$OverTime == "Yes"; jl1v <- d$JobLevel == 1
cell <- function(m, yy) list(n = sum(m), leavers = sum(m & yy), rate = if (sum(m)) mean(yy[m]) else NA)
pay_ot <- lapply(list(full = d, train = tr, test = te), function(df) { yy <- df$Attrition == "Yes"; lp <- df$MonthlyIncome < PB; o <- df$OverTime == "Yes"
  list(ot_low = cell(o & lp, yy), ot_high = cell(o & !lp, yy), noot_low = cell(!o & lp, yy), noot_high = cell(!o & !lp, yy)) })
excess <- sapply(list(ot_low = ot & lowp, ot_high = ot & !lowp, noot_low = !ot & lowp, noot_high = !ot & !lowp),
                 function(m) sum(m & y) - sum(m) * TH$impact$reference_rate)
jl1_pay <- list(full = list(jl1_low = cell(jl1v & lowp, y), jl1_high = cell(jl1v & !lowp, y),
                            notjl1_low = cell(!jl1v & lowp, y), notjl1_high = cell(!jl1v & !lowp, y)),
                test = list(jl1_low = cell(te$JobLevel == 1 & te$MonthlyIncome < PB, yte), jl1_high = cell(te$JobLevel == 1 & te$MonthlyIncome >= PB, yte)))
bands <- do.call(rbind, lapply(TH$context$bands_reported, function(cut) { m <- d$MonthlyIncome < cut; mtr <- tr$MonthlyIncome < cut; mte <- te$MonthlyIncome < cut
  data.frame(cut = cut, n = sum(m), pct_employees = 100 * mean(m), leavers = sum(m & y), rate = mean(y[m]), rate_above = mean(y[!m]), lift = mean(y[m]) / avg,
             pct_joblevel1 = 100 * mean(jl1v[m]), train_rate = mean(ytr[mtr]), train_rate_above = mean(ytr[!mtr]),
             test_n = sum(mte), test_rate = mean(yte[mte]), test_rate_above = mean(yte[!mte])) }))
band_range <- bands[bands$cut >= 3000 & bands$cut <= 4000, ]
train_lowpay <- list(n = sum(tr$MonthlyIncome < PB), rate = mean(ytr[tr$MonthlyIncome < PB]), rate_rest = mean(ytr[tr$MonthlyIncome >= PB]))
# where MonthlyIncome splits sit across the refits (branch = side of a root OverTime split)
inc_loc <- t(sapply(boot_ps, function(ps) {
  inc <- ps[ps$var == "MonthlyIncome", , drop = FALSE]
  if (!nrow(inc)) return(c(any = FALSE, root = FALSE, nodes123 = FALSE, in_ot_yes = FALSE, in_ot_no = FALSE, other = FALSE))
  rt <- ps[ps$node == 1, ]
  br <- sapply(inc$node, function(nd) { if (nd == 1) return("root"); top <- nd; while (top > 3) top <- top %/% 2
    if (rt$var != "OverTime") return("other")
    if ((top == 2) == grepl("{No}", rt$left, fixed = TRUE)) "ot_no" else "ot_yes" })
  c(any = TRUE, root = any(br == "root"), nodes123 = any(inc$node <= 3), in_ot_yes = any(br == "ot_yes"),
    in_ot_no = any(br == "ot_no"), other = any(br == "other")) }))
income_location <- list(anywhere = mean(inc_loc[, "any"]), nodes_1_3 = mean(inc_loc[, "nodes123"]), root = mean(inc_loc[, "root"]),
  in_ot_yes_branch = mean(inc_loc[, "in_ot_yes"]), in_ot_no_branch = mean(inc_loc[, "in_ot_no"]), under_other_root = mean(inc_loc[, "other"]),
  only_inside_ot_yes_branch = mean(inc_loc[, "in_ot_yes"] & !inc_loc[, "root"] & !inc_loc[, "in_ot_no"] & !inc_loc[, "other"]),
  company_wide_root_or_both_ot_branches = mean(inc_loc[, "root"] | (inc_loc[, "in_ot_yes"] & inc_loc[, "in_ot_no"])))
root_inc_cuts <- boot_cuts$cut[boot_cuts$var == "MonthlyIncome" & boot_cuts$node == 1]
root_cut_q <- quantile(root_inc_cuts, c(.1, .25, .5, .75, .9))
all_inc_q <- quantile(boot_cuts$cut[boot_cuts$var == "MonthlyIncome"], c(.25, .5, .75))
# the not-cleared groups named on the exec page, vs overtime OR lower-paid (F5)
exec_notcleared <- c(sol0 = "people with no stock options", yac_lt2 = "short tenure (under 2 years at the company)",
                     mgr_new = "a new manager (under 1 year)", travel_freq = "frequent business travel", envsat1 = "low environment satisfaction")
ctx_u <- memb[, "ot_yes"] | memb[, "inc_boot"]
near_ctx <- do.call(rbind, lapply(setdiff(cand$id[cand$status == "passes size and lift, not stable as a split" & !grepl("^(tree_node|fulltree_node)", cand$id)], c()), function(a)
  data.frame(group = a, n = sum(memb[, a]), leavers = sum(memb[, a] & y), in_overtime = sum(memb[, a] & memb[, "ot_yes"]),
             in_lowpaid = sum(memb[, a] & memb[, "inc_boot"]), in_either = sum(memb[, a] & ctx_u),
             pct_in_either = 100 * mean(ctx_u[memb[, a]]), on_exec_page = a %in% names(exec_notcleared))))
U_ctx <- union_stats(c("ot_yes", "inc_boot"))
OT <- cand[cand$id == "ot_yes", ]; LP <- cand[cand$id == "inc_boot", ]
stopifnot(identical(chosen, "ot_yes"))         # Quinn's ruling: one cleared pattern
after_rate <- avg - OT$impact_pp_to_avg / 100
r_no_ot <- cand$full_rate[cand$id == "ot_no"]
lp_jl1 <- sum(memb[, "inc_boot"] & jl1v)

# ------------------------------------------------------------------ write data outputs
top2_share <- sort(table(unlist(boot_top2)) / B, decreasing = TRUE)
write.csv(cand, file.path(out, "candidates.csv"), row.names = FALSE)
if (!is.null(ov)) write.csv(ov, file.path(out, "overlap.csv"), row.names = FALSE)
write.csv(near_ctx, file.path(out, "overlap_nonsurvivors.csv"), row.names = FALSE)
write.csv(sens_tab, file.path(out, "threshold_sensitivity.csv"), row.names = FALSE)
write.csv(bands, file.path(out, "pay_bands.csv"), row.names = FALSE)
res <- list(n = N, leavers = L, company_rate = avg, test_n = nrow(te), test_leavers = sum(yte), test_overall_rate = test_avg,
  train_n = nrow(tr), seed = SEED, minbucket_train = mb_tr, minbucket_full = mb_full,
  tree_train = list(pruned_cp = p_tr$cp, nsplit = p_tr$nsplit, primary_splits = ps_tr, cptable = as.data.frame(g_tr$cptable)),
  tree_class_for_record = list(train_nsplit_1se = p_tr_cls$nsplit, full_nsplit_1se = p_full_cls$nsplit,
    train_cptable = as.data.frame(g_tr_cls$cptable), full_cptable = as.data.frame(g_full_cls$cptable)),
  tree_method = METHOD,
  tree_full = list(pruned_cp = p_full$cp, nsplit = p_full$nsplit, primary_splits = ps_full, cptable = as.data.frame(g_full$cptable)),
  bootstrap = list(B = B, root_share = as.list(round(root_tab, 3)), var_primary_share_anywhere = as.list(round(var_freq, 3)),
                   var_primary_share_nodes_1_3 = as.list(round(top2_share, 3)),
                   n_split_vars_per_refit = as.list(nsplit_tab), cutpoints = cut_summ,
                   income_location = income_location, root_income_cut_quantiles = as.list(root_cut_q), n_root_income_cuts = length(root_inc_cuts)),
  headline = chosen, union_headline = U_head, union_overtime_or_lowpaid_context = U_ctx,
  overtime = list(after_rate = after_rate, rate_no_overtime = r_no_ot),
  lowpaid_context = list(cut = PB, n = LP$n, joblevel1 = lp_jl1, pct_joblevel1 = 100 * lp_jl1 / LP$n,
                         median_age = median(d$Age[lowp]), median_age_others = median(d$Age[!lowp]),
                         bands_3000_4000_rate_range = range(band_range$rate), bands_3000_4000_rate_above_range = range(band_range$rate_above),
                         train_only = train_lowpay),
  pay_x_overtime = pay_ot, excess_leavers_by_cell = as.list(excess), joblevel1_x_pay = jl1_pay,
  pass_rules_1_to_3 = sens_nostab, n_pass_rules_1_to_3 = length(sens_nostab), sensitivity = sens_tab)
write_json(res, file.path(out, "exec_results.json"), auto_unbox = TRUE, pretty = TRUE, digits = 6, dataframe = "rows")

# ------------------------------------------------------------------ figure: overtime split only (F-optional)
if (requireNamespace("rpart.plot", quietly = TRUE) && nrow(fit_full$frame) > 1) {
  fit_ot <- snip.rpart(fit_full, toss = 3)          # keep only the overtime split
  stopifnot(as.character(fit_ot$frame$var[1]) == "OverTime", nrow(fit_ot$frame) == 3)
  ids <- as.integer(rownames(fit_ot$frame))
  ot_node <- if (grepl("{No}", ps_full$left[ps_full$node == 1], fixed = TRUE)) 3L else 2L
  cols <- ifelse(ids == ot_node, "#D55E00", "grey88")
  ttl <- sprintf("Fictional IBM data: overtime workers left %.0f%% of the time vs %.0f%% without overtime", 100 * OT$full_rate, 100 * r_no_ot)
  png(file.path(out, "exec_tree.png"), width = 2000, height = 1100, res = 220)
  rpart.plot::rpart.plot(fit_ot, roundint = FALSE, type = 2, extra = 0, under = FALSE,
    node.fun = function(x, labs, digits, varlen) paste0(round(100 * x$frame$yval), "% left\n", format(x$frame$n, big.mark = ","), " people"),
    split.fun = function(x, labs, digits, varlen, faclen) gsub("OverTime = No", "No overtime", labs, fixed = TRUE),
    box.col = cols, shadow.col = 0, branch.col = "grey50", split.col = "grey20", faclen = 0, varlen = 0, cex = 1,
    main = ttl, sub = "All 1,470 fictional employees. Orange = the one group cleared for executives.")
  dev.off()
}

# ------------------------------------------------------------------ logistic benchmark (context for the appendix caveat)
suppressPackageStartupMessages(library(pROC))
gl <- suppressWarnings(glm(Attrition ~ ., data = tr, family = binomial))
auc_log <- as.numeric(auc(roc(te$Attrition, predict(gl, te, type = "response"), levels = c("No","Yes"), direction = "<", quiet = TRUE)))
auc_ot  <- as.numeric(auc(roc(te$Attrition, as.numeric(te$OverTime == "Yes"), levels = c("No","Yes"), direction = "<", quiet = TRUE)))

# ------------------------------------------------------------------ generated markdown (every number below is computed above)
P0 <- function(x) sprintf("%.0f%%", 100 * x); P1 <- function(x) sprintf("%.1f%%", 100 * x)
F1n <- function(x) sprintf("%.1f", x); F2n <- function(x) sprintf("%.2f", x); CM <- function(x) format(round(x), big.mark = ",")
cutfmt <- function(x) paste0("$", format(x, big.mark = ",", nsmall = 0, scientific = FALSE))
g <- function(id) cand[cand$id == id, ]
il <- income_location
small_rows <- cand[grepl("^too small", cand$status), ]
# ---- executive page
ot_pay_small <- g("ot_inc2475"); tn7 <- g("tree_node_7")
small_tab <- c("| Group | Employees | Share of staff | Share of all leavers |", "|---|---|---|---|",
sprintf("| Overtime and the lowest pay (under about $2,500 to $2,800 a month, depending on where the line is drawn) | %d–%d | %s–%s | %s–%s |",
  ot_pay_small$n, tn7$n, P1(ot_pay_small$n / N), P1(tn7$n / N), P0(ot_pay_small$leavers / L), P0(tn7$leavers / L)))
for (id in c("role_salesrep", "jobinv1", "wlb1")) { z <- g(id)
  lab <- c(role_salesrep = "Sales representatives", jobinv1 = "Lowest job involvement", wlb1 = "Lowest work-life balance")[id]
  small_tab <- c(small_tab, sprintf("| %s | %d | %s | %s |", lab, z$n, P1(z$n / N), P0(z$leavers / L))) }
ex <- c(
"# Who leaves most: overtime workers (IBM's fictional HR teaching data, not real employees)", "",
"*QA-cleared by Quinn, Oct 9, 2026.* Every number on this page is computed by `run_exec.R`; detail is in `technical_appendix.md`.", "",
"## Executive summary",
sprintf("In IBM's fictional dataset of %s employees, %s left. One large group clears every check: **overtime workers**. They are %s of staff but %s of everyone who left. Lower pay and early career also go with leaving, but they are shown below as context, not as a separate pattern. Nothing here shows what causes people to leave.",
  CM(N), P0(avg), P0(OT$n / N), P0(OT$leavers / L)), "",
"## What",
sprintf("Overtime workers (%s people, %s of staff) left at %s, about %s times the rate of staff without overtime (%s). They account for %s of everyone who left.",
  CM(OT$n), P0(OT$n / N), P0(OT$full_rate), c("one","two","three","four")[round(OT$full_rate / r_no_ot)], P0(r_no_ot), P0(OT$leavers / L)), "",
"## So What",
sprintf("Overtime is the clearest place to look first. As an illustration, not a forecast: if overtime workers left at the company average, overall attrition would fall from about %s to about %s, roughly %s fewer leavers.",
  P0(avg), P0(after_rate), round(OT$impact_people_to_avg, -1)), "",
"## Not What",
"This does not show that overtime causes leaving; overtime may mark busy or understaffed roles. Fictional teaching data, not a real workforce. Not a basis for decisions about individuals.", "",
"## Context: pay and career stage",
sprintf("Lower-paid staff (roughly the bottom third of earners, under about $3,000-$4,000 a month) leave more often, about %s vs %s for everyone else, wherever the pay line is drawn in that range. But %s of them are in the most junior job level, so this is one picture of pay and career stage together, and the data cannot say which matters. Most of their extra leaving is among those who also work overtime: lower-paid staff without overtime leave at about the company average (%s), against %s for better-paid staff without overtime. Not a separately cleared pattern.",
  P0(LP$full_rate), P0(LP$rate_outside), P0(lp_jl1 / LP$n), P0(pay_ot$full$noot_low$rate), P0(pay_ot$full$noot_high$rate)), "",
"## Left out because too small to act on",
"Several smaller groups, each under 100 people, are left out as too small to act on; see the appendix.")
ex <- c(ex, "",
"## Large, but not cleared",
sprintf("Some other groups are large and leave more often: %s. But these did not hold up consistently when we re-ran the analysis on reshuffled versions of the data. Several of them overlap with overtime workers or lower-paid, junior staff (for some, about half or more); frequent travel and low environment satisfaction are largely different people. Groups defined by age or marital status are not used for decisions about individuals.",
  paste(exec_notcleared, collapse = "; ")), "",
"## Caveats",
"- **Fictional data.** IBM made this dataset for teaching. The people in it are simulated, so it describes no real workforce.",
"- **Nothing here is causal.** The groups describe who left more, not why.",
"- **Pay goes with job level.** Lower pay and junior job level overlap heavily and can't be cleanly separated.",
"- **Not for decisions about individuals.** Age, gender and marital status are descriptive only and must not be used for decisions about individuals.",
"- **Snapshot timing.** Tenure and survey answers were recorded at the same time as whether people left, so they may not come before leaving.")
writeLines(ex, file.path(out, "exec_findings_draft.md"))

# ---- appendix tables (full detail)
md <- c("# Appendix tables (generated by run_exec.R; do not edit by hand)", "",
  sprintf("Company: %d employees, %d leavers, rate %s. Test set: %d employees, %d leavers, rate %s.", N, L, P1(avg), nrow(te), sum(yte), P1(test_avg)), "",
  "## All candidates (full data unless marked test)", "",
  "R1 size, R2 lift ≥ 1.5, R3 test direction with test n ≥ 30, R4 stability at nodes 1–3 > 50%. The Wilson column is an appendix check, not a pass condition.", "",
  "| id | definition | n | % emp | leavers | % leavers | rate | lift | Wilson 95% | Wilson lo > 16.12% (check) | test n | test rate [Wilson] | test overall | R4 nodes 1–3 | (old: anywhere) | impact to avg pts (people) | impact to outside rate pts (people) | R1 | R2 | R3 | R4 | status |",
  "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
for (i in seq_len(nrow(cand))) { z <- cand[i, ]
  md <- c(md, sprintf("| %s | %s | %d | %s | %d | %s | %s | %s | %s–%s | %s | %d | %s [%s–%s] | %s | %s | %s | %s (%s) | %s (%s) | %s | %s | %s | %s | %s |",
    z$id, z$definition, z$n, F1n(z$pct_employees), z$leavers, F1n(z$pct_all_leavers), P1(z$rate), F2n(z$lift),
    P1(z$wilson_lo), P1(z$wilson_hi), ifelse(z$wilson_lo_above_avg_check, "yes", "no"), z$test_n, P1(z$test_rate), P1(z$test_wilson_lo), P1(z$test_wilson_hi), P1(z$test_overall_rate),
    P1(z$stability_share), P1(z$stability_anywhere_old_reading), F2n(z$impact_pp_to_avg), F1n(z$impact_people_to_avg),
    F2n(z$impact_pp_to_outside), F1n(z$impact_people_to_outside),
    ifelse(z$pass_r1_size, "✓", "✗"), ifelse(z$pass_r2_rate, "✓", "✗"), ifelse(z$pass_r3_test, "✓", "✗"), ifelse(z$pass_r4_stability, "✓", "✗"), z$status)) }
md <- c(md, "", "## Bootstrap: primary-split shares by variable (500 refits on full data)", "",
  "| variable | nodes 1–3 (rule 4) | anywhere | root |", "|---|---|---|---|")
for (v in names(var_freq)) md <- c(md, sprintf("| %s | %s | %s | %s |", v,
  P1(ifelse(is.na(top2_share[v]), 0, top2_share[v])), P1(var_freq[[v]]), P1(ifelse(is.na(root_tab[v]), 0, root_tab[v]))))
md <- c(md, sprintf("| (pruned to root) | | | %s |", P1(ifelse(is.na(root_tab["<none: pruned to root>"]), 0, root_tab["<none: pruned to root>"]))))
md <- c(md, "", "Cutpoints of primary splits across refits (all nodes):", "", "| variable | splits | 25% | median | 75% |", "|---|---|---|---|---|")
for (i in seq_len(nrow(cut_summ))) md <- c(md, sprintf("| %s | %d | %s | %s | %s |", cut_summ$var[i], cut_summ$n_cuts[i], cut_summ$q25[i], cut_summ$median[i], cut_summ$q75[i]))
md <- c(md, "", "## Threshold sensitivity", "", "| variant | min n | min lift | groups passing | which |", "|---|---|---|---|---|")
for (i in seq_len(nrow(sens_tab))) md <- c(md, sprintf("| %s | %d | %s | %d | %s |", sens_tab$variant[i], sens_tab$min_n[i], sens_tab$min_lift[i], sens_tab$n_pass[i], sens_tab$passing[i]))
md <- c(md, "", "## Not-cleared groups vs overtime and lower-paid (full data)", "",
  "| group | n | leavers | in overtime | in lower-paid (< $3,500) | in either | % in either | named on exec page |", "|---|---|---|---|---|---|---|---|")
for (i in seq_len(nrow(near_ctx))) { z <- near_ctx[i, ]
  md <- c(md, sprintf("| %s | %d | %d | %d | %d | %d | %s | %s |", z$group, z$n, z$leavers, z$in_overtime, z$in_lowpaid, z$in_either, F1n(z$pct_in_either), ifelse(z$on_exec_page, "yes", ""))) }
writeLines(md, file.path(out, "appendix_tables.md"))

# ---- technical appendix
cpt <- function(ct) c("| CP | nsplit | rel error | xerror | xstd |", "|---|---|---|---|---|",
  apply(ct, 1, function(r) sprintf("| %.4f | %d | %.4f | %.4f | %.4f |", r["CP"], as.integer(r["nsplit"]), r["rel error"], r["xerror"], r["xstd"])))
po <- pay_ot; jp <- jl1_pay
cellf <- function(c0) sprintf("%s (%d/%d)", P1(c0$rate), c0$leavers, c0$n)
ta <- c(
"# Technical appendix: executive rework (IBM HR attrition, fictional data)", "",
"> *QA-cleared by Quinn, Oct 9, 2026.* Generated by `Rscript analysis/exec/run_exec.R` (run from the project root; seed 20261008; deterministic). Every number here is computed by the script. Full tables: `appendix_tables.md`.", "",
"## 1. Rule set (parameters in `thresholds.json`)",
"All rules are counted on the full 1,470 rows.",
sprintf("1. **Size:** n ≥ %d and leavers ≥ %d.", TH$rule1_size$min_n, TH$rule1_size$min_leavers),
sprintf("2. **Rate:** lift ≥ %s, where lift is the group rate divided by the company rate (%d/%d = %s).", TH$rule2_rate$min_lift, L, N, P1(avg)),
sprintf("3. **Test:** at least %d employees in the held-out test set, with a group test rate above the test-set overall rate (%s, %d/%d).", TH$rule3_test$min_test_n, P1(test_avg), sum(yte), nrow(te)),
paste0("4. **", TH$rule4_stability$wording, "**"), "",
"- **Wilson interval: an appendix check, not a pass condition.** The lower end of the 95% Wilson interval is compared with 16.12% and reported in `candidates.csv` (`wilson_lo_above_avg_check`). " ,
sprintf("  Adding it as a pass condition would change no verdict (%d groups pass either way).", sens_tab$n_pass[sens_tab$variant == "Wilson lower bound > 16.12% added as a pass condition"]),
"- **Impact (cleared groups only on the executive page):** (group leavers − n × 0.1612) / 1,470, in points and people, labelled as an illustration, not a forecast. The version using the rate of everyone outside the group is appendix-only (§7). Impacts are never summed across groups.",
"- **Too small to act on:** any group under 100 employees that passes the rate rule is labelled 'too small to act on' in `candidates.csv`, with its other failures listed.",
"- **Headline selection:** passing groups ordered by impact; groups defined by Age, Gender or MaritalStatus excluded; tree nodes identical to a simple group collapsed into it; cap 4.", "",
sprintf("**Result: one cleared pattern, OverTime = Yes** (identical to the overtime node of both trees). Rule-4 shares: OverTime %s, MonthlyIncome %s.",
  P1(top2_share[["OverTime"]]), P1(top2_share[["MonthlyIncome"]])),
"Compared with the earlier reading (primary split anywhere), only the four income groups change status (`inc_boot`, `inc_lt2500`, `inc_lt3000`, `inc_lt4000` → 'passes size and lift, not stable as a split'); no other candidate changes on any rule.", "",
"## 2. Data, predictors, split",
sprintf("Same 27 predictors as `analysis/METHOD.md` (EmployeeNumber, EmployeeCount, Over18, StandardHours, DailyRate, HourlyRate, MonthlyRate excluded). Same stratified 70/30 split, seed %d: %d training rows, %d test rows.", SEED, nrow(tr), nrow(te)), "",
"## 3. Tree settings",
sprintf("- maxdepth 3; minbucket %d on full data and %d on training data (100 × %d/%d, rounded up); minsplit 2 × minbucket; grown at cp 0.001; 10-fold CV (seed %d); 1-SE pruning. No tuning.", mb_full, mb_tr, nrow(tr), N, SEED),
sprintf("- **Criterion, disclosed:** the misclassification tree (`method = \"class\"`) was run first and its 1-SE rule pruned to the root (%d splits on training data, %d on full data), because no leaf of 70+ rows has a majority of leavers. The rate tree (`method = \"anova\"` on 0/1 attrition, Gini-equivalent split, Brier CV risk) was adopted after that. Both cp tables are in `exec_tree_rules.txt`.", p_tr_cls$nsplit, p_full_cls$nsplit),
sprintf("- Training tree: 1-SE pruned to cp %.4f (%d splits): OverTime, then %s within overtime.", p_tr$cp, p_tr$nsplit, ps_tr$left[ps_tr$node != 1]), "", cpt(g_tr$cptable), "",
sprintf("- Full-data tree: 1-SE pruned to cp %.4f (%d splits): OverTime, then %s within overtime.", p_full$cp, p_full$nsplit, ps_full$left[ps_full$node != 1]), "", cpt(g_full$cptable), "",
"`exec_tree.png` shows only the overtime split (the full-data tree's income branch is not validated) and is not embedded in the executive page.", "",
"## 4. Candidates",
sprintf("- %d candidates (`candidates.csv`): every non-root node of both trees; simple single-variable groups; income below the bootstrap-median cut (%s, rounded to %s) and fixed bands; combinations; the earlier v0.3 headline (overtime and under $2,475).", nrow(cand), cutfmt(bcut("MonthlyIncome")), cutfmt(INC_CUT)),
sprintf("- **Multiple comparisons, disclosed:** the 43 candidates were chosen with knowledge of the earlier analysis, and %d pass rules 1–3. The stability rule is therefore the main guard against multiple comparisons.", length(sens_nostab)),
sprintf("- **Test checks are not independent for data-driven cuts and full-tree nodes:** the cuts for `inc_boot`, `twy_boot`, `age_boot` and the full-data tree nodes were chosen on all 1,470 rows, which include the test rows. For lower pay this is mitigated: on training rows alone, under %s left at %s (n %d) vs %s for the rest.",
  cutfmt(PB), P1(train_lowpay$rate), train_lowpay$n, P1(train_lowpay$rate_rest)), "",
"### The cleared group",
sprintf("| OverTime = Yes | n %d (%s of staff) | %d leavers (%s of leavers) | rate %s, lift %s | Wilson %s–%s (check: %s) | test %d/%d = %s vs test overall %s | rule 4: %s (anywhere %s) |",
  OT$n, P1(OT$n / N), OT$leavers, P1(OT$leavers / L), P1(OT$full_rate), F2n(OT$lift), P1(OT$wilson_lo), P1(OT$wilson_hi), ifelse(OT$wilson_lo_above_avg_check, "above 16.12%", "not above"),
  OT$test_leavers, OT$test_n, P1(OT$test_rate), P1(test_avg), P1(OT$stability_share), P1(OT$stability_anywhere_old_reading)), "",
sprintf("No overtime: %s (%d/%d). Overtime rate is %.2f times the no-overtime rate. Single-variable overtime test AUC %.3f (context only).", P1(r_no_ot), g("ot_no")$leavers, g("ot_no")$n, OT$full_rate / r_no_ot, auc_ot), "",
"### Status of the other candidates",
paste0("- **Passes size and lift, not stable as a split:** ", paste(sprintf("%s (n %d, rule-4 share %s)", cand$id[cand$status == "passes size and lift, not stable as a split"], cand$n[cand$status == "passes size and lift, not stable as a split"], P1(cand$stability_share[cand$status == "passes size and lift, not stable as a split"])), collapse = "; "), "."),
paste0("- **Too small to act on:** ", paste(sprintf("%s (n %d, %s of staff, %s of leavers; %s)", small_rows$id, small_rows$n, P1(small_rows$n / N), P1(small_rows$leavers / L), sub("^too small to act on \\(under 100 employees; ", "", sub("\\)$", "", small_rows$status))), collapse = "; "), "."),
paste0("- **Fails the rate rule:** ", paste(sprintf("%s (lift %s)", cand$id[!cand$pass_r2_rate], F2n(cand$lift[!cand$pass_r2_rate])), collapse = "; "), "."), "",
"### Too small to act on: summary table (moved here from the executive page)",
"These groups have high leaving rates but fewer than 100 employees.", "", small_tab, "",
"## 5. Stability detail",
"- **Stability is measured per variable, not per group.** Rule 4 asks whether each defining variable is a primary split at nodes 1–3, at any cutpoint. Every income band therefore gets the same share.",
sprintf("- **Where MonthlyIncome splits sit across the 500 refits:** at the root or nodes 1–3: %s (rule 4); at the root: %s; company-wide (the root, or inside both overtime branches): %s; inside the overtime = Yes branch: %s; only inside the overtime = Yes branch: %s; inside the no-overtime branch: %s; anywhere in the tree (old reading): %s.",
  P1(il$nodes_1_3), P1(il$root), P1(il$company_wide_root_or_both_ot_branches), P1(il$in_ot_yes_branch), P1(il$only_inside_ot_yes_branch), P1(il$in_ot_no_branch), P1(il$anywhere)),
sprintf("- **Income cutpoints:** across all %d income splits the median is %s (IQR %s–%s), dominated by splits inside the overtime branch. Company-wide (root) income splits (%d refits) have median %s (middle half %s–%s).",
  sum(boot_cuts$var == "MonthlyIncome"), cutfmt(all_inc_q[2]), cutfmt(all_inc_q[1]), cutfmt(all_inc_q[3]), length(root_inc_cuts), cutfmt(root_cut_q[["50%"]]), cutfmt(round(root_cut_q[["25%"]])), cutfmt(round(root_cut_q[["75%"]]))),
"- **Stability shares are somewhat optimistic:** a bootstrap resample contains duplicate rows, which can fall in both the training and validation folds of the internal 10-fold CV, so pruning keeps more splits than it would on fresh data.",
sprintf("- Root variable: %s.", paste(sprintf("%s %s", names(root_tab), P1(root_tab)), collapse = "; ")), "",
"## 6. Pay and career stage (context item; no impact figure)",
sprintf("Fixed pay bands (full data; the context numbers use %s, a round cut in the middle of the stable range):", cutfmt(PB)), "",
"| cut | n | % staff | rate below | rate at or above | lift | % JobLevel 1 | train below / above | test n | test below / above |", "|---|---|---|---|---|---|---|---|---|---|",
apply(bands, 1, function(r) sprintf("| %s | %d | %s | %s | %s | %s | %s | %s / %s | %d | %s / %s |", cutfmt(r["cut"]), as.integer(r["n"]), F1n(r["pct_employees"]), P1(r["rate"]), P1(r["rate_above"]), F2n(r["lift"]),
  F1n(r["pct_joblevel1"]), P1(r["train_rate"]), P1(r["train_rate_above"]), as.integer(r["test_n"]), P1(r["test_rate"]), P1(r["test_rate_above"]))), "",
sprintf("Across cuts of $3,000–$4,000 the rate below the line is %s–%s and above it %s–%s.", P1(min(band_range$rate)), P1(max(band_range$rate)), P1(min(band_range$rate_above)), P1(max(band_range$rate_above))), "",
sprintf("**Pay × overtime (pay cut %s):**", cutfmt(PB)), "",
"| | full: lower-paid | full: better-paid | train: lower / better | test: lower / better |", "|---|---|---|---|---|",
sprintf("| Overtime | %s | %s | %s / %s | %s / %s |", cellf(po$full$ot_low), cellf(po$full$ot_high), P1(po$train$ot_low$rate), P1(po$train$ot_high$rate), P1(po$test$ot_low$rate), P1(po$test$ot_high$rate)),
sprintf("| No overtime | %s | %s | %s / %s | %s / %s |", cellf(po$full$noot_low), cellf(po$full$noot_high), P1(po$train$noot_low$rate), P1(po$train$noot_high$rate), P1(po$test$noot_low$rate), P1(po$test$noot_high$rate)), "",
sprintf("Excess leavers over 0.1612: overtime & lower-paid %s; overtime & better-paid %s; no overtime & lower-paid %s; no overtime & better-paid %s. Of the lower-paid group's %s excess leavers, %s are overtime workers.",
  F1n(excess[["ot_low"]]), F1n(excess[["ot_high"]]), F1n(excess[["noot_low"]]), F1n(excess[["noot_high"]]), F1n(LP$impact_people_to_avg), F1n(excess[["ot_low"]])), "",
sprintf("**JobLevel 1 × pay (cut %s):** %d of %d lower-paid staff (%s) are JobLevel 1; median age %s vs %s for everyone else.", cutfmt(PB), lp_jl1, LP$n, P1(lp_jl1 / LP$n), median(d$Age[lowp]), median(d$Age[!lowp])), "",
"| | lower-paid | better-paid |", "|---|---|---|",
sprintf("| JobLevel 1 | %s | %s |", cellf(jp$full$jl1_low), cellf(jp$full$jl1_high)),
sprintf("| JobLevel 2+ | %s | %s |", cellf(jp$full$notjl1_low), cellf(jp$full$notjl1_high)),
sprintf("| JobLevel 1, test set | %s | %s |", cellf(jp$test$jl1_low), cellf(jp$test$jl1_high)), "",
"Pay and career stage cannot be separated; no causal claim.", "",
"## 7. Impact (illustrations, not forecasts)",
sprintf("- **Overtime, to the company average (executive page):** %s points (%s people); overall attrition would go from %s to %s.", F2n(OT$impact_pp_to_avg), F1n(OT$impact_people_to_avg), P1(avg), P1(after_rate)),
sprintf("- **Overtime, to the rate of everyone outside the group (appendix only):** %s points (%s people); outside rate %s.", F2n(OT$impact_pp_to_outside), F1n(OT$impact_people_to_outside), P1(OT$rate_outside)),
sprintf("- Lower-paid has no impact figure (context only). For the record, overtime ∪ lower-paid covers %d employees (%s) and %d leavers (%s of all leavers); bringing that union to the average gives %s people, almost the same as overtime alone, because the lower-paid excess sits almost entirely inside overtime (§6).",
  U_ctx$n, P1(U_ctx$pct_employees / 100), U_ctx$leavers, P1(U_ctx$pct_all_leavers / 100), F1n(U_ctx$impact_people_to_avg)), "",
"## 8. Overlap of the not-cleared groups (F5)",
"Share of each group's employees who are overtime workers or lower-paid (< $3,500); groups named on the executive page are marked.", "",
"| group | n | in overtime | in lower-paid | in either | % in either |", "|---|---|---|---|---|---|",
apply(near_ctx[near_ctx$on_exec_page, ], 1, function(r) sprintf("| %s | %s | %s | %s | %s | %s |", r["group"], trimws(r["n"]), trimws(r["in_overtime"]), trimws(r["in_lowpaid"]), trimws(r["in_either"]), F1n(as.numeric(r["pct_in_either"])))), "",
sprintf("Frequent travel (%s) and low environment satisfaction (%s) are largely different people. No stock options is at %s, the lowest of the three groups the executive page describes as overlapping (no stock options, short tenure, new manager); hence 'for some, about half or more'. The full table, including all near misses, is in `appendix_tables.md` and `overlap_nonsurvivors.csv`.",
  P1(near_ctx$pct_in_either[near_ctx$group == "travel_freq"] / 100), P1(near_ctx$pct_in_either[near_ctx$group == "envsat1"] / 100), P1(near_ctx$pct_in_either[near_ctx$group == "sol0"] / 100)), "",
"## 9. Threshold sensitivity",
paste0("- ", sprintf("%s, min n %d, min lift %s: %d pass (%s)", sens_tab$variant, sens_tab$min_n, sens_tab$min_lift, sens_tab$n_pass, sens_tab$passing)),
"- The three passing ids are one group (OverTime = Yes and its two identical tree nodes). Lowering the size floor to 74 (or 59, 44) changes nothing: every 74–99 group also fails test n and/or stability.", "",
"## 10. Caveats",
"- **Fictional data.** IBM's fictional teaching dataset; it describes no real workforce.",
"- **Observational, no causal claims.** Groups describe who left more, not why.",
sprintf("- **Pay goes with job level.** %s of lower-paid staff are JobLevel 1; pay cannot be separated from career stage.", P1(lp_jl1 / LP$n)),
"- **Not for decisions about individuals.** Age, gender and marital status are descriptive only.",
"- **Snapshot timing.** Tenure and survey fields are measured at the same snapshot as the outcome.",
sprintf("- **A shallow tree is a coarse description.** A logistic regression on the same 27 predictors and the same split reaches test AUC %.3f (computed here; `analysis/qa_log.md` reports 0.863 for the same model), against %.3f for overtime alone. The groups capture only part of what separates leavers.", auc_log, auc_ot),
"- **Impact figures are arithmetic illustrations, not forecasts.**", "",
"## 11. Files",
"`run_exec.R` (script) · `thresholds.json` · `candidates.csv` · `appendix_tables.md` · `exec_results.json` · `exec_tree_rules.txt` · `overlap.csv` · `overlap_nonsurvivors.csv` · `threshold_sensitivity.csv` · `pay_bands.csv` · `exec_tree.png` (overtime split only) · `exec_findings_draft.md` · `technical_appendix.md`.")
writeLines(ta, file.path(out, "technical_appendix.md"))
cat("done\n")
