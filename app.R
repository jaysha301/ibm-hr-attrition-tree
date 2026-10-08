# IBM HR attrition: interactive recursive partitioning (JMP Partition style).
# Run from this directory: shiny::runApp(".")

source(file.path("R", "partition.R"), local = FALSE)

bundled_csv_path <- function() {
  candidates <- c(
    file.path("data", "WA_Fn-UseC_-HR-Employee-Attrition.csv"),
    file.path("..", "data", "WA_Fn-UseC_-HR-Employee-Attrition.csv")
  )
  hit <- candidates[file.exists(candidates)]
  if (!length(hit)) stop("Bundled CSV not found. Expected data/WA_Fn-UseC_-HR-Employee-Attrition.csv")
  normalizePath(hit[[1]], mustWork = TRUE)
}

rate_color <- function(rate) {
  t <- pmin(pmax(rate, 0), 0.6) / 0.6
  r <- round(23 + t * (146 - 23))
  g <- round(70 + t * (43 - 70))
  b <- round(110 + t * (33 - 110))
  sprintf("#%02X%02X%02X", r, g, b)
}

short_label <- function(x, n = 42) {
  ifelse(nchar(x) <= n, x, paste0(substr(x, 1, n - 1), "…"))
}

ui <- bslib::page_navbar(
  title = "HR Attrition Partition",
  theme = bslib::bs_theme(bootswatch = "flatly", primary = "#16324F"),
  header = tags$head(tags$style(HTML("
    .note {
      background: #f8f1e7; border-left: 4px solid #b9770e;
      padding: 8px 12px; margin-bottom: 10px; font-size: 0.92rem;
    }
    .statline { font-size: 1.02rem; margin-bottom: 0.3rem; }
  "))),
  bslib::nav_panel(
    "Partition",
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        width = 320,
        tags$h5("Data"),
        fileInput("file", "Upload a CSV", accept = c(".csv", "text/csv")),
        actionButton("use_bundled", "Use bundled IBM data", class = "btn-outline-primary btn-sm"),
        textOutput("data_status"),
        tags$hr(),
        selectInput("target", "Target", choices = NULL),
        selectInput("positive", "Positive class", choices = NULL),
        checkboxInput("include_id", "Include ID and constant columns", FALSE),
        checkboxInput("as_cat", "Treat integers with ≤10 values as categorical", TRUE),
        selectizeInput(
          "predictors", "Predictors", choices = NULL, multiple = TRUE,
          options = list(plugins = list("remove_button"))
        ),
        helpText("EmployeeNumber, EmployeeCount, Over18 and StandardHours stay hidden unless the box above is checked. DailyRate, HourlyRate and MonthlyRate are unchecked at the start: they are not compensation."),
        tags$hr(),
        tags$h5("Tree controls"),
        radioButtons("criterion", "Impurity", choices = c(Gini = "gini", "Information (entropy)" = "information"), selected = "gini"),
        numericInput("minsplit", "Minimum rows to split a node", value = 20, min = 2, step = 1),
        numericInput("minbucket", "Minimum rows in each child", value = 7, min = 1, step = 1),
        numericInput("max_depth", "Maximum depth (root is 0)", value = 5, min = 1, max = 30, step = 1),
        numericInput("cp", "Complexity (minimum relative improvement)", value = 0.01, min = 0, max = 1, step = 0.001),
        actionButton("reset_tree", "Reset to root", class = "btn-outline-secondary btn-sm")
      ),
      tags$div(
        class = "note",
        "In-sample explorer, in the spirit of SAS JMP Partition. Metrics describe this same dataset; they are not a held-out test. Color is the positive-class rate (blue low, red high)."
      ),
      bslib::layout_columns(
        col_widths = c(7, 5),
        bslib::card(
          full_screen = TRUE,
          bslib::card_header("Tree"),
          visNetwork::visNetworkOutput("tree", height = "560px"),
          tags$small("Click a node, or use the list under the plot. Yellow border marks the selection.")
        ),
        bslib::card(
          bslib::card_header("Selected node"),
          uiOutput("node_summary"),
          selectInput("node_picker", "Jump to node", choices = "1")
        )
      ),
      bslib::card(
        bslib::card_header("Candidate splits at the selected node"),
        tags$p(class = "text-muted", "Every predictor is ranked by its best binary split on the rows in this node. Improvement is n × impurity reduction (the same scale rpart reports). Importance % is that improvement's share among predictors at this node."),
        DT::DTOutput("cand_table")
      ),
      bslib::card(
        bslib::card_header("Split the selected node"),
        bslib::layout_columns(
          col_widths = c(4, 4, 4),
          selectInput("custom_var", "Predictor", choices = NULL),
          uiOutput("custom_controls"),
          tags$div(
            actionButton("auto_split", "Auto-split this node", class = "btn-primary"),
            actionButton("apply_custom", "Apply custom split", class = "btn-primary"),
            actionButton("grow_branch", "Grow this branch", class = "btn-outline-primary"),
            actionButton("grow_full", "Grow full tree", class = "btn-outline-primary"),
            actionButton("prune", "Remove split", class = "btn-outline-danger")
          )
        ),
        helpText("Auto-split and Grow honor the size, depth and cp limits. A custom split is applied even when it breaks those limits, and missing values go to the right branch.")
      )
    )
  ),
  bslib::nav_panel(
    "Fit",
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(
        bslib::card_header("In-sample classification"),
        numericInput("threshold", "Probability threshold for a positive call", value = 0.5, min = 0, max = 1, step = 0.01),
        uiOutput("metrics_ui")
      ),
      bslib::card(
        bslib::card_header("Importance of splits actually used"),
        DT::DTOutput("importance_table"),
        tags$p(class = "text-muted", "Sum of improvement over the splits in the current tree. This is not a permutation importance.")
      )
    ),
    bslib::card(
      bslib::card_header("Leaves"),
      DT::DTOutput("leaf_table"),
      downloadButton("download_leaves", "Download leaf table")
    )
  ),
  bslib::nav_panel(
    "About",
    bslib::card(
      bslib::card_header("What this is"),
      tags$p("This app is an interactive recursive-partitioning tool for a binary outcome, modeled on the Partition platform in SAS JMP. It ships with IBM's fictional HR Analytics Employee Attrition sample so it runs with no upload."),
      tags$p("Pick a node, read how every predictor would split that node, then accept the automatic split or set your own cutpoint or level grouping. Prune a split to explore a different branch. Grow fills out the tree under the current stopping rules."),
      tags$h5("How a split is scored"),
      tags$ul(
        tags$li("Gini impurity is 1 − Σ p². Information uses binary entropy (log base 2)."),
        tags$li("Improvement = (rows in the node) × (parent impurity − sample-size-weighted child impurity). Relative improvement divides that by the root node's total impurity. The cp control is a minimum relative improvement, in the same spirit as rpart."),
        tags$li("Numeric predictors: the search tries every midpoint between adjacent distinct values. The left branch is value < cut."),
        tags$li("Categorical predictors: levels are ordered by the positive-class rate and the best prefix of that order is kept (the CART binary split). A custom split may use any subset of levels on the left."),
        tags$li("Rows with a missing predictor value are sent to the right branch.")
      ),
      tags$h5("What the fit numbers are not"),
      tags$p("Accuracy, AUC and the confusion counts are computed on the same rows the tree was grown on. A deep tree will look better than it predicts on new employees. For a held-out rpart fit on this sample, see analysis/ in the project repository."),
      tags$h5("Data"),
      tags$p("IBM HR Analytics Employee Attrition & Performance, a fictional workforce sample released by IBM data scientists. The Kaggle copy (pavansubhasht/ibm-hr-analytics-attrition-dataset) is published under CC0 1.0 Universal. This project vendors a public GitHub mirror of that file (nelson-wu/employee-attrition-ml) because Kaggle itself requires an account. 1,470 employees, 237 of whom have Attrition = Yes (16.1%)."),
      tags$h5("Defaults"),
      tags$p("EmployeeCount, EmployeeNumber, Over18 and StandardHours are dropped unless you include them (they are an identifier or a constant). DailyRate, HourlyRate and MonthlyRate start unchecked because they are not pay measures. Integer columns with 10 or fewer distinct values, such as satisfaction scores and job level, start as categorical; uncheck that option to split them with a numeric cut.")
    )
  )
)

