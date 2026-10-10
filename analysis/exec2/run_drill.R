# Deeper drill-down of large groups (IBM HR fictional data). Run from the project root:
#   Rscript analysis/exec2/run_drill.R
# Parameters are read from analysis/exec2/thresholds.json (written before the final run; its SHA-256 is recorded).
# Every number in analysis/exec2/*.md and *.csv is computed here. Deterministic (seed 20261008).
# All trees and cut points are derived on the 70% training split only, then evaluated on the untouched 30% test set.
.libPaths(c("~/R/library", .libPaths()))
suppressPackageStartupMessages({library(rpart); library(jsonlite); library(parallel)})
T0 <- Sys.time()
TEST_MODE <- nzchar(Sys.getenv("DRILL_TEST"))          # developer smoke test only: small B / few shuffles, writes to /tmp
OUT <- if (TEST_MODE) "/tmp/exec2_test" else "analysis/exec2"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
thr_path <- "analysis/exec2/thresholds.json"; stopifnot(file.exists(thr_path))
TH <- fromJSON(thr_path, simplifyVector = TRUE)
TH_SHA <- sub(" .*", "", system2("sha256sum", thr_path, stdout = TRUE)); TH_MTIME <- format(as.POSIXct(file.info(thr_path)$mtime, tz = "America/Los_Angeles"), tz = "America/Los_Angeles", "%Y-%m-%d %H:%M:%S %Z")

SEED   <- TH$split_and_predictors$seed
MIN_N  <- TH$rule1_size$min_n;  MIN_LV <- TH$rule1_size$min_leavers
MIN_EXC <- TH$rule2_impact$min_excess_leavers
MIN_LIFT <- TH$rule3_rate$min_lift; CONF <- TH$rule3_rate$wilson_conf
MIN_TN <- TH$rule4_heldout$min_test_n
B_REAL <- TH$rule5_stability$n_bootstrap; STAB_MIN <- TH$rule5_stability$min_share_refits
SIM_TOL <- TH$rule5_stability$similar_cut_share_tolerance
DEPTH_BR <- TH$rule5_stability$branch_refit_max_depth; DEPTH_CO <- TH$rule5_stability$company_refit_max_depth
NODES_CO <- TH$rule5_stability$company_nodes
LIFT_OLD <- TH$reported_not_gating$lift_floor_old_rule
SS <- TH$reported_not_gating$stability_sensitivity; SS_CP <- SS$cp; SS_DEPTH <- SS$max_depth
SS_B <- SS$n_bootstrap; SS_MIN <- SS$min_share
MAX_DRILL_COND <- TH$drill$max_defining_conditions_safety_cap; PV_DRILL_MAX <- TH$drill$parent_view_drill_max_conditions
PAR_EXC <- TH$reported_not_gating$parent_branch_flag$min_excess_vs_parent
MB_FULL <- TH$trees$minbucket_full; MB_TR <- TH$trees$minbucket_training; MAXD <- TH$trees$max_depth
GRID_PROBS <- TH$grid$numeric_quantile_probs; DISC <- TH$grid$discrete_max_unique
PAIR_VARS <- TH$grid$pairs$variables; PAIR_PROBS <- TH$grid$pairs$quantile_probs
SENS <- TH$sensitive_vars; MAX_COND_EXEC <- TH$drill$max_conditions_on_executive_page
SAME_J <- TH$overlap$same_people_jaccard; NEST_C <- TH$overlap$nested_containment
N_SHUF <- TH$null_calibration$n_shuffles; B_NULL <- TH$null_calibration$n_bootstrap_per_scope_in_shuffles
if (TEST_MODE) { B_REAL <- 60; N_SHUF <- 6; B_NULL <- 20; SS_B <- 60 }
NC <- max(1, min(6, detectCores()))                  # 6 workers: the box shares memory with other jobs
LOGDIR <- if (TEST_MODE) "/tmp/exec2_test/logs" else "analysis/exec2/logs"; dir.create(LOGDIR, showWarnings = FALSE, recursive = TRUE)
NOCACHE <- nzchar(Sys.getenv("DRILL_NOCACHE"))         # DRILL_NOCACHE=1: recompute everything, write no cache (used for the identical-rerun check)
CACHE <- file.path(LOGDIR, "cache"); if (!NOCACHE) dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)
PLOG <- file.path(LOGDIR, if (NOCACHE) "progress_nocache.log" else "progress.log")
logp <- function(...) cat(format(Sys.time(), "%H:%M:%S"), sprintf(...), "\n", file = PLOG, append = TRUE)
# heavy steps are cached on disk (key = thresholds SHA + search-code version) so a restart resumes; delete logs/cache if the search code changes
CKEY <- paste(substr(TH_SHA, 1, 16), "search-v1")
cached <- function(name, fun) { f <- file.path(CACHE, paste0(name, ".rds")); if (!NOCACHE && file.exists(f)) { o <- readRDS(f); if (identical(o$key, CKEY)) return(o$val) }
  v <- fun(); if (!NOCACHE) saveRDS(list(key = CKEY, val = v), f); v }
MIN_STORE <- TH$reporting$min_stored_n              # groups below this size are counted as tested but not stored

# ------------------------------------------------------------------ data and the same 70/30 split as before
d <- read.csv("data/WA_Fn-UseC_-HR-Employee-Attrition.csv", fileEncoding = "UTF-8-BOM", stringsAsFactors = TRUE)
stopifnot(nrow(d) == 1470)
d <- d[, setdiff(names(d), TH$split_and_predictors$excluded)]
d$Attrition <- factor(d$Attrition, levels = c("No", "Yes")); stopifnot(ncol(d) == 28)
PRED <- setdiff(names(d), "Attrition"); stopifnot(length(PRED) == 27)
N <- nrow(d); y_all <- as.numeric(d$Attrition == "Yes"); L <- sum(y_all); AVG <- L / N
set.seed(SEED)
idx_tr <- unlist(lapply(split(seq_len(N), d$Attrition), function(ix) sample(ix, round(0.7 * length(ix)))))
is_tr <- seq_len(N) %in% idx_tr
NTR <- sum(is_tr); NTE <- N - NTR
TEST_AVG <- mean(y_all[!is_tr]); TRAIN_AVG <- mean(y_all[is_tr])
stopifnot(NTR == 1029, NTE == 441, sum(y_all[!is_tr]) == 71, L == 237)
IDX <- as.numeric(seq_len(N))
BR <- list(All = rep(TRUE, N), OT = d$OverTime == "Yes", nonOT = d$OverTime == "No")
INTV <- sapply(PRED, function(v) is.numeric(d[[v]]) && all(d[[v]] == round(d[[v]])))
DISCV <- sapply(PRED, function(v) is.numeric(d[[v]]) && length(unique(d[[v]])) <= DISC)

wilson_v <- function(x, n) { z <- qnorm(1 - (1 - CONF) / 2); p <- x / n; dd <- 1 + z^2 / n
  c0 <- (p + z^2 / (2 * n)) / dd; h <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / dd; cbind(lo = c0 - h, hi = c0 + h) }
P1 <- function(x) sprintf("%.1f%%", 100 * x); P0 <- function(x) sprintf("%.0f%%", 100 * x)
F1 <- function(x) sprintf("%.1f", x); F2 <- function(x) sprintf("%.2f", x)

# ------------------------------------------------------------------ conditions, groups
mkc <- function(var, op, cut = NA_real_, lv = character()) list(var = var, op = op, cut = cut, lv = lv)
ev <- function(cd, dat = d) { x <- dat[[cd$var]]
  switch(cd$op, "<" = x < cd$cut, ">=" = x >= cd$cut, "in" = as.character(x) %in% cd$lv, "notin" = !(as.character(x) %in% cd$lv)) }
ev_all <- function(conds, base = rep(TRUE, N)) { m <- base; for (cd in conds) m <- m & ev(cd); m }
grp_mask <- function(branch, conds) ev_all(conds, BR[[branch]])
cvars <- function(conds) vapply(conds, function(z) z$var, "")
is_sens <- function(conds) any(cvars(conds) %in% SENS)
tech_cond <- function(cd) switch(cd$op,
  "<" = sprintf("%s < %s", cd$var, format(cd$cut, digits = 7)), ">=" = sprintf("%s >= %s", cd$var, format(cd$cut, digits = 7)),
  "in" = if (length(cd$lv) == 1) sprintf("%s = %s", cd$var, cd$lv) else sprintf("%s in {%s}", cd$var, paste(cd$lv, collapse = ", ")),
  "notin" = if (length(cd$lv) == 1) sprintf("%s != %s", cd$var, cd$lv) else sprintf("%s not in {%s}", cd$var, paste(cd$lv, collapse = ", ")))
tech_label <- function(branch, conds) { pre <- switch(branch, All = character(), OT = "OverTime = Yes", nonOT = "OverTime = No")
  s <- c(pre, vapply(conds, tech_cond, "")); if (!length(s)) "all staff" else paste(s, collapse = " & ") }
PN <- c(TotalWorkingYears = "total working years", YearsAtCompany = "years at the company", YearsInCurrentRole = "years in current role",
  YearsWithCurrManager = "years with current manager", YearsSinceLastPromotion = "years since last promotion", JobLevel = "job level",
  MonthlyIncome = "monthly income", NumCompaniesWorked = "companies worked for before", StockOptionLevel = "stock option level",
  BusinessTravel = "business travel", Age = "age", JobRole = "job role", EducationField = "education field", Department = "department",
  EnvironmentSatisfaction = "environment satisfaction", JobSatisfaction = "job satisfaction", JobInvolvement = "job involvement",
  WorkLifeBalance = "work-life balance", RelationshipSatisfaction = "relationship satisfaction", DistanceFromHome = "distance from home (miles)",
  PercentSalaryHike = "salary hike %", PerformanceRating = "performance rating", TrainingTimesLastYear = "training times last year",
  Education = "education level", MaritalStatus = "marital status", Gender = "gender")
plain_cond <- function(cd) { v <- cd$var; nm <- if (v %in% names(PN)) PN[[v]] else v
  if (v == "OverTime") { yes <- (cd$op == "in") == (cd$lv[1] == "Yes"); return(if (yes) "works overtime" else "no overtime") }
  if (cd$op %in% c("<", ">=")) {
    if (v == "MonthlyIncome") return(if (cd$op == "<") sprintf("monthly income under $%s", format(round(cd$cut), big.mark = ",")) else sprintf("monthly income $%s or more", format(round(cd$cut), big.mark = ",")))
    if (INTV[[v]]) { lo <- cd$op == "<"; k <- if (lo) ceiling(cd$cut) - 1 else ceiling(cd$cut); r <- range(d[[v]])
      if (DISCV[[v]] && lo && k == r[1]) return(sprintf("%s = %d", nm, k)); if (DISCV[[v]] && !lo && k == r[2]) return(sprintf("%s = %d", nm, k))
      if (lo && k == 0 && grepl("^Years", v)) return(sprintf("%s: under 1 year", nm))
      return(sprintf("%s: %d or %s", nm, k, if (lo) "less" else "more")) }
    return(sprintf("%s %s %s", nm, if (cd$op == "<") "below" else "at least", format(cd$cut, digits = 4))) }
  if (cd$op == "in") return(sprintf("%s = %s", nm, paste(cd$lv, collapse = " or ")))
  sprintf("%s other than %s", nm, paste(cd$lv, collapse = " or ")) }
plain_label <- function(branch, conds) { pre <- switch(branch, All = character(), OT = "works overtime", nonOT = "no overtime")
  s <- c(pre, vapply(conds, plain_cond, "")); if (!length(s)) "all staff" else paste(s, collapse = " and ") }

# ------------------------------------------------------------------ trees (training rows only)
prune_1se <- function(f) { ct <- f$cptable; i <- which.min(ct[, "xerror"]); thr <- ct[i, "xerror"] + ct[i, "xstd"]
  j <- min(which(ct[, "xerror"] <= thr)); list(fit = prune(f, cp = ct[j, "CP"]), cp = ct[j, "CP"], nsplit = ct[j, "nsplit"]) }
grow_tree <- function(rows, y, mb, xval, seed, maxdepth = MAXD, drop_ot = FALSE) {
  prd <- if (drop_ot) setdiff(PRED, "OverTime") else PRED
  dat <- d[rows, prd, drop = FALSE]; dat$Attrition <- y[rows]; set.seed(seed)
  f <- rpart(Attrition ~ ., data = dat, method = "anova", control = rpart.control(cp = 0.001, minbucket = mb, minsplit = 2 * mb, maxdepth = maxdepth, xval = xval))
  list(fit = f, dat = dat) }
# primary split of every internal node as left/right conditions
tree_prim <- function(f, dat) { fr <- f$frame; ids <- as.integer(rownames(fr)); srow <- 1; res <- list()
  for (i in seq_len(nrow(fr))) { if (fr$var[i] == "<leaf>") next
    s <- f$splits[srow, , drop = FALSE]; v <- as.character(fr$var[i])
    if (abs(s[1, "ncat"]) == 1) { cut <- unname(s[1, "index"])
      if (s[1, "ncat"] < 0) { Lc <- mkc(v, "<", cut); Rc <- mkc(v, ">=", cut) } else { Lc <- mkc(v, ">=", cut); Rc <- mkc(v, "<", cut) } }
    else { lv <- levels(dat[[v]]); codes <- f$csplit[s[1, "index"], seq_along(lv)]; Lc <- mkc(v, "in", lv = lv[codes == 1]); Rc <- mkc(v, "notin", lv = lv[codes == 1]) }
    res[[as.character(ids[i])]] <- list(L = Lc, R = Rc, var = v, cut = if (abs(s[1, "ncat"]) == 1) unname(s[1, "index"]) else NA_real_)
    srow <- srow + 1 + fr$ncompete[i] + fr$nsurrogate[i] }
  res }
tree_nodes <- function(tobj, kind) { f <- tobj$fit; prim <- tree_prim(f, tobj$dat); ids <- as.integer(rownames(f$frame)); res <- list()
  for (id in setdiff(ids, 1L)) { path <- list(); m <- id
    while (m > 1) { p <- m %/% 2; pr <- prim[[as.character(p)]]; path <- c(list(if (m %% 2 == 0) pr$L else pr$R), path); m <- p }
    br <- switch(kind, full = "All", OT = "OT", nonOT = "nonOT")
    if (kind == "full" && path[[1]]$var == "OverTime") { c1 <- path[[1]]; yes <- (c1$op == "in") == (c1$lv[1] == "Yes"); br <- if (yes) "OT" else "nonOT"; path <- path[-1] }
    res[[length(res) + 1]] <- list(id = id, kind = kind, branch = br, conds = path, depth = floor(log2(id))) }
  res }

# ------------------------------------------------------------------ bootstrap refit stores (stability)
# One store per scope: refits of rpart on bootstrap resamples of that scope's rows (full data); keeps every primary split.
make_refits <- function(scope, y, B, maxdepth, maxnode, seed, cores, prune_cv = TRUE) {
  rows <- which(BR[[scope]]); prd <- if (scope == "All") PRED else setdiff(PRED, "OverTime")
  one <- function(b) { set.seed(seed + b); bi <- sample(rows, length(rows), replace = TRUE)
    dat <- d[bi, prd, drop = FALSE]; dat$Attrition <- y[bi]
    f <- rpart(Attrition ~ ., data = dat, method = "anova", control = rpart.control(cp = if (prune_cv) 0.001 else SS_CP, minbucket = MB_FULL, minsplit = 2 * MB_FULL, maxdepth = maxdepth, xval = if (prune_cv) 10 else 0))
    pr <- if (prune_cv) prune_1se(f)$fit else f; if (nrow(pr$frame) == 1) return(NULL)
    tp <- tree_prim(pr, dat); data.frame(b = b, node = as.integer(names(tp)), var = vapply(tp, function(z) z$var, ""), cut = vapply(tp, function(z) z$cut, 0)) }
  res <- if (cores > 1) mclapply(seq_len(B), one, mc.cores = cores, mc.set.seed = FALSE) else lapply(seq_len(B), one)
  sp <- do.call(rbind, res); if (is.null(sp)) sp <- data.frame(b = integer(), node = integer(), var = character(), cut = numeric())
  sp$cutrank <- rep(NA_real_, nrow(sp))
  for (v in unique(sp$var)) { k <- sp$var == v & !is.na(sp$cut); if (any(k)) { xs <- d[[v]][rows]; sp$cutrank[k] <- vapply(sp$cut[k], function(c) mean(xs < c), 0) } }
  sp <- sp[sp$node <= maxnode, ]
  list(scope = scope, B = B, rows = rows, sp = sp, byvar = split(sp, sp$var), cache = new.env(), n_pruned_root = B - length(unique(sp$b))) }
