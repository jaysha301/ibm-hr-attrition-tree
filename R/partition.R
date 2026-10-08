# Interactive recursive partitioning (JMP Partition-style) for a binary target.
# Impurity reduction is reported on the rpart scale: n_node * (parent impurity
# - weighted child impurity). For Gini, impurity = 1 - sum p^2.

impurity_vec <- function(p, criterion) {
  p <- pmin(pmax(p, 0), 1)
  if (criterion == "information") {
    out <- numeric(length(p))
    ok <- p > 0 & p < 1
    out[ok] <- -p[ok] * log2(p[ok]) - (1 - p[ok]) * log2(1 - p[ok])
    out
  } else {
    1 - p * p - (1 - p) * (1 - p)
  }
}

impurity_bin <- function(y, criterion) {
  if (!length(y)) return(0)
  impurity_vec(mean(y), criterion)
}

fmt_num <- function(z) {
  if (length(z) != 1 || is.na(z)) return("")
  if (abs(z - round(z)) < 1e-8) format(round(z), trim = TRUE, scientific = FALSE)
  else format(signif(z, 6), trim = TRUE, scientific = FALSE)
}

fmt_pct <- function(p) sprintf("%.1f%%", 100 * p)

# y is 0/1 on the SAME index as x (the node rows only).
# Left branch is the lower-risk side when a direction is free to choose.
best_numeric_split <- function(x, y, minbucket, criterion) {
  ok <- !is.na(x) & !is.na(y)
  x <- x[ok]
  y <- y[ok]
  n <- length(y)
  if (n < 2L || length(unique(x)) < 2L) return(NULL)
  ord <- order(x)
  x <- x[ord]
  y <- y[ord]
  change <- which(x[-n] != x[-1L])
  if (!length(change)) return(NULL)
  csum <- cumsum(y)
  total <- csum[n]
  nL <- change
  nR <- n - nL
  keep <- nL >= 1L & nR >= 1L
  # Prefer splits that meet minbucket, but remember the best unrestricted split
  # so the candidate table can still show a constant-free variable.
  gain_at <- function(idx) {
    yesL <- csum[idx]
    yesR <- total - yesL
    pL <- yesL / nL[match(idx, change)]
    # recompute locally to keep this function usable
    nLi <- idx
    nRi <- n - nLi
    pLi <- yesL / nLi
    pRi <- yesR / nRi
    p <- total / n
    impurity_vec(p, criterion) -
      (nLi / n) * impurity_vec(pLi, criterion) -
      (nRi / n) * impurity_vec(pRi, criterion)
  }
  gains <- gain_at(change)
  eligible_size <- nL >= minbucket & nR >= minbucket
  pick <- function(mask) {
    if (!any(mask) || all(!is.finite(gains[mask]))) return(NULL)
    rel <- which(mask)
    j <- rel[which.max(gains[mask])]
    i <- change[j]
    list(
      cut = (x[i] + x[i + 1L]) / 2,
      gain = gains[j],
      meets_minbucket = eligible_size[j]
    )
  }
  best <- pick(eligible_size)
  if (is.null(best)) best <- pick(rep(TRUE, length(change)))
  best
}

best_categorical_split <- function(x, y, minbucket, criterion) {
  ok <- !is.na(x) & !is.na(y)
  x <- as.character(x[ok])
  y <- y[ok]
  n <- length(y)
  if (n < 2L) return(NULL)
  levs <- unique(x)
  if (length(levs) < 2L) return(NULL)
  tab_n <- tapply(y, x, length)
  tab_yes <- tapply(y, x, sum)
  p <- tab_yes / tab_n
  levs <- names(sort(p, decreasing = FALSE))
  k <- length(levs)
  # Prefixes of the attrition-rate ordering are optimal binary CART splits.
  gains <- numeric(k - 1L)
  meets <- logical(k - 1L)
  total_yes <- sum(y)
  c_n <- cumsum(as.numeric(tab_n[levs]))
  c_yes <- cumsum(as.numeric(tab_yes[levs]))
  p_parent <- total_yes / n
  parent_imp <- impurity_vec(p_parent, criterion)
  for (i in seq_len(k - 1L)) {
    nL <- c_n[i]
    nR <- n - nL
    gains[i] <- parent_imp -
      (nL / n) * impurity_vec(c_yes[i] / nL, criterion) -
      (nR / n) * impurity_vec((total_yes - c_yes[i]) / nR, criterion)
    meets[i] <- nL >= minbucket && nR >= minbucket
  }
  pick_from <- function(mask) {
    if (!any(mask)) return(NA_integer_)
    idx <- which(mask)
    idx[which.max(gains[mask])]
  }
  j <- pick_from(meets)
  if (is.na(j)) j <- pick_from(rep(TRUE, k - 1L))
  if (is.na(j)) return(NULL)
  list(
    left_levels = levs[seq_len(j)],
    gain = gains[j],
    meets_minbucket = meets[j],
    all_levels = levs
  )
}

