# Checks that the numbers typed into R/presentation.R still match the analysis files.
# Run from the app directory after re-running the analysis:  Rscript tests/check_typed_numbers.R
# Typed-in numbers live ONLY in R/presentation.R: CLEARED_FINDING, HELD_OUT_AUC(_TEXT),
# PAY_CONTEXT_CUT, RULE_MIN_N, RULE_LEAVER_SHARE, RULE_MIN_LIFT.
source("R/partition.R"); source("R/presentation.R")
cand <- utils::read.csv("analysis/exec/candidates.csv", stringsAsFactors = FALSE)
th <- jsonlite::fromJSON("analysis/exec/thresholds.json")
ok <- TRUE
chk <- function(label, a, b, tol = 1e-9) {
  pass <- isTRUE(all.equal(as.numeric(a), as.numeric(b), tolerance = tol))
  cat(sprintf("%-34s %s  (app %s, file %s)\n", label, if (pass) "OK  " else "FAIL", paste(a, collapse = ","), paste(b, collapse = ",")))
  if (!pass) ok <<- FALSE
}
ot <- cand[cand$id == "ot_yes", ]; no <- cand[cand$id == "ot_no", ]
stopifnot(nrow(ot) == 1L, nrow(no) == 1L)
chk("overtime n", CLEARED_FINDING$n, ot$n)
chk("overtime leavers", CLEARED_FINDING$leavers, ot$leavers)
chk("overtime rate", CLEARED_FINDING$rate, ot$rate)
chk("rate outside overtime", CLEARED_FINDING$outside_rate, ot$rate_outside)
chk("lift", CLEARED_FINDING$lift, ot$lift)
chk("wilson (full data)", CLEARED_FINDING$wilson, c(ot$wilson_lo, ot$wilson_hi))
chk("test n / leavers", c(CLEARED_FINDING$test_n, CLEARED_FINDING$test_leavers), c(ot$test_n, ot$test_leavers))
chk("test rate", CLEARED_FINDING$test_rate, ot$test_rate)
chk("test wilson", CLEARED_FINDING$test_wilson, c(ot$test_wilson_lo, ot$test_wilson_hi))
chk("test overall rate", CLEARED_FINDING$test_overall_rate, ot$test_overall_rate)
chk("test, no overtime (n, leavers)", c(CLEARED_FINDING$test_n_other, CLEARED_FINDING$test_leavers_other), c(no$test_n, no$test_leavers))
chk("test rate, no overtime", CLEARED_FINDING$test_rate_other, no$test_rate)
chk("stability share", CLEARED_FINDING$stability_share, ot$stability_share)
chk("bootstrap refits", CLEARED_FINDING$n_bootstrap, th$rule4_stability$n_bootstrap)
chk("size floor (employees)", RULE_MIN_N, th$rule1_size$min_n)
chk("lift floor", RULE_MIN_LIFT, th$rule2_rate$min_lift)
md <- list(y = as.integer(read_hr_csv("data/WA_Fn-UseC_-HR-Employee-Attrition.csv")$Attrition == "Yes"))
chk("leaver floor (10% of leavers)", leaver_floor(sum(md$y)), th$rule1_size$min_leavers)
chk("pay context cut", PAY_CONTEXT_CUT, th$context$pay_band_for_numbers)
chk("impact points (exact formula)", round(impact_points(ot$leavers, ot$n, md$y), 2), round(ot$impact_pp_to_avg, 2))
method <- readLines("analysis/METHOD.md", warn = FALSE)
auc_ok <- any(grepl(sprintf("AUC %.3f", HELD_OUT_AUC), method, fixed = TRUE))
cat(sprintf("%-34s %s\n", "held-out AUC in METHOD.md", if (auc_ok) "OK  " else "FAIL")); if (!auc_ok) ok <- FALSE
if (!ok) stop("typed-in numbers are out of date: update R/presentation.R") else cat("typed-in numbers match the analysis files\n")