cond_hits <- function(st, cd, any_cut = FALSE) {
  key <- paste(cd$var, if (any_cut) "any" else cd$op, if (any_cut) "" else format(cd$cut, digits = 10), if (any_cut) "" else paste(cd$lv, collapse = ","))
  if (!is.null(h <- st$cache[[key]])) return(h)
  hits <- logical(st$B); sel <- st$byvar[[cd$var]]
  if (!is.null(sel)) { ok <- rep(TRUE, nrow(sel))
    if (!any_cut && cd$op %in% c("<", ">=")) { xs <- d[[cd$var]][st$rows]; tr_ <- mean(xs < cd$cut); ok <- !is.na(sel$cutrank) & abs(sel$cutrank - tr_) <= SIM_TOL }
    hits[unique(sel$b[ok])] <- TRUE }
  st$cache[[key]] <- hits; hits }
stab_within <- function(st, conds, any_cut = FALSE) { if (!length(conds)) return(NA_real_); mean(Reduce(`&`, lapply(conds, cond_hits, st = st, any_cut = any_cut))) }
stab_old <- function(st_all, branch, conds) { vars <- unique(c(if (branch != "All") "OverTime", cvars(conds)))
  mean(Reduce(`&`, lapply(vars, function(v) cond_hits(st_all, mkc(v, "in"), any_cut = TRUE)))) }

# ------------------------------------------------------------------ candidate atoms (cuts from TRAINING rows inside the node only)
acond <- function(A, i) mkc(A$var[i], A$op[i], A$cut[i], if (A$op[i] %in% c("in", "notin")) A$lv[i] else character())
atoms_in <- function(mask, vars, probs) {
  mt <- mask & is_tr; Ml <- list(); Al <- list()
  for (v in vars) { x <- d[[v]]
    if (is.factor(x)) { tb <- table(x[mt]); lvs <- names(tb)[tb > 0]; if (length(lvs) < 2) next
      for (l in lvs) { Ml[[length(Ml) + 1]] <- mask & (as.character(x) == l); Al[[length(Al) + 1]] <- data.frame(var = v, op = "in", cut = NA_real_, lv = l) } }
    else { xt <- x[mt]; u <- sort(unique(xt)); if (length(u) < 2) next
      cuts <- if (length(u) <= DISC) u[-1] else unique(as.numeric(quantile(xt, probs, type = 1, names = FALSE)))
      cuts <- cuts[cuts > min(u)]; if (!length(cuts)) next
      lo <- outer(x, cuts, "<"); Ml[[length(Ml) + 1]] <- cbind(mask & lo, mask & !lo)
      Al[[length(Al) + 1]] <- data.frame(var = v, op = rep(c("<", ">="), each = length(cuts)), cut = rep(cuts, 2), lv = "") } }
  if (!length(Ml)) return(list(A = data.frame(var = character(), op = character(), cut = numeric(), lv = character()), M = matrix(FALSE, N, 0)))
  list(A = do.call(rbind, Al), M = do.call(cbind, Ml)) }

# static (label-free) groups: branch roots, every single split inside each branch, pairs of experience variables inside each branch
build_static <- function() {
  Ml <- list(); br <- character(); cl <- list(); src <- character()
  add <- function(M, b, conds_list, s) { Ml[[length(Ml) + 1]] <<- M; br <<- c(br, rep(b, ncol(M))); cl <<- c(cl, conds_list); src <<- c(src, rep(s, ncol(M))) }
  for (b in c("OT", "nonOT")) add(matrix(BR[[b]], ncol = 1), b, list(list()), "branch root")
  for (b in c("All", "OT", "nonOT")) { vars <- if (b == "All") PRED else setdiff(PRED, "OverTime"); a <- atoms_in(BR[[b]], vars, GRID_PROBS)
    add(a$M, b, lapply(seq_len(nrow(a$A)), function(i) list(acond(a$A, i))), "single split") }
  for (b in c("All", "OT", "nonOT")) { a <- atoms_in(BR[[b]], PAIR_VARS, PAIR_PROBS); k <- nrow(a$A)
    ij <- which(outer(seq_len(k), seq_len(k), "<") & outer(a$A$var, a$A$var, "!="), arr.ind = TRUE)
    Mp <- a$M[, ij[, 1], drop = FALSE] & a$M[, ij[, 2], drop = FALSE]
    add(Mp, b, lapply(seq_len(nrow(ij)), function(r) list(acond(a$A, ij[r, 1]), acond(a$A, ij[r, 2]))), "pair of experience variables") }
  list(M = do.call(cbind, Ml), branch = br, conds = cl, src = src) }
STATIC <- build_static()

# ------------------------------------------------------------------ the search (real labels or shuffled labels)
build_rows <- function(n, lv, ntr, ltr, branch, sens, PARv, PARTEST, PARTR) {
  nte <- n - ntr; lte <- lv - ltr; rate <- lv / n; w <- wilson_v(lv, n); pr <- unname(PARv[branch]); excess <- lv - n * AVG; ep <- lv - n * pr
  df <- data.frame(branch = branch, n = n, pct_staff = n / N, leavers = lv, pct_leavers = lv / L, rate = rate, lift = rate / AVG,
    wilson_lo = w[, 1], wilson_hi = w[, 2], train_n = ntr, train_leavers = ltr, train_rate = ltr / ntr, test_n = nte, test_leavers = lte, test_rate = lte / nte,
    excess = excess, impact_pts = 100 * excess / N, parent_rate = pr, rate_vs_parent = rate / pr, excess_vs_parent = ep, impact_parent_pts = 100 * ep / N,
    wilson_lo_above_parent = w[, 1] > pr, train_excess = ltr - ntr * TRAIN_AVG, train_excess_parent = ltr - ntr * unname(PARTR[branch]), sensitive = sens, stringsAsFactors = FALSE)
  df$g1_size <- n >= MIN_N & lv >= MIN_LV
  df$g2_impact <- excess >= MIN_EXC
  df$g3_rate <- df$lift >= MIN_LIFT & w[, 1] > AVG
  df$test_too_small <- nte < MIN_TN
  df$g4_heldout <- !df$test_too_small & !is.na(df$test_rate) & df$test_rate > TEST_AVG
  df$lift_ge_1.5 <- df$lift >= LIFT_OLD
  df$parent_flag <- ep >= PAR_EXC & df$wilson_lo_above_parent
  df$g4_parent <- !df$test_too_small & !is.na(df$test_rate) & df$test_rate > unname(PARTEST[branch])
  df$pv_gates <- df$g1_size & ep >= PAR_EXC & df$rate_vs_parent >= MIN_LIFT & df$wilson_lo_above_parent & df$g4_parent & !sens
  df[is.na(df)] <- NA; df }

search <- function(y, real, seed0, cores) {
  S <- new.env(); S$tested <- 0; S$raw <- 0; S$c13 <- 0; S$c14 <- 0; S$c_new <- 0; S$c_sens <- 0; S$c_pv <- 0; S$c_pvg <- 0; S$capped <- 0; S$c_root <- 0; S$tb <- c(All = 0, OT = 0, nonOT = 0); S$tb100 <- c(All = 0, OT = 0, nonOT = 0); S$seen <- new.env(hash = TRUE); S$rows <- list(); S$conds <- list(); S$src <- list(); S$dups <- list()
  S$queue <- list(); S$qh <- 1; S$drilled <- new.env(hash = TRUE); S$log <- list(); S$stores <- list()
  PARv <- c(All = AVG, OT = mean(y[BR$OT]), nonOT = mean(y[BR$nonOT]))
  PARTR <- c(All = TRAIN_AVG, OT = mean(y[BR$OT & is_tr]), nonOT = mean(y[BR$nonOT & is_tr]))
  PARTEST <- c(All = TEST_AVG, OT = mean(y[BR$OT & !is_tr]), nonOT = mean(y[BR$nonOT & !is_tr]))
  store_for <- function(scope) { if (is.null(S$stores[[scope]])) { i <- match(scope, c("All", "OT", "nonOT"))
      S$stores[[scope]] <- if (scope == "All") make_refits("All", y, if (real) B_REAL else B_NULL, DEPTH_CO, max(NODES_CO), seed0 + 1000 * i, cores)
        else make_refits(scope, y, if (real) B_REAL else B_NULL, DEPTH_BR, Inf, seed0 + 1000 * i, cores) }
    S$stores[[scope]] }
  store_u <- function(scope) { k <- paste0("u_", scope); if (is.null(S$stores[[k]])) { i <- match(scope, c("All", "OT", "nonOT"))
      S$stores[[k]] <- make_refits(scope, y, if (real) SS_B else B_NULL, SS_DEPTH, Inf, seed0 + 5000 + 1000 * i, cores, prune_cv = FALSE) }
    S$stores[[k]] }
  if (real) for (sc in c("All", "OT", "nonOT")) store_for(sc)
  if (real) for (sc in c("OT", "nonOT")) store_u(sc)
  add_stab <- function(df, branch, conds_list) {
    df$pass_pv <- FALSE
    df$stab_within <- NA_real_; df$stab_old <- NA_real_; df$stab_unpruned <- NA_real_; df$stab_var_pruned <- NA_real_; df$stab_var_unpruned <- NA_real_
    need <- if (real) which(df$g1_size & (df$lift >= MIN_LIFT | df$rate_vs_parent >= MIN_LIFT)) else which((df$g1_size & df$g2_impact & df$g3_rate & df$g4_heldout & !df$sensitive) | df$pv_gates)
    for (i in need) { cds <- conds_list[[i]]; br <- branch[i]
      df$stab_within[i] <- if (!length(cds)) stab_within(store_for("All"), list(mkc("OverTime", "in", lv = if (br == "OT") "Yes" else "No"))) else stab_within(store_for(if (br == "All") "All" else br), cds)
      df$stab_old[i] <- stab_old(store_for("All"), br, cds)
      if (br != "All" && length(cds)) df$stab_unpruned[i] <- stab_within(store_u(br), cds)
      if (real && length(cds)) { df$stab_var_pruned[i] <- stab_within(store_for(br), cds, any_cut = TRUE)
        if (br != "All") df$stab_var_unpruned[i] <- stab_within(store_u(br), cds, any_cut = TRUE) } }
    df$g5_stable <- !is.na(df$stab_within) & df$stab_within > STAB_MIN
    df$pass_new <- df$g1_size & df$g2_impact & df$g3_rate & df$g4_heldout & df$g5_stable & !df$sensitive
    df$pass_sens <- df$g1_size & df$g2_impact & df$g3_rate & df$g4_heldout & !df$sensitive & !df$pass_new &
      ((df$branch == "All" & df$g5_stable) | (df$branch != "All" & !is.na(df$stab_unpruned) & df$stab_unpruned > SS_MIN))
    df$pass_pv <- df$pv_gates & df$g5_stable
    df$pass_old <- df$g1_size & df$lift_ge_1.5 & df$g4_heldout & !is.na(df$stab_old) & df$stab_old > STAB_MIN
    df }
  process_batch <- function(M, branch, conds_list, src) {
    if (length(branch) == 1) branch <- rep(branch, ncol(M))
    Z <- cbind(1, y, is_tr, y * is_tr, IDX, IDX^2); r <- crossprod(M, Z)
    key <- paste(r[, 1], r[, 5], r[, 6], sep = "|"); S$raw <- S$raw + ncol(M)
    sens <- vapply(conds_list, is_sens, TRUE)
    df <- build_rows(r[, 1], r[, 2], r[, 3], r[, 4], branch, sens, PARv, PARTEST, PARTR); df$key <- key
    df <- add_stab(df, branch, conds_list)
    isnew <- !duplicated(key) & r[, 1] > 0 & !vapply(key, function(k) exists(k, envir = S$seen, inherits = FALSE), TRUE)
    for (k in key[isnew]) assign(k, TRUE, envir = S$seen)
    S$tested <- S$tested + sum(isnew)
    for (bb in names(S$tb)) { S$tb[bb] <- S$tb[bb] + sum(isnew & branch == bb); S$tb100[bb] <- S$tb100[bb] + sum(isnew & branch == bb & df$n >= MIN_N) }
    S$c_new <- S$c_new + sum(isnew & df$pass_new); S$c_sens <- S$c_sens + sum(isnew & df$pass_sens); S$c_pv <- S$c_pv + sum(isnew & df$pass_pv); S$c_pvg <- S$c_pvg + sum(isnew & df$pv_gates)
    S$c_root <- S$c_root + sum(isnew & df$pass_new & lengths(conds_list) == 0 & branch == "OT")
    S$c13 <- S$c13 + sum(isnew & df$g1_size & df$g2_impact & df$g3_rate & !df$sensitive)
    S$c14 <- S$c14 + sum(isnew & df$g1_size & df$g2_impact & df$g3_rate & df$g4_heldout & !df$sensitive)
    keep <- if (real) isnew & df$n >= MIN_STORE else rep(FALSE, nrow(df))
    if (any(keep)) { ii <- which(keep); S$rows[[length(S$rows) + 1]] <- cbind(df[ii, ], source = if (length(src) == 1) src else src[ii], stringsAsFactors = FALSE)
      S$conds[[length(S$conds) + 1]] <- conds_list[ii] }
    if (real) { dd <- which(!isnew & df$g1_size & df$g3_rate); if (length(dd)) S$dups[[length(S$dups) + 1]] <- list(key = key[dd], branch = branch[dd], conds = conds_list[dd]) }
    for (i in which(isnew & (df$pass_new | df$pass_sens | df$pass_pv | (df$pv_gates & lengths(conds_list) <= PV_DRILL_MAX)))) { if (length(conds_list[[i]]) >= MAX_DRILL_COND) { S$capped <- S$capped + 1; next }
      S$queue[[length(S$queue) + 1]] <- list(branch = branch[i], conds = conds_list[[i]], row = df[i, ], src = if (length(src) == 1) src else src[i]) }
    list(rows = df, conds = conds_list) }

  # 1) static groups
  invisible(process_batch(STATIC$M, STATIC$branch, STATIC$conds, STATIC$src))
  # 2) trees on training rows only
  xv <- if (real) 10 else 0
  trees <- list(full = grow_tree(which(is_tr), y, MB_TR, xv, SEED, drop_ot = FALSE),
                OT = grow_tree(which(is_tr & BR$OT), y, MB_TR, xv, SEED, drop_ot = TRUE),
                nonOT = grow_tree(which(is_tr & BR$nonOT), y, MB_TR, xv, SEED, drop_ot = TRUE))
  pruned <- if (real) lapply(trees, function(t) prune_1se(t$fit)) else NULL
  # 3) drill roots first (company, overtime, no overtime), then every tree node, then qualifiers as they appear
  roots <- list(list(branch = "All", conds = list()), list(branch = "OT", conds = list()), list(branch = "nonOT", conds = list()))
  front <- list()
  for (rt in roots) { m <- if (rt$branch == "All") matrix(TRUE, N, 1) else matrix(BR[[rt$branch]], ncol = 1)
    Z <- cbind(1, y, is_tr, y * is_tr, IDX, IDX^2); r <- crossprod(m, Z)
    row <- build_rows(r[, 1], r[, 2], r[, 3], r[, 4], rt$branch, FALSE, PARv, PARTEST, PARTR); row$key <- paste(r[, 1], r[, 5], r[, 6], sep = "|")
    row$stab_within <- NA_real_; row$stab_old <- NA_real_; row$stab_unpruned <- NA_real_; row$stab_var_pruned <- NA_real_; row$stab_var_unpruned <- NA_real_; row$g5_stable <- NA; row$pass_new <- FALSE; row$pass_sens <- FALSE; row$pass_pv <- FALSE; row$pass_old <- FALSE
    front[[length(front) + 1]] <- list(branch = rt$branch, conds = list(), row = row, src = "company or branch root") }
  tn_all <- list()
  for (kind in names(trees)) { nd <- tree_nodes(trees[[kind]], kind); if (!length(nd)) next
    M <- do.call(cbind, lapply(nd, function(z) grp_mask(z$branch, z$conds)))
    pr_ids <- if (real) as.integer(rownames(pruned[[kind]]$fit$frame)) else integer()
    src <- vapply(nd, function(z) sprintf("%s tree node %d%s", c(full = "full-company training", OT = "overtime-branch training", nonOT = "no-overtime-branch training")[[kind]], z$id, if (z$id %in% pr_ids) " (in pruned tree)" else ""), "")
    res <- process_batch(M, vapply(nd, function(z) z$branch, ""), lapply(nd, function(z) z$conds), src)
    for (i in seq_along(nd)) if (res$rows$n[i] >= MIN_N && !res$rows$sensitive[i]) front[[length(front) + 1]] <- list(branch = nd[[i]]$branch, conds = nd[[i]]$conds, row = res$rows[i, ], src = src[i])
    tn_all[[kind]] <- list(nodes = nd, rows = res$rows, in_pruned = vapply(nd, function(z) z$id %in% pr_ids, TRUE)) }
  S$queue <- c(front, S$queue)
  # 4) drill loop
  while (S$qh <= length(S$queue)) { q <- S$queue[[S$qh]]; S$qh <- S$qh + 1; key <- q$row$key
    if (exists(key, envir = S$drilled, inherits = FALSE)) next; assign(key, TRUE, envir = S$drilled)
    mask <- grp_mask(q$branch, q$conds)
    vars <- setdiff(if (q$branch == "All") PRED else setdiff(PRED, "OverTime"), cvars(q$conds))
    a <- atoms_in(mask, vars, GRID_PROBS)
    if (ncol(a$M) == 0) { if (real) S$log[[length(S$log) + 1]] <- list(q = q, ch = NULL, cc = NULL); next }
    cl <- lapply(seq_len(nrow(a$A)), function(i) c(q$conds, list(acond(a$A, i))))
    res <- process_batch(a$M, q$branch, cl, "drill child")
    if (real) S$log[[length(S$log) + 1]] <- list(q = q, ch = res$rows, cc = res$conds) }
  out <- list(tested = S$tested, raw = S$raw, c13 = S$c13, c14 = S$c14, c_new = S$c_new, c_sens = S$c_sens, c_pv = S$c_pv, c_pvg = S$c_pvg, c_root = S$c_root, tb = S$tb, tb100 = S$tb100, capped = S$capped, drilled = length(S$drilled), S = S, trees = trees, pruned = pruned, tn = tn_all, PARv = PARv)
  out$rows <- if (length(S$rows)) do.call(rbind, S$rows) else NULL
  out$conds <- unlist(S$conds, recursive = FALSE); out }