describe_split <- function(variable, type, cut, left_levels, all_levels) {
  if (type == "numeric") {
    left_rule <- paste0(variable, " < ", fmt_num(cut))
    right_rule <- paste0(variable, " >= ", fmt_num(cut), " or missing")
  } else {
    left_rule <- paste0(variable, " in {", paste(left_levels, collapse = ", "), "}")
    right_levels <- setdiff(all_levels, left_levels)
    extra <- if (length(right_levels)) paste(right_levels, collapse = ", ") else "(none)"
    right_rule <- paste0(variable, " in {", extra, "} or missing")
  }
  list(left_rule = left_rule, right_rule = right_rule)
}

eval_partition <- function(y, left, criterion) {
  n <- length(y)
  nL <- sum(left)
  nR <- n - nL
  if (nL == 0L || nR == 0L) return(NULL)
  yesL <- sum(y[left])
  yesR <- sum(y[!left])
  gain <- impurity_bin(y, criterion) -
    (nL / n) * impurity_bin(y[left], criterion) -
    (nR / n) * impurity_bin(y[!left], criterion)
  list(
    n_left = nL, n_right = nR,
    yes_left = yesL, yes_right = yesR,
    rate_left = yesL / nL, rate_right = yesR / nR,
    gain = gain, improvement = n * gain
  )
}

candidate_splits <- function(df, y_all, rows, predictors, types, criterion,
                             minsplit, minbucket, max_depth, cp,
                             node_depth, root_impurity_total) {
  y <- y_all[rows]
  n <- length(y)
  specs <- list()
  rows_out <- vector("list", length(predictors))
  for (i in seq_along(predictors)) {
    v <- predictors[[i]]
    type <- types[[v]]
    x <- df[[v]][rows]
    base <- data.frame(
      variable = v,
      type = type,
      best_split = "no split",
      improvement = NA_real_,
      relative_improvement = NA_real_,
      eligible = FALSE,
      n_left = NA_integer_,
      yes_rate_left = NA_real_,
      n_right = NA_integer_,
      yes_rate_right = NA_real_,
      stringsAsFactors = FALSE
    )
    spec <- NULL
    if (type == "numeric" && is.numeric(x)) {
      found <- best_numeric_split(x, y, minbucket = 1L, criterion = criterion)
      if (!is.null(found)) {
        left <- !is.na(x) & x < found$cut
        ev <- eval_partition(y, left, criterion)
        if (!is.null(ev)) {
          rules <- describe_split(v, "numeric", found$cut, NULL, NULL)
          spec <- c(ev, list(
            type = "numeric", cut = found$cut, left_levels = NULL,
            all_levels = NULL, left_rule = rules$left_rule, right_rule = rules$right_rule
          ))
        }
      }
    } else {
      found <- best_categorical_split(x, y, minbucket = 1L, criterion = criterion)
      if (!is.null(found)) {
        all_levels <- unique(as.character(x[!is.na(x)]))
        left <- !is.na(x) & as.character(x) %in% found$left_levels
        ev <- eval_partition(y, left, criterion)
        if (!is.null(ev)) {
          rules <- describe_split(v, "categorical", NULL, found$left_levels, all_levels)
          spec <- c(ev, list(
            type = "categorical", cut = NA_real_, left_levels = found$left_levels,
            all_levels = all_levels, left_rule = rules$left_rule, right_rule = rules$right_rule
          ))
        }
      }
    }
    if (!is.null(spec)) {
      rel <- if (root_impurity_total > 0) spec$improvement / root_impurity_total else NA_real_
      size_ok <- n >= minsplit && spec$n_left >= minbucket && spec$n_right >= minbucket
      depth_ok <- node_depth < max_depth
      cp_ok <- is.finite(rel) && rel >= cp
      base$best_split <- spec$left_rule
      base$improvement <- spec$improvement
      base$relative_improvement <- rel
      base$eligible <- size_ok && depth_ok && cp_ok && spec$gain > 0
      base$n_left <- spec$n_left
      base$yes_rate_left <- spec$rate_left
      base$n_right <- spec$n_right
      base$yes_rate_right <- spec$rate_right
      specs[[v]] <- spec
    }
    rows_out[[i]] <- base
  }
  tab <- do.call(rbind, rows_out)
  rownames(tab) <- NULL
  imp <- tab$improvement
  imp[!is.finite(imp)] <- NA_real_
  pos <- imp
  pos[!is.finite(pos) | pos < 0] <- 0
  denom <- sum(pos)
  tab$importance_pct <- if (denom > 0) 100 * pos / denom else 0
  ord <- order(is.na(tab$improvement), -replace(tab$improvement, is.na(tab$improvement), -Inf))
  tab <- tab[ord, , drop = FALSE]
  specs <- specs[tab$variable]
  list(table = tab, specs = specs)
}

