.libPaths(c("~/R/library", .libPaths()))
suppressPackageStartupMessages({library(rpart); library(pROC)})
SEED <- 20261008
d0 <- read.csv("/workspace/projects/ibm-hr-attrition/data/WA_Fn-UseC_-HR-Employee-Attrition.csv", fileEncoding="UTF-8-BOM", stringsAsFactors=TRUE)
d0$Attrition <- factor(d0$Attrition, levels=c("No","Yes"))
drop <- c("EmployeeNumber","EmployeeCount","Over18","StandardHours","DailyRate","HourlyRate","MonthlyRate")
d <- d0[, setdiff(names(d0), drop)]
set.seed(SEED); idx_tr <- unlist(lapply(split(seq_len(nrow(d)), d$Attrition), function(ix) sample(ix, round(0.7*length(ix)))))
tr <- d[sort(idx_tr),]; te <- d[-idx_tr,]
wilson <- function(x, n, z=1.959964) { p <- x/n; c((p + z^2/(2*n) - z*sqrt(p*(1-p)/n + z^2/(4*n^2)))/(1+z^2/n), (p + z^2/(2*n) + z*sqrt(p*(1-p)/n + z^2/(4*n^2)))/(1+z^2/n)) }
rt <- function(y) { x <- sum(y=="Yes"); n <- length(y); if(!n) return("   -   "); ci <- wilson(x,n); sprintf("%3d/%-4d %5.1f%% [%4.1f,%5.1f]", x, n, 100*x/n, 100*ci[1], 100*ci[2]) }
low <- d$MonthlyIncome < 2475
cat("== Confounding: income<2475 vs JobLevel (full data) ==\n"); print(table(LowInc=low, JobLevel=d$JobLevel))
cat("JobLevel 1 income range:", range(d$MonthlyIncome[d$JobLevel==1]), " JobLevel 2 range:", range(d$MonthlyIncome[d$JobLevel==2]), "\n")
cat("\nAge band x low income:\n"); ab <- cut(d$Age, c(17,24,29,34,44,60)); print(table(LowInc=low, Age=ab))
cat("\nTotalWorkingYears band x low income:\n"); tb <- cut(d$TotalWorkingYears, c(-1,1,3,5,10,40)); print(table(LowInc=low, TWY=tb))
cat("\nYearsAtCompany band x low income:\n"); yb <- cut(d$YearsAtCompany, c(-1,1,3,5,10,40)); print(table(LowInc=low, YAC=yb))
cat("\nMedian age / TWY / YAC by low income:\n"); print(aggregate(cbind(Age,TotalWorkingYears,YearsAtCompany,JobLevel)~low, d, median))
cat("\nlow-income share who are JobLevel1:", mean(d$JobLevel[low]==1), "; age<30:", mean(d$Age[low]<30), "; TWY<=3:", mean(d$TotalWorkingYears[low]<=3), "\n")
cat("\n== Attrition within JobLevel 1 by income (full data) ==\n")
jl1 <- d$JobLevel==1
for (ot in c("Yes","No","All")) { m <- if (ot=="All") TRUE else d$OverTime==ot
  cat("OT=",ot," JL1&Inc<2475:", rt(d$Attrition[jl1&low&m]), "  JL1&Inc>=2475:", rt(d$Attrition[jl1&!low&m]), "  JL>=2:", rt(d$Attrition[!jl1&m]), "\n") }