# =================================================================== REAL RUN
cat("real search...\n"); logp("real search start")
R <- cached("real_search", function() search(y_all, TRUE, SEED, NC)); logp("real search done: tested %d, qualifying %d", R$tested, R$c_new)
A <- R$rows; AC <- R$conds; stopifnot(nrow(A) == length(AC))
A$id <- sprintf("g%05d", seq_len(nrow(A)))
A$label <- mapply(tech_label, A$branch, AC); A$plain <- mapply(plain_label, A$branch, AC)
A$n_conditions <- lengths(AC) + (A$branch != "All"); A$exec_describable <- A$n_conditions <= MAX_COND_EXEC
CSV <- c("TotalWorkingYears", "YearsAtCompany", "YearsInCurrentRole", "YearsWithCurrManager", "YearsSinceLastPromotion", "JobLevel", "MonthlyIncome")
A$career_stage_only <- vapply(AC, function(cs) length(cs) > 0 && all(cvars(cs) %in% CSV), TRUE)
A$n_defining_vars <- vapply(AC, function(cs) length(unique(cvars(cs))), 0L)
# aliases: other definitions that give exactly the same people (kept only for groups that pass size and rate)
al <- list(); for (dp in R$S$dups) for (i in seq_along(dp$key)) al[[dp$key[i]]] <- c(al[[dp$key[i]]], tech_label(dp$branch[i], dp$conds[[i]]))
A$also_defined_as <- vapply(A$key, function(k) if (is.null(al[[k]])) "" else paste(head(unique(al[[k]]), 3), collapse = " | "), "")
fail_txt <- function(r) { f <- c(if (!r$g1_size) "size", if (!r$g2_impact) "impact (<15 excess leavers)", if (!r$g3_rate) "rate (lift/Wilson)",
    if (r$test_too_small) "test too small" else if (!r$g4_heldout) "held-out direction", if (is.na(r$g5_stable) || !r$g5_stable) "stability"); paste(f, collapse = "; ") }
A$fails <- vapply(seq_len(nrow(A)), function(i) fail_txt(A[i, ]), "")
A$status <- with(A, ifelse(sensitive & g1_size & g3_rate, "descriptive only (age, gender or marital status; not headlined)",
  ifelse(pass_new, "QUALIFYING (passes rules 1-5)",
  ifelse(pass_sens, "supported; fails 1-SE stability, stable when unpruned",
  ifelse(g1_size & g2_impact & g3_rate & test_too_small, "supported on the full data, test too small (not cleared)",
  ifelse(g1_size & g2_impact & g3_rate, paste0("supported on the full data only (fails: ", fails, ")"),
  ifelse(!g1_size & lift >= MIN_LIFT, "too small to act on",
  "below the size, impact or rate gates")))))))
A$old_rule <- ifelse(A$pass_old, "passes old rule", "fails old rule")
A$new_rule <- ifelse(A$pass_new, "passes new rule", "fails new rule")
A$gates_1to4_new <- A$g1_size & A$g2_impact & A$g3_rate & A$g4_heldout
A$gates_1to3_old <- A$g1_size & A$lift_ge_1.5 & A$g4_heldout            # old rule before its stability rule
cat("tested", R$tested, "stored", nrow(A), "qualifying", sum(A$pass_new), "supported-unpruned", sum(A$pass_sens), "\n")

# =================================================================== TREE OUTPUT FILES
cat("trees, cut stability...\n")
tr_print <- function(file, title, items) { sink(file); cat(title, "\n\n"); for (it in items) { cat("----", it$name, "----\n"); print(it$fit); cat("\ncp table (grown at cp 0.001):\n"); print(it$fit$cptable)
    if (!is.null(it$pr)) { cat("\n1-SE rule picks cp", signif(it$pr$cp, 4), "with", it$pr$nsplit, "splits. Pruned tree:\n"); print(it$pr$fit) }; cat("\n") }; sink() }
ref_full <- grow_tree(seq_len(N), y_all, MB_FULL, 10, SEED); ref_OT <- grow_tree(which(BR$OT), y_all, MB_FULL, 10, SEED, drop_ot = TRUE); ref_nOT <- grow_tree(which(BR$nonOT), y_all, MB_FULL, 10, SEED, drop_ot = TRUE)
PR_ref <- lapply(list(full = ref_full, OT = ref_OT, nonOT = ref_nOT), function(t) prune_1se(t$fit))
hdr <- function(w) sprintf("Rate tree (rpart method=anova on 0/1 attrition; xerror = cross-validated Brier risk relative to the root). %s. Grown at cp 0.001, maxdepth %d (no hard cap in practice), 10-fold cross-validation (seed %d), 1-SE pruning.", w, MAXD, SEED)
tr_print(file.path(OUT, "tree_full_deep.txt"), hdr("Whole company"), list(
  list(name = sprintf("TRAINING rows only (n=%d), minbucket %d, minsplit %d: the tree whose nodes are tested", NTR, MB_TR, 2 * MB_TR), fit = R$trees$full$fit, pr = R$pruned$full),
  list(name = sprintf("Reference only, all %d rows, minbucket %d, minsplit %d (not used for any test: its cuts would see the test rows)", N, MB_FULL, 2 * MB_FULL), fit = ref_full$fit, pr = PR_ref$full)))
tr_print(file.path(OUT, "tree_overtime_branch.txt"), hdr("Overtime branch (OverTime = Yes rows only)"), list(
  list(name = sprintf("TRAINING overtime rows (n=%d), minbucket %d: the tree whose nodes are tested", sum(is_tr & BR$OT), MB_TR), fit = R$trees$OT$fit, pr = R$pruned$OT),
  list(name = sprintf("Reference only, all %d overtime rows, minbucket %d (not used for any test)", sum(BR$OT), MB_FULL), fit = ref_OT$fit, pr = PR_ref$OT)))
tr_print(file.path(OUT, "tree_nonovertime_branch.txt"), hdr("Non-overtime branch (OverTime = No rows only)"), list(
  list(name = sprintf("TRAINING non-overtime rows (n=%d), minbucket %d: the tree whose nodes are tested", sum(is_tr & BR$nonOT), MB_TR), fit = R$trees$nonOT$fit, pr = R$pruned$nonOT),
  list(name = sprintf("Reference only, all %d non-overtime rows, minbucket %d (not used for any test)", sum(BR$nonOT), MB_FULL), fit = ref_nOT$fit, pr = PR_ref$nonOT)))
cp_md <- function(f) { ct <- f$cptable; c("| CP | splits | rel error | xerror | xstd |", "|---|---|---|---|---|", sprintf("| %.4f | %d | %.4f | %.4f | %.4f |", ct[, "CP"], ct[, "nsplit"], ct[, "rel error"], ct[, "xerror"], ct[, "xstd"])) }
node_leaves <- function(t) { f <- t$fit; fr <- f$frame; sum(fr$var == "<leaf>") }

# refit cut stability table
cs_rows <- list()
for (sc in c("All", "OT", "nonOT")) for (ty in c("pruned", "unpruned")) { st <- if (ty == "pruned") R$S$stores[[sc]] else R$S$stores[[paste0("u_", sc)]]; if (is.null(st)) next
  for (v in sort(unique(st$sp$var))) { z <- st$sp[st$sp$var == v, ]; num <- any(!is.na(z$cut))
    cs_rows[[length(cs_rows) + 1]] <- data.frame(scope = c(All = "all staff (nodes 1-3 of depth-3 refits)", OT = "overtime branch", nonOT = "no-overtime branch")[[sc]], refits = ty, variable = v,
      share_of_refits_with_split = length(unique(z$b)) / st$B, cut_q25 = if (num) quantile(z$cut, .25, na.rm = TRUE) else NA, cut_median = if (num) median(z$cut, na.rm = TRUE) else NA, cut_q75 = if (num) quantile(z$cut, .75, na.rm = TRUE) else NA, row.names = NULL) } }
CUTSTAB <- do.call(rbind, cs_rows); CUTSTAB <- CUTSTAB[order(CUTSTAB$scope, CUTSTAB$refits, -CUTSTAB$share_of_refits_with_split), ]
NOSPLIT <- data.frame(scope = c("all staff", "overtime", "no overtime", "overtime", "no overtime"), refits = c("pruned", "pruned", "pruned", "unpruned", "unpruned"),
  refits_with_no_split = c(R$S$stores$All$n_pruned_root, R$S$stores$OT$n_pruned_root, R$S$stores$nonOT$n_pruned_root, R$S$stores$u_OT$n_pruned_root, R$S$stores$u_nonOT$n_pruned_root),
  of = c(R$S$stores$All$B, R$S$stores$OT$B, R$S$stores$nonOT$B, R$S$stores$u_OT$B, R$S$stores$u_nonOT$B))

# career-stage family: share of refits where at least one career-stage variable is a primary split
fam_row <- function(st, label, ty) data.frame(scope = label, refits = ty, any_career_stage_variable = length(unique(st$sp$b[st$sp$var %in% CSV])) / st$B, any_variable = length(unique(st$sp$b)) / st$B)
FAM <- rbind(fam_row(R$S$stores$All, "all staff (nodes 1-3)", "pruned"), fam_row(R$S$stores$OT, "overtime", "pruned"), fam_row(R$S$stores$nonOT, "no overtime", "pruned"),
             fam_row(R$S$stores$u_OT, "overtime", "unpruned"), fam_row(R$S$stores$u_nonOT, "no overtime", "unpruned"))
# best training-derived low-side cut per variable and branch
A$var1 <- vapply(AC, function(cs) if (length(cs)) cs[[1]]$var else "", ""); A$op1 <- vapply(AC, function(cs) if (length(cs)) cs[[1]]$op else "", "")
A$cut1 <- vapply(AC, function(cs) if (length(cs)) cs[[1]]$cut else NA_real_, 0)
NUMV <- PRED[sapply(PRED, function(v) is.numeric(d[[v]]))]
best_rows <- list()
for (b in c("All", "OT", "nonOT")) for (v in NUMV) { z <- which(A$branch == b & A$n_conditions == (b != "All") + 1 & A$var1 == v & A$op1 == "<" & A$n >= MIN_N)
  if (!length(z)) next; i <- z[which.max(if (b == "All") A$train_excess[z] else A$train_excess_parent[z])]
  cst <- CUTSTAB[CUTSTAB$scope == c(All = "all staff (nodes 1-3 of depth-3 refits)", OT = "overtime branch", nonOT = "no-overtime branch")[[b]] & CUTSTAB$variable == v & CUTSTAB$refits == "pruned", ]
  best_rows[[length(best_rows) + 1]] <- data.frame(branch = b, variable = v, best_group = A$label[i], cut = A$cut1[i], n = A$n[i], rate = A$rate[i], lift = A$lift[i], excess = A$excess[i], excess_vs_parent = A$excess_vs_parent[i],
    test_n = A$test_n[i], test_rate = A$test_rate[i], stab_within_1se = A$stab_within[i], stab_unpruned = A$stab_unpruned[i], stab_var_any_cut_1se = A$stab_var_pruned[i], refits_splitting_on_var_1se = if (nrow(cst)) cst$share_of_refits_with_split else 0,
    refit_cut_q25 = if (nrow(cst)) cst$cut_q25 else NA, refit_cut_median = if (nrow(cst)) cst$cut_median else NA, refit_cut_q75 = if (nrow(cst)) cst$cut_q75 else NA, sensitive = v %in% SENS, row.names = NULL) }
BEST <- do.call(rbind, best_rows)
BEST$cut_inside_refit_middle_half <- !is.na(BEST$refit_cut_q25) & BEST$cut >= BEST$refit_cut_q25 & BEST$cut <= BEST$refit_cut_q75

# =================================================================== CEO CHECK: low-experience groups inside each branch
desc <- function(m, parent_rate) { n <- sum(m); lv <- sum(y_all[m]); tn <- sum(m & !is_tr); tl <- sum(y_all[m & !is_tr]); w <- wilson_v(lv, n)
  list(n = n, leavers = lv, rate = lv / n, lift = lv / n / AVG, wilson_lo = w[1], excess = lv - n * AVG, impact_pts = 100 * (lv - n * AVG) / N, excess_vs_parent = lv - n * parent_rate, test_n = tn, test_rate = tl / tn) }