new_tree <- function(n) {
  list(
    nodes = list("1" = list(
      id = "1",
      parent = NA_character_,
      side = NA_character_,
      depth = 0L,
      rows = seq_len(n),
      split = NULL,
      children = NULL
    )),
    next_id = 2L
  )
}

get_node <- function(tree, id) tree$nodes[[as.character(id)]]

is_leaf <- function(node) is.null(node$children)

leaf_ids <- function(tree) {
  ids <- names(tree$nodes)
  ids[vapply(tree$nodes, is_leaf, logical(1))]
}

descendant_ids <- function(tree, id) {
  node <- get_node(tree, id)
  if (is.null(node) || is.null(node$children)) return(character())
  kids <- node$children
  c(kids, unlist(lapply(kids, function(k) descendant_ids(tree, k)), use.names = FALSE))
}

path_text <- function(tree, id) {
  parts <- character()
  cur <- as.character(id)
  guard <- 0L
  while (!is.na(get_node(tree, cur)$parent)) {
    guard <- guard + 1L
    if (guard > 100L) break
    nd <- get_node(tree, cur)
    parent <- get_node(tree, nd$parent)
    rule <- if (identical(nd$side, "left")) parent$split$left_rule else parent$split$right_rule
    parts <- c(rule, parts)
    cur <- nd$parent
  }
  if (!length(parts)) "All rows (root)" else paste(parts, collapse = " AND ")
}

apply_spec_split <- function(tree, node_id, variable, spec) {
  node_id <- as.character(node_id)
  node <- get_node(tree, node_id)
  if (is.null(node)) stop("Unknown node")
  if (is.null(spec)) stop("No split specification")
  # Replace an existing split rather than stacking onto children.
  if (!is.null(node$children)) tree <- prune_node(tree, node_id)
  node <- get_node(tree, node_id)
  nL <- spec$n_left
  nR <- spec$n_right
  if (is.null(nL) || nL == 0L || nR == 0L) {
    return(list(tree = tree, ok = FALSE, message = "That split puts every row on one side."))
  }
  # Caller passes spec built on this node's rows. Reconstruct membership from rules
  # stored alongside a left-index vector when present.
  if (is.null(spec$rows_left)) {
    return(list(tree = tree, ok = FALSE, message = "Split is missing row assignment."))
  }
  left_rows <- spec$rows_left
  right_rows <- spec$rows_right
  idL <- as.character(tree$next_id)
  idR <- as.character(tree$next_id + 1L)
  tree$next_id <- tree$next_id + 2L
  tree$nodes[[idL]] <- list(
    id = idL, parent = node_id, side = "left", depth = node$depth + 1L,
    rows = left_rows, split = NULL, children = NULL
  )
  tree$nodes[[idR]] <- list(
    id = idR, parent = node_id, side = "right", depth = node$depth + 1L,
    rows = right_rows, split = NULL, children = NULL
  )
  tree$nodes[[node_id]]$children <- c(idL, idR)
  tree$nodes[[node_id]]$split <- list(
    variable = variable,
    type = spec$type,
    cut = spec$cut,
    left_levels = spec$left_levels,
    left_rule = spec$left_rule,
    right_rule = spec$right_rule,
    improvement = spec$improvement
  )
  list(tree = tree, ok = TRUE, message = paste("Split", node_id, "on", variable))
}

