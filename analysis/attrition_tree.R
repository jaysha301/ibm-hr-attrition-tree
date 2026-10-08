# IBM HR Attrition: JMP-style classification tree (rpart). Run from project root:
#   Rscript analysis/attrition_tree.R
.libPaths(c("~/R/library", .libPaths()))
suppressPackageStartupMessages({library(rpart); library(pROC); library(jsonlite)})
SEED <- 20261008
dat_path <- "data/WA_Fn-UseC_-HR-Employee-Attrition.csv"
d <- read.csv(dat_path, fileEncoding = "UTF-8-BOM", stringsAsFactors = TRUE)
stopifnot(nrow(d) == 1470, ncol(d) == 35,
          all(c("Attrition","Age","OverTime","MonthlyIncome","JobRole","YearsAtCompany") %in% names(d)))

# ---- exclusions ----
id_const <- c("EmployeeNumber","EmployeeCount","Over18","StandardHours")
not_pay  <- c("DailyRate","HourlyRate","MonthlyRate")   # Ellis: not interpretable as pay
const_check <- sapply(d[c("EmployeeCount","Over18","StandardHours")], function(x) length(unique(x)))
d <- d[, setdiff(names(d), c(id_const, not_pay))]
d$Attrition <- factor(d$Attrition, levels = c("No","Yes"))
predictors <- setdiff(names(d), "Attrition")

# ---- stratified 70/30 split ----
set.seed(SEED)
idx_tr <- unlist(lapply(split(seq_len(nrow(d)), d$Attrition),
                        function(ix) sample(ix, round(0.7 * length(ix)))))
tr <- d[sort(idx_tr), ]; te <- d[-idx_tr, ]

# ---- pre-specified tree setting (not tuned) ----
ctrl <- rpart.control(cp = 0.01, minsplit = 20, minbucket = 7, maxdepth = 5, xval = 10)
fml <- Attrition ~ .
set.seed(SEED)
fit <- rpart(fml, data = tr, method = "class", parms = list(split = "gini"), control = ctrl)

# cp table from a fuller tree (cp=0.001) for reference only
set.seed(SEED)
fit_full <- rpart(fml, data = tr, method = "class",
                  control = rpart.control(cp = 0.001, minsplit = 20, minbucket = 7, maxdepth = 30, xval = 10))

sink("analysis/tree_rules.txt")
cat("IBM HR Attrition - classification tree (rpart, method='class', gini)\n")
cat("Training set n =", nrow(tr), "; settings: cp=0.01, minsplit=20, minbucket=7, maxdepth=5, no priors/weights\n")
cat("Excluded: ", paste(c(id_const, not_pay), collapse = ", "), "\n")
cat("Node line format: node) split n loss yval (P(No) P(Yes)); * = leaf\n\n")
print(fit)
cat("\n\ncp table for the displayed tree (10-fold xval on training set):\n"); printcp(fit)
cat("\n\ncp table for a fuller reference tree (cp=0.001, maxdepth=30), NOT used for interpretation:\n"); printcp(fit_full)
sink()

# ---- helpers: node membership & split description ----
node_ids <- as.integer(rownames(fit$frame))
leaf_node_tr <- node_ids[fit$where]
in_node <- function(leaf, n) { a <- leaf; res <- a == n
  while (any(a > n)) { a <- a %/% 2; res <- res | a == n }; res }
rate <- function(y) mean(y == "Yes")
# primary split per internal node
fr <- fit$frame; spl <- fit$splits
srow <- 1; prim <- list()
for (i in seq_len(nrow(fr))) {
  if (fr$var[i] == "<leaf>") next
  s <- spl[srow, , drop = FALSE]; v <- as.character(fr$var[i])
  if (s[1, "ncat"] < 0 || s[1, "ncat"] == 1) {
    cut <- s[1, "index"]
    left_rule <- if (s[1, "ncat"] < 0) paste0(v, " < ", cut) else paste0(v, " >= ", cut)
  } else {
    lv <- levels(d[[v]]); codes <- fit$csplit[s[1, "index"], seq_along(lv)]
    left_rule <- paste0(v, " in {", paste(lv[codes == 1], collapse = ", "), "}")
  }
  prim[[as.character(node_ids[i])]] <- list(var = v, left_rule = left_rule, improve = unname(s[1, "improve"]))
  srow <- srow + 1 + fr$ncompete[i] + fr$nsurrogate[i]
}
depth_of <- function(n) floor(log2(n))
# route test rows through the primary splits (no missing values in this data)
goes_left <- function(row, k) { p <- prim[[k]]; x <- row[[p$var]]
  r <- p$left_rule
  if (grepl(" < ", r, fixed = TRUE)) return(as.numeric(x) < as.numeric(sub(".* < ", "", r)))
  if (grepl(" >= ", r, fixed = TRUE)) return(as.numeric(x) >= as.numeric(sub(".* >= ", "", r)))
  lv <- strsplit(sub("^.*\\{(.*)\\}$", "\\1", r), ", ", fixed = TRUE)[[1]]
  as.character(x) %in% lv }