CEO <- list(); CEO_MASK <- list()
for (b in c("nonOT", "OT")) { prate <- mean(y_all[BR[[b]]]); bm <- BR[[b]]
  bb <- BEST[BEST$branch == b & !BEST$sensitive & BEST$variable %in% c("TotalWorkingYears", "YearsAtCompany", "YearsInCurrentRole", "YearsWithCurrManager", "YearsSinceLastPromotion", "JobLevel", "MonthlyIncome"), ]
  jl1 <- bm & d$JobLevel < 2; lowpay_cut <- bb$cut[bb$variable == "MonthlyIncome"]; lowpay <- bm & d$MonthlyIncome < lowpay_cut
  base_union <- jl1 | lowpay
  for (k in seq_len(nrow(bb))) { v <- bb$variable[k]; m <- bm & d[[v]] < bb$cut[k]; ds <- desc(m, prate); outside <- m & !base_union; uni <- base_union | m
    ud <- desc(uni, prate); bd <- desc(base_union, prate); od <- desc(outside, prate); m2 <- m & !jl1
    CEO[[length(CEO) + 1]] <- data.frame(branch = b, group = plain_label(b, list(mkc(v, "<", bb$cut[k]))), variable = v, cut = bb$cut[k], n = ds$n, pct_of_branch = ds$n / sum(bm), leavers = ds$leavers, pct_of_all_leavers = ds$leavers / L, pct_of_branch_leavers = ds$leavers / sum(y_all[bm]), rate = ds$rate, branch_rate = prate, rate_vs_branch = ds$rate / prate,
      lift_vs_company = ds$lift, wilson_lo = ds$wilson_lo, excess_vs_company = ds$excess, impact_pts_vs_company = ds$impact_pts, excess_vs_branch = ds$excess_vs_parent, test_n = ds$test_n, test_rate = ds$test_rate,
      stab_within_1se = bb$stab_within_1se[k], stab_unpruned = bb$stab_unpruned[k], stab_var_any_cut_1se = bb$stab_var_any_cut_1se[k], refit_cut_median = bb$refit_cut_median[k], refit_cut_q25 = bb$refit_cut_q25[k], refit_cut_q75 = bb$refit_cut_q75[k],
      pct_in_joblevel1 = mean(jl1[m]), pct_in_lowpay = mean(lowpay[m]), lowpay_cut = lowpay_cut,
      n_outside_jl1_and_lowpay = od$n, leavers_outside = od$leavers, rate_outside = od$rate, excess_outside_vs_branch = od$excess_vs_parent,
      excess_vs_branch_of_jl1_or_lowpay = bd$excess_vs_parent, excess_vs_branch_of_union = ud$excess_vs_parent, incremental_excess_vs_branch = ud$excess_vs_parent - bd$excess_vs_parent,
      incremental_excess_vs_company = ud$excess - bd$excess, rate_in_joblevel2plus = { mm <- m & d$JobLevel >= 2; if (sum(mm)) mean(y_all[mm]) else NA }, n_in_joblevel2plus = sum(m & d$JobLevel >= 2), row.names = NULL)
    CEO_MASK[[paste(b, v)]] <- m }
  CEO_MASK[[paste(b, "JL1")]] <- jl1; CEO_MASK[[paste(b, "lowpay")]] <- lowpay }
CEOD <- do.call(rbind, CEO)
# reference rows: JobLevel 1 and lowpay inside each branch are rows of the table above (variables JobLevel, MonthlyIncome)

# =================================================================== OVERLAP, ROLES, UNION
cat("overlap...\n")
masks_of <- function(idx) { if (!length(idx)) return(matrix(FALSE, N, 0)); do.call(cbind, lapply(idx, function(i) grp_mask(A$branch[i], AC[[i]]))) }
cluster_groups <- function(idx) { idx <- idx[order(-A$excess[idx], A$n_conditions[idx])]; M <- masks_of(idx); nn <- colSums(M); co <- crossprod(M * 1); ll <- crossprod(M * y_all, M * 1)
  jac <- co / (outer(nn, nn, "+") - co); role <- character(length(idx)); ref <- rep(NA_integer_, length(idx)); heads <- integer()
  for (k in seq_along(idx)) { same <- heads[jac[k, heads] >= SAME_J]; if (length(same)) { role[k] <- "same people as a listed group"; ref[k] <- idx[same[1]]; next }
    nest <- heads[co[k, heads] / nn[k] >= NEST_C]; if (length(nest)) { role[k] <- "mostly inside a listed group"; ref[k] <- idx[nest[1]]; next }
    role[k] <- "distinct"; heads <- c(heads, k) }
  list(idx = idx, M = M, n = nn, co = co, lc = ll, jac = jac, role = role, ref = ref, heads = heads) }
Q <- which(A$pass_new & !A$sensitive)
CLQ <- cluster_groups(Q)
pair_tab <- function(CL, only = seq_along(CL$idx)) { out <- list()
  for (a in only) for (b in only) if (a < b && CL$co[a, b] > 0) {
    sa <- CL$co[a, b] / CL$n[a]; sb <- CL$co[a, b] / CL$n[b]
    rel <- if (CL$jac[a, b] >= SAME_J) "essentially the same people" else if (max(sa, sb) >= NEST_C) "one is inside the other" else "partial overlap"
    out[[length(out) + 1]] <- data.frame(group_a = A$id[CL$idx[a]], label_a = A$label[CL$idx[a]], group_b = A$id[CL$idx[b]], label_b = A$label[CL$idx[b]],
      n_a = CL$n[a], n_b = CL$n[b], employees_in_common = CL$co[a, b], leavers_in_common = CL$lc[a, b], share_of_a_in_b = sa, share_of_b_in_a = sb,
      jaccard = CL$jac[a, b], relation = rel, stringsAsFactors = FALSE) }
  if (length(out)) do.call(rbind, out) else NULL }
union_stats <- function(M, label) { m <- rowSums(M) > 0; ds <- desc(m, AVG); data.frame(set = label, n = ds$n, pct_staff = ds$n / N, leavers = ds$leavers, pct_leavers = ds$leavers / L, rate = ds$rate, excess_vs_company = ds$excess, impact_pts_vs_company = ds$impact_pts, stringsAsFactors = FALSE) }
# supported-on-full-data-only lists (distinct patterns)
SUP_IDX <- which(!A$sensitive & A$g1_size & A$g2_impact & A$g3_rate & !A$pass_new & A$g4_heldout)
SUPT_IDX <- which(!A$sensitive & A$g1_size & A$g2_impact & A$g3_rate & A$test_too_small)
PV_IDX <- which(!A$sensitive & A$pv_gates & !A$pass_new & A$n_conditions <= 3 & A$career_stage_only)
cat("clusters for supported lists...\n")
CLS <- cluster_groups(SUP_IDX); CLP <- cluster_groups(PV_IDX)

# =================================================================== DRILL LOG (every drilled node with >= 100 employees)
cat("drill log...\n")
node_status <- function(r) { if (isTRUE(r$pass_new)) return("qualifies (rules 1-5)"); if (isTRUE(r$pass_sens)) return("supported; unstable under 1-SE pruning")
  if (isTRUE(r$pass_pv)) return("clear against its own branch, with stability"); if (isTRUE(r$g1_size) && isTRUE(r$g2_impact) && isTRUE(r$g3_rate)) return("supported on the full data only")
  if (isTRUE(r$pv_gates)) return("clear against its own branch only (not stable)"); "context node (not itself a qualifying group)" }
best_txt <- function(x) if (is.null(x) || !nrow(x)) c(NA, NA, NA, NA, NA, NA) else c(x$label[1], x$n[1], round(x$rate[1], 4), round(x$excess[1], 1), round(x$excess_vs_parent[1], 1), x$fails[1])
DLR <- list()
for (e in R$S$log) { q <- e$q; r <- q$row; ch <- e$ch
  base <- data.frame(node_source = q$src, branch = c(All = "whole company", OT = "overtime branch", nonOT = "no-overtime branch")[[q$branch]], node = tech_label(q$branch, q$conds), node_plain = plain_label(q$branch, q$conds),
    defining_conditions = length(q$conds) + (q$branch != "All"), n = r$n, leavers = r$leavers, rate = round(r$rate, 4), rate_vs_parent = round(r$rate_vs_parent, 3), node_status = node_status(r), stringsAsFactors = FALSE)
  if (is.null(ch)) { base[c("children_tested", "children_100plus", "children_pass_1to3", "children_pass_1to4", "children_qualifying", "children_supported_other", "best_child_by_company_excess", "best_child_n", "best_child_rate", "best_child_excess", "best_child_excess_vs_parent", "best_child_fails", "verdict")] <-
      list(0, 0, 0, 0, 0, 0, NA, NA, NA, NA, NA, NA, "no splittable children"); DLR[[length(DLR) + 1]] <- base; next }
  big <- ch$n >= MIN_N & !ch$sensitive; ch$label <- NA; ch$fails <- vapply(seq_len(nrow(ch)), function(i) fail_txt(ch[i, ]), "")
  chb <- ch[big, , drop = FALSE]; cc <- e$cc[big]; if (nrow(chb)) chb$label <- mapply(tech_label, rep(q$branch, nrow(chb)), cc)
  c13 <- sum(chb$g1_size & chb$g2_impact & chb$g3_rate); c14 <- sum(chb$g1_size & chb$g2_impact & chb$g3_rate & chb$g4_heldout)
  cq <- sum(chb$pass_new); co <- sum(chb$pass_sens | chb$pass_pv & !chb$pass_new)
  bt <- chb[order(-chb$excess), ][seq_len(min(1, nrow(chb))), , drop = FALSE]
  verdict <- if (!nrow(chb)) "no child has 100 or more employees" else if (cq > 0) sprintf("%d child group(s) qualify: %s", cq, paste(head(chb$label[chb$pass_new], 3), collapse = " | "))
    else if (co > 0) sprintf("%d child group(s) supported by the sensitivity checks: %s", co, paste(head(chb$label[chb$pass_sens | chb$pass_pv], 2), collapse = " | "))
    else if (c14 > 0) sprintf("%d children pass size, impact, rate and the test set but are not stable as splits; none qualifies", c14)
    else if (c13 > 0) sprintf("%d children pass size, impact and rate on the full data but not the test-set check; none qualifies", c13)
    else sprintf("no child passes the effect gates; best child adds %.1f people above the company rate", bt$excess)
  b <- best_txt(bt)
  base[c("children_tested", "children_100plus", "children_pass_1to3", "children_pass_1to4", "children_qualifying", "children_supported_other", "best_child_by_company_excess", "best_child_n", "best_child_rate", "best_child_excess", "best_child_excess_vs_parent", "best_child_fails", "verdict")] <-
    list(nrow(ch), sum(ch$n >= MIN_N), c13, c14, cq, co, b[1], b[2], b[3], b[4], b[5], b[6], verdict)
  DLR[[length(DLR) + 1]] <- base }
DRILL <- do.call(rbind, DLR); DRILL <- DRILL[order(DRILL$branch, DRILL$defining_conditions, -DRILL$n), ]
DRILL$children_qualifying_were_drilled <- NA
qual_keys <- A$key[A$pass_new]; drilled_keys <- ls(R$S$drilled)
STOP_UNDRILLED <- sum(!(qual_keys %in% drilled_keys))
N_NODES_CHILD_QUAL <- sum(DRILL$children_qualifying > 0)

# =================================================================== RULE COMPARISON (old vs new on the same tested groups)
ok <- !A$sensitive & A$n >= MIN_N
CMP14 <- table(new_gates_1to4 = A$gates_1to4_new[ok], old_gates_1to3 = A$gates_1to3_old[ok])
CMP_FINAL <- table(new_rule_passes = A$pass_new[ok], old_rule_passes = A$pass_old[ok])
NEW_ONLY <- which(ok & A$gates_1to4_new & !A$gates_1to3_old); OLD_ONLY <- which(ok & A$gates_1to3_old & !A$gates_1to4_new)
OLD_ONLY_WHY <- c(impact_under_15 = sum(!A$g2_impact[OLD_ONLY]), wilson_not_above_company = sum(A$g2_impact[OLD_ONLY] & !A$g3_rate[OLD_ONLY]))
NEW_ONLY_LIFT <- range(A$lift[NEW_ONLY])
OLDX <- read.csv("analysis/exec/candidates.csv", stringsAsFactors = FALSE)       # read-only: the earlier run

# =================================================================== NULL CALIBRATION
cat("null calibration (", N_SHUF, "x2 shuffles)...\n")
shuffle_y <- function(s, type) { set.seed(SEED + 7000 + s + (type == "within_overtime") * 500000); y <- y_all
  if (type == "global") { y[is_tr] <- sample(y[is_tr]); y[!is_tr] <- sample(y[!is_tr]) }
  else for (g in list(is_tr & BR$OT, is_tr & BR$nonOT, !is_tr & BR$OT, !is_tr & BR$nonOT)) y[g] <- sample(y[g])
  y }
null_fun <- function(s, type) { v <- cached(sprintf("null_%s_%03d", type, s), function() { r <- search(shuffle_y(s, type), FALSE, SEED + 100000 * s + (type == "within_overtime") * 50000000, 1); null_vec(r) })
  logp("null %s shuffle %d done", type, s); v }
null_vec <- function(r) c(tested = r$tested, drilled = r$drilled, pass_1to3 = r$c13, pass_1to4 = r$c14, pass_1to5 = r$c_new, pass_unpruned_check = r$c_sens, pass_parent_view_stable = r$c_pv, parent_view_gates_1to4 = r$c_pvg, ot_root = r$c_root)
NULLRES <- list()
for (ty in c("global", "within_overtime")) { logp("null calibration %s start", ty); rr <- mclapply(seq_len(N_SHUF), null_fun, type = ty, mc.cores = NC, mc.set.seed = FALSE)
  bad <- vapply(rr, function(z) inherits(z, "try-error") || is.null(z), TRUE); if (any(bad)) stop("null calibration failed in ", sum(bad), " shuffles")
  NULLRES[[ty]] <- do.call(rbind, rr) }
null_sum <- function(m, col, excl_root = FALSE) { v <- m[, col] - if (excl_root) m[, "ot_root"] else 0; c(mean = mean(v), p95 = unname(quantile(v, 0.95)), max = max(v), share_with_any = mean(v > 0)) }
REAL_COUNTS <- c(tested = R$tested, drilled = R$drilled, pass_1to3 = R$c13, pass_1to4 = R$c14, pass_1to5 = R$c_new, pass_unpruned_check = R$c_sens, pass_parent_view_stable = R$c_pv, parent_view_gates_1to4 = R$c_pvg)
cat("null done\n")

# =================================================================== WRITE CSV FILES
cat("writing files...\n")
rnd <- function(df) { for (nm in names(df)) if (is.numeric(df[[nm]]) && !is.integer(df[[nm]])) df[[nm]] <- signif(df[[nm]], 5); df }
A$impact_people <- A$excess; A$impact_to_parent_rate_people <- A$excess_vs_parent
A$test_too_small_flag <- A$test_too_small
col_order <- c("id", "label", "plain", "branch", "n_conditions", "exec_describable", "career_stage_only", "sensitive", "source", "status",
  "n", "pct_staff", "leavers", "pct_leavers", "rate", "lift", "wilson_lo", "wilson_hi", "train_n", "train_rate", "test_n", "test_leavers", "test_rate",
  "excess", "impact_pts", "impact_people", "parent_rate", "rate_vs_parent", "excess_vs_parent", "impact_parent_pts", "impact_to_parent_rate_people", "wilson_lo_above_parent",
  "g1_size", "g2_impact", "g3_rate", "g4_heldout", "test_too_small", "g5_stable", "pass_new", "pass_sens", "pv_gates", "pass_pv", "lift_ge_1.5", "gates_1to4_new", "gates_1to3_old",
  "stab_within", "stab_unpruned", "stab_var_pruned", "stab_var_unpruned", "stab_old", "pass_old", "fails", "also_defined_as", "key")
names(A)[names(A) == "pct_staff"] <- "pct_staff"
CAND <- rnd(A[order(-A$excess), col_order]); CAND$pct_staff <- CAND$pct_staff * 100; CAND$pct_leavers <- CAND$pct_leavers * 100
write.csv(CAND, file.path(OUT, "candidates_all.csv"), row.names = FALSE)
QDF <- A[Q, ]; QDF$role <- CLQ$role[match(Q, CLQ$idx)]; QDF$related_to <- ifelse(is.na(CLQ$ref[match(Q, CLQ$idx)]), "", A$label[CLQ$ref[match(Q, CLQ$idx)]])
QDF$share_of_people_inside_related <- NA_real_
for (k in seq_along(CLQ$idx)) if (!is.na(CLQ$ref[k])) { kk <- match(CLQ$ref[k], CLQ$idx); QDF$share_of_people_inside_related[QDF$id == A$id[CLQ$idx[k]]] <- CLQ$co[k, kk] / CLQ$n[k] }
write.csv(rnd(QDF[order(-QDF$excess), c("id", "label", "plain", "branch", "n_conditions", "exec_describable", "career_stage_only", "role", "related_to", "share_of_people_inside_related", "n", "pct_staff", "leavers", "pct_leavers", "rate", "lift", "wilson_lo", "wilson_hi", "test_n", "test_rate",
  "excess", "impact_pts", "parent_rate", "rate_vs_parent", "excess_vs_parent", "impact_parent_pts", "stab_within", "stab_unpruned", "stab_old", "pass_old", "also_defined_as")]), file.path(OUT, "qualifying.csv"), row.names = FALSE)
