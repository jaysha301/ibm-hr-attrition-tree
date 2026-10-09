# Attrition Tree Explorer: interactive recursive partitioning in the spirit of
# SAS JMP Partition. Run from this directory: shiny::runApp(".")
#
# Every package is attached explicitly so shinyapps.io detects and loads it.
library(shiny)
library(bslib)
library(magrittr)
library(visNetwork)
library(DT)

source(file.path("R", "partition.R"), local = FALSE)    # split engine (unchanged from v1)
source(file.path("R", "presentation.R"), local = FALSE) # formatting only

bundled_csv_path <- function() {
  candidates <- c(
    file.path("data", "WA_Fn-UseC_-HR-Employee-Attrition.csv"),
    file.path("..", "data", "WA_Fn-UseC_-HR-Employee-Attrition.csv")
  )
  hit <- candidates[file.exists(candidates)]
  if (!length(hit)) stop("Bundled CSV not found. Expected data/WA_Fn-UseC_-HR-Employee-Attrition.csv")
  normalizePath(hit[[1]], mustWork = TRUE)
}

tool_btn <- function(id = NULL, label, icon_name, onclick = NULL, title = label, primary = FALSE, ...) {
  cls <- paste("btn-tool", if (primary) "primary")
  if (is.null(id)) {
    tags$button(type = "button", class = cls, onclick = onclick, title = title, `aria-label` = title,
                shiny::icon(icon_name), tags$span(class = "lbl", label), ...)
  } else {
    actionButton(id, tags$span(class = "lbl", label), icon = shiny::icon(icon_name), class = cls,
                 title = title, `aria-label` = title, ...)
  }
}

theme <- bs_theme(
  version = 5,
  bg = "#FFFFFF", fg = "#1F2937",
  primary = "#1F2937", secondary = "#6B7280",
  base_font = font_collection("system-ui", "-apple-system", "Segoe UI", "Roboto", "Helvetica Neue", "Arial", "sans-serif"),
  "border-radius" = "8px",
  "link-color" = "#1F2937"
)

explore_panel <- nav_panel(
  "Explore",
  icon = shiny::icon("diagram-project"),
  layout_sidebar(
    fillable = FALSE,
    border = FALSE,
    border_radius = FALSE,
    sidebar = sidebar(
      id = "controls",
      title = "Controls",
      width = 300,
      open = list(desktop = "open", mobile = "closed"),
      accordion(
        id = "control_sections",
        open = c("Data", "Highlight"),
        multiple = TRUE,
        accordion_panel(
          "Data", icon = shiny::icon("table"),
          fileInput("file", "Upload a CSV", accept = c(".csv", "text/csv"), placeholder = "No file"),
          actionButton("use_bundled", "Use the bundled IBM sample", icon = shiny::icon("rotate-left"),
                       class = "btn-light btn-sm w-100"),
          tags$div(class = "data-status", textOutput("data_status", inline = TRUE)),
          tags$hr(),
          selectInput("target", "Outcome (target)", choices = NULL),
          selectInput("positive", "Count as the event", choices = NULL)
        ),
        accordion_panel(
          "Highlight", icon = shiny::icon("highlighter"),
          numericInput("min_group", "Smallest group to act on (employees)", value = 100, min = 1, step = 10),
          uiOutput("min_group_help"),
          sliderInput("flag_rate", "Highlight groups with a rate of at least (default: 1.5\u00d7 the company average)",
                      min = 0, max = 100, value = 25, step = 1, post = "%", ticks = FALSE),
          helpText("Only the cleared group (validated and big enough) gets the accent color. Other big groups above this rate get a dark outline. Groups that are too small are never highlighted.")
        ),
        accordion_panel(
          "Predictors", icon = shiny::icon("list-check"),
          selectizeInput("predictors", "Use these predictors", choices = NULL, multiple = TRUE,
                         options = list(plugins = list("remove_button"))),
          checkboxInput("include_id", "Offer ID and constant columns", FALSE),
          checkboxInput("as_cat", "Treat integers with \u226410 values as categories", TRUE),
          helpText("EmployeeNumber, EmployeeCount, Over18 and StandardHours are hidden unless offered. DailyRate, HourlyRate and MonthlyRate start unchecked: they are not pay.")
        ),
        accordion_panel(
          "Tree rules", icon = shiny::icon("sliders"),
          radioButtons("criterion", "Split criterion",
                       choices = c("Gini" = "gini", "Information (entropy)" = "information"), selected = "gini"),
          numericInput("minsplit", "Smallest node that can split", value = 20, min = 2, step = 1),
          numericInput("minbucket", "Smallest allowed child", value = 7, min = 1, step = 1),
          numericInput("max_depth", "Maximum depth (root = 0)", value = 5, min = 1, max = 30, step = 1),
          numericInput("cp", "Minimum relative improvement (cp)", value = 0.01, min = 0, max = 1, step = 0.001),
          helpText("Auto-split and Grow follow these rules. Custom splits may break them; the app warns you.")
        )
      )
    ),
    uiOutput("takeaway"),
    uiOutput("findings_note"),
    uiOutput("pay_context"),
    layout_columns(
      col_widths = breakpoints(sm = 12, lg = c(8, 4)),
      card(
        full_screen = TRUE,
        class = "tree-card",
        card_header(
          tags$div(
            class = "tree-toolbar",
            tags$div(
              class = "tool-group",
              tool_btn("undo", "Undo", "rotate-left", title = "Undo the last change", disabled = "disabled"),
              tool_btn("reset_tree", "Reset", "arrows-rotate", title = "Back to a single root node"),
              tool_btn("grow_full", "Grow full tree", "sitemap", title = "Grow the whole tree under the rules", primary = TRUE)
            ),
            tags$div(
              class = "tool-group",
              tool_btn(NULL, "Zoom in", "magnifying-glass-plus", onclick = "HRTree.zoom(1.25)"),
              tool_btn(NULL, "Zoom out", "magnifying-glass-minus", onclick = "HRTree.zoom(0.8)"),
              tool_btn(NULL, "Fit", "expand", onclick = "HRTree.fit()", title = "Fit the tree to the view"),
              tool_btn(NULL, "PNG", "image", onclick = "HRTree.exportPng()", title = "Download the tree as PNG")
            )
          )
        ),
        card_body(
          padding = 0,
          tags$div(
            class = "tree-wrap",
            tags$div(
              id = "first-tip", class = "first-tip d-none", role = "status",
              tags$span(class = "tip-text", "Click a box to see its numbers."),
              tags$button(type = "button", onclick = "HRTree.dismissTip()", "Got it")
            ),
            visNetworkOutput("tree", height = "600px")
          ),
          uiOutput("legend")
        )
      ),
      card(
        card_header(tags$span(class = "card-title-sm", "Selected group")),
        uiOutput("node_card"),
        tags$div(
          class = "node-foot",
          selectInput("node_picker", "Go to node", choices = c("Node 1" = "1"), width = "100%")
        )
      )
    ),
    card(
      card_header(
        class = "d-flex flex-wrap gap-2 justify-content-between align-items-center",
        uiOutput("preview_title", inline = TRUE),
        tags$div(
          class = "tool-group",
          actionButton("imp_all", "All predictors", icon = shiny::icon("chart-bar"), class = "btn-tool"),
          actionButton("custom_open", "Custom split", icon = shiny::icon("sliders"), class = "btn-tool")
        )
      ),
      tags$p(class = "imp-caption",
             "Primary-split improvement at the selected node (n \u00d7 impurity reduction). Surrogate splits get no credit. A search aid, not a validated ranking. Click a row to try that split."),
      uiOutput("preview_list")
    )
  )
)

