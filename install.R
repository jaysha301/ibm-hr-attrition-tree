# Install the packages the Shiny app needs. The analysis/ script also uses rpart and pROC.
pkgs <- c("shiny", "bslib", "DT", "visNetwork", "htmlwidgets", "magrittr", "jsonlite", "rpart", "pROC")
missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  install.packages(missing, repos = "https://cloud.r-project.org")
} else {
  message("All packages already installed: ", paste(pkgs, collapse = ", "))
}