TOPS <- unique(c(Q, head(CLS$idx[CLS$heads], 15), head(CLP$idx[CLP$heads], 15)))
CLO <- cluster_groups(TOPS); OVT <- pair_tab(CLO)
OVT$set_a <- ifelse(match(OVT$group_a, A$id) %in% Q, "qualifying", ifelse(match(OVT$group_a, A$id) %in% SUP_IDX, "supported on the full data only", "clear against own branch only"))
OVT$set_b <- ifelse(match(OVT$group_b, A$id) %in% Q, "qualifying", ifelse(match(OVT$group_b, A$id) %in% SUP_IDX, "supported on the full data only", "clear against own branch only"))
write.csv(rnd(OVT), file.path(OUT, "overlap.csv"), row.names = FALSE)
write.csv(rnd(DRILL[, setdiff(names(DRILL), "children_qualifying_were_drilled")]), file.path(OUT, "drill_log.csv"), row.names = FALSE)
write.csv(rnd(CUTSTAB), file.path(OUT, "cut_stability.csv"), row.names = FALSE)
write.csv(rnd(BEST), file.path(OUT, "best_cuts.csv"), row.names = FALSE)
write.csv(rnd(CEOD), file.path(OUT, "ceo_check.csv"), row.names = FALSE)

# career-stage overlap inside the no-overtime branch (share of the row group's people who are also in the column group)
CSN <- grep("^nonOT ", names(CEO_MASK), value = TRUE); CSN <- CSN[!grepl("JL1|lowpay", CSN)]
CS_OV <- sapply(CSN, function(a) sapply(CSN, function(b) sum(CEO_MASK[[a]] & CEO_MASK[[b]]) / sum(CEO_MASK[[a]])))
rownames(CS_OV) <- colnames(CS_OV) <- sub("^nonOT ", "", CSN)
write.csv(rnd(data.frame(group = rownames(CS_OV), round(CS_OV, 4), check.names = FALSE)), file.path(OUT, "career_stage_overlap_nonovertime.csv"), row.names = FALSE)
# unions, counted once
UQ <- union_stats(CLQ$M, "all qualifying groups (employees counted once)")
nonOT_pv <- CEOD[CEOD$branch == "nonOT" & CEOD$rate_vs_branch >= MIN_LIFT & CEOD$excess_vs_branch >= PAR_EXC, ]
U_NONOT <- if (nrow(nonOT_pv)) { M <- do.call(cbind, lapply(seq_len(nrow(nonOT_pv)), function(k) CEO_MASK[[paste("nonOT", nonOT_pv$variable[k])]])); ds <- desc(rowSums(M) > 0, mean(y_all[BR$nonOT]))
  data.frame(set = "no-overtime low-experience, pay and job-level groups that are clear against their own branch's rate, counted once", n = ds$n, pct_staff = ds$n / N, leavers = ds$leavers, pct_leavers = ds$leavers / L, rate = ds$rate,
    excess_vs_company = ds$excess, impact_pts_vs_company = ds$impact_pts, excess_vs_branch = ds$excess_vs_parent, test_n = ds$test_n, test_rate = ds$test_rate, stringsAsFactors = FALSE) } else NULL
UOT <- {m <- BR$OT; ds <- desc(m, AVG); data.frame(set = "overtime workers", n = ds$n, pct_staff = ds$n / N, leavers = ds$leavers, pct_leavers = ds$leavers / L, rate = ds$rate, excess_vs_company = ds$excess, impact_pts_vs_company = ds$impact_pts, stringsAsFactors = FALSE)}
U_BOTH <- if (!is.null(U_NONOT)) { M <- cbind(BR$OT, do.call(cbind, lapply(seq_len(nrow(nonOT_pv)), function(k) CEO_MASK[[paste("nonOT", nonOT_pv$variable[k])]]))); union_stats(M, "overtime workers plus the no-overtime groups above, counted once") } else NULL

# =================================================================== NESTED INCREMENTAL IMPACT, DEEP NODES, TESTED PER BRANCH
ni_rows <- list()
for (a in seq_along(CLQ$idx)) for (b in seq_along(CLQ$idx)) if (a != b && CLQ$n[a] < CLQ$n[b] && CLQ$co[a, b] / CLQ$n[a] >= NEST_C) {
  ia <- CLQ$idx[a]; ib <- CLQ$idx[b]; rest <- CLQ$M[, b] & !CLQ$M[, a]; dr <- desc(rest, AVG); la <- A$leavers[ia]; na <- A$n[ia]; rp <- A$rate[ib]
  ni_rows[[length(ni_rows) + 1]] <- data.frame(inner_group = A$label[ia], inner_plain = A$plain[ia], outer_group = A$label[ib], outer_plain = A$plain[ib], n_inner = na, share_of_outer = na / A$n[ib], rate_inner = A$rate[ia], rate_outer = rp,
    n_outer_without_inner = dr$n, leavers_outer_without_inner = dr$leavers, rate_outer_without_inner = dr$rate, inner_people_above_company_rate = A$excess[ia], inner_extra_people_above_outer_rate = la - na * rp, inner_extra_points = 100 * (la - na * rp) / N,
    outer_people_above_company_rate = A$excess[ib], outer_without_inner_people_above_company_rate = dr$excess, note = "not additive: the inner group's people are already inside the outer group", stringsAsFactors = FALSE) }
NI <- if (length(ni_rows)) do.call(rbind, ni_rows) else NULL
if (!is.null(NI)) write.csv(rnd(NI), file.path(OUT, "nested_incremental_impact.csv"), row.names = FALSE) else write.csv(data.frame(note = "no nested qualifying groups"), file.path(OUT, "nested_incremental_impact.csv"), row.names = FALSE)
TB <- data.frame(Branch = c("whole company (groups not split by overtime first)", "overtime branch", "no-overtime branch"), `Distinct groups tested` = format(R$tb, big.mark = ","), `With 100+ people` = format(R$tb100, big.mark = ","),
  `Pass rules 1-3` = sapply(c("All", "OT", "nonOT"), function(b) format(sum(A$branch == b & !A$sensitive & A$g1_size & A$g2_impact & A$g3_rate), big.mark = ",")),
  `Pass rules 1-4` = sapply(c("All", "OT", "nonOT"), function(b) format(sum(A$branch == b & !A$sensitive & A$gates_1to4_new), big.mark = ",")),
  `Pass rules 1-5` = sapply(c("All", "OT", "nonOT"), function(b) sum(A$branch == b & A$pass_new)), check.names = FALSE, stringsAsFactors = FALSE, row.names = NULL)
write.csv(rnd(data.frame(branch = TB$Branch, tested = R$tb, tested_100plus = R$tb100, pass_1to3 = sapply(c("All", "OT", "nonOT"), function(b) sum(A$branch == b & !A$sensitive & A$g1_size & A$g2_impact & A$g3_rate)),
  pass_1to4 = sapply(c("All", "OT", "nonOT"), function(b) sum(A$branch == b & !A$sensitive & A$gates_1to4_new)), pass_1to5 = sapply(c("All", "OT", "nonOT"), function(b) sum(A$branch == b & A$pass_new)))), file.path(OUT, "groups_tested_by_branch.csv"), row.names = FALSE)
DEEPA <- which(A$n_conditions >= 3 & A$n >= MIN_N & !A$sensitive)
DEEP_STAT <- c(tested_100plus = length(DEEPA), pass_1to3 = sum(A$g1_size[DEEPA] & A$g2_impact[DEEPA] & A$g3_rate[DEEPA]), pass_1to4 = sum(A$gates_1to4_new[DEEPA]), qualifying = sum(A$pass_new[DEEPA]),
  test_too_small = sum(A$g1_size[DEEPA] & A$g2_impact[DEEPA] & A$g3_rate[DEEPA] & A$test_too_small[DEEPA]))
DEEP_IDX <- DEEPA[A$g1_size[DEEPA] & A$g2_impact[DEEPA] & A$g3_rate[DEEPA]]; DEEP_IDX <- head(DEEP_IDX[order(-A$excess[DEEP_IDX])], 300)

# =================================================================== MARKDOWN
cat("markdown...\n")
fnum <- function(x) ifelse(is.na(x), "n/a", vapply(x, function(z) if (is.na(z)) "n/a" else format(z, digits = 5, trim = TRUE), ""))
mdt <- function(df) { c(paste0("| ", paste(names(df), collapse = " | "), " |"), paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
  apply(df, 1, function(r) paste0("| ", paste(trimws(r), collapse = " | "), " |"))) }
pct <- function(x, k = 1) ifelse(is.na(x), "n/a", sprintf(paste0("%.", k, "f%%"), 100 * x))
pp <- function(x) ifelse(is.na(x), "n/a", sprintf("%.1f", x)); ppl <- function(x) sprintf("%.0f", x)
ts <- format(as.POSIXct(Sys.time(), tz = "America/Los_Angeles"), "%Y-%m-%d")
TH_WRITTEN <- TH$written_at
n_stored100 <- sum(A$n >= MIN_N); n_sens_tested <- sum(A$sensitive)
real_root_pass <- any(A$pass_new & A$branch == "OT" & A$n_conditions == 1)
ncount <- function(st) sum(grepl(st, A$status, fixed = TRUE) & !A$sensitive & A$n >= 0)
n_sup_only <- sum(!A$sensitive & grepl("^supported on the full data only", A$status)); n_sup_test <- sum(!A$sensitive & grepl("test too small", A$status)); n_small <- sum(A$status == "too small to act on" & !A$sensitive)
n_pass13 <- R$c13; n_pass14 <- R$c14
q_lines <- function(i) { r <- A[i, ]; sprintf("%s: %s people (%s of staff), %s left (%s), %s of all who left; %s people above the company rate (%s points of company attrition)",
    r$plain, format(r$n, big.mark = ","), pct(r$pct_staff), r$leavers, pct(r$rate), pct(r$pct_leavers), ppl(r$excess), pp(r$impact_pts)) }
lift_old_txt <- function(i) { r <- A[i, ]; c(sprintf("lift %s (%s the 1.5 floor)", F2(r$lift), if (r$lift_ge_1.5) "above" else "below"), sprintf("company-wide stability %s (%s)", pct(r$stab_old, 0), if (!is.na(r$stab_old) && r$stab_old > STAB_MIN) "pass" else "fail")) }

# ---- the table of qualifying patterns (plain language)
QO <- Q[order(-A$n[Q])]
q_tab <- data.frame(Pattern = A$plain[QO], People = format(A$n[QO], big.mark = ","), `% of staff` = pct(A$pct_staff[QO]), `Left` = sprintf("%d (%s)", A$leavers[QO], pct(A$rate[QO])), `% of all who left` = pct(A$pct_leavers[QO]),
  `People above the company rate (points)` = sprintf("%s (%s)", ppl(A$excess[QO]), pp(A$impact_pts[QO])), `People above its branch's rate (points)` = ifelse(A$branch[QO] == "All" | (A$branch[QO] != "All" & A$n_conditions[QO] == 1), "n/a (it is the branch)", sprintf("%s (%s)", ppl(A$excess_vs_parent[QO]), pp(A$impact_parent_pts[QO]))),
  `Test-set people and rate` = sprintf("%d, %s", A$test_n[QO], pct(A$test_rate[QO])), check.names = FALSE, stringsAsFactors = FALSE)
nest_lines <- character(); for (k in seq_along(CLQ$idx)) if (!is.na(CLQ$ref[k])) { kk <- match(CLQ$ref[k], CLQ$idx); nest_lines <- c(nest_lines, sprintf("- **%s** is %s inside **%s** (%s of its people are also in it); it is a narrower slice, so its numbers are not added to the larger group's.", A$plain[CLQ$idx[k]], if (CLQ$jac[k, kk] >= SAME_J) "essentially the same people as" else "mostly", A$plain[CLQ$ref[k]], pct(CLQ$co[k, kk] / CLQ$n[k], 0))) }

# ---- CEO check sentences
CN <- CEOD[CEOD$branch == "nonOT", ]; CNx <- CN[!CN$variable %in% c("JobLevel", "MonthlyIncome"), ]
cn_best <- CNx[which.max(CNx$excess_vs_branch), ]; cn_big <- CNx[which.max(CNx$excess_vs_company), ]
co_fails <- function(z) { f <- c(if (z$n < MIN_N | z$leavers < MIN_LV) "size", if (z$excess_vs_company < MIN_EXC) sprintf("impact vs company (%s people)", ppl(z$excess_vs_company)), if (!(z$lift_vs_company >= MIN_LIFT & z$wilson_lo > AVG)) "rate vs company",
  if (z$test_n < MIN_TN) "test too small" else if (!(z$test_rate > TEST_AVG)) "held-out direction", if (is.na(z$stab_within_1se) || z$stab_within_1se <= STAB_MIN) sprintf("stability (%s)", pct(z$stab_within_1se, 0))); if (length(f)) paste(f, collapse = "; ") else "none" }
CEOD$fails_company_gates <- vapply(seq_len(nrow(CEOD)), function(i) co_fails(CEOD[i, ]), "")
CN <- CEOD[CEOD$branch == "nonOT", ]; CO <- CEOD[CEOD$branch == "OT", ]
ceo_tab <- function(Z) data.frame(Group = Z$group, People = Z$n, `% of branch` = pct(Z$pct_of_branch, 0), `% of all who left` = pct(Z$pct_of_all_leavers, 1), `Left rate (branch average)` = sprintf("%s (%s)", pct(Z$rate), pct(Z$branch_rate)), `Times branch rate` = F2(Z$rate_vs_branch),
  `People above branch rate` = ppl(Z$excess_vs_branch), `People above company rate (points)` = sprintf("%s (%s)", ppl(Z$excess_vs_company), pp(Z$impact_pts_vs_company)), `Test people, rate` = sprintf("%d, %s", Z$test_n, pct(Z$test_rate, 0)),
  `Held up in refits (strict / loose)` = sprintf("%s / %s", pct(Z$stab_within_1se, 0), pct(Z$stab_unpruned, 0)), `% in job level 1` = pct(Z$pct_in_joblevel1, 0), `% in lower-paid group` = pct(Z$pct_in_lowpay, 0), check.names = FALSE, stringsAsFactors = FALSE)
add_tab <- function(Z) data.frame(Group = Z$group, `People outside job level 1 and lower pay` = Z$n_outside_jl1_and_lowpay, `Left rate there` = pct(Z$rate_outside), `People above branch rate there` = ppl(Z$excess_outside_vs_branch),
  `Extra people above branch rate when added to job level 1 + lower pay` = pp(Z$incremental_excess_vs_branch), `Rate among job level 2+ members` = sprintf("%s (%d people)", pct(Z$rate_in_joblevel2plus, 0), Z$n_in_joblevel2plus), check.names = FALSE, stringsAsFactors = FALSE)

# ---- supported lists: distinct patterns
top_distinct <- function(CL, k = 10) { h <- CL$heads[seq_len(min(k, length(CL$heads)))]; i <- CL$idx[h]
  data.frame(Pattern = A$plain[i], People = A$n[i], `Left rate` = pct(A$rate[i]), `People above the company rate` = ppl(A$excess[i]), `People above its branch rate` = ppl(A$excess_vs_parent[i]), `Test people, rate` = sprintf("%d, %s", A$test_n[i], pct(A$test_rate[i], 0)),
    `Held up in refits (strict / loose)` = sprintf("%s / %s", pct(A$stab_within[i], 0), pct(A$stab_unpruned[i], 0)), `Variants folded into it (same or mostly the same people)` = vapply(h, function(hh) sum(CL$role[CL$ref %in% CL$idx[hh] & !is.na(CL$ref)] != ""), 0L), check.names = FALSE, stringsAsFactors = FALSE) }