# Build a spec for an explicit user choice. x and y are FULL-data vectors.
manual_spec <- function(df, y_all, rows, variable, type, cut = NULL, left_levels = NULL, criterion) {
  x <- df[[variable]][rows]
  y <- y_all[rows]
  if (type == "numeric") {
    if (is.null(cut) || !is.finite(cut)) return(NULL)
    left <- !is.na(x) & x < cut
    all_levels <- NULL
    left_levels <- NULL
  } else {
    all_levels <- unique(as.character(df[[variable]][!is.na(df[[variable]])]))
    # Levels are defined on the whole column so the rule text stays stable,
    # but membership is evaluated on the node.
    present <- unique(as.character(x[!is.na(x)]))
    if (is.null(left_levels) || !length(left_levels)) return(NULL)
    left_levels <- intersect(as.character(left_levels), present)
    if (!length(left_levels) || length(left_levels) >= length(present)) return(NULL)
    left <- !is.na(x) & as.character(x) %in% left_levels
    all_levels <- present
  }
  ev <- eval_partition(y, left, criterion)
  if (is.null(ev)) return(NULL)
  rules <- describe_split(variable, type, cut, left_levels, all_levels)
  c(ev, list(
    type = type,
    cut = if (type == "numeric") cut else NA_real_,
    left_levels = left_levels,
    all_levels = all_levels,
    left_rule = rules$left_rule,
    right_rule = rules$right_rule,
    rows_left = rows[left],
    rows_right = rows[!left]
  ))
}

attach_rows <- function(spec, df, y_all, rows, variable) {
  if (is.null(spec)) return(NULL)
  built <- manual_spec(
    df, y_all, rows, variable, spec$type,
    cut = spec$cut, left_levels = spec$left_levels, criterion = "gini"
  )
  # manual_spec recomputes gain under gini; keep the caller's already-evaluated
  # counts by assigning rows directly.
  x <- df[[variable]][rows]
  if (spec$type == "numeric") left <- !is.na(x) & x < spec$cut
  else left <- !is.na(x) & as.character(x) %in% spec$left_levels
  spec$rows_left <- rows[left]
  spec$rows_right <- rows[!left]
  spec
}

prune_node <- function(tree, node_id) {
  node_id <- as.character(node_id)
  node <- get_node(tree, node_id)
  if (is.null(node) || is.null(node$children)) return(tree)
  drop <- descendant_ids(tree, node_id)
  for (d in drop) tree$nodes[[d]] <- NULL
  tree$nodes[[node_id]]$children <- NULL
  tree$nodes[[node_id]]$split <- NULL
  tree
}

auto_grow <- function(tree, df, y_all, predictors, types, criterion,
                      minsplit, minbucket, max_depth, cp,
                      only_under = NULL, max_splits = 100L) {
  root_imp <- impurity_bin(y_all, criterion) * length(y_all)
  n_added <- 0L
  repeat {
    if (n_added >= max_splits) break
    leaves <- leaf_ids(tree)
    if (!is.null(only_under)) {
      keep <- c(as.character(only_under), descendant_ids(tree, only_under))
      leaves <- intersect(leaves, keep)
    }
    best <- NULL
    for (id in leaves) {
      node <- get_node(tree, id)
      cand <- candidate_splits(
        df, y_all, node$rows, predictors, types, criterion,
        minsplit, minbucket, max_depth, cp, node$depth, root_imp
      )
      tab <- cand$table
      elig <- tab[tab$eligible %in% TRUE, , drop = FALSE]
      if (!nrow(elig)) next
      top <- elig[1, , drop = FALSE]
      if (is.null(best) || top$improvement > best$improvement) {
        spec <- cand$specs[[top$variable]]
        spec <- attach_rows(spec, df, y_all, node$rows, top$variable)
        best <- list(id = id, variable = top$variable, spec = spec, improvement = top$improvement)
      }
    }
    if (is.null(best)) break
    out <- apply_spec_split(tree, best$id, best$variable, best$spec)
    if (!out$ok) break
    tree <- out$tree
    n_added <- n_added + 1L
  }
  tree
}

node_stats <- function(tree, y_all, id, positive_label) {
  node <- get_node(tree, id)
  y <- y_all[node$rows]
  n <- length(y)
  yes <- sum(y == 1)
  no <- n - yes
  list(
    id = id,
    n = n,
    yes = yes,
    no = no,
    rate = if (n) yes / n else NA_real_,
    depth = node$depth,
    leaf = is_leaf(node),
    path = path_text(tree, id),
    positive = positive_label,
    split_variable = if (is.null(node$split)) NA_character_ else node$split$variable
  )
}