route <- function(df) sapply(seq_len(nrow(df)), function(j) { n <- 1L
  while (as.character(n) %in% names(prim)) n <- if (goes_left(df[j, ], as.character(n))) 2L*n else 2L*n + 1L
  n })
leaf_node_te <- route(te)
stopifnot(all(route(tr) == leaf_node_tr))   # routing reproduces rpart's own training assignment
split_tab <- do.call(rbind, lapply(names(prim), function(k) {
  n <- as.integer(k); p <- prim[[k]]
  mtr <- in_node(leaf_node_tr, n); mte <- in_node(leaf_node_te, n)
  ltr <- in_node(leaf_node_tr, 2*n); rtr <- in_node(leaf_node_tr, 2*n+1)
  lte <- in_node(leaf_node_te, 2*n); rte <- in_node(leaf_node_te, 2*n+1)
  data.frame(node = n, level = depth_of(n) + 1, variable = p$var, left_rule = p$left_rule,
             improve = round(p$improve, 3),
             n_node_train = sum(mtr), rate_node_train = rate(tr$Attrition[mtr]),
             n_left_train = sum(ltr), rate_left_train = rate(tr$Attrition[ltr]),
             n_right_train = sum(rtr), rate_right_train = rate(tr$Attrition[rtr]),
             n_left_test = sum(lte), rate_left_test = if (sum(lte)) rate(te$Attrition[lte]) else NA,
             n_right_test = sum(rte), rate_right_test = if (sum(rte)) rate(te$Attrition[rte]) else NA)
}))
write.csv(split_tab, "analysis/tree_splits.csv", row.names = FALSE)

# leaves
leaf_rows <- which(fr$var == "<leaf>")
leaf_tab <- do.call(rbind, lapply(leaf_rows, function(i) {
  n <- node_ids[i]; path <- path.rpart(fit, n, print.it = FALSE)[[1]][-1]
  data.frame(node = n, path = paste(path, collapse = " & "),
             n_train = sum(leaf_node_tr == n), rate_train = rate(tr$Attrition[leaf_node_tr == n]),
             n_test = sum(leaf_node_te == n),
             rate_test = if (sum(leaf_node_te == n)) rate(te$Attrition[leaf_node_te == n]) else NA)
}))
leaf_tab <- leaf_tab[order(-leaf_tab$rate_train), ]
write.csv(leaf_tab, "analysis/tree_leaves.csv", row.names = FALSE)

# ---- importance ----
vi <- fit$variable.importance; vi_pct <- round(100 * vi / sum(vi), 1)
prim_imp <- tapply(sapply(prim, `[[`, "improve"), sapply(prim, `[[`, "var"), sum)
prim_imp <- sort(prim_imp, decreasing = TRUE)

# ---- single-split scan (each predictor alone, best binary split on training) ----
scan <- do.call(rbind, lapply(predictors, function(v) {
  f1 <- rpart(as.formula(paste("Attrition ~", v)), data = tr, method = "class",
              control = rpart.control(cp = -1, maxdepth = 1, minbucket = 7, minsplit = 20, xval = 0,
                                      maxcompete = 0, maxsurrogate = 0))
  if (nrow(f1$frame) < 3) return(data.frame(variable = v, rule_left = NA, improve = 0,
     n_left = NA, rate_left = NA, n_right = NA, rate_right = NA))
  lab <- labels(f1, minlength = 0)[2]
  w <- f1$where; nid <- as.integer(rownames(f1$frame))[w]
  data.frame(variable = v, rule_left = lab, improve = round(f1$splits[1, "improve"], 3),
             n_left = sum(nid == 2), rate_left = rate(tr$Attrition[nid == 2]),
             n_right = sum(nid == 3), rate_right = rate(tr$Attrition[nid == 3]))
}))
scan <- scan[order(-scan$improve), ]
scan$rate_diff_pts <- round(100 * abs(scan$rate_left - scan$rate_right), 1)
write.csv(scan, "analysis/single_split_scan.csv", row.names = FALSE)