SUPS_T <- top_distinct(CLS, 10)
SUPT_IDX_ns <- SUPT_IDX[order(-A$excess[SUPT_IDX])]; CLT <- cluster_groups(head(SUPT_IDX_ns, 300)); SUPT_T <- top_distinct(CLT, 6)
PV_T <- top_distinct(CLP, 10)
NEWONLY_T <- { idx <- head(NEW_ONLY[order(-A$excess[NEW_ONLY])], 300); if (length(idx)) top_distinct(cluster_groups(idx), 8) else NULL }
OLDONLY_T <- { idx <- head(OLD_ONLY[order(-A$lift[OLD_ONLY])], 6); data.frame(Pattern = A$plain[idx], People = A$n[idx], `Left rate` = pct(A$rate[idx]), Lift = F2(A$lift[idx]), `People above the company rate` = ppl(A$excess[idx]), check.names = FALSE, stringsAsFactors = FALSE) }
SMALL_IDX <- which(A$status == "too small to act on" & !A$sensitive); SMALL_IDX <- SMALL_IDX[order(-A$excess[SMALL_IDX])]
SMALL_T <- { CLsm <- cluster_groups(head(SMALL_IDX, 300)); top_distinct(CLsm, 6) }
DEEP_T <- if (length(DEEP_IDX)) top_distinct(cluster_groups(DEEP_IDX), 8) else NULL
DEEP_DR <- DRILL[DRILL$defining_conditions >= 3, ]
deep_lines <- c(sprintf("%s groups with three or more defining conditions (counting the overtime split as one) and 100+ people were tested. %d pass size, impact and rate on all employees, %d of those also pass the held-out check, %d qualify, and %d have too few held-out people to confirm.", format(DEEP_STAT[["tested_100plus"]], big.mark = ","), DEEP_STAT[["pass_1to3"]], DEEP_STAT[["pass_1to4"]], DEEP_STAT[["qualifying"]], DEEP_STAT[["test_too_small"]]),
  sprintf("%d drilled nodes had three or more defining conditions%s.", nrow(DEEP_DR), if (nrow(DEEP_DR)) sprintf("; deepest: %d conditions", max(DEEP_DR$defining_conditions)) else ""))
ni_lines <- if (is.null(NI)) "No qualifying group is nested inside another." else c("Nested groups, incremental impact (the inner group's people are already counted in the outer group, so these are never added):", "",
  mdt(data.frame(`Inner group` = NI$inner_plain, `Outer group` = NI$outer_plain, `Inner people` = NI$n_inner, `Share of outer group` = pct(NI$share_of_outer, 0), `Left rate inner` = pct(NI$rate_inner), `Left rate outer` = pct(NI$rate_outer), `Left rate of the rest of the outer group` = sprintf("%s (%d people)", pct(NI$rate_outer_without_inner), NI$n_outer_without_inner),
    `Extra people above the outer group's rate` = ppl(NI$inner_extra_people_above_outer_rate), `Extra points` = pp(NI$inner_extra_points), check.names = FALSE, stringsAsFactors = FALSE)))

# ---- null calibration table
nc_tab <- function(ty) { m <- NULLRES[[ty]]; cols <- c("pass_1to3", "pass_1to4", "pass_1to5"); data.frame(Count = c("pass rules 1-3 (size, impact, rate)", "pass rules 1-4 (plus held-out)", "pass rules 1-5 (plus stability)"),
  Real = as.character(REAL_COUNTS[cols]), `Shuffled: mean` = sprintf("%.1f", sapply(cols, function(cn) null_sum(m, cn)["mean"])), `95th percentile` = sprintf("%.0f", sapply(cols, function(cn) null_sum(m, cn)["p95"])), Max = sprintf("%.0f", sapply(cols, function(cn) null_sum(m, cn)["max"])),
  `Shuffles with at least one` = pct(sapply(cols, function(cn) null_sum(m, cn)["share_with_any"]), 0), check.names = FALSE, stringsAsFactors = FALSE) }
null_g <- NULLRES$global; null_w <- NULLRES$within_overtime
g_p95_15 <- unname(null_sum(null_g, "pass_1to5")["p95"]); w_p95_15 <- unname(null_sum(null_w, "pass_1to5", TRUE)["p95"]); w_max_15 <- unname(null_sum(null_w, "pass_1to5", TRUE)["max"])
real_15_excl <- REAL_COUNTS[["pass_1to5"]] - as.integer(real_root_pass)
g_p95_14 <- unname(null_sum(null_g, "pass_1to4")["p95"]); w_p95_14 <- unname(null_sum(null_w, "pass_1to4")["p95"])
null_plain <- c(
  sprintf("With labels shuffled across everyone (%d shuffles), %.1f groups per shuffle pass rules 1-4 on average (95th percentile %.0f); the real data has %d. With labels shuffled only within overtime status (this keeps the overtime effect and removes everything else), the average is %.1f (95th percentile %.0f).",
    N_SHUF, null_sum(null_g, "pass_1to4")["mean"], g_p95_14, REAL_COUNTS[["pass_1to4"]], null_sum(null_w, "pass_1to4")["mean"], w_p95_14),
  sprintf("Passing all five rules: real data %d group(s) (%s); shuffled across everyone, %s%% of shuffles produce any (maximum %.0f); shuffled within overtime status, excluding the overtime group itself, %s%% of shuffles produce any (maximum %.0f).",
    REAL_COUNTS[["pass_1to5"]], if (real_root_pass) "including the overtime group itself" else "none of them the overtime group", sprintf("%.0f", 100 * null_sum(null_g, "pass_1to5")["share_with_any"]), null_sum(null_g, "pass_1to5")["max"],
    sprintf("%.0f", 100 * null_sum(null_w, "pass_1to5", TRUE)["share_with_any"]), w_max_15))
ot_share <- mean(null_w[, "pass_1to4"]) / REAL_COUNTS[["pass_1to4"]]
null_verdict <- paste0(
  if (real_15_excl > w_p95_15) sprintf("Besides the overtime group itself, the %d other group(s) clearing all five checks go beyond anything the %d shuffled searches produced (at most %.0f in any shuffle).", real_15_excl, N_SHUF, w_max_15)
  else "Besides the overtime group itself, the real data is NOT clearly above what shuffled labels produce for groups clearing all five checks.",
  sprintf(" Groups clearing the first four checks: %s in the real data versus %.0f on average (95th percentile %.0f) when labels are shuffled across everyone, and %.0f (95th percentile %.0f) when shuffled only within overtime status, which keeps the overtime effect. The real count is %s the shuffled range, but the real passers overlap heavily, so it is not a count of independent findings.",
    format(REAL_COUNTS[["pass_1to4"]], big.mark = ","), null_sum(null_g, "pass_1to4")["mean"], g_p95_14, null_sum(null_w, "pass_1to4")["mean"], w_p95_14, if (REAL_COUNTS[["pass_1to4"]] > w_p95_14) "above" else "not clearly above"))

# ---- refit statistics
nosplit <- NOSPLIT
nsp <- function(sc, ty) { r <- nosplit[nosplit$scope == sc & nosplit$refits == ty, ]; sprintf("%d of %d", r$refits_with_no_split, r$of) }
cut_for <- function(sc, v, ty = "pruned") { z <- CUTSTAB[CUTSTAB$scope == sc & CUTSTAB$variable == v & CUTSTAB$refits == ty, ]; if (!nrow(z)) "no splits" else sprintf("%s of refits split on it; cut median %s (middle half %s to %s)", pct(z$share_of_refits_with_split, 0), format(z$cut_median, digits = 5), format(z$cut_q25, digits = 5), format(z$cut_q75, digits = 5)) }
inc_cut_ot <- cut_for("overtime branch", "MonthlyIncome")
QL <- Q[order(-A$n[Q])]
source(file.path("analysis/exec2", "run_followups.R"), local = FALSE)

# ------------------------------------------------------------------ drill_summary.md (plain language, for Quinn)
cn_txt <- sprintf("%s: %d people (%s of the no-overtime branch, %s of all who left), %s of them left (the branch rate is %s, so %.1f times higher). That is about %s people above the branch rate but %s above the company rate (%s points of company attrition). On the held-out employees: %d people, %s left (held-out no-overtime average %s). It held up in %s of the strict re-runs and %s of the looser ones. It does not clear: %s.",
  cn_best$group, cn_best$n, pct(cn_best$pct_of_branch, 0), pct(cn_best$pct_of_all_leavers), pct(cn_best$rate), pct(cn_best$branch_rate), cn_best$rate_vs_branch, ppl(cn_best$excess_vs_branch), ppl(cn_best$excess_vs_company), pp(cn_best$impact_pts_vs_company),
  cn_best$test_n, pct(cn_best$test_rate, 0), pct(mean(y_all[BR$nonOT & !is_tr]), 0), pct(cn_best$stab_within_1se, 0), pct(cn_best$stab_unpruned, 0), cn_best$fails_company_gates)
cn_big_txt <- sprintf("The largest low-experience group by people above the company rate is %s: %d people, %s left, %s people above the company rate (needs 15).", cn_big$group, cn_big$n, pct(cn_big$rate), ppl(cn_big$excess_vs_company))
SUM <- c("# Deeper drill-down: which large groups leave more? (IBM HR fictional data)", "",
  sprintf("> **QA-cleared by Quinn, Oct 9, 2026** (executive page; review fixes R1-R7 applied). Rule: `thresholds.json` (written %s, before the final run; SHA-256 `%s`). Every number here is computed by `analysis/exec2/run_drill.R` (seed %d). Fictional data, nothing causal. Detail: `technical_appendix.md`, `drill_log.md`.", TH_WRITTEN, substr(TH_SHA, 1, 12), SEED), "",
  "## Short answer",
  sprintf("- **Search size.** We tested %s different groups (%s of them with 100 or more people), drilling into every large group and every group that cleared the checks until no group of 100 or more people produced a clear new pattern inside it (%d groups drilled).", format(R$tested, big.mark = ","), format(n_stored100, big.mark = ","), R$drilled),
  sprintf("- **Clear patterns: %d.** %s", length(Q), paste(vapply(QL, q_lines, ""), collapse = " | ")),
  sprintf("- **The CEO's observation is partly right.** Inside the no-overtime group (%s people, %s left) short-experience staff do leave more often than their own group (the best groups at %.1f to %.1f times its rate). Best example: %s", format(sum(BR$nonOT), big.mark = ","), pct(mean(y_all[BR$nonOT])), min(CNx$rate_vs_branch[CNx$excess_vs_branch >= PAR_EXC]), max(CNx$rate_vs_branch[CNx$excess_vs_branch >= PAR_EXC]), cn_txt),
  sprintf("- **Why the old rule missed things.** It required 1.5 times the company rate and a company-wide stability check. %d large groups pass the new size, impact, rate and test-set checks but not the old rate and test checks; %d pass the old size, 1.5x and held-out gates (before stability) but give fewer than 15 people above the company rate; only the overtime group passes the full old rule.", length(NEW_ONLY), length(OLD_ONLY)),
  sprintf("- **How much to trust the search.** %s", null_verdict), "",
  "## 1. Patterns that clear every check", "",
  "A group clears every check when it has 100+ people and 24+ who left; at least 15 people above the company rate (about 1 point of company attrition); a left-rate at least 1.25 times the company rate with the low end of its uncertainty range above the company rate; the same direction on the held-out 30% of employees (30+ of them); and it held up when we re-ran the analysis on reshuffled versions of the data inside its own branch, at a similar cut.", "",
  mdt(q_tab), "", nest_lines, "",
  sprintf("Counted once, all clear patterns together cover %s people (%s of staff) and %s of everyone who left; if they fell to the company average that would be %s people (%s points). Impacts are never added across overlapping groups.", format(UQ$n, big.mark = ","), pct(UQ$pct_staff, 0), pct(UQ$pct_leavers, 0), ppl(UQ$excess_vs_company), pp(UQ$impact_pts_vs_company)),
  "Pay, tenure, experience and job level move together (one career-stage picture), so a pay-based group is one view of career stage, not a separate pattern, and impacts are never added. Groups defined by age, gender or marital status are never listed.", "",
  ni_lines, "", "**Groups tested, by branch** (a group is counted once; the branch is the one it was first defined in):", "", mdt(TB), "",
  "## 2. The CEO's question: no-overtime staff with less experience", "",
  sprintf("Inside the no-overtime group (%s people, %d left, %s). Each group below uses a cut chosen on the training 70%% only and is then checked on the held-out 30%%.", format(sum(BR$nonOT), big.mark = ","), sum(y_all[BR$nonOT]), pct(mean(y_all[BR$nonOT]))), "",
  mdt(ceo_tab(CN)), "",
  sprintf("**Reading the table.** %s %s", cn_txt, cn_big_txt),
  sprintf("Career stage as a family (tenure, experience, job level and pay together): at least one of them is chosen as a split in %s of the strict re-runs inside the no-overtime group and %s of the looser ones, against %s of the strict company-wide re-runs; each single variable scores lower because the correlated variables share the signal.", pct(FAM$any_career_stage_variable[FAM$scope == "no overtime" & FAM$refits == "pruned"], 0), pct(FAM$any_career_stage_variable[FAM$scope == "no overtime" & FAM$refits == "unpruned"], 0), pct(FAM$any_career_stage_variable[FAM$scope == "all staff (nodes 1-3)"], 0)),
  sprintf("In %d re-runs inside the no-overtime group, the strict version of the analysis (cross-validated pruning) found no split at all in %s, so no group inside it can reach the 50%% bar (at most %s); the looser check (unpruned shallow trees) is reported next to it. Years at the company, loose check: %s.", R$S$stores$nonOT$B, nsp("no overtime", "pruned"), pct(1 - R$S$stores$nonOT$n_pruned_root / R$S$stores$nonOT$B, 0), cut_for("no-overtime branch", "YearsAtCompany", "unpruned")),
  "", "**What the short-experience groups add beyond job level 1 and lower pay** (never summed; the groups overlap):", "", mdt(add_tab(CN[!CN$variable %in% c("JobLevel", "MonthlyIncome"), ])), "",
  sprintf("Union, counted once: %s", if (!is.null(U_NONOT)) sprintf("the no-overtime groups above that are clear against their own branch's rate (%s) together cover %s people (%s of staff) and %d of the %d people who left from that branch; they left at %s versus %s for the branch, so combined they are a broad, modestly higher-than-average group, not a sharp one. The overlap table is in the appendix (section 8).", paste(nonOT_pv$group, collapse = "; "), format(U_NONOT$n, big.mark = ","), pct(U_NONOT$pct_staff, 0), U_NONOT$leavers, sum(y_all[BR$nonOT]), pct(U_NONOT$rate), pct(mean(y_all[BR$nonOT]))) else "none of the no-overtime groups is clear against its branch's rate."), "",
  "**The same check inside the overtime group** (416 people, 30.5% left):", "", mdt(ceo_tab(CO)), "",
  "## 3. Supported on the full data only (not cleared)", "",
  sprintf("These pass size, impact and rate on all employees but fail the held-out check, the stability check, or have too few people in the test set. There are %s such groups (%d more where the test set is too small to confirm); most are variants of a few patterns, so only the distinct ones are shown (largest effect first).", format(n_sup_only, big.mark = ","), n_sup_test), "",
  mdt(SUPS_T), "", "**Test set too small to confirm** (fewer than 30 people in the held-out group; not cleared):", "", mdt(SUPT_T), "",
  "**Clear against their own branch only** (career-stage groups, at most three conditions; not cleared because they do not hold up as splits):", "", mdt(PV_T), "",
  "## 3b. Deeper groups (three or more conditions)", "", deep_lines, "", if (!is.null(DEEP_T)) c("Distinct deeper patterns passing size, impact and rate on all employees (largest effect first):", "", mdt(DEEP_T), "") else NULL,
  "## 4. Too small to act on", "",
  sprintf("%d groups leave at 1.25 times the company rate or more but have fewer than 100 people (or fewer than 24 who left). The largest distinct ones:", n_small), "", mdt(SMALL_T), "",
  "## 5. Old rule versus new rule", "",
  sprintf("Old rule (earlier run, `analysis/exec/thresholds.json`): 100+ people, 1.5 times the company rate, same direction in the test set, company-wide stability at the top three levels of the tree. It cleared one pattern: overtime. The new rule replaces the 1.5 times floor with an impact test (15+ people above the company rate) plus a 1.25 times floor and an uncertainty check, and measures stability inside the group's own branch."),
  sprintf("Applied to the same %s groups: both rules admit %d on the size, rate and test-set checks; the new rule admits %d the old one did not (rate between %.2f and %.2f times the company rate); %d pass the old size, 1.5x and held-out gates (before stability) but not the new ones (%d of them give fewer than 15 people above the company rate; %d fail the uncertainty check); only the overtime group passes the full old rule. After stability, the new rule clears %d and the old rule %d of these groups.",
    format(sum(ok), big.mark = ","), CMP14["TRUE", "TRUE"], length(NEW_ONLY), NEW_ONLY_LIFT[1], NEW_ONLY_LIFT[2], length(OLD_ONLY), OLD_ONLY_WHY[["impact_under_15"]], OLD_ONLY_WHY[["wilson_not_above_company"]], sum(A$pass_new[ok]), sum(A$pass_old[ok])), "",
  "Qualifying patterns and what the old rule said about them:", "", mdt(data.frame(Pattern = A$plain[QL], `Rate vs company` = F2(A$lift[QL]), `Old rule: rate floor 1.5` = ifelse(A$lift_ge_1.5[QL], "passes", "filtered out"), `Old rule: company-wide stability` = sprintf("%s (%s)", pct(A$stab_old[QL], 0), ifelse(!is.na(A$stab_old[QL]) & A$stab_old[QL] > STAB_MIN, "passes", "filtered out")),
     `Old rule overall` = ifelse(A$pass_old[QL], "admitted", "filtered out"), `New rule` = "admitted", check.names = FALSE, stringsAsFactors = FALSE)), "",
  if (!is.null(NEWONLY_T) && nrow(NEWONLY_T)) c("Large groups the new size, impact and test checks admit that the old rate floor (1.5 times) filtered out, before the stability check (distinct patterns):", "", mdt(NEWONLY_T), "") else NULL,
  "Groups the old rule admitted on rate and test that the new impact rule does not (examples):", "", mdt(OLDONLY_T), "",
  "## 6. How much to trust the search", "",
  null_plain[1], null_plain[2], null_verdict, "",
  FU_SUM, "",
  "## 7. Caveats", "",
  "- **Fictional data.** IBM made this dataset for teaching; it describes no real workforce.",
  "- **Nothing here is causal.** Groups describe who left more, not why.",
  "- **Pay and career stage cannot be separated.** Pay, job level, tenure and experience (which also tracks age) move together; they are one career-stage picture, so impacts are never added.",
  "- **Age, gender and marital status** are descriptive only: groups defined by them are tested and counted but never headlined.",
  "- **Snapshot timing.** Tenure and survey fields were recorded at the same time as whether people left, so they may not come before leaving.",
  "- **Cuts are chosen on the training 70% and checked on the test 30%**, but size, impact and the uncertainty range use all 1,470 people, so they still reflect cuts picked from the data.", "")
