# Presentation helpers for the Shiny app.
# Formatting only: every split, count, rate and improvement comes unchanged from
# R/partition.R. Nothing here re-scores or re-ranks anything.

ACCENT <- "#C2410C"        # the one accent: high-attrition groups only
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

# Is this group one of the two cross-validated splits Quinn approved?
validation_status <- function(conds, md) {
  if (!length(conds)) return("overall")
  if (!isTRUE(md$bundled)) return("exploratory")
  vars <- names(conds)
  if (!all(vars %in% c("OverTime", "MonthlyIncome")) || !"OverTime" %in% vars) return("exploratory")
  ot <- conds[["OverTime"]]
  if (!identical(ot$type, "categorical") || length(ot$levels) != 1L) return("exploratory")
  if ("MonthlyIncome" %in% vars) {
    inc <- conds[["MonthlyIncome"]]
    if (!identical(ot$levels, "Yes") || !identical(inc$type, "numeric")) return("exploratory")
    bounds <- c(inc$lower, inc$upper)
    bounds <- bounds[!is.na(bounds)]
    if (length(bounds) != 1L || abs(bounds - 2475) > 1e-8) return("exploratory")
  }
  "validated"
}

node_basic <- function(tree, id, y) {
  nd <- get_node(tree, id)
  yy <- y[nd$rows]
  n <- length(yy)
  yes <- sum(yy)
  list(id = id, n = n, yes = yes, no = n - yes, rate = if (n) yes / n else NA_real_,
       share = n / length(y), depth = nd$depth, leaf = is.null(nd$children))
}

# Leaf with the highest rate among leaves large enough to headline.
headline_leaf <- function(tree, y, min_n) {
  ids <- leaf_ids(tree)
  if (length(tree$nodes) <= 1L) return(NULL)
  st <- lapply(ids, function(i) node_basic(tree, i, y))
  n <- vapply(st, `[[`, numeric(1), "n")
  r <- vapply(st, `[[`, numeric(1), "rate")
  ok <- n >= min_n
  if (!any(ok)) ok <- rep(TRUE, length(ids))
  cand <- which(ok)
  best <- cand[order(-r[cand], -n[cand])][1]
  ids[[best]]
}

flagged_leaves <- function(tree, y, flag_rate) {
  ids <- leaf_ids(tree)
  if (length(tree$nodes) <= 1L) return(character())
  ids[vapply(ids, function(i) {
    r <- node_basic(tree, i, y)$rate
    !is.na(r) && r >= flag_rate
  }, logical(1))]
}

# Data for visNetwork: mostly gray, accent only on highlighted leaves and the
# branches that lead to them. Edge width follows the rows flowing down it.
tree_vis_data <- function(tree, md, flag_rate) {
  y <- md$y
  N <- length(y)
  ids <- names(tree$nodes)
  ids <- ids[order(as.integer(ids))]
  flagged <- flagged_leaves(tree, y, flag_rate)
  on_path <- unique(unlist(lapply(flagged, function(f) node_chain(tree, f))))
  verb <- rate_verb(md)
  nodes <- do.call(rbind, lapply(ids, function(id) {
    st <- node_basic(tree, id, y)
    is_flag <- id %in% flagged
    bg <- if (is_flag) ACCENT else if (st$leaf) GRAY_FILL else "#FFFFFF"
    border <- if (is_flag) ACCENT else GRAY_BORDER
    fc <- if (is_flag) "#FFFFFF" else INK
    conds <- path_conditions(tree, id, md$df)
    rule <- if (length(conds)) paste(vapply(conds, cond_text_full, character(1)), collapse = "\n") else "All rows"
    data.frame(
      id = id,
      label = paste0(
        sprintf("<b>%s</b>\nn %s \u00b7 %s", fmt_rate1(st$rate), fmt_count(st$n), fmt_share(st$share)),
        if (st$leaf) "" else sprintf("\n<i>split: %s</i>", get_node(tree, id)$split$variable)
      ),
      title = sprintf("Node %s\n%s\n%s of %s %s (%s)", id, rule, fmt_count(st$yes), fmt_count(st$n), verb, fmt_rate1(st$rate)),
      level = st$depth,
      color.background = bg,
      color.border = border,
      color.highlight.background = bg,
      color.highlight.border = INK,
      color.hover.background = bg,
      color.hover.border = INK_MUTED,
      font.color = fc,
      borderWidth = if (is_flag) 2 else 1,
      menuTitle = sprintf("Node %s \u00b7 %s %s", id, fmt_rate1(st$rate), verb),
      menuSub = sprintf("n %s \u00b7 %s of all rows", fmt_count(st$n), fmt_share(st$share)),
      isLeaf = st$leaf,
      flagged = is_flag,
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
  list(nodes = nodes, edges = edges, flagged = flagged)
}

# Ranked list with bars for the per-node candidate table. Values are shown with
# the same rounding as v1 (improvement 2 dp, share 1 dp).
importance_list_html <- function(tab, max_rows = NULL, clickable = TRUE, verb = "left") {
  if (!is.null(max_rows)) tab <- utils::head(tab, max_rows)
  max_imp <- suppressWarnings(max(tab$improvement, na.rm = TRUE))
  if (!is.finite(max_imp) || max_imp <= 0) max_imp <- 1
  rows <- lapply(seq_len(nrow(tab)), function(i) {
    r <- tab[i, , drop = FALSE]
    has <- is.finite(r$improvement)
    w <- if (has) max(0, 100 * r$improvement / max_imp) else 0
    top <- i == 1L && has
    detail <- if (has) {
      sprintf("Best split: %s \u00b7 left n %s (%s %s) \u00b7 right n %s (%s %s)",
              r$best_split, fmt_count(r$n_left), fmt_rate1(r$yes_rate_left), verb,
              fmt_count(r$n_right), fmt_rate1(r$yes_rate_right), verb)
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
node_export_table <- function(tree, md) {
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
      split_variable = if (is.null(nd$split)) "" else nd$split$variable,
      split_left_rule = if (is.null(nd$split)) "" else nd$split$left_rule,
      split_improvement = if (is.null(nd$split)) NA_real_ else nd$split$improvement,
      rule = if (length(conds)) paste(vapply(conds, cond_text_full, character(1)), collapse = " AND ") else "All rows",
      rule_exact = path_text(tree, id),
      stringsAsFactors = FALSE
    )
  }))
}