# ---- test-set performance ----
p_te <- predict(fit, te, type = "prob")[, "Yes"]
roc_te <- roc(te$Attrition, p_te, levels = c("No","Yes"), direction = "<", quiet = TRUE)
set.seed(SEED)
ci_boot <- ci.auc(roc_te, method = "bootstrap", boot.n = 2000, progress = "none")
ci_delong <- ci.auc(roc_te, method = "delong")
bal_acc <- function(y, p, thr) { pr <- p >= thr
  sens <- mean(pr[y == "Yes"]); spec <- mean(!pr[y == "No"]); c(sens = sens, spec = spec, bal_acc = (sens + spec) / 2) }
base_tr <- rate(tr$Attrition)
perf_te <- list(n = nrow(te), n_yes = sum(te$Attrition == "Yes"),
  auc = as.numeric(auc(roc_te)),
  auc_ci95_bootstrap2000 = as.numeric(ci_boot)[c(1, 3)],
  auc_ci95_delong = as.numeric(ci_delong)[c(1, 3)],
  observed_rate = rate(te$Attrition), mean_predicted = mean(p_te),
  brier = mean((p_te - (te$Attrition == "Yes"))^2),
  at_threshold_0.5 = as.list(bal_acc(te$Attrition, p_te, 0.5)),
  at_threshold_train_base_rate = c(threshold = base_tr, as.list(bal_acc(te$Attrition, p_te, base_tr))))

# ---- repeated stratified 10-fold CV on all 1470 (same fixed setting) ----
cv_auc <- c(); cv_ba <- c(); cv_obs <- c(); cv_pred <- c(); pooled <- c()
for (r in 1:5) {
  set.seed(SEED + r)
  fold <- integer(nrow(d))
  for (cl in levels(d$Attrition)) { ix <- which(d$Attrition == cl)
    fold[ix] <- sample(rep(1:10, length.out = length(ix))) }
  oof <- numeric(nrow(d))
  for (k in 1:10) {
    f <- rpart(fml, data = d[fold != k, ], method = "class", control = rpart.control(cp = 0.01, minsplit = 20, minbucket = 7, maxdepth = 5, xval = 0))
    oof[fold == k] <- predict(f, d[fold == k, ], type = "prob")[, "Yes"]
    yk <- d$Attrition[fold == k]
    cv_auc <- c(cv_auc, as.numeric(auc(roc(yk, oof[fold == k], levels = c("No","Yes"), direction = "<", quiet = TRUE))))
    cv_ba <- c(cv_ba, bal_acc(yk, oof[fold == k], rate(d$Attrition[fold != k]))["bal_acc"])
  }
  pooled <- c(pooled, as.numeric(auc(roc(d$Attrition, oof, levels = c("No","Yes"), direction = "<", quiet = TRUE))))
  cv_obs <- c(cv_obs, rate(d$Attrition)); cv_pred <- c(cv_pred, mean(oof))
}
cv <- list(scheme = "5 x stratified 10-fold, seeds 20261009-20261013, full data n=1470, same fixed setting",
  auc_fold_mean = mean(cv_auc), auc_fold_sd = sd(cv_auc), auc_fold_range = range(cv_auc),
  auc_pooled_oof_per_repeat = pooled,
  balanced_accuracy_fold_mean_at_train_base_rate = mean(cv_ba), balanced_accuracy_fold_sd = sd(cv_ba),
  mean_oof_predicted_rate = mean(cv_pred), observed_rate = mean(cv_obs))

