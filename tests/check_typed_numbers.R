# Checks that the numbers typed into R/presentation.R still match the analysis files.
# Run from the app directory after re-running the analysis:  Rscript tests/check_typed_numbers.R
# Typed-in numbers live ONLY in R/presentation.R: CLEARED_FINDING, HELD_OUT_AUC(_TEXT), JUNIOR_RANGE,
# WATCH_GROUP, RULE_MIN_N, RULE_LEAVER_SHARE, RULE_MIN_LIFT, RULE_MIN_EXCESS.
# v4 sources: analysis/exec2/ (thresholds.json, qualifying.csv, followup_cut_sensitivity.csv,
# followup_short_tenure.csv, exec_findings_v2_draft.md) and, for the held-out detail, analysis/exec/candidates.csv.
source("R/partition.R"); source("R/presentation.R")
cand <- utils::read.csv("analysis/exec/candidates.csv", stringsAsFactors = FALSE)
th <- jsonlite::fromJSON("analysis/exec2/thresholds.json")
qual <- utils::read.csv("analysis/exec2/qualifying.csv", stringsAsFactors = FALSE)
cutsens <- utils::read.csv("analysis/exec2/followup_cut_sensitivity.csv", stringsAsFactors = FALSE)
tenure <- utils::read.csv("analysis/exec2/followup_short_tenure.csv", stringsAsFactors = FALSE)
draft <- paste(readLines("analysis/exec2/exec_findings_v2_draft.md", warn = FALSE), collapse = " ")
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
g1 <- qual[qual$label == "OverTime = Yes", ]; stopifnot(nrow(g1) == 1L)
chk("exec2 overtime n, leavers", c(CLEARED_FINDING$n, CLEARED_FINDING$leavers), c(g1$n, g1$leavers))
chk("exec2 overtime rate (5 dp)", round(CLEARED_FINDING$rate, 5), g1$rate)
chk("exec2 wilson (5 dp)", round(CLEARED_FINDING$wilson, 5), c(g1$wilson_lo, g1$wilson_hi))
chk("exec2 test n and rate", c(CLEARED_FINDING$test_n, round(CLEARED_FINDING$test_rate, 5)), c(g1$test_n, g1$test_rate))
chk("stability share (exec2 within-branch)", CLEARED_FINDING$stability_share, g1$stab_within)
chk("bootstrap refits", CLEARED_FINDING$n_bootstrap, th$rule5_stability$n_bootstrap)
chk("size floor (employees)", RULE_MIN_N, th$rule1_size$min_n)
chk("lift floor", RULE_MIN_LIFT, th$rule3_rate$min_lift)
chk("excess floor (people)", RULE_MIN_EXCESS, th$rule2_impact$min_excess_leavers)
md <- list(y = as.integer(read_hr_csv("data/WA_Fn-UseC_-HR-Employee-Attrition.csv")$Attrition == "Yes"))
chk("leaver floor (10% of leavers)", leaver_floor(sum(md$y)), th$rule1_size$min_leavers)
chk("impact points (exact formula)", round(impact_points(g1$leavers, g1$n, md$y), 2), round(g1$impact_pts, 2))
# --- v4: junior subgroup range and worth-watching group
at <- function(cut) cutsens[cutsens$cut == cut, ]
chk("junior range cut ends", c(JUNIOR_RANGE$cut_lo, JUNIOR_RANGE$cut_hi), c(3000, 3500))
chk("junior n at low/high cut", c(JUNIOR_RANGE$n_lo, JUNIOR_RANGE$n_hi), c(at(JUNIOR_RANGE$cut_lo)$n, at(JUNIOR_RANGE$cut_hi)$n))
chk("junior leavers at low/high cut", c(JUNIOR_RANGE$leavers_lo, JUNIOR_RANGE$leavers_hi), c(at(JUNIOR_RANGE$cut_lo)$leavers, at(JUNIOR_RANGE$cut_hi)$leavers))
pass <- cutsens$cut[as.logical(cutsens$pass_all_five)]
chk("cuts that pass all five (first, last)", c(JUNIOR_RANGE$pass_lo, JUNIOR_RANGE$pass_hi), c(min(pass), max(pass)))
chk("fails size at cut (n)", c(JUNIOR_RANGE$fail_size_cut, JUNIOR_RANGE$fail_size_n), c(at(JUNIOR_RANGE$fail_size_cut)$cut, at(JUNIOR_RANGE$fail_size_cut)$n))
chk("fails size = gate1 FALSE", as.numeric(as.logical(at(JUNIOR_RANGE$fail_size_cut)$gate1_size)), 0)
chk("fails stability at cut", c(JUNIOR_RANGE$fail_stab_cut, JUNIOR_RANGE$fail_stab_share), c(at(JUNIOR_RANGE$fail_stab_cut)$cut, at(JUNIOR_RANGE$fail_stab_cut)$stability_within_overtime))
w <- tenure[tenure$group == "Everyone, short tenure", ]; stopifnot(nrow(w) == 1L)
chk("watch group n, leavers", c(WATCH_GROUP$n, WATCH_GROUP$leavers), c(w$n, w$leavers))
chk("watch excess (people)", WATCH_GROUP$excess, w$excess, tol = 1e-5)
chk("watch test n, rate", c(WATCH_GROUP$test_n, WATCH_GROUP$test_rate), c(w$test_n, round(w$test_rate, 5)))
df <- read_hr_csv("data/WA_Fn-UseC_-HR-Employee-Attrition.csv")
bmd <- list(df = df, y = md$y, target = "Attrition", positive = "Yes", bundled = TRUE)
wi <- watch_info(bmd)
chk("watch group from the data (n, leavers)", c(wi$n, wi$yes), c(w$n, w$leavers))
chk("watch overtime share (typed 0.32)", round(wi$ot_share, 2), WATCH_GROUP$ot_share)
# phrases built from the data must appear in the QA-cleared executive draft
jr <- junior_range(bmd)
has <- function(label, phrase) { r <- grepl(phrase, draft, fixed = TRUE); cat(sprintf("%-34s %s  (\"%s\")\n", label, if (r) "OK  " else "FAIL", phrase)); if (!r) ok <<- FALSE }
has("range: people", sub("^about ", "about ", sub(" people$", "", jr$n_text)))
has("range: share of staff", sub(" of staff$", "", jr$staff_text))
has("range: rate", jr$rate_text)
has("range: vs rest of overtime", sub("^about ", "", sub(" the rate.*$", "", jr$vs_rest_text)))
has("range: share of leavers", sub(" of everyone who left$", "", jr$leavers_text))
has("range: pay cut text", sub(" a month$", "", jr$cut_text))
has("watch: people and share", sprintf("%s people, %s of staff", fmt_count(wi$n), fmt_pct0(wi$share)))
has("watch: rate", sprintf("left at %s", fmt_pct0(wi$rate)))
has("watch: about 40 above", sprintf("about %s people above the company rate", fmt_count(round5(wi$excess))))
has("watch: overtime share", sprintf("(%s) work overtime", fmt_pct0(wi$ot_share)))
has("junior share in job level 1", sprintf("(%s) are in the most junior job level", fmt_pct0(jr$junior_share)))
method <- readLines("analysis/METHOD.md", warn = FALSE)
auc_ok <- any(grepl(sprintf("AUC %.3f", HELD_OUT_AUC), method, fixed = TRUE))
cat(sprintf("%-34s %s\n", "held-out AUC in METHOD.md", if (auc_ok) "OK  " else "FAIL")); if (!auc_ok) ok <- FALSE
if (!ok) stop("typed-in numbers are out of date: update R/presentation.R") else cat("typed-in numbers match the analysis files\n")