fit_panel <- nav_panel(
  "Model fit",
  icon = shiny::icon("gauge"),
  uiOutput("fit_takeaway"),
  uiOutput("metric_cards"),
  layout_columns(
    col_widths = breakpoints(sm = 12, lg = c(5, 7)),
    card(
      card_header(tags$span(class = "card-title-sm", "Confusion matrix (in-sample)")),
      sliderInput("threshold", "Call a row positive when its group's rate is at least",
                  min = 0, max = 1, value = 0.5, step = 0.01, ticks = FALSE),
      uiOutput("confusion")
    ),
    card(
      card_header(uiOutput("used_imp_title", inline = TRUE)),
      tags$p(class = "imp-caption", "Primary-split share % (no surrogates): the sum of improvement on splits this tree actually made. Unlike rpart's default variable importance, surrogate splits get no credit. Exploratory."),
      uiOutput("used_importance")
    )
  ),
  card(
    card_header(
      class = "d-flex flex-wrap gap-2 justify-content-between align-items-center",
      tags$span(class = "card-title-sm", "End groups (leaves)"),
      tags$div(
        class = "tool-group",
        downloadButton("download_leaves", "Leaves CSV", class = "btn-tool"),
        downloadButton("download_nodes", "All nodes + rules CSV", class = "btn-tool")
      )
    ),
    DTOutput("leaf_table")
  )
)

about_panel <- nav_panel(
  "About",
  icon = shiny::icon("circle-info"),
  card(
    class = "about",
    card_body(
      tags$h4("Attrition Tree Explorer"),
      tags$p(tags$strong("Synthetic IBM teaching dataset. "),
             "The bundled file is IBM's fictional HR Analytics Employee Attrition sample. The people in it are not real employees."),
      tags$p("Build a decision tree one split at a time, in the spirit of the Partition platform in SAS JMP. Every node shows how each predictor would split it, and you choose: the best split, your own cut, or none."),
      tags$p(tags$strong("The one cleared finding: overtime. "), "Overtime workers are 416 of 1,470 people (28%) but 127 of the 237 who left (54%). 30.5% of them left, against 10.4% of everyone else. Pay and career stage are shown as context only. Deeper splits are exploratory, and a full importance ranking is not a finding."),
      tags$h5("How to use it"),
      tags$ul(
        tags$li(tags$strong("Select a group: "), "click a box (tap on a phone). Its numbers appear in the Selected group card."),
        tags$li(tags$strong("Act on a group: "), "right-click a box on desktop, or tap / long-press on a phone. The menu offers variable importance, auto-split, custom split, grow and remove split."),
        tags$li(tags$strong("Navigate: "), "scroll or pinch to zoom, drag to pan. Fit re-centers the tree. The breadcrumb jumps to any parent."),
        tags$li(tags$strong("Undo "), "reverses the last split, prune, grow or reset."),
        tags$li(tags$strong("Export: "), "PNG of the tree view, CSVs of the leaves, all node rules, and any node's predictor table.")
      ),
      tags$h5("Reading the tree"),
      tags$ul(
        tags$li("The big number in each box is the share of that group who left. Below it: n (rows in the group) and the group's share of all rows."),
        tags$li("Boxes are gray. Only the cleared group (validated, big enough, at or above the highlight rate) gets the accent color, along with the branch that leads to it. Big exploratory end groups above the highlight rate get a dark outline."),
        tags$li("A dashed box marked \u201ctoo small to act on\u201d has fewer employees or leavers than the floors in the Highlight controls (default 100 employees and 24 leavers). It is never highlighted and never headlined."),
        tags$li("Each group shows its share of all employees, its share of all leavers, and its rate as a multiple of the company rate. The \u201cif this group left at the company average\u201d line is an illustration, not a forecast. It is (group leavers \u2212 group size \u00d7 company rate) \u00f7 all employees, in points. Do not add it up across groups: groups overlap."),
        tags$li("Line width is proportional to the rows flowing down that branch.")
      ),
      tags$h5("How a split is scored"),
      tags$ul(
        tags$li("Gini impurity is 1 \u2212 \u03a3 p\u00b2. Information uses binary entropy (log base 2)."),
        tags$li("Improvement = (rows in the node) \u00d7 (parent impurity \u2212 size-weighted child impurity). Relative improvement divides that by the root's total impurity; cp is the minimum relative improvement for an automatic split."),
        tags$li("Importance in this app is primary-split only. Surrogate splits are not searched and get no credit, unlike rpart's default variable importance."),
        tags$li("Numeric predictors: every midpoint between adjacent distinct values is tried; the left branch is value < cut."),
        tags$li("Categorical predictors: levels are ordered by event rate and the best prefix is kept (binary CART). A custom split may put any subset of levels on the left."),
        tags$li("Rows with a missing value go to the right branch.")
      ),
      tags$h5("Why overtime is the one cleared finding (technical detail)"),
      tags$p(sprintf("A group is cleared only if it passes every check in analysis/exec/thresholds.json, counted on all 1,470 rows: (1) at least 100 employees and 24 leavers (10%% of the 237); (2) a rate at least 1.5\u00d7 the company rate of 16.1%%; (3) the same direction in the held-out test set, with at least 30 people there; (4) the group's defining variable is a primary split at the root or the level below it in more than half of %d bootstrap refits.", CLEARED_FINDING$n_bootstrap)),
      tags$ul(
        tags$li(sprintf("Overtime workers: %s people, %s leavers, %s left (95%% Wilson interval %s), %s the company rate.",
                        fmt_count(CLEARED_FINDING$n), fmt_count(CLEARED_FINDING$leavers), fmt_rate1(CLEARED_FINDING$rate),
                        fmt_ci(CLEARED_FINDING$leavers, CLEARED_FINDING$n), sprintf("%s\u00d7", fmt_times(CLEARED_FINDING$lift)))),
        tags$li(sprintf("Held-out test set: %s of overtime workers left (%s of %s, CI %s), against %s of the rest (%s of %s), and %s overall in the test set.",
                        fmt_rate1(CLEARED_FINDING$test_rate), CLEARED_FINDING$test_leavers, CLEARED_FINDING$test_n,
                        sprintf("%.1f\u2013%.1f%%", 100 * CLEARED_FINDING$test_wilson[1], 100 * CLEARED_FINDING$test_wilson[2]),
                        fmt_rate1(CLEARED_FINDING$test_rate_other), CLEARED_FINDING$test_leavers_other, CLEARED_FINDING$test_n_other,
                        fmt_rate1(CLEARED_FINDING$test_overall_rate))),
        tags$li(sprintf("Stability: overtime was a primary split at the root or the level below in %.1f%% of %d bootstrap refits.", 100 * CLEARED_FINDING$stability_share, CLEARED_FINDING$n_bootstrap))
      ),
      tags$p("Groups that miss the size floor are \u201ctoo small to act on\u201d, however high their rate. For example, overtime workers earning under about $2,500 a month were 69 people, which is why that group is no longer highlighted. Pay and career stage are context only: they did not hold up as a separate pattern. Nothing here shows what causes people to leave."),
      tags$h5("What the fit numbers are not"),
      tags$p("Accuracy, AUC and the confusion matrix use the same rows the tree was grown on. A deep tree looks better than it would predict for new employees, and these numbers do not validate any split. The held-out rpart analysis is in analysis/ in the project repository."),
      tags$h5("Data"),
      tags$p("IBM HR Analytics Employee Attrition & Performance, a fictional sample from IBM data scientists. The Kaggle copy (pavansubhasht/ibm-hr-analytics-attrition-dataset) is CC0 1.0. This app bundles a public GitHub mirror of that file. 1,470 rows; 237 (16.1%) have Attrition = Yes."),
      tags$p(tags$strong("Age, gender and marital status are included only to describe this fictional dataset. Do not use splits on them, or on proxies for them, to select, rate or target real employees.")),
      tags$p(class = "text-muted small", "This public app is for the fictional sample. Do not upload real employee records.")
    )
  )
)