writeLines(SUM, file.path(OUT, "drill_summary.md"))

# ------------------------------------------------------------------ drill_log.md
DR <- DRILL[, c("branch", "node_plain", "defining_conditions", "n", "rate", "node_status", "children_100plus", "children_pass_1to3", "children_pass_1to4", "children_qualifying", "verdict")]
dr_tab <- function(Z) mdt(data.frame(Group = Z$node_plain, `Conds` = Z$defining_conditions, People = Z$n, `Left rate` = pct(Z$rate), `Status of the group itself` = Z$node_status, `Children with 100+ people` = Z$children_100plus,
  `Pass 1-3` = Z$children_pass_1to3, `Pass 1-4` = Z$children_pass_1to4, `Qualify` = Z$children_qualifying, Verdict = Z$verdict, check.names = FALSE, stringsAsFactors = FALSE))
DL_MD <- c("# Drill log (every node with 100+ people that was examined)", "",
  sprintf("> Rule: `thresholds.json` (written %s). Generated by `run_drill.R`. Also in `drill_log.csv` (more columns).", TH_WRITTEN), "",
  "## What was examined", "",
  sprintf("- **Nodes drilled: %d.** A node is the whole company, a branch (overtime, no overtime), a node of a tree grown on the training 70%% (whole company, overtime-only, no-overtime-only; every level, no depth cap), a group that cleared the checks, or a one-condition group inside a branch that was clear against its branch's own rate.", nrow(DRILL)),
  "- **For each node** we tested every single split of every one of the 27 predictors inside it (numeric variables at their training-set deciles, or every value for variables with 6 or fewer values; each category of a categorical variable against the rest), both sides, and applied all five rules to each child. Cuts are chosen on the training rows inside the node only.",
  sprintf("- **Stopping rule:** no remaining node with 100 or more people yields a child that qualifies. Check: %d qualifying group(s) found; %d of them were not drilled in turn; %d of the drilled nodes had a qualifying child and %d qualifying group(s) have no qualifying child (the end of the drill).", length(Q), STOP_UNDRILLED, N_NODES_CHILD_QUAL, sum(DRILL$node_status == "qualifies (rules 1-5)" & DRILL$children_qualifying == 0)),
  sprintf("- **Branches where nothing qualified:** %s.", {nb <- tapply(DRILL$children_qualifying, DRILL$branch, sum); paste(names(nb)[nb == 0], collapse = ", ")}),
  sprintf("- **Safety cap:** drilling stops at %d defining conditions; it was reached %d time(s).", MAX_DRILL_COND, R$capped),
  "- **Depth and the test set:** deeper leaves with fewer than about 120 people have fewer than 30 test-set people and land in 'supported on the full data, test too small', not cleared.", "")
for (br_ in c("whole company", "overtime branch", "no-overtime branch")) { Z <- DR[DR$branch == br_, ]; if (!nrow(Z)) next
  DL_MD <- c(DL_MD, sprintf("## %s (%d nodes drilled)", br_, nrow(Z)), "", dr_tab(Z), "") }
writeLines(DL_MD, file.path(OUT, "drill_log.md"))

# ------------------------------------------------------------------ technical_appendix.md
ps_txt <- function(pr, dat) { tp <- tree_prim(pr$fit, dat); if (!length(tp)) return("no splits (pruned to the root)")
  paste(sprintf("node %s: %s", names(tp), vapply(tp, function(z) tech_cond(if (!is.na(z$cut)) mkc(z$var, "<", z$cut) else z$L), "")), collapse = "; ") }
tree_block <- function(nm, kind, desc_txt) { t <- R$trees[[kind]]; pr <- R$pruned[[kind]]
  c(sprintf("### %s", nm), sprintf("%s Grown tree: %d nodes, %d leaves. 1-SE pruning picks cp %s (%d split%s): %s.", desc_txt, nrow(t$fit$frame), node_leaves(t), signif(pr$cp, 3), pr$nsplit, if (pr$nsplit == 1) "" else "s", ps_txt(pr, t$dat)), "",
    cp_md(t$fit), "") }
