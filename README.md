# IBM HR attrition partition

Interactive recursive partitioning for a binary outcome, in the spirit of the Partition platform in SAS JMP. The bundled dataset is IBM's fictional HR Analytics Employee Attrition sample (1,470 employees, target `Attrition`).

The Shiny app lets you:

- start from the bundled IBM file, or upload any CSV with a two-class target
- grow a tree under Gini or information gain, with minimum node size, depth, and a complexity (`cp`) limit
- click a node and see **every** predictor ranked by its best split on the rows in that node
- apply that automatic split, or set a **custom** cutpoint (numeric) or level grouping (categorical)
- prune a split, grow the selected branch, or grow the whole tree
- read in-sample accuracy, sensitivity, specificity, AUC, and a confusion table

In-sample fit numbers describe the same rows the tree was grown on. They will look better than a prediction on new employees. `analysis/` is a separate held-out `rpart` study of this same sample (train/test and cross-validation). The app does not use those files.

## Run locally

From this directory:

```bash
Rscript install.R
Rscript tests/smoke.R
Rscript -e 'shiny::runApp(".", host = "127.0.0.1", port = 8073, launch.browser = TRUE)'
```

Then open http://127.0.0.1:8073 . Packages used by the app: shiny, bslib, DT, visNetwork, htmlwidgets, jsonlite. `install.R` also checks rpart and pROC, which `analysis/attrition_tree.R` uses.

## Data

See `data/SOURCE.md`. The CSV is IBM's fictional sample. The Kaggle listing (`pavansubhasht/ibm-hr-analytics-attrition-dataset`) is under CC0 1.0 Universal. This repo vendors a public GitHub mirror of that file.

By default the app hides `EmployeeCount`, `EmployeeNumber`, `Over18`, and `StandardHours` (identifier or constant). Check **Include ID and constant columns** to put them back. `DailyRate`, `HourlyRate`, and `MonthlyRate` start unchecked because they are not compensation; select them in **Predictors** if you want them in the tree. Integer columns with 10 or fewer distinct values start as categorical.

## Publish on shinyapps.io

No deploy token is stored in this project. To publish on the free account **jaysha301** (public app):

1. Install the deploy helper if you need it: `install.packages("rsconnect")`.
2. In the browser, open https://www.shinyapps.io and sign in as **jaysha301**.
3. Open **Account → Tokens → Show** (or **+ Token / Add Token**) and copy the token and secret. Do not commit them.
4. In R, from this directory:

```r
rsconnect::setAccountInfo(
  name = "jaysha301",
  token = "PASTE_TOKEN",
  secret = "PASTE_SECRET"
)
rsconnect::deployApp(
  appDir = ".",
  appName = "ibm-hr-attrition-tree",
  account = "jaysha301",
  forceUpdate = TRUE
)
```

`setAccountInfo` writes the credential under the user account (typically `~/.config/rsconnect/`), not in this repo. After a successful deploy the public URL is:

https://jaysha301.shinyapps.io/ibm-hr-attrition-tree/

Free shinyapps.io apps are public. This dataset is a public fictional sample, so that is appropriate. Do not upload a CSV of real employee records to this app while it is public.

## Project layout

| Path | What it is |
| --- | --- |
| `app.R` | Shiny app |
| `R/partition.R` | Split search, custom splits, grow, prune, metrics |
| `data/` | Bundled IBM CSV and source note |
| `tests/smoke.R` | Loads the CSV, checks the root split, grows a tree, grows a default `rpart` tree |
| `analysis/` | Held-out `rpart` write-up (separate from the interactive app) |
| `install.R` | Package check |

## Split rules implemented in the app

- Numeric: best cut is the midpoint between adjacent distinct values with the largest impurity reduction. The left branch is `value < cut`.
- Categorical: levels are ordered by the positive-class rate; the best prefix of that order is the candidate split (binary CART). A custom split may put any subset of levels on the left.
- Missing predictor values go to the right branch.
- Improvement is `n` times the impurity reduction at that node. Relative improvement divides by the root impurity total. `cp` is the minimum relative improvement required for an automatic split.