leaf_table <- function(tree, y_all) {
  ids <- leaf_ids(tree)
  # stable-ish: depth then id
  ids <- ids[order(vapply(ids, function(i) get_node(tree, i)$depth, integer(1)), as.integer(ids))]
  rows <- lapply(ids, function(id) {
    node <- get_node(tree, id)
    y <- y_all[node$rows]
    n <- length(y)
    yes <- sum(y == 1)
    data.frame(
      leaf = id,
      depth = node$depth,
      n = n,
      n_yes = yes,
      n_no = n - yes,
      yes_rate = if (n) yes / n else NA_real_,
      rule = path_text(tree, id),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

used_importance <- function(tree) {
  vars <- character()
  imps <- numeric()
  for (nd in tree$nodes) {
    if (is.null(nd$split)) next
    vars <- c(vars, nd$split$variable)
    imps <- c(imps, nd$split$improvement)
  }
  if (!length(vars)) {
    return(data.frame(variable = character(), improvement = numeric(), importance_pct = numeric()))
  }
  agg <- tapply(imps, vars, sum)
  out <- data.frame(
    variable = names(agg),
    improvement = as.numeric(agg),
    stringsAsFactors = FALSE
  )
  out <- out[order(-out$improvement), , drop = FALSE]
  out$importance_pct <- 100 * out$improvement / sum(out$improvement)
  rownames(out) <- NULL
  out
}

predict_leaf_prob <- function(tree, y_all) {
  n <- length(y_all)
  prob <- rep(NA_real_, n)
  leaf <- rep(NA_character_, n)
  for (id in leaf_ids(tree)) {
    node <- get_node(tree, id)
    rows <- node$rows
    rate <- mean(y_all[rows])
    prob[rows] <- rate
    leaf[rows] <- id
  }
  list(prob = prob, leaf = leaf)
}

classification_metrics <- function(y, prob, threshold = 0.5) {
  ok <- !is.na(prob) & !is.na(y)
  y <- y[ok]
  prob <- prob[ok]
  pred <- as.integer(prob >= threshold)
  tp <- sum(pred == 1 & y == 1)
  tn <- sum(pred == 0 & y == 0)
  fp <- sum(pred == 1 & y == 0)
  fn <- sum(pred == 0 & y == 1)
  acc <- if (length(y)) mean(pred == y) else NA_real_
  sens <- if ((tp + fn) > 0) tp / (tp + fn) else NA_real_
  spec <- if ((tn + fp) > 0) tn / (tn + fp) else NA_real_
  bal <- mean(c(sens, spec), na.rm = TRUE)
  base_acc <- if (length(y)) max(mean(y == 1), mean(y == 0)) else NA_real_
  n1 <- sum(y == 1)
  n0 <- sum(y == 0)
  auc <- NA_real_
  if (n1 > 0 && n0 > 0 && length(unique(prob)) > 1) {
    r <- rank(prob, ties.method = "average")
    auc <- (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
  } else if (n1 > 0 && n0 > 0) {
    auc <- 0.5
  }
  brier <- if (length(y)) mean((prob - y)^2) else NA_real_
  list(
    n = length(y), accuracy = acc, baseline_accuracy = base_acc,
    sensitivity = sens, specificity = spec, balanced_accuracy = bal,
    auc = auc, brier = brier, threshold = threshold,
    tp = tp, tn = tn, fp = fp, fn = fn
  )
}

read_hr_csv <- function(path) {
  df <- utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    fileEncoding = "UTF-8-BOM",
    na.strings = c("", "NA", "N/A")
  )
  names(df) <- sub("^\ufeff", "", names(df), perl = TRUE)
  names(df) <- make.unique(trimws(names(df)), sep = "_")
  df
}

column_type <- function(x, as_categorical_ints) {
  if (is.character(x) || is.factor(x) || is.logical(x)) return("categorical")
  if (is.numeric(x)) {
    ux <- unique(x[!is.na(x)])
    if (isTRUE(as_categorical_ints) && length(ux) <= 10L &&
        length(ux) >= 1L && all(abs(ux - round(ux)) < 1e-8)) {
      return("categorical")
    }
    return("numeric")
  }
  "categorical"
}

default_positive <- function(values) {
  vals <- unique(as.character(values[!is.na(values)]))
  if ("Yes" %in% vals) return("Yes")
  if ("1" %in% vals && "0" %in% vals) return("1")
  tab <- sort(table(as.character(values[!is.na(values)])))
  names(tab)[1]  # minority class
}

ID_CONST_COLUMNS <- c("EmployeeNumber", "EmployeeCount", "Over18", "StandardHours")
NOT_PAY_COLUMNS <- c("DailyRate", "HourlyRate", "MonthlyRate")

default_predictors <- function(columns) {
  setdiff(columns, NOT_PAY_COLUMNS)
}