# ---- bootstrap stability of the displayed tree ----
B <- 500; set.seed(SEED)
root_var <- character(B); top5 <- list()
for (b in 1:B) {
  bi <- sample(nrow(tr), replace = TRUE)
  fb <- rpart(fml, data = tr[bi, ], method = "class", control = rpart.control(cp = 0.01, minsplit = 20, minbucket = 7, maxdepth = 5, xval = 0))
  root_var[b] <- as.character(fb$frame$var[1])
  top5[[b]] <- names(sort(fb$variable.importance, decreasing = TRUE))[1:5]
}
root_freq <- sort(table(root_var) / B, decreasing = TRUE)
top5_freq <- sort(table(unlist(top5)) / B, decreasing = TRUE)

# ---- plot ----
if (requireNamespace("rpart.plot", quietly = TRUE)) {
  wrap_split <- function(x, labs, digits, varlen, faclen) {
    sapply(labs, function(l) paste(strwrap(gsub(",", ", ", l), width = 34), collapse = "\n")) }
  png("analysis/tree.png", width = 3600, height = 2200, res = 220)
  rpart.plot::rpart.plot(fit, type = 2, extra = 107, under = TRUE, box.palette = "Grays",
     shadow.col = 0, branch.lty = 1, fallen.leaves = FALSE, faclen = 0, varlen = 0,
     cex = 0.8, split.cex = 0.95, split.fun = wrap_split, tweak = 1,
     main = "IBM HR attrition tree, training n=1029\n(box: P(Attrition=Yes) and % of training rows; left branch = rule true)")
  dev.off()
}

# ---- level-1/2 rules applied to all 1470 rows (descriptive only) ----
ot <- d$OverTime == "Yes"
full_rules <- list(
  OverTime_No  = list(n = sum(!ot), rate = rate(d$Attrition[!ot])),
  OverTime_Yes = list(n = sum(ot),  rate = rate(d$Attrition[ot])),
  OverTime_No_MonthlyIncome_lt_1559  = list(n = sum(!ot & d$MonthlyIncome < 1559),  rate = rate(d$Attrition[!ot & d$MonthlyIncome < 1559])),
  OverTime_No_MonthlyIncome_ge_1559  = list(n = sum(!ot & d$MonthlyIncome >= 1559), rate = rate(d$Attrition[!ot & d$MonthlyIncome >= 1559])),
  OverTime_Yes_MonthlyIncome_lt_2475 = list(n = sum(ot & d$MonthlyIncome < 2475),   rate = rate(d$Attrition[ot & d$MonthlyIncome < 2475])),
  OverTime_Yes_MonthlyIncome_ge_2475 = list(n = sum(ot & d$MonthlyIncome >= 2475),  rate = rate(d$Attrition[ot & d$MonthlyIncome >= 2475])))

# ---- metrics.json ----
m <- list(
  data = list(file = dat_path, n_rows = 1470, n_cols_raw = 35,
              attrition_yes = sum(d$Attrition == "Yes"), attrition_no = sum(d$Attrition == "No"),
              overall_attrition_rate = rate(d$Attrition),
              constant_column_unique_counts = as.list(const_check)),
  exclusions = list(id_and_constant = id_const, not_pay_per_Ellis = not_pay),
  predictors_used = predictors, n_predictors = length(predictors),
  split = list(seed = SEED, scheme = "stratified 70/30 by Attrition",
               n_train = nrow(tr), n_test = nrow(te), rate_train = base_tr, rate_test = rate(te$Attrition)),
  tree_settings = list(engine = paste("R", getRversion(), "rpart", packageVersion("rpart")),
     method = "class", split = "gini", cp = 0.01, minsplit = 20, minbucket = 7, maxdepth = 5,
     priors_weights = "none (empirical priors, equal loss)", tuned = FALSE),
  tree_size = list(n_splits = length(prim), n_leaves = length(leaf_rows)),
  cptable = as.data.frame(fit$cptable),
  variable_importance_rpart = as.list(round(vi, 3)),
  variable_importance_rpart_pct = as.list(vi_pct),
  primary_split_improvement_by_var = as.list(round(prim_imp, 3)),
  splits = split_tab, leaves = leaf_tab, single_split_scan_top10 = head(scan, 10),
  full_data_level1_2_rules = full_rules,
  test = perf_te, cv = cv,
  bootstrap_stability = list(B = B, root_variable_freq = as.list(round(root_freq, 3)),
                             in_top5_importance_freq = as.list(round(top5_freq, 3))))
write_json(m, "analysis/metrics.json", auto_unbox = TRUE, pretty = TRUE, digits = 6, dataframe = "rows")
cat("done\n")