ui <- page_navbar(
  title = tags$span("Attrition Tree Explorer", tags$span(class = "brand-sub d-none d-md-inline", "recursive partitioning")),
  window_title = "Attrition Tree Explorer",
  theme = theme,
  fillable = FALSE,
  navbar_options = navbar_options(bg = "#FFFFFF", theme = "light", collapsible = TRUE),
  header = tagList(
    tags$head(
      tags$meta(name = "viewport", content = "width=device-width, initial-scale=1, viewport-fit=cover"),
      tags$link(rel = "stylesheet", href = "app.css"),
      tags$script(src = "app.js")
    ),
    useBusyIndicators(spinners = TRUE, pulse = TRUE),
    uiOutput("data_strip")
  ),
  explore_panel,
  fit_panel,
  about_panel
)

server <- function(input, output, session) {
  source_mode <- reactiveVal("bundled")
  upload_path <- reactiveVal(NULL)
  upload_name <- reactiveVal(NULL)
  tree_rv <- reactiveVal(new_tree(1L))
  selected_node <- reactiveVal("1")
  history <- reactiveVal(list())

  # ---- data ---------------------------------------------------------------
  observeEvent(input$file, {
    req(input$file)
    upload_path(input$file$datapath)
    upload_name(input$file$name)
    source_mode("upload")
  })
  observeEvent(input$use_bundled, source_mode("bundled"))

  dataset <- reactive({
    path <- if (identical(source_mode(), "upload")) upload_path() else bundled_csv_path()
    shiny::validate(need(!is.null(path) && file.exists(path), "No CSV is available."))
    out <- tryCatch(read_hr_csv(path), error = function(e) e)
    shiny::validate(need(!inherits(out, "error"),
                         paste("Could not read the CSV:", if (inherits(out, "error")) conditionMessage(out) else "")))
    shiny::validate(need(ncol(out) >= 2 && nrow(out) >= 2, "The CSV needs at least 2 columns and 2 rows."))
    out
  })

  output$data_status <- renderText({
    df <- dataset()
    label <- if (identical(source_mode(), "upload")) paste("Uploaded:", upload_name()) else "Bundled synthetic IBM teaching sample"
    sprintf("%s \u00b7 %s rows \u00b7 %s columns", label, fmt_count(nrow(df)), ncol(df))
  })

  output$data_strip <- renderUI({
    if (identical(source_mode(), "upload")) {
      tags$div(class = "data-strip", role = "note",
               tags$span(class = "tag", "Uploaded"),
               tags$span(tags$strong("Your file. "),
                         tags$span(class = "long", "Every split is in-sample and exploratory. Do not upload real employee records to this public app.")))
    } else {
      tags$div(class = "data-strip", role = "note",
               tags$span(class = "tag", "Fictional"),
               tags$span(tags$strong("Synthetic IBM teaching dataset. "),
                         tags$span(class = "short", "Not real people."),
                         tags$span(class = "long", "Fictional employees from IBM's HR Analytics Attrition sample, not real people.")))
    }
  })

  observeEvent(dataset(), {
    df <- dataset()
    tgt <- isolate(input$target)
    if (is.null(tgt) || !tgt %in% names(df)) tgt <- if ("Attrition" %in% names(df)) "Attrition" else names(df)[1]
    updateSelectInput(session, "target", choices = names(df), selected = tgt)
  }, ignoreInit = FALSE)

  observeEvent(list(dataset(), input$target, input$include_id), {
    df <- dataset()
    tgt <- input$target
    req(tgt %in% names(df))
    vals <- unique(as.character(df[[tgt]]))
    vals <- vals[!is.na(vals) & nzchar(vals)]
    pos <- isolate(input$positive)
    if (is.null(pos) || !pos %in% vals) pos <- default_positive(df[[tgt]])
    updateSelectInput(session, "positive", choices = vals, selected = pos)
    cols <- setdiff(names(df), tgt)
    if (!isTRUE(input$include_id)) cols <- setdiff(cols, ID_CONST_COLUMNS)
    prev <- isolate(input$predictors)
    sel <- intersect(prev, cols)
    if (!length(sel)) sel <- default_predictors(cols)
    updateSelectizeInput(session, "predictors", choices = cols, selected = sel)
  }, ignoreInit = FALSE)

  model_data <- reactive({
    df <- dataset()
    tgt <- input$target
    pos <- input$positive
    preds <- input$predictors
    shiny::validate(need(!is.null(tgt) && tgt %in% names(df), "Choose a target."))
    shiny::validate(need(!is.null(pos) && nzchar(pos), "Choose the positive class."))
    shiny::validate(need(length(preds) >= 1, "Select at least one predictor."))
    preds <- intersect(preds, setdiff(names(df), tgt))
    shiny::validate(need(length(preds) >= 1, "Select at least one predictor other than the target."))
    keep <- !is.na(df[[tgt]]) & nzchar(as.character(df[[tgt]]))
    df <- df[keep, , drop = FALSE]
    y <- as.integer(as.character(df[[tgt]]) == pos)
    shiny::validate(need(length(unique(y)) == 2L, "The target needs exactly two classes."))
    types <- stats::setNames(
      vapply(preds, function(v) column_type(df[[v]], isTRUE(input$as_cat)), character(1)),
      preds
    )
    list(df = df, y = y, predictors = preds, types = types, target = tgt, positive = pos,
         bundled = identical(source_mode(), "bundled"))
  })

  ctrl <- function() {
    num <- function(x, d) if (is.null(x) || length(x) != 1L || is.na(x)) d else x
    list(criterion = input$criterion %or% "gini",
         minsplit = num(input$minsplit, 20), minbucket = num(input$minbucket, 7),
         max_depth = num(input$max_depth, 5), cp = num(input$cp, 0.01))
  }

  root_impurity_total <- reactive({
    md <- model_data()
    impurity_bin(md$y, ctrl()$criterion) * length(md$y)
  })

  # Best eligible split at one node: the exact path v1 used for Auto-split.
  split_best <- function(tree, id, md) {
    p <- ctrl()
    node <- get_node(tree, id)
    cand_tab <- candidate_splits(md$df, md$y, node$rows, md$predictors, md$types, p$criterion,
                                 p$minsplit, p$minbucket, p$max_depth, p$cp, node$depth,
                                 impurity_bin(md$y, p$criterion) * length(md$y))
    elig <- cand_tab$table[cand_tab$table$eligible %in% TRUE, , drop = FALSE]
    if (!nrow(elig)) return(NULL)
    v <- elig$variable[[1]]
    spec <- attach_rows(cand_tab$specs[[v]], md$df, md$y, node$rows, v)
    out <- apply_spec_split(tree, id, v, spec)
    if (!out$ok) return(NULL)
    list(tree = out$tree, variable = v, rule = spec$left_rule)
  }

  # Starting view: the best root split only. On the IBM sample that is OverTime, the one
  # cleared finding. Deeper splits are the user's choice (and are flagged when too small).
  starter_tree <- function(md) {
    tree <- new_tree(nrow(md$df))
    s1 <- split_best(tree, "1", md)
    if (is.null(s1)) return(list(tree = tree, select = "1"))
    kids <- s1$tree$nodes[["1"]]$children
    rates <- vapply(kids, function(k) mean(md$y[get_node(s1$tree, k)$rows]), numeric(1))
    list(tree = s1$tree, select = kids[[which.max(rates)]])
  }

  push_tree <- function(new) {
    h <- c(list(list(tree = tree_rv(), sel = selected_node())), history())
    if (length(h) > 30L) h <- h[seq_len(30L)]
    history(h)
    tree_rv(new)
  }

  observeEvent(list(model_data(), input$criterion), {
    md <- tryCatch(model_data(), error = function(e) NULL)
    if (is.null(md)) return()
    st <- starter_tree(md)
    tree_rv(st$tree)
    history(list())
    selected_node(st$select)
  }, ignoreInit = FALSE)

  observeEvent(model_data(), {
    md <- tryCatch(model_data(), error = function(e) NULL)
    if (is.null(md)) return()
    updateSliderInput(session, "flag_rate", value = default_flag_pct(mean(md$y)))
    updateNumericInput(session, "min_group", value = default_min_group(length(md$y)), max = length(md$y))
  }, ignoreInit = FALSE)

  observe({
    session$sendCustomMessage("hr-undo", list(enabled = length(history()) > 0L))
  })

  cand <- reactive({
    md <- model_data()
    tree <- tree_rv()
    id <- selected_node()
    node <- get_node(tree, id)
    shiny::validate(need(!is.null(node), "Select a node."))
    p <- ctrl()
    candidate_splits(
      md$df, md$y, node$rows, md$predictors, md$types, p$criterion,
      minsplit = p$minsplit, minbucket = p$minbucket,
      max_depth = p$max_depth, cp = p$cp,
      node_depth = node$depth, root_impurity_total = root_impurity_total()
    )
  })

  flag_rate <- reactive({
    md <- model_data()
    (input$flag_rate %or% default_flag_pct(mean(md$y))) / 100
  })
  min_group <- reactive({
    md <- model_data()
    v <- input$min_group
    if (is.null(v) || length(v) != 1L || is.na(v) || v < 1) default_min_group(length(md$y)) else min(round(v), length(md$y))
  })
  rules <- reactive(make_rules(model_data(), min_group(), flag_rate()))

  output$min_group_help <- renderUI({
    md <- model_data()
    N <- length(md$y)
    tags$p(class = "help-block small text-muted mb-2",
           sprintf("%s %s = %s of %s. A group also needs at least %s %s (%s of the %s in the data).",
                   fmt_count(min_group()), unit_all(md), fmt_rate1(min_group() / N), unit_staff(md),
                   fmt_count(leaver_floor(sum(md$y))), unit_pos(md), fmt_pct0(RULE_LEAVER_SHARE), fmt_count(sum(md$y))))
  })

  # ---- selection ------------------------------------------------------------
  set_selected <- function(id) {
    id <- as.character(id)
    if (length(id) == 1L && id %in% names(tree_rv()$nodes) && !identical(id, selected_node())) selected_node(id)
  }
  observeEvent(input$tree_click, set_selected(input$tree_click$id))
  observeEvent(input$jump_node, set_selected(input$jump_node$id))
  observeEvent(input$node_picker, { req(input$node_picker); set_selected(input$node_picker) })

  observeEvent(tree_rv(), {
    tree <- tree_rv()
    ids <- names(tree$nodes)
    ids <- ids[order(as.integer(ids))]
    if (!selected_node() %in% ids) selected_node("1")
    md <- tryCatch(model_data(), error = function(e) NULL)
    labels <- vapply(ids, function(id) {
      nd <- tree$nodes[[id]]
      rate <- if (!is.null(md)) fmt_rate1(mean(md$y[nd$rows])) else ""
      sprintf("Node %s \u00b7 n %s \u00b7 %s%s", id, fmt_count(length(nd$rows)), rate, if (is.null(nd$children)) "" else " \u00b7 split")
    }, character(1))
    updateSelectInput(session, "node_picker", choices = stats::setNames(ids, labels), selected = selected_node())
  }, ignoreNULL = FALSE)

  observeEvent(selected_node(), {
    session$sendCustomMessage("hr-select", list(id = selected_node()))
    if (!identical(isolate(input$node_picker), selected_node())) {
      updateSelectInput(session, "node_picker", selected = selected_node())
    }
  })

  # ---- actions ----------------------------------------------------------------
  do_auto <- function() {
    md <- model_data()
    s <- split_best(tree_rv(), selected_node(), md)
    if (is.null(s)) {
      showNotification("No predictor meets the size, depth and cp rules here. Relax the rules or use a custom split.",
                       type = "warning", duration = 7)
      return(invisible())
    }
    push_tree(s$tree)
    showNotification(sprintf("Split node %s on %s.", selected_node(), s$variable), type = "message", duration = 3)
  }
  do_prune <- function() {
    tree <- tree_rv()
    node <- get_node(tree, selected_node())
    if (is.null(node) || is_leaf(node)) {
      showNotification("This group has no split to remove.", type = "message", duration = 3)
      return(invisible())
    }
    push_tree(prune_node(tree, selected_node()))
  }
  do_grow_branch <- function() {
    md <- model_data()
    p <- ctrl()
    tree <- auto_grow(tree_rv(), md$df, md$y, md$predictors, md$types, p$criterion,
                      p$minsplit, p$minbucket, p$max_depth, p$cp, only_under = selected_node())
    push_tree(tree)
    showNotification(sprintf("Branch grown. %d end groups in the tree.", length(leaf_ids(tree))), type = "message", duration = 3)
  }

  observeEvent(input$auto_split, do_auto())
  observeEvent(input$prune, do_prune())
  observeEvent(input$grow_branch, do_grow_branch())
  observeEvent(input$grow_full, {
    md <- model_data()
    p <- ctrl()
    tree <- auto_grow(new_tree(nrow(md$df)), md$df, md$y, md$predictors, md$types, p$criterion,
                      p$minsplit, p$minbucket, p$max_depth, p$cp)
    push_tree(tree)
    selected_node("1")
    showNotification(sprintf("Full tree: %d nodes, %d end groups.", length(tree$nodes), length(leaf_ids(tree))),
                     type = "message", duration = 3)
  })
  observeEvent(input$reset_tree, {
    md <- model_data()
    push_tree(new_tree(nrow(md$df)))
    selected_node("1")
  })
  observeEvent(input$undo, {
    h <- history()
    if (!length(h)) return()
    prev <- h[[1]]
    history(h[-1])
    tree_rv(prev$tree)
    selected_node(if (prev$sel %in% names(prev$tree$nodes)) prev$sel else "1")
  })

  observeEvent(input$node_action, {
    a <- input$node_action
    id <- as.character(a$id)
    req(id %in% names(tree_rv()$nodes))
    selected_node(id)
    switch(a$action,
           importance = show_importance_modal(),
           auto = do_auto(),
           custom = show_custom_modal(),
           grow = do_grow_branch(),
           prune = do_prune())
  })
  observeEvent(input$btn_importance, show_importance_modal())
  observeEvent(input$imp_all, show_importance_modal())
  observeEvent(input$btn_custom, show_custom_modal())
  observeEvent(input$custom_open, show_custom_modal())
  observeEvent(input$imp_pick, show_custom_modal(input$imp_pick$variable))

  # ---- modals -----------------------------------------------------------------
  node_facts_html <- function(tree, md, id, rl) {
    ar <- node_assess(tree, md, rl)
    ar <- ar[ar$id == id, ]
    imp <- impact_sentence(ar, md)
    tags$div(
      class = "node-facts",
      tags$span(sprintf("%s of %s", fmt_share(ar$share), unit_all(md))),
      tags$span(sprintf("%s of %s", fmt_share(ar$share_pos), unit_pos(md))),
      if (ar$depth > 0L) tags$span(sprintf("%s\u00d7 the company rate of %s", fmt_times(ar$lift), fmt_rate1(mean(md$y)))),
      if (isTRUE(ar$cleared)) tags$span(class = "pill accent", "Cleared finding"),
      if (isTRUE(ar$too_small)) tags$span(class = "pill small", "Too small to act on"),
      if (nzchar(imp)) tags$div(class = "impact-note", imp),
      if (isTRUE(ar$too_small)) tags$div(class = "small-note", too_small_reason(ar$n, ar$yes, rl, md), ". Never highlighted; no impact figure.")
    )
  }

  show_importance_modal <- function() {
    md <- model_data()
    tab <- cand()$table
    st <- node_basic(tree_rv(), selected_node(), md$y)
    conds <- path_conditions(tree_rv(), selected_node(), md$df)
    top <- tab$variable[is.finite(tab$improvement)][1]
    showModal(modalDialog(
      title = if (is.na(top)) sprintf("No usable split at node %s", st$id) else sprintf("%s splits node %s best", top, st$id),
      size = "l", easyClose = TRUE,
      tags$div(class = "note-lite",
               tags$strong(if (length(conds)) paste(vapply(conds, cond_text, character(1)), collapse = " \u203a ") else "All rows"),
               sprintf(" \u00b7 n %s \u00b7 %s %s", fmt_count(st$n), fmt_rate1(st$rate), rate_verb(md))),
      node_facts_html(tree_rv(), md, selected_node(), rules()),
      tags$p(class = "imp-caption",
             sprintf("All %d predictors, ranked by primary-split improvement at this node (n \u00d7 impurity reduction). Surrogate splits get no credit. Share %% is each predictor's portion of this node's total. A search aid, not a validated ranking. Click a row to try that split.", nrow(tab))),
      importance_list_html(tab, clickable = TRUE, verb = rate_verb(md)),
      footer = tagList(
        downloadButton("download_node_cand", "Download CSV", class = "btn-light"),
        modalButton("Close")
      )
    ))
  }

  show_custom_modal <- function(variable = NULL) {
    md <- model_data()
    tab <- cand()$table
    node <- get_node(tree_rv(), selected_node())
    st <- node_basic(tree_rv(), selected_node(), md$y)
    vars <- tab$variable
    labs <- ifelse(is.finite(tab$improvement), sprintf("%s  (best %.2f)", vars, tab$improvement), paste(vars, " (no split)"))
    elig <- tab$variable[tab$eligible %in% TRUE]
    sel <- if (!is.null(variable) && variable %in% vars) variable else if (length(elig)) elig[[1]] else vars[[1]]
    showModal(modalDialog(
      title = sprintf("Custom split \u00b7 node %s", st$id),
      size = "m", easyClose = TRUE,
      tags$div(class = "note-lite", sprintf("%s rows \u00b7 %s %s", fmt_count(st$n), fmt_rate1(st$rate), rate_verb(md)),
               if (!is.null(node$children)) tags$div("This node already has a split. Applying replaces everything below it. Undo restores it.")),
      selectInput("custom_var", "Split on", choices = stats::setNames(vars, labs), selected = sel, width = "100%"),
      uiOutput("custom_controls"),
      uiOutput("custom_preview"),
      footer = tagList(modalButton("Cancel"), actionButton("apply_custom", "Apply split", class = "btn-dark"))
    ))
  }

  output$custom_controls <- renderUI({
    md <- model_data()
    v <- input$custom_var
    req(v, v %in% names(md$types))
    spec <- cand()$specs[[v]]
    node <- get_node(tree_rv(), selected_node())
    if (identical(md$types[[v]], "numeric")) {
      x <- md$df[[v]][node$rows]
      rng <- range(x, na.rm = TRUE)
      val <- if (!is.null(spec) && is.finite(spec$cut)) spec$cut else mean(rng)
      tagList(
        numericInput("custom_cut", sprintf("Left branch: %s below", v), value = signif(val, 6),
                     min = rng[[1]], max = rng[[2]], width = "100%"),
        helpText(sprintf("Range in this node: %s to %s. Best cut here: %s. Values at or above the cut, and missing values, go right.",
                         fmt_cut_value(v, rng[[1]]), fmt_cut_value(v, rng[[2]]),
                         if (!is.null(spec)) fmt_cut_value(v, spec$cut) else "none"))
      )
    } else {
      xv <- as.character(md$df[[v]][node$rows])
      yv <- md$y[node$rows]
      present <- sort(unique(xv[!is.na(xv)]))
      lab <- vapply(present, function(l) {
        k <- !is.na(xv) & xv == l
        sprintf("%s \u2014 %s %s, n %s", l, fmt_rate1(mean(yv[k])), rate_verb(md), fmt_count(sum(k)))
      }, character(1))
      sel <- if (!is.null(spec) && length(spec$left_levels)) spec$left_levels else present[[1]]
      tags$div(
        class = "level-choices",
        checkboxGroupInput("custom_levels", "Levels in the left branch", choiceNames = unname(lab),
                           choiceValues = present, selected = sel, width = "100%"),
        helpText("Unchecked levels, and missing values, go right.")
      )
    }
  })

  current_spec <- function(md, node) {
    v <- input$custom_var
    if (is.null(v) || !v %in% names(md$types)) return(NULL)
    p <- ctrl()
    if (identical(md$types[[v]], "numeric")) {
      manual_spec(md$df, md$y, node$rows, v, "numeric", cut = input$custom_cut, criterion = p$criterion)
    } else {
      manual_spec(md$df, md$y, node$rows, v, "categorical", left_levels = input$custom_levels, criterion = p$criterion)
    }
  }

  output$custom_preview <- renderUI({
    md <- model_data()
    node <- get_node(tree_rv(), selected_node())
    spec <- current_spec(md, node)
    if (is.null(spec)) return(tags$p(class = "text-muted", "Choose a cut or levels that leave rows on both sides."))
    best <- suppressWarnings(max(cand()$table$improvement, na.rm = TRUE))
    p <- ctrl()
    small <- length(node$rows) < p$minsplit || spec$n_left < p$minbucket || spec$n_right < p$minbucket
    side <- function(name, rule, n, rate) {
      tags$div(class = "side",
               tags$div(class = "rule", tags$strong(name), " \u00b7 ", rule),
               tags$div(class = "nums", tags$span(sprintf("%s %s", fmt_rate1(rate), rate_verb(md))), tags$span(sprintf("n %s", fmt_count(n)))),
               tags$div(class = "stackbar", tags$div(class = "yes", style = sprintf("width:%.1f%%", 100 * rate))))
    }
    tags$div(
      class = "split-preview",
      side("Left", spec$left_rule, spec$n_left, spec$rate_left),
      side("Right", spec$right_rule, spec$n_right, spec$rate_right),
      tags$div(class = "gain", sprintf("Improvement %.2f%s", spec$improvement,
                                       if (is.finite(best)) sprintf(" \u00b7 best available here %.2f", best) else "")),
      if (small) tags$div(class = "note-lite", "Below the minimum-size rules. You can still apply it."),
      {
        rl <- rules()
        tiny <- c(Left = spec$n_left < rl$min_n || round(spec$rate_left * spec$n_left) < rl$min_pos,
                  Right = spec$n_right < rl$min_n || round(spec$rate_right * spec$n_right) < rl$min_pos)
        if (any(tiny)) tags$div(class = "small-note", role = "note", tags$strong("Too small to act on: "),
                                sprintf("the %s side would have under %s %s or under %s %s. It would be shown, but never highlighted.",
                                        tolower(paste(names(tiny)[tiny], collapse = " and ")),
                                        fmt_count(rl$min_n), unit_all(md), fmt_count(rl$min_pos), unit_pos(md)))
      }
    )
  })

  observeEvent(input$apply_custom, {
    md <- model_data()
    tree <- tree_rv()
    node <- get_node(tree, selected_node())
    req(node, input$custom_var)
    spec <- current_spec(md, node)
    if (is.null(spec)) {
      showNotification("That split puts every row on one side, or no levels were chosen.", type = "error")
      return()
    }
    p <- ctrl()
    if (length(node$rows) < p$minsplit || spec$n_left < p$minbucket || spec$n_right < p$minbucket) {
      showNotification("Below the minimum-size rules. The custom split was applied anyway.", type = "warning", duration = 6)
    }
    out <- apply_spec_split(tree, selected_node(), input$custom_var, spec)
    if (!out$ok) {
      showNotification(out$message, type = "error")
    } else {
      push_tree(out$tree)
      removeModal()
      showNotification(out$message, type = "message", duration = 3)
    }
  })

  # ---- explore outputs --------------------------------------------------------
  output$takeaway <- renderUI({
    md <- model_data()
    tree <- tree_rv()
    rl <- rules()
    base <- mean(md$y)
    N <- length(md$y)
    P <- sum(md$y)
    verb <- rate_verb(md)
    a <- node_assess(tree, md, rl)
    if (nrow(a) <= 1L) {
      return(tags$div(class = "takeaway",
                      tags$div(class = "eyebrow", "Overall"),
                      tags$h2(sprintf("%s of %s %s (%s of %s)", fmt_rate1(base), unit_all(md), verb, fmt_count(P), fmt_count(N))),
                      tags$p("Split a group to find where the rate is highest. Auto-split picks the best split for you.")))
    }
    hid <- headline_node(a)
    if (is.null(hid)) {
      return(tags$div(class = "takeaway",
                      tags$div(class = "eyebrow", "No group highlighted"),
                      tags$h2("No group in this tree is both big enough and above the highlight rate"),
                      tags$p(sprintf("Overall: %s of %s %s (%s of %s). To be highlighted a group needs at least %s %s, %s %s and a rate of %s or more. Smaller groups are marked \u201ctoo small to act on\u201d.",
                                     fmt_rate1(base), unit_all(md), verb, fmt_count(P), fmt_count(N),
                                     fmt_count(rl$min_n), unit_all(md), fmt_count(rl$min_pos), unit_pos(md), fmt_rate1(rl$thr)))))
    }
    r <- a[a$id == hid, ]
    conds <- path_conditions(tree, hid, md$df)
    phrase <- group_phrase(conds, md)
    imp <- impact_sentence(r, md)
    if (isTRUE(r$cleared)) {
      title <- HTML(sprintf('%s are %s of %s but %s of %s: <span class="accent">%s left</span> vs %s of everyone else',
                            htmltools::htmlEscape(phrase), fmt_pct0(r$share), unit_staff(md), fmt_pct0(r$share_pos), unit_pos(md),
                            fmt_rate1(r$rate), fmt_rate1(r$outside_rate)))
      return(tags$div(
        class = "takeaway",
        tags$div(class = "eyebrow", "Cleared finding \u00b7 fictional data"),
        tags$h2(title),
        tags$p(sprintf("%s people, %s of the %s who left: %s the company average of %s. If %s left at the company average, %s would be about %s points lower (illustration, not a forecast).",
                       fmt_count(r$n), fmt_count(r$yes), fmt_count(P), sprintf("%s\u00d7", fmt_times(r$lift)), fmt_rate1(base),
                       lower_first(phrase), overall_phrase(md), fmt_pts(r$impact))),
        tags$p(class = "takeaway-note", sprintf("Counts are for all %s people in this fictional file. They describe who left, not why.", fmt_count(N)))
      ))
    }
    title <- if (is_attrition_target(md)) {
      sprintf("%s left at %s", phrase, fmt_rate1(r$rate))
    } else {
      sprintf("%s: %s are %s", phrase, fmt_rate1(r$rate), verb)
    }
    tags$div(
      class = "takeaway",
      tags$div(class = "eyebrow", "Highest-rate group big enough to act on \u00b7 exploratory, not validated"),
      tags$h2(title),
      tags$p(sprintf("%s of %s %s (%s of all %s), %s of all %s \u00b7 %s\u00d7 the company rate of %s \u00b7 in-sample%s",
                     fmt_count(r$yes), fmt_count(r$n), verb, fmt_share(r$share), unit_all(md), fmt_share(r$share_pos), unit_pos(md),
                     fmt_times(r$lift), fmt_rate1(base), if (isTRUE(md$bundled)) ", fictional data" else "")),
      if (nzchar(imp)) tags$p(class = "takeaway-note", imp)
    )
  })

  output$findings_note <- renderUI({
    md <- model_data()
    rl <- rules()
    if (isTRUE(md$bundled)) {
      tags$div(class = "findings-note", shiny::icon("circle-check"),
               tags$span(tags$strong("Cleared finding: overtime. "),
                         sprintf("Highlighted groups need at least %s employees and %s leavers, a rate of %s\u00d7 the company rate or more, and a held-out check. Pay and career stage: context only.",
                                 fmt_count(rl$min_n), fmt_count(rl$min_pos), fmt_times(RULE_MIN_LIFT))))
    } else {
      tags$div(class = "findings-note", shiny::icon("circle-info"),
               tags$span(tags$strong("Uploaded data: "), "every split here is in-sample and exploratory. Nothing has been validated."))
    }
  })

  output$pay_context <- renderUI({
    md <- model_data()
    pc <- pay_context(md)
    if (is.null(pc)) return(NULL)
    tags$details(
      class = "context-box",
      tags$summary("Context: pay and career stage (not a finding)"),
      tags$p(sprintf("Lower-paid staff (under about $%s a month, roughly the bottom third of earners) left at %s, vs %s for everyone else. %s of them are in the most junior job level, so pay and career stage cannot be told apart here. Most of the extra leaving is among those who also work overtime: lower-paid staff without overtime left at %s, vs %s for better-paid staff without overtime.",
                     fmt_count(PAY_CONTEXT_CUT), fmt_pct0(pc$rate), fmt_pct0(pc$rate_rest), fmt_pct0(pc$junior), fmt_pct0(pc$lo_no_ot), fmt_pct0(pc$hi_no_ot))),
      tags$p(class = "text-muted small mb-0", "Not validated and not highlighted: it did not hold up as a separate pattern. No impact figure is given.")
    )
  })

  output$tree <- renderVisNetwork({
    md <- model_data()
    tree <- tree_rv()
    vd <- tree_vis_data(tree, md, rules())
    sel <- isolate(selected_node())
    font_face <- "system-ui, -apple-system, Segoe UI, Roboto, Helvetica Neue, Arial, sans-serif"
    visNetwork(vd$nodes, vd$edges, width = "100%", height = "100%") %>%
      visNodes(shape = "box", margin = list(top = 9, bottom = 9, left = 12, right = 12),
               widthConstraint = list(minimum = 92),
               font = list(multi = "html", size = 15, face = font_face, bold = list(size = 22, face = font_face),
                           ital = list(size = 13, face = font_face, color = INK_MUTED)),
               shadow = FALSE, borderWidthSelected = 3, shapeProperties = list(borderRadius = 6)) %>%
      visEdges(smooth = list(enabled = TRUE, type = "cubicBezier", forceDirection = "vertical", roundness = 0.45),
               arrows = list(to = list(enabled = FALSE)),
               font = list(size = 14, face = font_face, color = INK_MUTED, background = "rgba(255,255,255,0.92)",
                           strokeWidth = 0, align = "horizontal"),
               selectionWidth = 0, hoverWidth = 0) %>%
      visHierarchicalLayout(direction = "UD", sortMethod = "directed", levelSeparation = 120,
                            nodeSpacing = 130, treeSpacing = 160, parentCentralization = TRUE) %>%
      visPhysics(enabled = FALSE) %>%
      visInteraction(hover = TRUE, tooltipDelay = 250, dragNodes = FALSE, dragView = TRUE, zoomView = TRUE,
                     selectConnectedEdges = FALSE, navigationButtons = FALSE, keyboard = FALSE) %>%
      visEvents(click = "function(p){ HRTree.onClick(this, p); }",
                oncontext = "function(p){ HRTree.onContext(this, p); }",
                hold = "function(p){ HRTree.onHold(this, p); }",
                release = "function(p){ HRTree.onRelease(this, p); }") %>%
      visEvents(type = "once", afterDrawing = sprintf("function(){ HRTree.ready(this, '%s'); }", sel))
  })

  output$legend <- renderUI({
    md <- model_data()
    rl <- rules()
    a <- node_assess(tree_rv(), md, rl)
    item <- function(key, ...) tags$span(class = "legend-item", if (!is.null(key)) tags$span(class = "key", key), tags$span(class = "txt", ...))
    thr_txt <- sprintf("%d%%", round(100 * rl$thr))
    tags$div(
      class = "legend",
      if (isTRUE(md$bundled)) item(tags$span(class = "sw acc"),
           sprintf("Cleared group: validated, at least %s %s and %s %s, rate %s or more",
                   fmt_count(rl$min_n), unit_all(md), fmt_count(rl$min_pos), unit_pos(md), thr_txt)),
      item(tags$span(class = "sw gray"), sprintf("Other groups (gray)")),
      if (any(a$outlined)) item(tags$span(class = "sw expl"), sprintf("Big enough and above %s, but not validated (exploratory)", thr_txt)),
      item(tags$span(class = "sw small"), sprintf("Too small to act on: under %s %s or under %s %s",
                                                    fmt_count(rl$min_n), unit_all(md), fmt_count(rl$min_pos), unit_pos(md))),
      item(tagList(tags$span(class = "ln", style = "width:22px;height:2px"), tags$span(class = "ln", style = "width:22px;height:7px")),
           "Line width = rows on the branch"),
      item(NULL, tags$strong("Big number"), sprintf(" = %% %s \u00b7 n = rows \u00b7 %% = share of all rows", rate_verb(md)))
    )
  })

  output$node_card <- renderUI({
    md <- model_data()
    tree <- tree_rv()
    id <- selected_node()
    req(id %in% names(tree$nodes))
    st <- node_basic(tree, id, md$y)
    base <- mean(md$y)
    conds <- path_conditions(tree, id, md$df)
    status <- validation_status(conds, md)
    rl <- rules()
    ar <- node_assess(tree, md, rl)
    ar <- ar[ar$id == id, ]
    is_flag <- isTRUE(ar$cleared)
    is_out <- isTRUE(ar$outlined)
    is_small <- isTRUE(ar$too_small)
    is_root <- st$depth == 0L
    imp <- impact_sentence(ar, md)
    chain <- node_chain(tree, id)
    crumbs <- list()
    for (i in seq_along(chain)) {
      cid <- chain[[i]]
      lab <- if (i == 1L) (if (is_attrition_target(md)) "All employees" else "All rows") else cond_text(step_condition(tree, cid, md$df), 2L)
      if (i > 1L) crumbs <- c(crumbs, list(tags$span(class = "crumb-sep", "\u203a")))
      crumbs <- c(crumbs, list(
        if (cid == id) tags$span(class = "crumb current", lab)
        else tags$button(type = "button", class = "crumb", `data-id` = cid, onclick = "HRTree.jump(this.dataset.id)", lab)
      ))
    }
    tags$div(
      class = "node-card",
      tags$div(class = "eyebrow",
               sprintf("Node %s \u00b7 %s \u00b7 depth %d", id, if (st$leaf) "end group" else "split", st$depth),
               if (is_flag) tags$span(class = "pill accent", "Cleared finding"),
               if (is_small) tags$span(class = "pill small", "Too small to act on"),
               if (is_out) tags$span(class = "pill outline", "Above threshold"),
               if (status == "comparison") tags$span(class = "pill", "Comparison group")
               else if (status == "exploratory" && !is_flag) tags$span(class = "pill", "Exploratory")),
      tags$div(class = paste("big", if (is_flag) "accent"), fmt_rate1(st$rate)),
      tags$div(class = "big-sub", if (is_root) sprintf("%s overall", rate_verb(md))
               else sprintf("%s in this group \u00b7 %s\u00d7 the company rate of %s", rate_verb(md),
                            fmt_times(ar$lift), fmt_rate1(base))),
      tags$div(class = "stackbar", role = "img",
               `aria-label` = sprintf("%s of %s %s", st$yes, st$n, rate_verb(md)),
               tags$div(class = paste("yes", if (is_flag) "accent"), style = sprintf("width:%.2f%%", 100 * st$rate))),
      tags$div(class = "stack-legend",
               tags$span(sprintf("%s %s (%s)", fmt_count(st$yes), rate_verb(md), md$positive)),
               tags$span(sprintf("%s other", fmt_count(st$no)))),
      tags$div(class = "stat-grid",
               tags$div(tags$div(class = "k", sprintf("%s (n)", tools::toTitleCase(unit_all(md)))), tags$div(class = "v", fmt_count(st$n))),
               tags$div(tags$div(class = "k", sprintf("Share of %s", unit_all(md))), tags$div(class = "v", fmt_share(st$share))),
               tags$div(tags$div(class = "k", sprintf("Share of %s", if (is_attrition_target(md)) "leavers" else "events")), tags$div(class = "v", fmt_share(ar$share_pos))),
               tags$div(tags$div(class = "k", "vs company rate"), tags$div(class = "v", if (is_root) "1\u00d7" else sprintf("%s\u00d7", fmt_times(ar$lift))))),
      if (is_small) tags$div(class = "small-note", role = "note", tags$strong("Too small to act on. "),
                             sprintf("This group is %s. It is never highlighted, and no impact figure is given.",
                                     too_small_reason(st$n, st$yes, rl, md))),
      if (nzchar(imp)) tags$div(class = "impact-note", imp),
      tags$div(class = "card-title-sm mb-1", "Path"),
      tags$div(class = "crumbs", crumbs),
      tags$div(
        class = "node-actions",
        actionButton("btn_importance", "Importance", icon = shiny::icon("chart-bar"), class = "btn-light"),
        actionButton("auto_split", "Auto-split", icon = shiny::icon("bolt"), class = "btn-dark"),
        actionButton("btn_custom", "Custom split", icon = shiny::icon("sliders"), class = "btn-light"),
        actionButton("prune", "Remove split", icon = shiny::icon("scissors"), class = "btn-light",
                     disabled = if (st$leaf) "disabled" else NULL),
        actionButton("grow_branch", "Grow branch", icon = shiny::icon("sitemap"), class = "btn-light")
      )
    )
  })

  output$preview_title <- renderUI({
    tab <- cand()$table
    top <- tab$variable[is.finite(tab$improvement)][1]
    tags$span(class = "card-title-sm",
              if (is.na(top)) sprintf("No usable split at node %s", selected_node())
              else sprintf("%s splits node %s best \u00b7 top 8 of %d predictors", top, selected_node(), nrow(tab)))
  })
  output$preview_list <- renderUI({
    md <- model_data()
    importance_list_html(cand()$table, max_rows = 8L, clickable = TRUE, verb = rate_verb(md))
  })

  output$download_node_cand <- downloadHandler(
    filename = function() sprintf("node_%s_predictors.csv", selected_node()),
    content = function(file) utils::write.csv(cand()$table, file, row.names = FALSE)
  )

  # ---- fit tab ----------------------------------------------------------------
  fit_prob <- reactive({
    md <- model_data()
    predict_leaf_prob(tree_rv(), md$y)
  })
  metrics <- reactive({
    md <- model_data()
    classification_metrics(md$y, fit_prob()$prob, threshold = input$threshold %or% 0.5)
  })

  output$fit_takeaway <- renderUI({
    m <- metrics()
    md <- model_data()
    n_leaves <- length(leaf_ids(tree_rv()))
    tags$div(class = "takeaway",
             tags$div(class = "eyebrow", sprintf("In-sample fit \u00b7 %d-group tree \u00b7 not a held-out estimate", n_leaves)),
             tags$h2(sprintf("In-sample AUC (this tree on all %s rows): %.3f", fmt_count(length(md$y)), m$auc)),
             tags$p(if (isTRUE(md$bundled)) paste("Deeper trees always look better in-sample. Only overtime has cleared the checks.", HELD_OUT_AUC_TEXT)
                    else "Deeper trees always look better in-sample. Nothing in an uploaded file has been validated."))
  })

  output$metric_cards <- renderUI({
    m <- metrics()
    card_m <- function(k, v, s) tags$div(class = "metric", tags$div(class = "k", k), tags$div(class = "v", v), tags$div(class = "s", s))
    layout_columns(
      col_widths = breakpoints(sm = 6, lg = 3),
      card_m("Accuracy", fmt_rate1(m$accuracy), sprintf("Majority-class baseline %s", fmt_rate1(m$baseline_accuracy))),
      card_m("In-sample AUC", sprintf("%.3f", m$auc), sprintf("Brier %.3f", m$brier)),
      card_m("Sensitivity", fmt_rate1(m$sensitivity), "Share of events caught"),
      card_m("Specificity", fmt_rate1(m$specificity), sprintf("Balanced accuracy %s", fmt_rate1(m$balanced_accuracy)))
    )
  })

  output$confusion <- renderUI({
    m <- metrics()
    tags$table(
      class = "confusion",
      tags$thead(tags$tr(tags$th(""), tags$th(class = "text-end", "Predicted event"), tags$th(class = "text-end", "Predicted other"))),
      tags$tbody(
        tags$tr(tags$th("Actual event"), tags$td(fmt_count(m$tp)), tags$td(fmt_count(m$fn))),
        tags$tr(tags$th("Actual other"), tags$td(fmt_count(m$fp)), tags$td(fmt_count(m$tn)))
      )
    )
  })

  output$used_imp_title <- renderUI({
    imp <- used_importance(tree_rv())
    tags$span(class = "card-title-sm",
              if (nrow(imp)) sprintf("%s carries the most split improvement in this tree", imp$variable[1])
              else "No splits yet")
  })
  output$used_importance <- renderUI(used_importance_html(used_importance(tree_rv())))

  leaves_df <- reactive({
    md <- model_data()
    tab <- leaf_table(tree_rv(), md$y)
    tab$yes_rate <- round(tab$yes_rate, 4)
    names(tab)[names(tab) == "n_yes"] <- paste0("n_", md$positive)
    tab
  })
  output$leaf_table <- renderDT({
    tab <- leaves_df()
    show <- tab
    show$yes_rate <- sprintf("%.1f%%", 100 * show$yes_rate)
    names(show) <- c("Leaf", "Depth", "n", names(tab)[4], "n_other", "Rate", "Rule")
    ar <- node_assess(tree_rv(), model_data(), rules())
    show$Note <- ifelse(ar$too_small[match(show$Leaf, ar$id)], "Too small to act on", "")
    datatable(show, rownames = FALSE, selection = "single",
              options = list(pageLength = 10, scrollX = TRUE, dom = "ftip", order = list(list(7, "asc"), list(5, "desc"))))
  })
  observeEvent(input$leaf_table_rows_selected, {
    i <- input$leaf_table_rows_selected
    if (length(i) == 1L) set_selected(leaves_df()$leaf[[i]])
  })
  output$download_leaves <- downloadHandler(
    filename = function() "attrition_tree_leaves.csv",
    content = function(file) utils::write.csv(leaves_df(), file, row.names = FALSE)
  )
  output$download_nodes <- downloadHandler(
    filename = function() "attrition_tree_nodes_rules.csv",
    content = function(file) utils::write.csv(node_export_table(tree_rv(), model_data(), rules()), file, row.names = FALSE)
  )
}

shinyApp(ui, server)