cat("\nWithin JL1 & TWY<=3 / >3 by low income (full):\n")
for (t in c(TRUE,FALSE)) { mm <- jl1 & ((d$TotalWorkingYears<=3)==t); cat("TWY<=3 ==",t," low:", rt(d$Attrition[mm&low]), " notlow:", rt(d$Attrition[mm&!low]), "\n") }
cat("\nWithin OT=Yes & JL1, by TWY<=3 and low income:\n")
for (t in c(TRUE,FALSE)) { mm <- jl1 & d$OverTime=="Yes" & ((d$TotalWorkingYears<=3)==t); cat("TWY<=3 ==",t," low:", rt(d$Attrition[mm&low]), " notlow:", rt(d$Attrition[mm&!low]), "\n") }
cat("\nWithin OT=Yes & age<30 vs >=30 by low income:\n")
for (t in c(TRUE,FALSE)) { mm <- d$OverTime=="Yes" & ((d$Age<30)==t); cat("Age<30 ==",t," low:", rt(d$Attrition[mm&low]), " notlow:", rt(d$Attrition[mm&!low]), "\n") }
cat("\nLogistic (full data, descriptive): Attrition ~ OT*low + JobLevel1 + log(TWY+1) + Age + log(YAC+1)\n")
g <- glm(Attrition ~ OverTime + low + I(JobLevel==1) + log1p(TotalWorkingYears) + Age + log1p(YearsAtCompany), data=cbind(d, low=low), family=binomial)
print(round(cbind(OR=exp(coef(g)), exp(confint.default(g))), 2))
g0 <- glm(Attrition ~ OverTime + I(JobLevel==1) + log1p(TotalWorkingYears) + Age + log1p(YearsAtCompany), data=d, family=binomial)
cat("LR test adding low-income:", anova(g0, g, test="LRT")[2,"Pr(>Chi)"], "\n")
g2 <- glm(Attrition ~ OverTime + log(MonthlyIncome) + factor(JobLevel) + log1p(TotalWorkingYears) + Age + log1p(YearsAtCompany), data=d, family=binomial)
print(round(cbind(OR=exp(coef(g2)), exp(confint.default(g2))), 2))
cat("cor(log income, JobLevel)=", round(cor(log(d$MonthlyIncome), d$JobLevel),3), " cor(income,JobLevel)=", round(cor(d$MonthlyIncome,d$JobLevel),3), " cor(income,TWY)=", round(cor(d$MonthlyIncome,d$TotalWorkingYears),3), " cor(income,Age)=", round(cor(d$MonthlyIncome,d$Age),3), " cor(income,YAC)=", round(cor(d$MonthlyIncome,d$YearsAtCompany),3), "\n")
cat("R^2 of income on JobLevel (factor):", round(summary(lm(MonthlyIncome~factor(JobLevel), d))$r.squared,3), "\n")

cat("\n== Single vs StockOptionLevel ==\n"); print(table(d$MaritalStatus, d$StockOptionLevel))
cat("Full data, SOL0 & Single:", rt(d$Attrition[d$StockOptionLevel==0 & d$MaritalStatus=="Single"]), " SOL0 & Mar/Div:", rt(d$Attrition[d$StockOptionLevel==0 & d$MaritalStatus!="Single"]), " SOL>=1 (all Mar/Div):", rt(d$Attrition[d$StockOptionLevel>0]), "\n")
nd <- d$OverTime=="Yes" & d$MonthlyIncome>=2475
cat("In better-paid OT node (full): Single(all SOL0):", rt(d$Attrition[nd & d$MaritalStatus=="Single"]), "| Mar/Div SOL0:", rt(d$Attrition[nd & d$MaritalStatus!="Single" & d$StockOptionLevel==0]), "| Mar/Div SOL>=1:", rt(d$Attrition[nd & d$MaritalStatus!="Single" & d$StockOptionLevel>0]), "\n")
ndt <- te$OverTime=="Yes" & te$MonthlyIncome>=2475
cat("Same, TEST: Single:", rt(te$Attrition[ndt & te$MaritalStatus=="Single"]), "| Mar/Div SOL0:", rt(te$Attrition[ndt & te$MaritalStatus!="Single" & te$StockOptionLevel==0]), "| Mar/Div SOL>=1:", rt(te$Attrition[ndt & te$MaritalStatus!="Single" & te$StockOptionLevel>0]), "\n")
cat("Mar/Div with SOL0 count in node (full):", sum(nd & d$MaritalStatus!="Single" & d$StockOptionLevel==0), "\n")
cat("\nJobRole in single LabTech/Sales group vs income/JobLevel (full):\n")
sg <- nd & d$MaritalStatus=="Single"; hr <- d$JobRole %in% c("Laboratory Technician","Sales Executive","Sales Representative")
print(table(HighRiskRole=hr[sg], JobLevel=d$JobLevel[sg])); cat("median income hr / other:", median(d$MonthlyIncome[sg&hr]), median(d$MonthlyIncome[sg&!hr]), "\n")
print(table(d$JobRole[sg&hr]))

