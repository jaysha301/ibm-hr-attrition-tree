# Presentation helpers for the Shiny app.
# Formatting only: every split, count, rate and improvement comes unchanged from
# R/partition.R. Nothing here re-scores or re-ranks anything.

ACCENT <- "#C2410C"        # the one accent: the cleared group only
INK <- "#1F2937"
INK_MUTED <- "#4B5563"
GRAY_LINE <- "#9CA3AF"
GRAY_FILL <- "#F3F4F6"
GRAY_BORDER <- "#C9CED6"
MONEY_VARS <- c("MonthlyIncome")

`%or%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

fmt_count <- function(x) formatC(as.numeric(x), format = "d", big.mark = ",")
fmt_rate1 <- function(p) ifelse(is.na(p), "\u2013", sprintf("%.1f%%", 100 * p))
fmt_share <- function(p) {
  ifelse(is.na(p), "\u2013", ifelse(p > 0 & p < 0.001, "<0.1%", sprintf("%.1f%%", 100 * p)))
}

fmt_cut_value <- function(variable, x) {
  if (length(x) != 1L || is.na(x)) return("")
  s <- if (abs(x - round(x)) < 1e-8) {
    formatC(round(x), format = "d", big.mark = ",")
  } else {
    format(signif(x, 6), big.mark = ",", scientific = FALSE, trim = TRUE)
  }
  if (variable %in% MONEY_VARS) paste0("$", s) else s
}

join_and <- function(x) {
  x <- x[nzchar(x)]
  if (length(x) <= 1L) return(paste(x, collapse = ""))
  paste(paste(x[-length(x)], collapse = ", "), "and", x[length(x)])
}

node_chain <- function(tree, id) {
  ids <- character()
  cur <- as.character(id)
  guard <- 0L
  while (!is.null(cur) && !is.na(cur) && guard < 200L) {
    ids <- c(cur, ids)
    cur <- get_node(tree, cur)$parent
    guard <- guard + 1L
  }
  ids
}

node_levels_present <- function(df, variable, rows) {
  v <- as.character(df[[variable]][rows])
  sort(unique(v[!is.na(v)]))
}

# The single condition that leads from a parent into one of its children.
step_condition <- function(tree, child_id, df) {
  child <- get_node(tree, child_id)
  parent <- get_node(tree, child$parent)
  sp <- parent$split
  v <- sp$variable
  if (identical(sp$type, "numeric")) {
    if (identical(child$side, "left")) {
      list(variable = v, type = "numeric", lower = NA_real_, upper = sp$cut)
    } else {
      list(variable = v, type = "numeric", lower = sp$cut, upper = NA_real_)
    }
  } else {
    present <- node_levels_present(df, v, parent$rows)
    left <- intersect(present, as.character(sp$left_levels))
    lev <- if (identical(child$side, "left")) left else setdiff(present, left)
    list(variable = v, type = "categorical", levels = lev)
  }
}

# Conditions from the root to a node, merged per variable (e.g. two income cuts
# become one range).
path_conditions <- function(tree, id, df) {
  chain <- node_chain(tree, id)
  conds <- list()
  for (cid in chain[-1L]) {
    s <- step_condition(tree, cid, df)
    v <- s$variable
    cur <- conds[[v]]
    if (is.null(cur)) {
      conds[[v]] <- s
    } else if (identical(s$type, "numeric")) {
      if (!is.na(s$upper)) cur$upper <- if (is.na(cur$upper)) s$upper else min(cur$upper, s$upper)
      if (!is.na(s$lower)) cur$lower <- if (is.na(cur$lower)) s$lower else max(cur$lower, s$lower)
      conds[[v]] <- cur
    } else {
      cur$levels <- intersect(cur$levels, s$levels)
      conds[[v]] <- cur
    }
  }
  conds
}

cond_text <- function(c, max_levels = 3L) {
  v <- c$variable
  if (identical(c$type, "numeric")) {
    lo <- c$lower
    hi <- c$upper
    if (!is.na(lo) && !is.na(hi)) {
      return(sprintf("%s %s to <%s", v, fmt_cut_value(v, lo), fmt_cut_value(v, hi)))
    }
    if (!is.na(hi)) return(sprintf("%s < %s", v, fmt_cut_value(v, hi)))
    return(sprintf("%s \u2265 %s", v, fmt_cut_value(v, lo)))
  }
  lev <- c$levels
  if (length(lev) == 1L) return(sprintf("%s = %s", v, lev))
  if (length(lev) <= max_levels) return(sprintf("%s: %s", v, paste(lev, collapse = ", ")))
  sprintf("%s: %d levels", v, length(lev))
}

cond_text_full <- function(c) cond_text(c, max_levels = 1000L)

# Short edge label without the variable name (the parent node names it).
edge_short_text <- function(c) {
  v <- c$variable
  if (identical(c$type, "numeric")) {
    if (!is.na(c$upper)) return(sprintf("< %s", fmt_cut_value(v, c$upper)))
    return(sprintf("\u2265 %s", fmt_cut_value(v, c$lower)))
  }
  lev <- c$levels
  if (length(lev) <= 2L) return(paste(lev, collapse = ", "))
  sprintf("%d levels", length(lev))
}

is_attrition_target <- function(md) identical(md$target, "Attrition") && identical(md$positive, "Yes")

rate_verb <- function(md) if (is_attrition_target(md)) "left" else paste0(md$target, " = ", md$positive)

# Plain-language subject for a group, e.g. "Overtime workers earning under $2,475 a month".
group_phrase <- function(conds, md) {
  subject <- NULL
  earning <- character()
  withs <- character()
  for (c in conds) {
    v <- c$variable
    if (identical(v, "OverTime") && identical(c$type, "categorical") && length(c$levels) == 1L &&
        c$levels %in% c("Yes", "No")) {
      subject <- if (c$levels == "Yes") "Overtime workers" else "Employees without overtime"
      next
    }
    if (identical(v, "MonthlyIncome") && identical(c$type, "numeric")) {
      lo <- c$lower
      hi <- c$upper
      earning <- c(earning, if (!is.na(lo) && !is.na(hi)) {
        sprintf("earning %s to under %s a month", fmt_cut_value(v, lo), fmt_cut_value(v, hi))
      } else if (!is.na(hi)) {
        sprintf("earning under %s a month", fmt_cut_value(v, hi))
      } else {
        sprintf("earning %s or more a month", fmt_cut_value(v, lo))
      })
      next
    }
    withs <- c(withs, cond_text(c))
  }
  if (is.null(subject)) subject <- if (is_attrition_target(md)) "Employees" else "Rows"
  out <- subject
  if (length(earning)) out <- paste(out, join_and(earning))
  if (length(withs)) out <- paste(out, "with", join_and(withs))
  out
}

# ---- Rules for what may be highlighted --------------------------------------
# Source: analysis/exec2/thresholds.json (rule1_size, rule2_impact, rule3_rate; v4 rule, replaces
# analysis/exec/thresholds.json). The size floor is user-adjustable in the app; the leaver floor is
# 10% of all leavers (24 of 237). RULE_MIN_EXCESS (15 people above the company rate, about 1 point)
# is part of the analysis rule and is quoted in About; the interactive highlight uses the rate floor only.
RULE_MIN_N <- 100L
RULE_LEAVER_SHARE <- 0.10
RULE_MIN_LIFT <- 1.25
RULE_MIN_EXCESS <- 15L

leaver_floor <- function(total_pos) as.integer(ceiling(RULE_LEAVER_SHARE * total_pos - 1e-9))
default_min_group <- function(N) as.integer(min(RULE_MIN_N, max(5, round(0.07 * N))))
default_flag_pct <- function(base) as.integer(min(95, max(5, ceiling(100 * RULE_MIN_LIFT * base - 1e-9))))

make_rules <- function(md, min_n, flag_rate) {
  list(min_n = min_n, min_pos = leaver_floor(sum(md$y)), thr = flag_rate)
}

# Plain words for the group and the event, so the same text works for any target.
unit_all <- function(md) if (is_attrition_target(md)) "employees" else "rows"
unit_staff <- function(md) if (is_attrition_target(md)) "staff" else "rows"
unit_pos <- function(md) if (is_attrition_target(md)) "leavers" else sprintf("%s = %s rows", md$target, md$positive)
overall_phrase <- function(md) if (is_attrition_target(md)) "overall attrition" else sprintf("the overall %s rate", rate_verb(md))

# Illustration only: points of overall rate removed if this group fell to the
# company average. (group events - group n x overall rate) / total n.
# Never add this across overlapping or multiple groups.
impact_points <- function(yes, n, y) 100 * (yes - n * mean(y)) / length(y)

# Status of a group: "cleared" is the one finding that passed every check
# (OverTime = Yes on the bundled IBM sample; analysis/exec/candidates.csv, id ot_yes).
# "comparison" is its other side. Everything else is "exploratory".
validation_status <- function(conds, md) {
  if (!length(conds)) return("overall")
  if (!isTRUE(md$bundled)) return("exploratory")
  if (!is_attrition_target(md)) return("exploratory")
  if (length(conds) != 1L || !identical(names(conds), "OverTime")) return("exploratory")
  ot <- conds[["OverTime"]]
  if (!identical(ot$type, "categorical") || length(ot$levels) != 1L) return("exploratory")
  if (identical(ot$levels, "Yes")) return("cleared")
  if (identical(ot$levels, "No")) return("comparison")
  "exploratory"
}

node_basic <- function(tree, id, y) {
  nd <- get_node(tree, id)
  yy <- y[nd$rows]
  n <- length(yy)
  yes <- sum(yy)
  list(id = id, n = n, yes = yes, no = n - yes, rate = if (n) yes / n else NA_real_,
       share = n / length(y), depth = nd$depth, leaf = is.null(nd$children))
}

# One row per node: size, rate, shares, status and the highlight decision.
# cleared  = validated AND big enough (rules$min_n employees, rules$min_pos events) AND rate >= threshold.
# too_small = under the size or event floor; never accented, never headlined.
node_assess <- function(tree, md, rules) {
  y <- md$y
  N <- length(y)
  P <- sum(y)
  base <- P / N
  ids <- names(tree$nodes)
  ids <- ids[order(as.integer(ids))]
  w_rows <- watch_rows(md)
  do.call(rbind, lapply(ids, function(id) {
    st <- node_basic(tree, id, y)
    conds <- path_conditions(tree, id, md$df)
    status <- validation_status(conds, md)
    root <- st$depth == 0L
    too_small <- !root && (st$n < rules$min_n || st$yes < rules$min_pos)
    hi <- !is.na(st$rate) && st$rate >= rules$thr
    out_n <- N - st$n
    watch_node <- !root && !is.null(w_rows) && st$n == length(w_rows) && identical(sort(as.integer(get_node(tree, id)$rows)), w_rows)
    data.frame(
      id = id, depth = st$depth, leaf = st$leaf, n = st$n, yes = st$yes, rate = st$rate,
      share = st$share, share_pos = if (P) st$yes / P else NA_real_,
      lift = if (base > 0) st$rate / base else NA_real_,
      outside_rate = if (out_n > 0) (P - st$yes) / out_n else NA_real_,
      impact = impact_points(st$yes, st$n, y),
      # "Worth watching" marker: only a node that is exactly the staff with 1 year or less at the company.
      watch = watch_node,
      status = status, too_small = too_small, hi = hi,
      cleared = !root && !too_small && hi && identical(status, "cleared"),
      outlined = !root && !too_small && hi && st$leaf && !identical(status, "cleared") && !watch_node,
      stringsAsFactors = FALSE
    )
  }))
}

# The group to headline: the cleared one if it exists, else the highest-rate big-enough
# group at or above the threshold (labelled exploratory). NULL when nothing qualifies.
headline_node <- function(a) {
  a <- a[a$depth > 0L, , drop = FALSE]
  if (!nrow(a)) return(NULL)
  cl <- a[a$cleared, , drop = FALSE]
  if (nrow(cl)) return(cl$id[order(-cl$rate, -cl$n)][1])
  ex <- a[!a$too_small & a$hi & !a$watch, , drop = FALSE]
  if (nrow(ex)) return(ex$id[order(-ex$rate, -ex$n)][1])
  NULL
}

# Wilson score 95% interval (technical detail only, never in the headline).
wilson_ci <- function(x, n, z = stats::qnorm(0.975)) {
  if (!n) return(c(NA_real_, NA_real_))
  p <- x / n
  d <- 1 + z^2 / n
  ctr <- (p + z^2 / (2 * n)) / d
  h <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / d
  c(ctr - h, ctr + h)
}
fmt_ci <- function(x, n) {
  ci <- wilson_ci(x, n)
  sprintf("%.1f\u2013%.1f%%", 100 * ci[1], 100 * ci[2])
}

fmt_times <- function(x) {
  s <- sprintf("%.1f", x)
  sub("\\.0$", "", s)
}
fmt_pct0 <- function(p) sprintf("%.0f%%", 100 * p)
fmt_pts <- function(x) sprintf("%.1f", x)
lower_first <- function(s) paste0(tolower(substr(s, 1, 1)), substr(s, 2, nchar(s)))

# Why a group is too small, in words.
too_small_reason <- function(n, yes, rules, md) {
  r <- character()
  if (n < rules$min_n) r <- c(r, sprintf("under %s %s", fmt_count(rules$min_n), unit_all(md)))
  if (yes < rules$min_pos) r <- c(r, sprintf("under %s %s", fmt_count(rules$min_pos), unit_pos(md)))
  paste(r, collapse = " and ")
}

# The illustration sentence; the cleared group only (thresholds.json impact); empty otherwise.
impact_sentence <- function(a_row, md) {
  if (!isTRUE(a_row$cleared) || is.na(a_row$impact) || a_row$impact < 0.05 || a_row$depth == 0L) return("")
  sprintf("If this group left at the company average, %s would be about %s points lower (illustration, not a forecast).",
          overall_phrase(md), fmt_pts(a_row$impact))
}

# ---- Typed-in numbers from the analysis (update these if the analysis is re-run) ----
# Source: analysis/exec/candidates.csv, row id == "ot_yes" (and "ot_no"), analysis/exec2/qualifying.csv (g00001)
# and analysis/exec2/thresholds.json. tests/check_typed_numbers.R compares them to those files.
CLEARED_FINDING <- list(
  label = "Overtime workers",
  n = 416L, leavers = 127L, rate = 0.305288461538462, outside_rate = 0.104364326375712,
  lift = 1.89356134371957, wilson = c(0.26298229805817, 0.35115776220399),
  test_n = 114L, test_leavers = 37L, test_rate = 0.324561403508772, test_wilson = c(0.245551462356787, 0.415009426821754),
  test_overall_rate = 0.160997732426304,
  test_n_other = 327L, test_leavers_other = 34L, test_rate_other = 0.103975535168196,
  stability_share = 0.818, n_bootstrap = 500L   # stability: analysis/exec2/qualifying.csv, stab_within
)
# Held-out AUC of the analysis tree (analysis/METHOD.md, "Held-out test set"; findings_draft.md).
HELD_OUT_AUC <- 0.670
HELD_OUT_AUC_TEXT <- "The analysis tree scored 0.670 on the held-out test set (a different measure from the in-sample number above)."

# ---- v4: the lower-paid, mostly junior subgroup and the "worth watching" group ----------------
# Both are shown only on the bundled IBM sample with Attrition = Yes as the event.
# Sources: analysis/exec2/exec_findings_v2_draft.md (QA-cleared, wording of narrative v9),
# analysis/exec2/followup_cut_sensitivity.csv (the cut range), analysis/exec2/followup_short_tenure.csv.
# tests/check_typed_numbers.R checks every typed number below against those files.
JUNIOR_RANGE <- list(
  cut_lo = 3000, cut_hi = 3500,                 # followup_cut_sensitivity.csv rows 3000 and 3500
  n_lo = 114L, n_hi = 132L, leavers_lo = 64L, leavers_hi = 73L,
  pass_lo = 2900, pass_hi = 3900,               # first and last cut in the table that pass all five checks
  fail_size_cut = 2500, fail_size_n = 70L,      # at this cut the group is under the 100-employee floor
  fail_stab_cut = 4000, fail_stab_share = 0.50, # at this cut stability is no longer above 50%
  best_cut = 3221, best_n = 122L, best_leavers = 68L, best_rate = 0.55738, best_wilson = c(0.46883, 0.64242)  # qualifying.csv g00305
)
WATCH_GROUP <- list(
  variable = "YearsAtCompany", max_years = 1,   # staff with 1 year or less at the company
  n = 215L, leavers = 75L, excess = 40.33673,   # followup_short_tenure.csv row "Everyone, short tenure"
  test_n = 62L, test_rate = 0.43548, ot_share = 0.32
)

is_v4_data <- function(md) {
  isTRUE(md$bundled) && is_attrition_target(md) && identical(md$positive, "Yes")
}

round5 <- function(x) 5 * round(x / 5)
range_pct <- function(a, b) { x <- round(100 * c(a, b)); if (x[1] == x[2]) sprintf("%d%%", x[1]) else sprintf("%d%% to %d%%", x[1], x[2]) }

# The junior subgroup as a RANGE, computed from the data at the two ends of the cut range.
# Never an exact cut; never an illustration of its own (it sits inside the overtime group).
junior_range <- function(md) {
  df <- md$df
  if (!is_v4_data(md) || !all(c("MonthlyIncome", "OverTime", "JobLevel") %in% names(df))) return(NULL)
  y <- md$y; N <- length(y); P <- sum(y)
  ot <- df$OverTime == "Yes"
  one <- function(cut) {
    g <- ot & df$MonthlyIncome < cut
    list(n = sum(g), yes = sum(y[g]), rate = mean(y[g]), share = sum(g) / N, share_pos = sum(y[g]) / P,
         rest_rate = mean(y[ot & !g]), junior = mean(df$JobLevel[g] == 1))
  }
  lo <- one(JUNIOR_RANGE$cut_lo); hi <- one(JUNIOR_RANGE$cut_hi)
  m <- function(f) mean(c(f(lo), f(hi)))
  list(lo = lo, hi = hi,
       n_text = sprintf("about %d to %d people", as.integer(round5(lo$n)), as.integer(round5(hi$n))),
       staff_text = sprintf("%s of staff", range_pct(lo$share, hi$share)),
       rate_text = sprintf("about %d%%", as.integer(round5(100 * m(function(z) z$rate)))),
       leavers_text = sprintf("close to %d%% of everyone who left", as.integer(round5(100 * m(function(z) z$share_pos)))),
       vs_rest_text = sprintf("about %s to %s times the rate of the other overtime workers (about %d%%)",
                              fmt_times(round(lo$rate / lo$rest_rate, 1)), fmt_times(round(hi$rate / hi$rest_rate, 1)),
                              as.integer(round5(100 * m(function(z) z$rest_rate)))),
       cut_text = sprintf("under roughly %s to %s a month", fmt_cut_value("MonthlyIncome", JUNIOR_RANGE$cut_lo),
                          fmt_cut_value("MonthlyIncome", JUNIOR_RANGE$cut_hi)),
       junior_share = m(function(z) z$junior))
}

# Plain-language description, v9 narrative wording.
junior_text <- function(jr) {
  sprintf("Overtime workers earning %s (%s, %s) left at %s, %s. They account for %s. They are part of the overtime finding, not added to it, and not a separate pattern.",
          jr$cut_text, jr$n_text, jr$staff_text, jr$rate_text, jr$vs_rest_text, jr$leavers_text)
}
junior_short <- function(jr) {
  sprintf("Includes its lower-paid, mostly junior subgroup (%s, left at %s): part of the overtime finding, not added to it.",
          jr$n_text, jr$rate_text)
}

# Staff with 1 year or less at the company: row indices (sorted), or NULL when not available.
watch_rows <- function(md) {
  if (!is_v4_data(md) || !(WATCH_GROUP$variable %in% names(md$df)) || !is.numeric(md$df[[WATCH_GROUP$variable]])) return(NULL)
  v <- md$df[[WATCH_GROUP$variable]]
  as.integer(which(!is.na(v) & v <= WATCH_GROUP$max_years))
}

watch_info <- function(md) {
  w <- watch_rows(md)
  if (is.null(w) || !length(w) || !("OverTime" %in% names(md$df))) return(NULL)
  y <- md$y; N <- length(y)
  list(n = length(w), yes = sum(y[w]), rate = mean(y[w]), share = length(w) / N,
       excess = sum(y[w]) - length(w) * mean(y), ot_share = mean(md$df$OverTime[w] == "Yes"))
}

# v9 narrative wording ("Worth watching, not a cleared finding: newer staff"), numbers from the data.
watch_text <- function(wi) {
  sprintf("Staff with 1 year or less at the company (%s people, %s of staff) left at %s, about %s people above the company rate; about a third of them (%s) work overtime. The group is large, but the exact group isn't stable across repeated analyses, because new hires, short tenure, junior level and low pay overlap. Treat them as one career-stage picture to watch, not a proven cause; it is not added to the overtime figures.",
          fmt_count(wi$n), fmt_pct0(wi$share), fmt_pct0(wi$rate), fmt_count(round5(wi$excess)), fmt_pct0(wi$ot_share))
}
WATCH_LABEL <- "Worth watching, not a cleared finding"

# A group that sits inside the overtime finding (OverTime = Yes plus another condition).
inside_overtime <- function(conds, md) {
  if (!is_v4_data(md) || length(conds) < 2L || !("OverTime" %in% names(conds))) return(FALSE)
  ot <- conds[["OverTime"]]
  identical(ot$type, "categorical") && identical(ot$levels, "Yes")
}
inside_overtime_note <- function(conds) {
  pay <- "MonthlyIncome" %in% names(conds)
  paste0("Inside the overtime group: its people are already counted in the overtime finding, so its numbers are not added to it and it has no illustration of its own.",
         if (pay) " The lower-paid, mostly junior subgroup is described as a range in the findings panel, not as this exact cut." else "")
}

# Career-stage context from the data (not a finding): v9 "Context: one career-stage picture".
career_context <- function(md) {
  df <- md$df
  if (!is_v4_data(md) || !all(c("JobLevel", "OverTime") %in% names(df))) return(NULL)
  y <- md$y
  ot <- df$OverTime == "Yes"; j1 <- df$JobLevel == 1
  g1 <- ot & j1; g2 <- ot & !j1
  if (!any(g1) || !any(g2)) return(NULL)
  list(n1 = sum(g1), rate1 = mean(y[g1]), n2 = sum(g2), rate2 = mean(y[g2]))
}

# Data for visNetwork: mostly gray; the accent only on the cleared group and the
# branch into it; too-small groups dashed and muted. Edge width follows the rows.
tree_vis_data <- function(tree, md, rules) {
  y <- md$y
  N <- length(y)
  a <- node_assess(tree, md, rules)
  ids <- a$id
  cleared <- a$id[a$cleared]
  outlined <- a$id[a$outlined]
  too_small <- a$id[a$too_small]
  watch <- a$id[a$watch]
  jr <- junior_range(md)
  on_path <- unique(unlist(lapply(cleared, function(f) node_chain(tree, f))))
  verb <- rate_verb(md)
  nodes <- do.call(rbind, lapply(seq_along(ids), function(i) {
    id <- ids[[i]]
    r <- a[i, ]
    is_c <- id %in% cleared
    is_o <- id %in% outlined
    is_s <- id %in% too_small
    is_w <- id %in% watch
    bg <- if (is_c) ACCENT else if (is_s) "#FFFFFF" else if (r$leaf) GRAY_FILL else "#FFFFFF"
    border <- if (is_c) ACCENT else if (is_o) INK else if (is_s || is_w) INK_MUTED else GRAY_BORDER
    fc <- if (is_c) "#FFFFFF" else if (is_s) INK_MUTED else INK
    conds <- path_conditions(tree, id, md$df)
    rule <- if (length(conds)) paste(vapply(conds, cond_text_full, character(1)), collapse = "\n") else "All rows"
    flag <- if (is_c) "Cleared finding" else if (is_s) "Too small to act on" else if (is_w) WATCH_LABEL else ""
    imp <- impact_sentence(r, md)
    note <- if (is_c && !is.null(jr)) junior_short(jr) else if (is_w) "Not accented and not added to the overtime figures." else if (inside_overtime(conds, md)) "Inside the overtime group; not added to it." else ""
    data.frame(
      id = id,
      label = paste0(
        sprintf("<b>%s</b>\nn %s \u00b7 %s", fmt_rate1(r$rate), fmt_count(r$n), fmt_share(r$share)),
        if (r$leaf) "" else if (is_c) sprintf("\nsplit: %s", get_node(tree, id)$split$variable)  # plain text: readable on the accent fill
        else sprintf("\n<i>split: %s</i>", get_node(tree, id)$split$variable),
        if (is_s) "\n<i>too small to act on</i>" else if (is_w) "\n<i>worth watching</i>" else ""
      ),
      title = paste0(
        sprintf("Node %s\n%s\n%s of %s %s (%s)", id, rule, fmt_count(r$yes), fmt_count(r$n), verb, fmt_rate1(r$rate)),
        sprintf("\n%s of all %s \u00b7 %s of all %s", fmt_share(r$share), unit_all(md), fmt_share(r$share_pos), unit_pos(md)),
        if (nzchar(flag)) paste0("\n", flag, if (is_s) paste0(" (", too_small_reason(r$n, r$yes, rules, md), ")") else "") else ""
      ),
      level = r$depth,
      color.background = bg,
      color.border = border,
      color.highlight.background = bg,
      color.highlight.border = INK,
      color.hover.background = bg,
      color.hover.border = INK_MUTED,
      font.color = fc,
      borderWidth = if (is_c || is_o || is_w) 2 else 1,
      menuTitle = sprintf("Node %s \u00b7 %s %s", id, fmt_rate1(r$rate), verb),
      menuSub = sprintf("n %s \u00b7 %s of %s \u00b7 %s of %s", fmt_count(r$n), fmt_share(r$share), unit_all(md),
                        fmt_share(r$share_pos), unit_pos(md)),
      menuLift = if (r$depth == 0L) "" else sprintf("%s\u00d7 the company average of %s", fmt_times(r$lift), fmt_rate1(mean(y))),
      menuFlag = flag,
      menuFlagWhy = if (is_s) too_small_reason(r$n, r$yes, rules, md) else "",
      menuImpact = imp,
      menuNote = note,
      isLeaf = r$leaf,
      tooSmall = is_s,
      cleared = is_c,
      watch = is_w,
      stringsAsFactors = FALSE
    )
  }))
  edges <- data.frame(from = character(), to = character(), label = character(), title = character(),
                      width = numeric(), color = character(), stringsAsFactors = FALSE)
  for (id in ids) {
    nd <- get_node(tree, id)
    if (is.null(nd$children)) next
    for (k in nd$children) {
      s <- step_condition(tree, k, md$df)
      n_k <- length(get_node(tree, k)$rows)
      edges <- rbind(edges, data.frame(
        from = id, to = k,
        label = edge_short_text(s),
        title = sprintf("%s\n%s rows (%s of all)", cond_text_full(s), fmt_count(n_k), fmt_share(n_k / N)),
        width = 1 + 15 * n_k / N,
        color = if (k %in% on_path) ACCENT else GRAY_LINE,
        stringsAsFactors = FALSE
      ))
    }
  }
  list(nodes = nodes, edges = edges, cleared = cleared, outlined = outlined, too_small = too_small, watch = watch, assess = a)
}

# Ranked list with bars for the per-node candidate table. Values are shown with
# the same rounding as v1 (improvement 2 dp, share 1 dp).
importance_list_html <- function(tab, max_rows = NULL, clickable = TRUE, verb = "left", rules = NULL) {
  small_tag <- function(n, rate) {
    if (is.null(rules) || is.na(n) || is.na(rate)) return("")
    if (n < rules$min_n || round(rate * n) < rules$min_pos) " (too small to act on)" else ""
  }
  if (!is.null(max_rows)) tab <- utils::head(tab, max_rows)
  max_imp <- suppressWarnings(max(tab$improvement, na.rm = TRUE))
  if (!is.finite(max_imp) || max_imp <= 0) max_imp <- 1
  rows <- lapply(seq_len(nrow(tab)), function(i) {
    r <- tab[i, , drop = FALSE]
    has <- is.finite(r$improvement)
    w <- if (has) max(0, 100 * r$improvement / max_imp) else 0
    top <- i == 1L && has
    detail <- if (has) {
      sprintf("Best split: %s \u00b7 left n %s (%s %s)%s \u00b7 right n %s (%s %s)%s",
              r$best_split, fmt_count(r$n_left), fmt_rate1(r$yes_rate_left), verb, small_tag(r$n_left, r$yes_rate_left),
              fmt_count(r$n_right), fmt_rate1(r$yes_rate_right), verb, small_tag(r$n_right, r$yes_rate_right))
    } else {
      "No usable split at this node"
    }
    tags$div(
      class = paste("imp-row", if (clickable && has) "clickable"),
      `data-var` = r$variable,
      role = if (clickable && has) "button",
      tabindex = if (clickable && has) "0",
      onclick = if (clickable && has) "HRTree.pickVar(this.dataset.var)",
      onkeydown = if (clickable && has) "if(event.key==='Enter'){HRTree.pickVar(this.dataset.var)}",
      title = if (clickable && has) "Try this split",
      tags$div(
        class = "imp-head",
        tags$span(class = "imp-rank", i),
        tags$span(class = "imp-var", r$variable),
        tags$span(class = "imp-type", r$type),
        if (has && !isTRUE(r$eligible)) tags$span(class = "imp-flag", "below limits")
      ),
      tags$div(
        class = "imp-barline",
        tags$div(class = "imp-track", tags$div(class = paste("imp-bar", if (top) "top"), style = sprintf("width:%.2f%%", w))),
        tags$span(class = "imp-val", if (has) sprintf("%.2f", r$improvement) else "\u2013"),
        tags$span(class = "imp-share", if (has) sprintf("%.1f%%", r$importance_pct) else "")
      ),
      tags$div(class = "imp-detail", detail)
    )
  })
  tags$div(
    class = "imp-list",
    tags$div(class = "imp-colhead", tags$span("Predictor"), tags$span(class = "right", "Improvement \u00b7 primary-split share")),
    rows
  )
}

used_importance_html <- function(imp) {
  if (!nrow(imp)) return(tags$p(class = "text-muted", "No splits yet."))
  max_imp <- max(imp$improvement)
  tags$div(
    class = "imp-list compact",
    lapply(seq_len(nrow(imp)), function(i) {
      tags$div(
        class = "imp-row",
        tags$div(class = "imp-head", tags$span(class = "imp-rank", i), tags$span(class = "imp-var", imp$variable[i])),
        tags$div(
          class = "imp-barline",
          tags$div(class = "imp-track", tags$div(class = paste("imp-bar", if (i == 1L) "top"),
                                                 style = sprintf("width:%.2f%%", 100 * imp$improvement[i] / max_imp))),
          tags$span(class = "imp-val", sprintf("%.2f", imp$improvement[i])),
          tags$span(class = "imp-share", sprintf("%.1f%%", imp$importance_pct[i]))
        )
      )
    })
  )
}

# Every node with its stats and rules, for CSV export.
node_export_table <- function(tree, md, rules = NULL) {
  if (!is.null(rules)) a <- node_assess(tree, md, rules)
  ids <- names(tree$nodes)
  ids <- ids[order(as.integer(ids))]
  do.call(rbind, lapply(ids, function(id) {
    nd <- get_node(tree, id)
    st <- node_basic(tree, id, md$y)
    conds <- path_conditions(tree, id, md$df)
    data.frame(
      node = id,
      parent = if (is.na(nd$parent)) "" else nd$parent,
      depth = st$depth,
      leaf = st$leaf,
      n = st$n,
      n_positive = st$yes,
      n_other = st$no,
      positive_rate = st$rate,
      share_of_rows = st$share,
      share_of_positives = if (is.null(rules)) NA_real_ else a$share_pos[a$id == id],
      times_company_rate = if (is.null(rules)) NA_real_ else a$lift[a$id == id],
      too_small_to_act_on = if (is.null(rules)) NA else a$too_small[a$id == id],
      status = if (is.null(rules)) "" else switch(a$status[a$id == id], cleared = "cleared finding", comparison = "comparison group", exploratory = if (isTRUE(a$watch[a$id == id])) "worth watching, not a cleared finding" else "exploratory", overall = "all rows"),
      split_variable = if (is.null(nd$split)) "" else nd$split$variable,
      split_left_rule = if (is.null(nd$split)) "" else nd$split$left_rule,
      split_improvement = if (is.null(nd$split)) NA_real_ else nd$split$improvement,
      rule = if (length(conds)) paste(vapply(conds, cond_text_full, character(1)), collapse = " AND ") else "All rows",
      rule_exact = path_text(tree, id),
      stringsAsFactors = FALSE
    )
  }))
}