server <- function(input, output, session) {
  source_mode <- reactiveVal("bundled")
  upload_path <- reactiveVal(NULL)
  upload_name <- reactiveVal(NULL)
  tree_rv <- reactiveVal(new_tree(1L))
  selected_node <- reactiveVal("1")
  var_choices <- reactiveVal(character())

  observeEvent(input$file, {
    req(input$file)
    upload_path(input$file$datapath)
    upload_name(input$file$name)
    source_mode("upload")
  })
  observeEvent(input$use_bundled, source_mode("bundled"))

  dataset <- reactive({
    path <- if (identical(source_mode(), "upload")) upload_path() else bundled_csv_path()
    validate(need(!is.null(path) && file.exists(path), "No CSV is available."))
    out <- tryCatch(read_hr_csv(path), error = function(e) e)
    validate(need(!inherits(out, "error"), paste("Could not read the CSV:", if (inherits(out, "error")) out$message else "")))
    validate(need(ncol(out) >= 2 && nrow(out) >= 2, "The CSV needs at least 2 columns and 2 rows."))
    out
  })

  output$data_status <- renderText({
    df <- dataset()
    label <- if (identical(source_mode(), "upload")) paste("Uploaded:", upload_name()) else "Bundled IBM HR sample"
    sprintf("%s · %s rows · %s columns", label, format(nrow(df), big.mark = ","), ncol(df))
  })

  observeEvent(dataset(), {
    df <- dataset()
    tgt <- isolate(input$target)
    if (is.null(tgt) || !tgt %in% names(df)) {
      tgt <- if ("Attrition" %in% names(df)) "Attrition" else names(df)[1]
    }
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
    updateSelectizeInput(session, "predictors", choices = cols, selected = sel, server = TRUE)
  }, ignoreInit = FALSE)

  model_data <- reactive({
    df <- dataset()
    tgt <- input$target
    pos <- input$positive
    preds <- input$predictors
    validate(need(!is.null(tgt) && tgt %in% names(df), "Choose a target."))
    validate(need(!is.null(pos) && nzchar(pos), "Choose the positive class."))
    validate(need(length(preds) >= 1, "Select at least one predictor."))
    preds <- intersect(preds, setdiff(names(df), tgt))
    validate(need(length(preds) >= 1, "Select at least one predictor other than the target."))
    keep <- !is.na(df[[tgt]]) & nzchar(as.character(df[[tgt]]))
    df <- df[keep, , drop = FALSE]
    y <- as.integer(as.character(df[[tgt]]) == pos)
    validate(need(length(unique(y)) == 2L, "The target needs exactly two classes."))
    types <- stats::setNames(
      vapply(preds, function(v) column_type(df[[v]], isTRUE(input$as_cat)), character(1)),
      preds
    )
    list(df = df, y = y, predictors = preds, types = types, target = tgt, positive = pos)
  })

  observeEvent(list(model_data(), input$criterion), {
    md <- tryCatch(model_data(), error = function(e) NULL)
    if (is.null(md)) return()
    tree_rv(new_tree(nrow(md$df)))
    selected_node("1")
  }, ignoreInit = FALSE)

  root_impurity_total <- reactive({
    md <- model_data()
    impurity_bin(md$y, input$criterion) * length(md$y)
  })

  cand <- reactive({
    md <- model_data()
    tree <- tree_rv()
    id <- selected_node()
    node <- get_node(tree, id)
    validate(need(!is.null(node), "Select a node."))
    candidate_splits(
      md$df, md$y, node$rows, md$predictors, md$types, input$criterion,
      minsplit = input$minsplit, minbucket = input$minbucket,
      max_depth = input$max_depth, cp = input$cp,
      node_depth = node$depth, root_impurity_total = root_impurity_total()
    )
  })

  observeEvent(tree_rv(), {
    tree <- tree_rv()
    ids <- names(tree$nodes)
    sel <- selected_node()
    if (!sel %in% ids) sel <- "1"
    labels <- vapply(ids, function(id) {
      nd <- tree$nodes[[id]]
      sprintf("Node %s · depth %d · n=%d%s", id, nd$depth, length(nd$rows),
              if (is_leaf(nd)) " · leaf" else " · split")
    }, character(1))
    names(ids) <- labels
    # selectInput choices: named vector, values are ids
    ch <- stats::setNames(ids, labels)
    updateSelectInput(session, "node_picker", choices = ch, selected = sel)
    if (!identical(selected_node(), sel)) selected_node(sel)
  }, ignoreNULL = FALSE)

  observeEvent(input$node_picker, {
    req(input$node_picker)
    if (!identical(input$node_picker, selected_node())) selected_node(input$node_picker)
  })

  observeEvent(input$tree_selected, {
    id <- as.character(input$tree_selected)
    if (length(id) == 1L && nzchar(id) && id %in% names(tree_rv()$nodes)) {
      if (!identical(id, selected_node())) selected_node(id)
    }
  })

  observe({
    vars <- cand()$table$variable
    prev <- isolate(var_choices())
    if (identical(vars, prev)) return()
    var_choices(vars)
    sel <- isolate(input$custom_var)
    if (is.null(sel) || !sel %in% vars) sel <- vars[[1]]
    updateSelectInput(session, "custom_var", choices = vars, selected = sel)
  })

  observeEvent(list(selected_node(), input$custom_var), {
    v <- input$custom_var
    req(v)
    md <- isolate(model_data())
    spec <- isolate(cand()$specs[[v]])
    type <- md$types[[v]]
    if (identical(type, "numeric")) {
      x <- md$df[[v]]
      rng <- range(x, na.rm = TRUE)
      val <- if (!is.null(spec) && is.finite(spec$cut)) spec$cut else mean(rng)
      updateNumericInput(session, "custom_cut", value = signif(val, 6), min = rng[[1]], max = rng[[2]])
    } else {
      present <- sort(unique(as.character(md$df[[v]][!is.na(md$df[[v]])])))
      sel <- if (!is.null(spec)) spec$left_levels else present[[1]]
      updateSelectizeInput(session, "custom_levels", choices = present, selected = sel, server = TRUE)
    }
  }, ignoreInit = FALSE)

  output$custom_controls <- renderUI({
    md <- model_data()
    v <- input$custom_var
    req(v, v %in% names(md$types))
    if (identical(md$types[[v]], "numeric")) {
      numericInput("custom_cut", "Left branch: value < cut", value = NA_real_)
    } else {
      selectizeInput("custom_levels", "Levels on the LEFT branch", choices = NULL, multiple = TRUE,
                     options = list(plugins = list("remove_button")))
    }
  })

  output$tree <- visNetwork::renderVisNetwork({
    md <- model_data()
    tree <- tree_rv()
    sel <- selected_node()
    ids <- names(tree$nodes)
    bg <- character(length(ids))
    border <- character(length(ids))
    lab <- character(length(ids))
    tip <- character(length(ids))
    depth <- integer(length(ids))
    width <- numeric(length(ids))
    for (i in seq_along(ids)) {
      nd <- tree$nodes[[ids[[i]]]]
      yy <- md$y[nd$rows]
      rate <- if (length(yy)) mean(yy) else 0
      bg[[i]] <- rate_color(rate)
      border[[i]] <- if (ids[[i]] == sel) "#F4D03F" else "#1C2833"
      width[[i]] <- if (ids[[i]] == sel) 4 else 1
      lab[[i]] <- sprintf("Node %s\nn=%d\n%s %.1f%%", ids[[i]], length(yy), md$positive, 100 * rate)
      tip[[i]] <- path_text(tree, ids[[i]])
      depth[[i]] <- nd$depth
    }
    nodes <- data.frame(
      id = ids, label = lab, title = tip, level = depth,
      color.background = bg, color.border = border, borderWidth = width,
      font.color = "white", shape = "box", stringsAsFactors = FALSE
    )
    from <- character()
    to <- character()
    elab <- character()
    etitle <- character()
    for (nd in tree$nodes) {
      if (is.null(nd$children) || is.null(nd$split)) next
      from <- c(from, nd$id, nd$id)
      to <- c(to, nd$children[[1]], nd$children[[2]])
      elab <- c(elab, short_label(nd$split$left_rule), short_label(nd$split$right_rule))
      etitle <- c(etitle, nd$split$left_rule, nd$split$right_rule)
    }
    edges <- data.frame(from = from, to = to, label = elab, title = etitle, stringsAsFactors = FALSE)
    visNetwork::visNetwork(nodes, edges, height = "560px", width = "100%") %>%
      visNetwork::visHierarchicalLayout(direction = "UD", sortMethod = "directed", levelSeparation = 110) %>%
      visNetwork::visOptions(nodesIdSelection = TRUE, selected = sel) %>%
      visNetwork::visInteraction(hover = TRUE, tooltipDelay = 60) %>%
      visNetwork::visEdges(smooth = FALSE, arrows = "to")
  })

  output$node_summary <- renderUI({
    md <- model_data()
    st <- node_stats(tree_rv(), md$y, selected_node(), md$positive)
    tags$div(
      tags$p(class = "statline", tags$strong(sprintf(
        "Node %s · %s · depth %d", st$id, if (st$leaf) "leaf" else "internal", st$depth
      ))),
      tags$p(class = "statline", sprintf(
        "n = %s · %s %s (%s) · other %s (%s)",
        format(st$n, big.mark = ","), md$positive, format(st$yes, big.mark = ","), fmt_pct(st$rate),
        format(st$no, big.mark = ","), fmt_pct(if (st$n) st$no / st$n else NA_real_)
      )),
      tags$p(tags$strong("Rule: "), st$path)
    )
  })

  output$cand_table <- DT::renderDT({
    tab <- cand()$table
    show <- data.frame(
      Variable = tab$variable,
      Type = tab$type,
      `Best left split` = tab$best_split,
      Improvement = round(tab$improvement, 2),
      `Relative improvement` = round(tab$relative_improvement, 4),
      Eligible = ifelse(tab$eligible, "yes", "no"),
      `Left n` = tab$n_left,
      `Left positive %` = round(100 * tab$yes_rate_left, 1),
      `Right n` = tab$n_right,
      `Right positive %` = round(100 * tab$yes_rate_right, 1),
      `Importance %` = round(tab$importance_pct, 1),
      check.names = FALSE, stringsAsFactors = FALSE
    )
    DT::datatable(
      show, rownames = FALSE, selection = "single",
      options = list(pageLength = 12, scrollX = TRUE, order = list(list(3, "desc")))
    )
  })

  observeEvent(input$cand_table_rows_selected, {
    i <- input$cand_table_rows_selected
    if (length(i) == 1L) {
      v <- cand()$table$variable[[i]]
      if (!identical(v, input$custom_var)) updateSelectInput(session, "custom_var", selected = v)
    }
  })

  current_spec <- function(md, node) {
    v <- input$custom_var
    type <- md$types[[v]]
    if (identical(type, "numeric")) {
      manual_spec(md$df, md$y, node$rows, v, "numeric", cut = input$custom_cut, criterion = input$criterion)
    } else {
      manual_spec(md$df, md$y, node$rows, v, "categorical",
                  left_levels = input$custom_levels, criterion = input$criterion)
    }
  }

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
    if (length(node$rows) < input$minsplit || spec$n_left < input$minbucket || spec$n_right < input$minbucket) {
      showNotification("Below the minimum size settings. The custom split was applied anyway.", type = "warning", duration = 6)
    }
    out <- apply_spec_split(tree, selected_node(), input$custom_var, spec)
    if (!out$ok) showNotification(out$message, type = "error") else {
      tree_rv(out$tree)
      showNotification(out$message, type = "message", duration = 3)
    }
  })

  observeEvent(input$auto_split, {
    md <- model_data()
    tab <- cand()$table
    elig <- tab[tab$eligible %in% TRUE, , drop = FALSE]
    if (!nrow(elig)) {
      showNotification("No predictor meets the size, depth and cp limits at this node. Relax the controls, or apply a custom split.", type = "warning", duration = 8)
      return()
    }
    v <- elig$variable[[1]]
    node <- get_node(tree_rv(), selected_node())
    spec <- attach_rows(cand()$specs[[v]], md$df, md$y, node$rows, v)
    out <- apply_spec_split(tree_rv(), selected_node(), v, spec)
    if (!out$ok) showNotification(out$message, type = "error") else {
      tree_rv(out$tree)
      showNotification(sprintf("Auto-split on %s (%s).", v, spec$left_rule), type = "message", duration = 4)
    }
  })

  observeEvent(input$prune, {
    tree <- tree_rv()
    node <- get_node(tree, selected_node())
    if (is.null(node) || is_leaf(node)) {
      showNotification("This node has no split to remove.", type = "message")
      return()
    }
    tree_rv(prune_node(tree, selected_node()))
  })

  observeEvent(input$grow_branch, {
    md <- model_data()
    tree <- auto_grow(
      tree_rv(), md$df, md$y, md$predictors, md$types, input$criterion,
      input$minsplit, input$minbucket, input$max_depth, input$cp,
      only_under = selected_node()
    )
    tree_rv(tree)
    showNotification(sprintf("Branch grown. The tree now has %d leaves.", length(leaf_ids(tree))), type = "message")
  })

  observeEvent(input$grow_full, {
    md <- model_data()
    tree <- auto_grow(
      new_tree(nrow(md$df)), md$df, md$y, md$predictors, md$types, input$criterion,
      input$minsplit, input$minbucket, input$max_depth, input$cp
    )
    tree_rv(tree)
    selected_node("1")
    showNotification(sprintf("Full tree grown: %d nodes, %d leaves.", length(tree$nodes), length(leaf_ids(tree))), type = "message")
  })

  observeEvent(input$reset_tree, {
    md <- model_data()
    tree_rv(new_tree(nrow(md$df)))
    selected_node("1")
  })

  fit_prob <- reactive({
    md <- model_data()
    predict_leaf_prob(tree_rv(), md$y)
  })

  output$metrics_ui <- renderUI({
    md <- model_data()
    pr <- fit_prob()
    m <- classification_metrics(md$y, pr$prob, threshold = input$threshold)
    tags$div(
      tags$p(class = "note", "These numbers reuse the rows the tree was just grown on."),
      tags$p(sprintf("Rows scored: %s", format(m$n, big.mark = ","))),
      tags$p(sprintf("Accuracy %.1f%%  ·  majority-class baseline %.1f%%", 100 * m$accuracy, 100 * m$baseline_accuracy)),
      tags$p(sprintf("Sensitivity %.1f%%  ·  specificity %.1f%%  ·  balanced accuracy %.1f%%",
                     100 * m$sensitivity, 100 * m$specificity, 100 * m$balanced_accuracy)),
      tags$p(sprintf("AUC %.3f  ·  Brier %.3f  ·  threshold %.2f", m$auc, m$brier, m$threshold)),
      tags$table(
        class = "table table-sm",
        tags$thead(tags$tr(tags$th(""), tags$th("Predicted positive"), tags$th("Predicted other"))),
        tags$tbody(
          tags$tr(tags$th("Actual positive"), tags$td(m$tp), tags$td(m$fn)),
          tags$tr(tags$th("Actual other"), tags$td(m$fp), tags$td(m$tn))
        )
      )
    )
  })

  output$importance_table <- DT::renderDT({
    imp <- used_importance(tree_rv())
    if (!nrow(imp)) imp <- data.frame(variable = character(), improvement = numeric(), importance_pct = numeric())
    show <- data.frame(
      Variable = imp$variable,
      Improvement = round(imp$improvement, 2),
      `Importance %` = round(imp$importance_pct, 1),
      check.names = FALSE
    )
    DT::datatable(show, rownames = FALSE, selection = "none", options = list(pageLength = 10, dom = "tip"))
  })

  leaves_df <- reactive({
    md <- model_data()
    tab <- leaf_table(tree_rv(), md$y)
    tab$yes_rate <- round(tab$yes_rate, 4)
    names(tab)[names(tab) == "n_yes"] <- paste0("n_", md$positive)
    tab
  })

  output$leaf_table <- DT::renderDT({
    DT::datatable(leaves_df(), rownames = FALSE, selection = "single", options = list(pageLength = 15, scrollX = TRUE))
  })

  observeEvent(input$leaf_table_rows_selected, {
    i <- input$leaf_table_rows_selected
    if (length(i) == 1L) {
      id <- as.character(leaves_df()$leaf[[i]])
      if (id %in% names(tree_rv()$nodes)) selected_node(id)
    }
  })

  output$download_leaves <- downloadHandler(
    filename = function() "attrition_tree_leaves.csv",
    content = function(file) utils::write.csv(leaves_df(), file, row.names = FALSE)
  )
}

shiny::shinyApp(ui, server)
