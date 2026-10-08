# Smoke test. From the project root:
#   Rscript tests/smoke.R
if (!file.exists("data/WA_Fn-UseC_-HR-Employee-Attrition.csv")) {
  stop("Run this from the project root.")
}
source("R/partition.R")
suppressPackageStartupMessages(library(rpart))

df <- read_hr_csv("data/WA_Fn-UseC_-HR-Employee-Attrition.csv")
stopifnot(nrow(df) == 1470, ncol(df) == 35, names(df)[1] == "Age")
stopifnot(sum(df$Attrition == "Yes") == 237)

y <- as.integer(df$Attrition == "Yes")
preds <- default_predictors(setdiff(names(df), c("Attrition", ID_CONST_COLUMNS)))
types <- stats::setNames(vapply(df[preds], function(x) column_type(x, TRUE), character(1)), preds)
root_imp <- impurity_bin(y, "gini") * length(y)
cand <- candidate_splits(df, y, seq_len(nrow(df)), preds, types, "gini", 20, 7, 5, 0.01, 0, root_imp)
stopifnot(cand$table$variable[1] == "OverTime")
stopifnot(abs(cand$table$n_left[1] - 1054) < 1)

spec <- attach_rows(cand$specs[["OverTime"]], df, y, seq_len(nrow(df)), "OverTime")
out <- apply_spec_split(new_tree(nrow(df)), "1", "OverTime", spec)
stopifnot(out$ok, length(out$tree$nodes) == 3)

inc <- manual_spec(df, y, seq_len(nrow(df)), "MonthlyIncome", "numeric", cut = 3000, criterion = "gini")
tree <- apply_spec_split(new_tree(nrow(df)), "1", "MonthlyIncome", inc)$tree
tree <- prune_node(tree, "1")
stopifnot(length(tree$nodes) == 1)

tree <- auto_grow(new_tree(nrow(df)), df, y, preds, types, "gini", 20, 7, 5, 0.01)
leaves <- leaf_table(tree, y)
stopifnot(sum(leaves$n) == 1470, nrow(leaves) > 1)
met <- classification_metrics(y, predict_leaf_prob(tree, y)$prob, 0.5)
stopifnot(is.finite(met$auc), met$auc > 0.6)

model_df <- df[, c("Attrition", preds), drop = FALSE]
model_df$Attrition <- factor(model_df$Attrition, levels = c("No", "Yes"))
fit <- rpart(
  Attrition ~ ., data = model_df, method = "class",
  control = rpart.control(cp = 0.01, minsplit = 20, minbucket = 7, maxdepth = 5)
)
stopifnot(nrow(fit$frame) > 1)

tmp <- tempfile(fileext = ".csv")
toy <- data.frame(
  Quit = rep(c("Yes", "No"), c(20, 30)),
  Score = c(rnorm(20, 1), rnorm(30, -1)),
  Team = rep(c("A", "B"), length.out = 50)
)
utils::write.csv(toy, tmp, row.names = FALSE)
toy2 <- read_hr_csv(tmp)
stopifnot(nrow(toy2) == 50, all(c("Quit", "Score", "Team") %in% names(toy2)))

message(sprintf(
  "smoke ok: OverTime improvement %.2f; auto leaves %d; in-sample AUC %.3f; rpart nodes %d",
  cand$table$improvement[1], nrow(leaves), met$auc, nrow(fit$frame)
))