src_tab <- as.data.frame(table(source = sub(" [0-9]+ \\(in pruned tree\\)$| [0-9]+$", "", A$source)), stringsAsFactors = FALSE)
st_tab <- as.data.frame(table(status = A$status), stringsAsFactors = FALSE); st_tab <- st_tab[order(-st_tab$Freq), ]
old_st <- as.data.frame(table(status = sub(" \\(under.*$", "", OLDX$status)), stringsAsFactors = FALSE)
old_pass <- OLDX[OLDX$status == "PASS", c("id", "definition", "n", "full_rate", "lift", "stability_share")]
old_small <- OLDX[grepl("^passes size and lift, not stable", OLDX$status), c("id", "definition", "n", "full_rate", "lift", "stability_share")]
cmp_tab <- function(tb) { m <- as.data.frame.matrix(tb); data.frame(` ` = c("new rule fails", "new rule passes"), `old rule fails` = m[[1]], `old rule passes` = m[[2]], check.names = FALSE) }
ap <- c("# Technical appendix: deeper drill-down (IBM HR fictional data)", "",
  sprintf("> **QA-cleared by Quinn, Oct 9, 2026** (executive page; review fixes R1-R7 applied). Generated by `Rscript analysis/exec2/run_drill.R` (project root, seed %d, deterministic). Parameters: `thresholds.json`, written %s (file last modified %s, before the final run), SHA-256 `%s` (read by the script; unchanged during the run). Every number below is computed by the script.", SEED, TH_WRITTEN, TH_MTIME, TH_SHA), "",
  "## 1. Why this analysis, and the rules",
  "The CEO viewed the app and asked for deeper drilling: stopping at the overtime split leaves 72% of staff (the no-overtime branch) undrilled, and a 1.5x rate floor can filter out larger groups at a lower rate ratio whose total effect on company attrition is bigger. Quinn confirmed the rule below as final. The standing requirement: keep drilling into large groups until the meaningful patterns are found.", "",
  paste0("**Amendment note in `thresholds.json`:** ", TH$amendment), "",
  "| Gate | Rule (all on the full 1,470 rows unless stated) |", "|---|---|",
  sprintf("| 1 Size | n >= %d and leavers >= %d |", MIN_N, MIN_LV),
  sprintf("| 2 Impact | excess leavers = leavers - n x %.4f >= %d (about 1 point of company attrition; points = excess / %d) |", AVG, MIN_EXC, N),
  sprintf("| 3 Rate | lift (rate / %.4f) >= %.2f AND lower end of the 95%% Wilson interval > %.4f |", AVG, MIN_LIFT, AVG),
  sprintf("| 4 Held-out | at least %d test employees, and test rate > test-set rate %.4f (71/441). Fewer than %d: 'supported on the full data, test too small', not cleared |", MIN_TN, TEST_AVG, MIN_TN),
  sprintf("| 5 Stability | across %d bootstrap refits fit on the group's own branch rows (overtime rows for overtime groups, no-overtime rows for no-overtime groups; minbucket %d, 10-fold CV, 1-SE pruning, depth up to %d), every defining variable is a primary split in > %d%% of refits at a similar cut (within +/-%.2f of the share of the branch below the cut; categorical: same variable). Groups defined on all staff use the old rule: nodes 1-3 of depth-%d refits. |", B_REAL, MB_FULL, DEPTH_BR, 100 * STAB_MIN, SIM_TOL, DEPTH_CO), "",
  "Reported but not gating: the 1.5x lift (`lift_ge_1.5`), the parent-branch view (rate, lift, excess and impact against overtime 30.5% or no-overtime 10.4%; `pv_gates` applies gates 1-4 with the parent branch as the comparison and `pass_pv` adds stability), the old company-wide stability (`stab_old`: every defining variable including OverTime a primary split at nodes 1-3 of depth-3 company-wide refits, any cut), and a looser stability (`stab_unpruned`: unpruned depth-3 refits, see section 5). Impact in points = excess / 1,470 x 100. Impact 'if the group fell to its parent branch rate' = leavers - n x parent rate, an illustration, not a forecast.", "",
  "## 2. Data, split, predictors",
  sprintf("Same 27 predictors as before (EmployeeNumber, EmployeeCount, Over18, StandardHours, DailyRate, HourlyRate, MonthlyRate excluded) and the same stratified 70/30 split (seed %d): %d training rows (%d leavers, %s), %d test rows (71 leavers, %s). Company: %d leavers of %d (%s). Overtime branch: %d rows, %d leavers (%s). No-overtime branch: %d rows, %d leavers (%s).",
    SEED, NTR, sum(y_all[is_tr]), pct(TRAIN_AVG), NTE, pct(TEST_AVG), L, N, pct(AVG), sum(BR$OT), sum(y_all[BR$OT]), pct(mean(y_all[BR$OT])), sum(BR$nonOT), sum(y_all[BR$nonOT]), pct(mean(y_all[BR$nonOT]))),
  "**Training-only cuts.** Every tree and every cut point (tree splits, quantile grids, the hand-built career-stage groups) is derived on the training rows only (inside the node being examined), then evaluated untouched on the test rows. Size, impact, Wilson and stability use full-data counts, so they still include the rows that chose the cut; the test-set columns are the honest check.", "",
  "## 3. Trees (training rows, rate trees: rpart anova on 0/1 attrition)",
  sprintf("Grown at cp 0.001, maxdepth %d (no hard cap in practice: minbucket %d on training rows, scaled from 100 on the full data, and minsplit %d end growth), 10-fold cross-validation (seed %d), 1-SE pruning. Every non-root node of the **grown** tree is a candidate group (flagged if it is also in the pruned tree). Full printed trees: `tree_full_deep.txt`, `tree_overtime_branch.txt`, `tree_nonovertime_branch.txt` (each also shows a full-data reference tree with minbucket 100, not used for any test).", MAXD, MB_TR, 2 * MB_TR, SEED), "",
  tree_block("Whole company", "full", sprintf("Training rows n=%d.", NTR)), tree_block("Overtime branch", "OT", sprintf("Training overtime rows n=%d.", sum(is_tr & BR$OT))), tree_block("No-overtime branch", "nonOT", sprintf("Training no-overtime rows n=%d.", sum(is_tr & BR$nonOT))),
  "The two branch trees repeat the company tree's subtrees (same rows, same seed), so most of their nodes are the same groups as nodes already tested and are counted once.", "",
  "## 4. Search space: how many groups were tested",
  sprintf("- **%s distinct groups tested** (distinct sets of people; %s definitions were evaluated before removing duplicates). %s of them have 100 or more people; %d are defined by age, gender or marital status (tested and counted, never headlined). %d nodes were drilled.", format(R$tested, big.mark = ","), format(R$raw, big.mark = ","), format(n_stored100, big.mark = ","), n_sens_tested, R$drilled),
  "- Sources: branch roots; every single split of every predictor inside the whole company, overtime and no-overtime scopes (numeric variables at the training deciles, or at every value when a variable has 6 or fewer values; categories one against the rest; both sides of every cut); pairs of experience variables (TotalWorkingYears, YearsAtCompany, JobLevel, YearsInCurrentRole, YearsWithCurrManager, YearsSinceLastPromotion, MonthlyIncome, NumCompaniesWorked, StockOptionLevel; training quartiles) inside each scope; every node of the three grown trees; and the single splits inside every drilled node (section 6).",
  sprintf("- Groups stored in `candidates_all.csv`: %s (every tested group with 50 or more people; smaller groups are counted as tested but not stored).", format(nrow(A), big.mark = ",")), "",
  mdt(data.frame(Status = st_tab$status, Groups = format(st_tab$Freq, big.mark = ","), check.names = FALSE)), "",
  sprintf("Groups passing rules 1-3: %s; rules 1-4: %s; rules 1-5: %d (not counting groups defined by age, gender or marital status).", format(R$c13, big.mark = ","), format(R$c14, big.mark = ","), R$c_new), "",
  "## 5. Stability detail",
  "Rule 5 is evaluated on refits fit on each branch separately. Refits that pruned all the way to the root have no splits, so a group's stability share cannot exceed the share of refits that kept a split:", "",
  mdt(data.frame(Scope = nosplit$scope, Refits = nosplit$refits, `Refits with no split` = sprintf("%d of %d", nosplit$refits_with_no_split, nosplit$of), `Highest stability any group can reach` = pct(1 - nosplit$refits_with_no_split / nosplit$of, 0), check.names = FALSE, stringsAsFactors = FALSE)), "",
  sprintf("**Property of the rule, not of any group.** Inside the no-overtime branch, 1-SE pruning leaves %s refits with no split, so no no-overtime group can exceed %s stability by rule 5. The unpruned check (depth 3, cp 0.005, no cross-validation) always finds splits and shows whether the *variable* keeps being chosen; it is reported but not a pass condition.", nsp("no overtime", "pruned"), pct(1 - R$S$stores$nonOT$n_pruned_root / R$S$stores$nonOT$B, 0)), "",
  "**Career-stage family.** Tenure, experience, job level and pay are correlated, so refits spread the same signal over several of them, which lowers each variable's own share. Share of refits in which at least one of them (TotalWorkingYears, YearsAtCompany, YearsInCurrentRole, YearsWithCurrManager, YearsSinceLastPromotion, JobLevel, MonthlyIncome) is a primary split:", "",
  mdt(data.frame(Scope = FAM$scope, Refits = FAM$refits, `At least one career-stage variable` = pct(FAM$any_career_stage_variable, 0), `Any split at all` = pct(FAM$any_variable, 0), check.names = FALSE, stringsAsFactors = FALSE)), "",
  "Primary-split variables and cut ranges across refits (share of refits that split on the variable; cut median and middle half):", "",
  mdt(do.call(rbind, lapply(split(CUTSTAB, paste(CUTSTAB$scope, CUTSTAB$refits)), function(z) head(z, 6)))[, c("scope", "refits", "variable", "share_of_refits_with_split", "cut_q25", "cut_median", "cut_q75")] |> (function(z) { z$share_of_refits_with_split <- pct(z$share_of_refits_with_split, 0); z$cut_q25 <- fnum(z$cut_q25); z$cut_median <- fnum(z$cut_median); z$cut_q75 <- fnum(z$cut_q75); z })()), "",
  "Best training-derived low-side cut per variable inside the no-overtime branch (`best_cuts.csv` has all branches): the cut maximises training leavers above the branch rate; 'refit cut' is the median of the cuts chosen by the strict refits.", "",
  mdt(data.frame(Variable = BEST$variable[BEST$branch == "nonOT"], Group = BEST$best_group[BEST$branch == "nonOT"], People = BEST$n[BEST$branch == "nonOT"], Rate = pct(BEST$rate[BEST$branch == "nonOT"]), `Above branch rate` = ppl(BEST$excess_vs_parent[BEST$branch == "nonOT"]),
    `Strict stab.` = pct(BEST$stab_within_1se[BEST$branch == "nonOT"], 0), `Loose stab.` = pct(BEST$stab_unpruned[BEST$branch == "nonOT"], 0), `Variable split in refits` = pct(BEST$refits_splitting_on_var_1se[BEST$branch == "nonOT"], 0), `Refit cut (middle half)` = ifelse(is.na(BEST$refit_cut_median[BEST$branch == "nonOT"]), "n/a", sprintf("%s (%s to %s)", fnum(BEST$refit_cut_median[BEST$branch == "nonOT"]), fnum(BEST$refit_cut_q25[BEST$branch == "nonOT"]), fnum(BEST$refit_cut_q75[BEST$branch == "nonOT"]))), check.names = FALSE, stringsAsFactors = FALSE)), "",
  "Qualifying groups, stability detail:", "",
  mdt(data.frame(Group = A$label[QL], `Strict (rule 5)` = pct(A$stab_within[QL], 1), `Variable only, any cut` = pct(A$stab_var_pruned[QL], 1), `Unpruned refits` = pct(A$stab_unpruned[QL], 1), `Old company-wide rule` = pct(A$stab_old[QL], 1), check.names = FALSE, stringsAsFactors = FALSE)), "",
  sprintf("Income cut inside the overtime branch (strict refits): %s. The qualifying group's cut is %s.", inc_cut_ot, paste(unique(sprintf("MonthlyIncome < %s", format(A$cut1[QL][A$var1[QL] == "MonthlyIncome"], digits = 5))), collapse = ", ")),
  "**Bootstrap duplicates make stability somewhat optimistic:** a resample contains duplicate rows that can fall in both the training and validation folds of the internal 10-fold CV, so pruning keeps more splits than it would on fresh data.", "",
  "## 6. Drill and stopping rule",
  sprintf("%d nodes were drilled (`drill_log.md`, `drill_log.csv`). For each node with 100+ people, every single split of every predictor was tested (cuts from the training rows inside the node), all five rules applied to each child, and any child that qualified (or passed the sensitivity checks, or was a one-condition group clear against its own branch) was drilled in turn. **Stopping rule: no remaining node with 100 or more people yields a child that qualifies.** Result: %d qualifying group(s); %d not drilled; safety cap of %d conditions reached %d time(s).", nrow(DRILL), length(Q), STOP_UNDRILLED, MAX_DRILL_COND, R$capped),
  "Deeper leaves with fewer than about 120 people have fewer than 30 test-set people and land in 'supported on the full data, test too small'.", "",
  "### Groups tested by branch", "", mdt(TB), "", "### Deeper groups (three or more conditions)", "", deep_lines, "", if (!is.null(DEEP_T)) c(mdt(DEEP_T), "") else NULL,
  "## 7. The CEO's observation: low-experience groups inside each branch", "",
  "Cuts are the best training-derived low-side cuts per variable (by training leavers above the branch rate). 'Strict / loose' are the stability checks of section 5. Job level 1 and the lower-pay group (best training income cut inside the branch) are rows of the table.", "",
  "### No-overtime branch", "", mdt(ceo_tab(CN)), "", "Gate failures against the company average:", "", mdt(data.frame(Group = CN$group, `Fails` = CN$fails_company_gates, check.names = FALSE, stringsAsFactors = FALSE)), "",
  "What each group adds beyond job level 1 and the lower-pay group:", "", mdt(add_tab(CN)), "",
  "Overlap inside the no-overtime branch (share of the row group's people who are also in the column group):", "", mdt(data.frame(Group = rownames(CS_OV), apply(CS_OV, 2, function(z) pct(z, 0)), check.names = FALSE, stringsAsFactors = FALSE)), "",
  "### Overtime branch", "", mdt(ceo_tab(CO)), "", "Gate failures against the company average:", "", mdt(data.frame(Group = CO$group, `Fails` = CO$fails_company_gates, check.names = FALSE, stringsAsFactors = FALSE)), "",
  "What each group adds beyond job level 1 and the lower-pay group:", "", mdt(add_tab(CO)), "",
  "## 8. Overlap and unions (never summed)", "",
  if (length(Q) > 1) c("Qualifying groups, pairwise:", "", mdt(data.frame(A = pair_tab(CLQ)$label_a, B = pair_tab(CLQ)$label_b, `In common` = pair_tab(CLQ)$employees_in_common, `Leavers in common` = pair_tab(CLQ)$leavers_in_common, `Share of A in B` = pct(pair_tab(CLQ)$share_of_a_in_b, 0), `Share of B in A` = pct(pair_tab(CLQ)$share_of_b_in_a, 0), Relation = pair_tab(CLQ)$relation, check.names = FALSE, stringsAsFactors = FALSE)), "") else "Only one group qualifies, so there is no overlap table among qualifying groups.",
  ni_lines, "", "Unions, each counted once (excess and impact are against the company average):", "",
  mdt(data.frame(Set = c(UOT$set, UQ$set, if (!is.null(U_NONOT)) U_NONOT$set, if (!is.null(U_BOTH)) U_BOTH$set), People = c(UOT$n, UQ$n, if (!is.null(U_NONOT)) U_NONOT$n, if (!is.null(U_BOTH)) U_BOTH$n),
    `% of staff` = pct(c(UOT$pct_staff, UQ$pct_staff, if (!is.null(U_NONOT)) U_NONOT$pct_staff, if (!is.null(U_BOTH)) U_BOTH$pct_staff), 0), Leavers = c(UOT$leavers, UQ$leavers, if (!is.null(U_NONOT)) U_NONOT$leavers, if (!is.null(U_BOTH)) U_BOTH$leavers),
    `% of all leavers` = pct(c(UOT$pct_leavers, UQ$pct_leavers, if (!is.null(U_NONOT)) U_NONOT$pct_leavers, if (!is.null(U_BOTH)) U_BOTH$pct_leavers), 0), Rate = pct(c(UOT$rate, UQ$rate, if (!is.null(U_NONOT)) U_NONOT$rate, if (!is.null(U_BOTH)) U_BOTH$rate)),
    `People above company rate (points)` = sprintf("%s (%s)", ppl(c(UOT$excess_vs_company, UQ$excess_vs_company, if (!is.null(U_NONOT)) U_NONOT$excess_vs_company, if (!is.null(U_BOTH)) U_BOTH$excess_vs_company)), pp(c(UOT$impact_pts_vs_company, UQ$impact_pts_vs_company, if (!is.null(U_NONOT)) U_NONOT$impact_pts_vs_company, if (!is.null(U_BOTH)) U_BOTH$impact_pts_vs_company))), check.names = FALSE, stringsAsFactors = FALSE)), "",
  "Overlap among the distinct patterns of every list (qualifying, supported on the full data only, clear against own branch only) is in `overlap.csv`. Groups are 'essentially the same people' when the overlap (Jaccard) is at least 0.7 and 'inside' another when 90% of their people are in it.", "",
  "## 9. Old rule versus new rule", "",
  "**Why the rule changed:** the CEO asked for deeper drilling after viewing the app; the old rule (1.5x lift floor, company-wide stability at nodes 1-3, no impact test) could not see a large no-overtime group or a deeper subgroup. The old results are kept below.", "",
  sprintf("**Earlier run (`analysis/exec/`, unchanged):** %d candidates; %s. Cleared: %s.", nrow(OLDX), paste(sprintf("%d %s", old_st$Freq, old_st$status), collapse = "; "), paste(old_pass$id, collapse = ", ")), "",
  "Groups that passed size and lift in the earlier run but were not stable as a split: ", paste(sprintf("%s (n %d, %s, stability %s)", old_small$id, old_small$n, pct(old_small$full_rate), pct(old_small$stability_share, 0)), collapse = "; "), "",
  "**Both rules applied to the same tested groups (100+ people, not defined by age, gender or marital status).** New gates 1-4 (size, impact, rate, held-out) against the old gates 1-3 (size, 1.5x lift, held-out):", "", mdt(cmp_tab(CMP14)), "",
  "After stability (new rule: rules 1-5; old rule: its four rules):", "", mdt(cmp_tab(CMP_FINAL)), "",
  sprintf("The new rule admits %d groups (before stability) that the old lift floor filtered out (lift %.2f to %.2f); %d pass the old size, 1.5x and held-out gates but not the new ones (%d fail impact, %d fail the Wilson check).", length(NEW_ONLY), NEW_ONLY_LIFT[1], NEW_ONLY_LIFT[2], length(OLD_ONLY), OLD_ONLY_WHY[["impact_under_15"]], OLD_ONLY_WHY[["wilson_not_above_company"]]), "",
  "## 10. Null calibration (permutation check)", "",
  sprintf("The same search (trees and cuts re-derived on the shuffled training rows; same rules; stability with %d refits per scope instead of %d, computed only for groups that pass rules 1-4) was run on %d shuffles of the Attrition labels. Two kinds of shuffle: **across everyone** (within the training rows and within the test rows, keeping both rates) and **within overtime status** (also keeping the overtime effect, so only everything else is removed).", B_NULL, B_REAL, N_SHUF), "",
  "Shuffled across everyone:", "", mdt(nc_tab("global")), "", "Shuffled within overtime status (the overtime group itself passes in every one of these shuffles, so subtract one for the 1-5 row):", "", mdt(nc_tab("within_overtime")), "",
  null_plain[1], null_plain[2], null_verdict, "",
  sprintf("Mean share of tested groups that pass rules 1-4 by chance: %s (across everyone), %s (within overtime status); real data: %s.", pct(mean(null_g[, "pass_1to4"] / null_g[, "tested"]), 2), pct(mean(null_w[, "pass_1to4"] / null_w[, "tested"]), 2), pct(REAL_COUNTS[["pass_1to4"]] / REAL_COUNTS[["tested"]], 2)),
  "Caveat: parent-branch figures in the shuffles use the shuffled branch rates, so the parent-branch columns are only approximately calibrated.", "",
  "## 11. Caveats",
  "- **Fictional dataset** (IBM teaching data); nothing here describes a real workforce.",
  "- **Nothing is causal**; groups describe who left more, not why.",
  "- **Pay, job level, tenure and total experience are one correlated cluster** (experience also tracks age). They are shown as one career-stage picture; impacts are never added across them.",
  "- **Age, gender and marital status** are descriptive only; groups defined by them are tested, counted and never headlined.",
  "- **Snapshot timing:** tenure and survey fields are measured at the same time as the outcome.",
  "- **Multiple comparisons:** thousands of overlapping groups were tested; the held-out and stability checks and the shuffle check are the guards, and the shuffle counts above show how far they go.",
  "- **Stability is optimistic** (bootstrap duplicates in cross-validation), and for the no-overtime branch rule 5 is limited by how often 1-SE pruning keeps any split.", "",
  FU_AP, "",
  "## 12. Files",
  "`run_drill.R` · `thresholds.json` · `candidates_all.csv` · `qualifying.csv` · `overlap.csv` · `drill_log.md` · `drill_log.csv` · `drill_summary.md` · `technical_appendix.md` · `tree_full_deep.txt` · `tree_overtime_branch.txt` · `tree_nonovertime_branch.txt` · `cut_stability.csv` · `best_cuts.csv` · `ceo_check.csv` · `career_stage_overlap_nonovertime.csv` · `drill_tree.png`", "")
writeLines(ap, file.path(OUT, "technical_appendix.md"))

# ------------------------------------------------------------------ README.md
RD <- c("# exec2: deeper drill-down (impact-based rule)", "",
  "**Status: the executive page is QA-cleared by Quinn, Oct 9, 2026 (review fixes R1-R7 applied).** Written after the CEO viewed the app and asked for deeper drilling than the overtime split (the earlier, QA-cleared run is untouched in `../exec/`). Fictional IBM teaching data; nothing causal.", "",
  sprintf("**Rule (final, confirmed by Quinn):** `thresholds.json`, written %s before the final run (SHA-256 `%s`): 100+ people and 24+ leavers; 15+ people above the company rate; rate at least 1.25x the company rate with the Wilson lower end above it; same direction in the held-out 30%% with 30+ test people; stability inside the group's own branch (500 refits, >50%%, similar cut). Judged against the company average and the parent branch. Every tree and cut is derived on the 70%% training split only.", TH_WRITTEN, substr(TH_SHA, 1, 12)),
  "", "**Read first:** `drill_summary.md` (plain language for Quinn), then `exec_findings_v2_draft.md` (executive page draft), then `technical_appendix.md`.", "",
  "| File | What it is |", "|---|---|",
  "| `run_drill.R` | the generator; reads `thresholds.json`; deterministic (seed 20261008) |", "| `run_followups.R` | companion script, sourced by `run_drill.R`: follow-up tables after Quinn's review (cut sensitivity, job level 1, the 19 non-overtime combinations, short tenure, parent-branch null), the executive page draft and the chart; no new search |", "| `followup_*.csv` | the follow-up tables as CSV |", "| `thresholds.json` | the rule parameters, with timestamp and amendment notes |",
  "| `candidates_all.csv` | every tested group with 50+ people: n, % of staff, leavers, % of leavers, full and test rates, lift, Wilson, impact vs company and vs parent branch, stability (within-branch, unpruned, old company-wide), test n, pass/fail per gate, old-rule result |",
  "| `qualifying.csv` | groups passing all five rules, with role (distinct / same people / inside another) |", "| `overlap.csv` | pairwise overlap among qualifying groups and the distinct patterns of the other lists |",
  "| `nested_incremental_impact.csv` | incremental impact of nested qualifying groups (never added) |", "| `groups_tested_by_branch.csv` | groups tested and passing, by branch |",
  "| `drill_log.md`, `drill_log.csv` | every node with 100+ people that was drilled, with verdict and the stopping rule |",
  "| `tree_full_deep.txt`, `tree_overtime_branch.txt`, `tree_nonovertime_branch.txt` | pruned trees and cp tables (training rows; full-data reference trees below them) |",
  "| `cut_stability.csv`, `best_cuts.csv` | refit cut ranges and the best training-derived cut per variable and branch |", "| `ceo_check.csv`, `career_stage_overlap_nonovertime.csv` | the CEO's question: low-experience groups in each branch, overlap and incremental impact |",
  "| `technical_appendix.md` | methods, cp tables, stability, null calibration, rule comparison, old-rule results |", "| `drill_summary.md` | plain-language summary for Quinn |", "| `exec_findings_v2_draft.md` | executive page, revised after Quinn's review (R1-R4); QA-cleared by Quinn, Oct 9, 2026 |",
  "| `drill_tree.png` | one chart: share who left, overtime finding in the accent colour |", "| `logs/` | progress log and cached heavy steps (the real search and each shuffle) |", "",
  "## How to run", "`Rscript analysis/exec2/run_drill.R` from the project root. Heavy steps (the real search with 500 refits per branch, and the 200 + 200 label shuffles) are cached in `logs/cache/` and progress is logged to `logs/progress.log`, so an interrupted run resumes. `DRILL_NOCACHE=1 Rscript analysis/exec2/run_drill.R` recomputes everything without touching the cache (used for the identical-rerun check). Delete `logs/cache/` if the search code or `thresholds.json` changes (the cache key includes the thresholds SHA).", "",
  "## Headline", sprintf("%d group(s) clear all five rules out of %s distinct groups tested (%d drilled nodes). See `drill_summary.md`.", length(Q), format(R$tested, big.mark = ","), R$drilled), "")
writeLines(RD, file.path(OUT, "README.md"))
logp("all files written")
cat(sprintf("done in %.0f seconds\n", as.numeric(difftime(Sys.time(), T0, units = "secs"))))