cat("\n== Benchmarks ==\n")
fml <- Attrition ~ .
lr <- glm(fml, data=tr, family=binomial)
p_lr <- predict(lr, te, type="response")
ctrl <- rpart.control(cp=0.01, minsplit=20, minbucket=7, maxdepth=5, xval=10)
set.seed(SEED); fit <- rpart(fml, data=tr, method="class", control=ctrl)
p_tree <- predict(fit, te, type="prob")[,"Yes"]
r_lr <- roc(te$Attrition, p_lr, levels=c("No","Yes"), direction="<", quiet=TRUE)
r_tr <- roc(te$Attrition, p_tree, levels=c("No","Yes"), direction="<", quiet=TRUE)
set.seed(SEED); ci_lr <- ci.auc(r_lr, method="bootstrap", boot.n=2000, progress="none")
cat("Logistic (27 predictors) test AUC:", round(auc(r_lr),3), "CI", round(as.numeric(ci_lr)[c(1,3)],3), "\n")
print(roc.test(r_lr, r_tr, method="delong"))
thr <- mean(tr$Attrition=="Yes"); ba <- function(p) { pr <- p>=thr; s <- mean(pr[te$Attrition=="Yes"]); sp <- mean(!pr[te$Attrition=="No"]); round(c(sens=s, spec=sp, ba=(s+sp)/2),3) }
cat("LR at base-rate thr:", ba(p_lr), "\n")
# 2-split pruned tree
p2 <- prune(fit, cp=0.0241); print(p2)
pp2 <- predict(p2, te, type="prob")[,"Yes"]; r2 <- roc(te$Attrition, pp2, levels=c("No","Yes"), direction="<", quiet=TRUE)
set.seed(SEED); ci2 <- ci.auc(r2, method="bootstrap", boot.n=2000, progress="none")
cat("2-split tree (OT + OT-yes income) test AUC:", round(auc(r2),3), "CI", round(as.numeric(ci2)[c(1,3)],3), " BA:", ba(pp2), "\n")
print(roc.test(r_tr, r2, method="delong"))
# OverTime only
po <- ifelse(te$OverTime=="Yes", 1, 0); ro <- roc(te$Attrition, po, levels=c("No","Yes"), direction="<", quiet=TRUE); cat("OverTime-only test AUC:", round(auc(ro),3), "\n")
# CV: same folds as Rowan
cvauc <- function(fitfun) { a <- c(); pooled <- c()
  for (r in 1:5) { set.seed(SEED + r); fold <- integer(nrow(d))
    for (cl in levels(d$Attrition)) { ix <- which(d$Attrition==cl); fold[ix] <- sample(rep(1:10, length.out=length(ix))) }
    oof <- numeric(nrow(d))
    for (k in 1:10) { oof[fold==k] <- fitfun(d[fold!=k,], d[fold==k,])
      a <- c(a, as.numeric(auc(roc(d$Attrition[fold==k], oof[fold==k], levels=c("No","Yes"), direction="<", quiet=TRUE)))) }
    pooled <- c(pooled, as.numeric(auc(roc(d$Attrition, oof, levels=c("No","Yes"), direction="<", quiet=TRUE)))) }
  c(mean=mean(a), sd=sd(a), pooled=mean(pooled)) }
cv_lr <- suppressWarnings(cvauc(function(a,b) predict(glm(fml, data=a, family=binomial), b, type="response")))
cv_tree <- cvauc(function(a,b) predict(rpart(fml, data=a, method="class", control=rpart.control(cp=0.01,minsplit=20,minbucket=7,maxdepth=5,xval=0)), b, type="prob")[,"Yes"])
cv_2 <- cvauc(function(a,b) predict(rpart(fml, data=a, method="class", control=rpart.control(cp=0.01,minsplit=20,minbucket=7,maxdepth=2,xval=0)), b, type="prob")[,"Yes"])
cv_ot <- cvauc(function(a,b) as.numeric(b$OverTime=="Yes"))
cat("CV AUC (5x10, Rowan's folds) logistic:", round(cv_lr,3), "\n tree (Rowan setting):", round(cv_tree,3), "\n depth-2 tree:", round(cv_2,3), "\n OverTime only:", round(cv_ot,3), "\n")
cat("\n== Sensitivity: refit including DailyRate/HourlyRate/MonthlyRate ==\n")
dd <- d0[, setdiff(names(d0), c("EmployeeNumber","EmployeeCount","Over18","StandardHours"))]
trr <- dd[sort(idx_tr),]; ter <- dd[-idx_tr,]
set.seed(SEED); fr <- rpart(fml, data=trr, method="class", control=ctrl)
cat("same top-3 levels?\n"); print(head(fr$frame[,c("var","n")], 8))
cat("rate vars in importance:", round(fr$variable.importance[c("DailyRate","HourlyRate","MonthlyRate")],2), "\n")
pr_ <- predict(fr, ter, type="prob")[,"Yes"]; cat("test AUC with rates:", round(auc(roc(ter$Attrition, pr_, levels=c("No","Yes"), direction="<", quiet=TRUE)),3), "\n")
for (v in c("DailyRate","HourlyRate","MonthlyRate")) cat(v, "univariate AUC (full):", round(auc(roc(d0$Attrition, d0[[v]], levels=c("No","Yes"), quiet=TRUE)),3), "\n")
cat("\n== Tenure/timing vars univariate (full) ==\n")
for (v in c("YearsAtCompany","YearsInCurrentRole","YearsWithCurrManager","YearsSinceLastPromotion","TotalWorkingYears","MonthlyIncome")) cat(v, round(auc(roc(d$Attrition, d[[v]], levels=c("No","Yes"), quiet=TRUE)),3), "\n")
cat("YearsAtCompany==0 n:", sum(d$YearsAtCompany==0), " rate:", rt(d$Attrition[d$YearsAtCompany==0]), "\n")
