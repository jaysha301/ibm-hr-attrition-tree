.libPaths(c("~/R/library", .libPaths())); suppressPackageStartupMessages(library(pROC))
d0 <- read.csv("/workspace/projects/ibm-hr-attrition/data/WA_Fn-UseC_-HR-Employee-Attrition.csv", stringsAsFactors=TRUE)
d0$Attrition <- factor(d0$Attrition, levels=c("No","Yes"))
d <- d0[, setdiff(names(d0), c("EmployeeNumber","EmployeeCount","Over18","StandardHours","DailyRate","HourlyRate","MonthlyRate"))]
set.seed(20261008); idx <- unlist(lapply(split(seq_len(nrow(d)), d$Attrition), function(ix) sample(ix, round(0.7*length(ix))))); tr <- d[sort(idx),]; te <- d[-idx,]
y <- d$Attrition=="Yes"
nd <- d$OverTime=="Yes" & d$MonthlyIncome>=2475
S <- nd & d$MaritalStatus=="Single"; M0 <- nd & d$MaritalStatus!="Single" & d$StockOptionLevel==0; M1 <- nd & d$MaritalStatus!="Single" & d$StockOptionLevel>0
f <- function(a,b) fisher.test(matrix(c(sum(y[a]),sum(!y[a]),sum(y[b]),sum(!y[b])),2))$p.value
cat("Single vs MarDiv-SOL0 p=", round(f(S,M0),3), "; MarDiv SOL0 vs SOL>=1 p=", round(f(M0,M1),3), "\n")
cat("whole data: MarDiv SOL0 vs SOL>=1:", sum(y[d$MaritalStatus!="Single"&d$StockOptionLevel==0]), "/", sum(d$MaritalStatus!="Single"&d$StockOptionLevel==0), " vs ", sum(y[d$MaritalStatus!="Single"&d$StockOptionLevel>0]),"/",sum(d$MaritalStatus!="Single"&d$StockOptionLevel>0), "\n")
cat("phi OverTime vs Attrition:", round(cor(d$OverTime=="Yes", y),3), "\n")
cat("\nUnivariate rates (full) and point-biserial r:\n")
for (v in c("JobSatisfaction","EnvironmentSatisfaction","JobInvolvement","WorkLifeBalance","RelationshipSatisfaction")) { t <- tapply(y, d[[v]], mean); n <- table(d[[v]]); cat(sprintf("%-25s r=%6.3f  rates by level: %s\n", v, cor(d[[v]], y), paste(sprintf("%d:%.1f%%(n=%d)", as.integer(names(t)), 100*t, n), collapse="  "))) }
for (v in c("Age","DistanceFromHome","YearsWithCurrManager","TotalWorkingYears","YearsAtCompany","MonthlyIncome")) cat(sprintf("%-25s r=%6.3f\n", v, cor(d[[v]], y)))
cat("Test-set: JobSat=1 vs 2-4:", sum(te$Attrition[te$JobSatisfaction==1]=="Yes"),"/",sum(te$JobSatisfaction==1), "vs", sum(te$Attrition[te$JobSatisfaction>1]=="Yes"),"/",sum(te$JobSatisfaction>1), "\n")
cat("Test-set: EnvSat=1 vs 2-4:", sum(te$Attrition[te$EnvironmentSatisfaction==1]=="Yes"),"/",sum(te$EnvironmentSatisfaction==1), "vs", sum(te$Attrition[te$EnvironmentSatisfaction>1]=="Yes"),"/",sum(te$EnvironmentSatisfaction>1), "\n")
cat("Test-set: Age<30 vs >=30:", sum(te$Attrition[te$Age<30]=="Yes"),"/",sum(te$Age<30), "vs", sum(te$Attrition[te$Age>=30]=="Yes"),"/",sum(te$Age>=30), "\n")
cat("Test-set: Dist>=11 vs <11:", sum(te$Attrition[te$DistanceFromHome>=11]=="Yes"),"/",sum(te$DistanceFromHome>=11), "vs", sum(te$Attrition[te$DistanceFromHome<11]=="Yes"),"/",sum(te$DistanceFromHome<11), "\n")
cat("\nLogistic on train (27 predictors): selected terms\n")
g <- glm(Attrition~., data=tr, family=binomial); cf <- summary(g)$coefficients
print(round(cf[c("JobSatisfaction","EnvironmentSatisfaction","JobInvolvement","WorkLifeBalance","RelationshipSatisfaction","DistanceFromHome","Age","YearsWithCurrManager","OverTimeYes","MonthlyIncome","NumCompaniesWorked","YearsSinceLastPromotion"),],4))
