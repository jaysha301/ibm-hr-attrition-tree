# Regression snapshot of every number the app shows for the bundled IBM data.
# Usage (from the app directory):  Rscript tests/regression_snapshot.R <out_dir>
# Drives the real Shiny server (testServer) and the engine directly, then writes
# snapshot.json plus CSVs. Run it on two versions and diff the outputs.
suppressPackageStartupMessages(library(shiny))
args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args)) args[[1]] else "regression_out"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

app <- source("app.R", local = TRUE)$value  # defines `server` and helpers in this env

csv <- read_hr_csv("data/WA_Fn-UseC_-HR-Employee-Attrition.csv")
default_preds <- default_predictors(setdiff(names(csv), c("Attrition", ID_CONST_COLUMNS)))

node_frame <- function(tree, y) {
  ids <- names(tree$nodes)
  ids <- ids[order(as.integer(ids))]
  do.call(rbind, lapply(ids, function(id) {
    nd <- tree$nodes[[id]]
    yy <- y[nd$rows]
    data.frame(
      node = id,
      parent = if (is.na(nd$parent)) "" else nd$parent,
      side = if (is.na(nd$side)) "" else nd$side,
      depth = nd$depth,
      n = length(yy),
      n_yes = sum(yy),
      n_no = length(yy) - sum(yy),
      yes_rate = mean(yy),
      share_of_data = length(yy) / length(y),
      leaf = is.null(nd$children),
      split_variable = if (is.null(nd$split)) "" else nd$split$variable,
      split_left_rule = if (is.null(nd$split)) "" else nd$split$left_rule,
      split_right_rule = if (is.null(nd$split)) "" else nd$split$right_rule,
      split_improvement = if (is.null(nd$split)) NA_real_ else nd$split$improvement,
      path = path_text(tree, id),
      stringsAsFactors = FALSE
    )
  }))
}

snap <- list()
testServer(server, {
  session$setInputs(
    target = "Attrition", positive = "Yes", include_id = FALSE, as_cat = TRUE,
    predictors = default_preds, criterion = "gini", minsplit = 20, minbucket = 7,
    max_depth = 5, cp = 0.01, threshold = 0.5
  )
  session$flushReact()
  md <- model_data()
  # Start from an explicit root-only tree in both versions.
  session$setInputs(reset_tree = 1); session$flushReact()
  session$setInputs(node_picker = "1"); session$flushReact()
  snap$data <<- list(n = nrow(md$df), n_yes = sum(md$y), base_rate = mean(md$y),
                     n_predictors = length(md$predictors), predictors = md$predictors,
                     types = as.list(md$types))
  snap$root_candidates <<- cand()$table

  # Validated two-split view: auto-split root, then auto-split the OverTime = Yes child.
  session$setInputs(auto_split = 1); session$flushReact()
  tr <- tree_rv()
  kids <- tr$nodes[["1"]]$children
  ot_yes <- kids[vapply(kids, function(k) grepl("Yes", path_text(tr, k)), logical(1))]
  session$setInputs(node_picker = ot_yes); session$flushReact()
  snap$overtime_yes_node <<- ot_yes
  snap$overtime_yes_candidates <<- cand()$table
  session$setInputs(auto_split = 2); session$flushReact()
  snap$two_split_nodes <<- node_frame(tree_rv(), md$y)

  # Full auto tree under defaults.
  session$setInputs(grow_full = 1); session$flushReact()
  tr <- tree_rv()
  snap$auto_tree_nodes <<- node_frame(tr, md$y)
  snap$auto_tree_leaves <<- leaf_table(tr, md$y)
  snap$auto_tree_importance <<- used_importance(tr)
  pr <- predict_leaf_prob(tr, md$y)
  snap$auto_tree_metrics_t050 <<- classification_metrics(md$y, pr$prob, 0.5)
  snap$auto_tree_metrics_base_rate <<- classification_metrics(md$y, pr$prob, mean(md$y))
})

# Engine-only cross-check (no Shiny): must equal the server path.
y <- as.integer(csv$Attrition == "Yes")
types <- stats::setNames(vapply(csv[default_preds], function(x) column_type(x, TRUE), character(1)), default_preds)
eng_tree <- auto_grow(new_tree(nrow(csv)), csv, y, default_preds, types, "gini", 20, 7, 5, 0.01)
snap$engine_matches_server <- isTRUE(all.equal(node_frame(eng_tree, y), snap$auto_tree_nodes))

jsonlite::write_json(snap, file.path(out_dir, "snapshot.json"), digits = NA, auto_unbox = TRUE, pretty = TRUE, na = "null")
for (nm in c("root_candidates", "overtime_yes_candidates", "two_split_nodes", "auto_tree_nodes",
             "auto_tree_leaves", "auto_tree_importance")) {
  utils::write.csv(snap[[nm]], file.path(out_dir, paste0(nm, ".csv")), row.names = FALSE)
}
m <- snap$auto_tree_metrics_t050
message(sprintf("snapshot written to %s | root top: %s | auto nodes %d | AUC %.6f | engine==server %s",
                out_dir, snap$root_candidates$variable[1], nrow(snap$auto_tree_nodes), m$auc,
                snap$engine_matches_server))
