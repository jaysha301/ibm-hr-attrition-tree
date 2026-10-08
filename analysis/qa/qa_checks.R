.libPaths(c("~/R/library", .libPaths()))
suppressPackageStartupMessages({library(rpart); library(pROC)})
SEED <- 20261008
d0 <- read.csv("/workspace/projects/ibm-hr-attrition/data/WA_Fn-UseC_-HR-Employee-Attrition.csv", fileEncoding="UTF-8-BOM", stringsAsFactors=TRUE)
id_const <- c("EmployeeNumber","EmployeeCount","Over18","StandardHours"); not_pay <- c("DailyRate","HourlyRate","MonthlyRate")
d <- d0[, setdiff(names(d0), c(id_const, not_pay))]
d$Attrition <- factor(d$Attrition, levels=c("No","Yes"))
set.seed(SEED)
idx_tr <- unlist(lapply(split(seq_len(nrow(d)), d$Attrition), function(ix) sample(ix, round(0.7*length(ix)))))
tr <- d[sort(idx_tr),]; te <- d[-idx_tr,]
ctrl <- rpart.control(cp=0.01, minsplit=20, minbucket=7, maxdepth=5, xval=10)
set.seed(SEED); fit <- rpart(Attrition~., data=tr, method="class", parms=list(split="gini"), control=ctrl)
wilson <- function(x, n, z=1.959964) { if (n==0) return(c(NA,NA)); p <- x/n
  c((p + z^2/(2*n) - z*sqrt(p*(1-p)/n + z^2/(4*n^2)))/(1+z^2/n), (p + z^2/(2*n) + z*sqrt(p*(1-p)/n + z^2/(4*n^2)))/(1+z^2/n)) }
fmt <- function(df, m, lab) { x <- sum(df$Attrition[m]=="Yes"); n <- sum(m); ci <- wilson(x,n)
  sprintf("%-8s %4d/%-4d = %5.1f%% [%5.1f, %5.1f]", lab, x, n, 100*x/n, 100*ci[1], 100*ci[2]) }
cat("== class balance ==\n"); for (df in list(d,tr,te)) cat(nrow(df), sum(df$Attrition=="Yes"), round(100*mean(df$Attrition=="Yes"),2), "\n")
cat("missing:", sum(is.na(d0)), " predictors:", ncol(d)-1, "\n")
segs <- list(
 "OT=No" = function(z) z$OverTime=="No",
 "OT=Yes" = function(z) z$OverTime=="Yes",
 "OT=Yes & Inc<2475" = function(z) z$OverTime=="Yes" & z$MonthlyIncome<2475,
 "OT=Yes & Inc>=2475" = function(z) z$OverTime=="Yes" & z$MonthlyIncome>=2475,
 "OT=No & Inc<1559" = function(z) z$OverTime=="No" & z$MonthlyIncome<1559,
 "OT=No & Inc>=1559" = function(z) z$OverTime=="No" & z$MonthlyIncome>=1559,
 "OT=No & Inc<2475" = function(z) z$OverTime=="No" & z$MonthlyIncome<2475,
 "OT=No & Inc>=2475" = function(z) z$OverTime=="No" & z$MonthlyIncome>=2475,
 "Inc<2475 (all)" = function(z) z$MonthlyIncome<2475,
 "Inc>=2475 (all)" = function(z) z$MonthlyIncome>=2475,
 "OT=Yes&Inc>=2475&Single" = function(z) z$OverTime=="Yes" & z$MonthlyIncome>=2475 & z$MaritalStatus=="Single",
 "OT=Yes&Inc>=2475&Mar/Div" = function(z) z$OverTime=="Yes" & z$MonthlyIncome>=2475 & z$MaritalStatus!="Single",
 "..Single&LabTech/Sales" = function(z) z$OverTime=="Yes" & z$MonthlyIncome>=2475 & z$MaritalStatus=="Single" & z$JobRole %in% c("Laboratory Technician","Sales Executive","Sales Representative"),
 "..Single&OtherRoles" = function(z) z$OverTime=="Yes" & z$MonthlyIncome>=2475 & z$MaritalStatus=="Single" & !(z$JobRole %in% c("Laboratory Technician","Sales Executive","Sales Representative")),
 "OT=Yes&Inc<2475&RelSat>=3" = function(z) z$OverTime=="Yes" & z$MonthlyIncome<2475 & z$RelationshipSatisfaction>=2.5,
 "OT=Yes&Inc<2475&RelSat<3" = function(z) z$OverTime=="Yes" & z$MonthlyIncome<2475 & z$RelationshipSatisfaction<2.5,
 "OT=No&Inc>=1559&TechDeg" = function(z) z$OverTime=="No" & z$MonthlyIncome>=1559 & z$EducationField=="Technical Degree",
 "OT=No&Inc>=1559&NotTech" = function(z) z$OverTime=="No" & z$MonthlyIncome>=1559 & z$EducationField!="Technical Degree")
cat("\n== segment rates (train / test / full) with Wilson 95% CI ==\n")
for (s in names(segs)) { f <- segs[[s]]; cat(sprintf("%-28s", s), fmt(tr,f(tr),"train"), " | ", fmt(te,f(te),"test"), " | ", fmt(d,f(d),"full"), "\n") }
cat("\n== Fisher tests in TEST for each reported split ==\n")
ft <- function(a,b,lab) { A <- te$Attrition[a]; B <- te$Attrition[b]
  m <- matrix(c(sum(A=="Yes"),sum(A=="No"),sum(B=="Yes"),sum(B=="No")),2); p <- fisher.test(m)$p.value
  cat(sprintf("%-40s test %d/%d vs %d/%d  diff=%.1f pts  Fisher p=%.4f\n", lab, sum(A=="Yes"), length(A), sum(B=="Yes"), length(B), 100*(mean(A=="Yes")-mean(B=="Yes")), p)) }
ft(segs[["OT=Yes"]](te), segs[["OT=No"]](te), "L1 OverTime Yes vs No")
ft(segs[["OT=Yes & Inc<2475"]](te), segs[["OT=Yes & Inc>=2475"]](te), "L2 OT=Yes: Inc<2475 vs >=")
ft(segs[["OT=No & Inc<1559"]](te), segs[["OT=No & Inc>=1559"]](te), "L2 OT=No: Inc<1559 vs >=")
ft(segs[["OT=Yes&Inc>=2475&Single"]](te), segs[["OT=Yes&Inc>=2475&Mar/Div"]](te), "L3 Single vs Mar/Div (better-paid OT)")
ft(segs[["..Single&LabTech/Sales"]](te), segs[["..Single&OtherRoles"]](te), "L4 LabTech/Sales vs other (single)")
ft(segs[["OT=Yes&Inc<2475&RelSat<3"]](te), segs[["OT=Yes&Inc<2475&RelSat>=3"]](te), "L3 RelSat<3 vs >=3 (low-paid OT)")
ft(segs[["OT=No&Inc>=1559&TechDeg"]](te), segs[["OT=No&Inc>=1559&NotTech"]](te), "L3 TechDeg vs not")

cat("\n== test performance ==\n")
p_te <- predict(fit, te, type="prob")[,"Yes"]; r <- roc(te$Attrition, p_te, levels=c("No","Yes"), direction="<", quiet=TRUE)
set.seed(SEED); cib <- ci.auc(r, method="bootstrap", boot.n=2000, progress="none")
cat("AUC", round(auc(r),4), "boot CI", round(as.numeric(cib)[c(1,3)],4), "\n")
thr <- mean(tr$Attrition=="Yes"); pr <- p_te>=thr
sens <- mean(pr[te$Attrition=="Yes"]); spec <- mean(!pr[te$Attrition=="No"])
cat("thr", round(thr,4), "sens", round(sens,4), "spec", round(spec,4), "BA", round((sens+spec)/2,4), " flagged:", sum(pr), "of", length(pr), "\n")
pr5 <- p_te>=0.5; cat("thr 0.5 BA", round((mean(pr5[te$Attrition=="Yes"])+mean(!pr5[te$Attrition=="No"]))/2,4), "\n")
cat("distinct test leaf probs:", length(unique(round(p_te,6))), "\n")

cat("\n== 1-SE rule robustness over 20 xval seeds (cp=0.01 tree) ==\n")
ose <- sapply(1:20, function(s) { set.seed(SEED+100+s); f <- rpart(Attrition~., data=tr, method="class", control=ctrl)
  ct <- f$cptable; i <- which.min(ct[,"xerror"]); thr <- ct[i,"xerror"]+ct[i,"xstd"]; c(min_ns=ct[i,"nsplit"], min_xerr=ct[i,"xerror"], ose_ns=ct[min(which(ct[,"xerror"]<=thr)),"nsplit"]) })
print(table(ose["ose_ns",])); print(summary(ose["min_xerr",])); print(table(ose["min_ns",]))

cat("\n== importance decomposition (primary vs surrogate credit) ==\n")
ff <- fit$frame; sp <- fit$splits; rows <- 1; recs <- list()
for (i in seq_len(nrow(ff))) { if (ff$var[i]=="<leaf>") next
  nc <- ff$ncompete[i]; ns <- ff$nsurrogate[i]; node <- rownames(ff)[i]
  pimp <- sp[rows,"improve"]; recs[[length(recs)+1]] <- data.frame(node=node, var=rownames(sp)[rows], type="primary", credit=pimp, adj=1)
  if (ns>0) for (j in (rows+nc+1):(rows+nc+ns)) recs[[length(recs)+1]] <- data.frame(node=node, var=rownames(sp)[j], type="surrogate", credit=pimp*sp[j,"adj"], adj=sp[j,"adj"])
  rows <- rows+1+nc+ns }
R <- do.call(rbind, recs)
tab <- aggregate(credit~var+type, R, sum); w <- reshape(tab, idvar="var", timevar="type", direction="wide"); w[is.na(w)] <- 0
w$total <- w$credit.primary + w$credit.surrogate; w <- w[order(-w$total),]
w$check_vi <- round(fit$variable.importance[w$var],3)
w$pct_total <- round(100*w$total/sum(w$total),1); w$pct_primary_only <- round(100*w$credit.primary/sum(w$credit.primary),1)
print(w, row.names=FALSE)
cat("\nsurrogates at income nodes (node 2 and 3):\n"); print(R[R$node %in% c("2","3") & R$type=="surrogate",], row.names=FALSE)
cat("\nsurrogates at root:\n"); print(R[R$node=="1" & R$type=="surrogate",], row.names=FALSE)
f0 <- rpart(Attrition~., data=tr, method="class", control=rpart.control(cp=0.01,minsplit=20,minbucket=7,maxdepth=5,xval=0,maxsurrogate=0))
cat("\nmaxsurrogate=0 refit: same structure?", identical(f0$frame$var, fit$frame$var), "\n"); print(round(f0$variable.importance,3))
print(round(100*f0$variable.importance/sum(f0$variable.importance),1))

cat("\n== bootstrap: root, income cutpoint in OT=Yes branch, primary-only top5 ==\n")
B <- 500; set.seed(SEED)
root <- character(B); cut3 <- rep(NA,B); var3 <- rep(NA,B); allinc <- list(); top5p <- list(); cut2 <- rep(NA,B); var2<-rep(NA,B)
getcut <- function(f, node) { fr <- f$frame; i <- which(rownames(fr)==node); if (!length(i) || fr$var[i]=="<leaf>") return(c(NA,NA))
  row <- 1 + sum(1 + fr$ncompete[seq_len(i-1)][fr$var[seq_len(i-1)]!="<leaf>"] + fr$nsurrogate[seq_len(i-1)][fr$var[seq_len(i-1)]!="<leaf>"])
  c(as.character(fr$var[i]), f$splits[row,"index"]) }
for (b in 1:B) { bi <- sample(nrow(tr), replace=TRUE)
  fb <- rpart(Attrition~., data=tr[bi,], method="class", control=rpart.control(cp=0.01,minsplit=20,minbucket=7,maxdepth=5,xval=0))
  root[b] <- as.character(fb$frame$var[1])
  if (root[b]=="OverTime") { yesnode <- if (levels(tr$OverTime)[fb$csplit[fb$splits[1,"index"],1]==1][1]=="No") "3" else "2"
    g <- getcut(fb, yesnode); var3[b] <- g[1]; cut3[b] <- as.numeric(g[2]) }
  # all MonthlyIncome primary cutpoints
  fr <- fb$frame; rr <- 1; cs <- c()
  for (i in seq_len(nrow(fr))) { if (fr$var[i]=="<leaf>") next; if (fr$var[i]=="MonthlyIncome") cs <- c(cs, fb$splits[rr,"index"]); rr <- rr+1+fr$ncompete[i]+fr$nsurrogate[i] }
  allinc[[b]] <- cs
  # primary-only importance
  rr <- 1; pv <- c()
  for (i in seq_len(nrow(fr))) { if (fr$var[i]=="<leaf>") next; v <- as.character(fr$var[i]); pv[v] <- sum(pv[v], fb$splits[rr,"improve"], na.rm=TRUE); rr <- rr+1+fr$ncompete[i]+fr$nsurrogate[i] }
  top5p[[b]] <- names(sort(pv, decreasing=TRUE))[1:min(5,length(pv))] }
print(round(sort(table(root)/B, decreasing=TRUE),3))
cat("Root=OverTime:", sum(root=="OverTime"), "; of those, OT=Yes child splits on:\n"); print(sort(table(var3), decreasing=TRUE))
c3 <- cut3[!is.na(var3) & var3=="MonthlyIncome"]
cat("OT=Yes child income cutpoint (n=", length(c3), "): quantiles\n"); print(quantile(c3, c(0,.05,.1,.25,.5,.75,.9,.95,1)))
cat("share within [2300,2700]:", round(mean(c3>=2300 & c3<=2700),3), " within +-$100 of 2475:", round(mean(abs(c3-2475)<=100),3), "\n")
print(table(cut(c3, c(0,2000,2300,2400,2500,2600,2700,3000,4000,6000,1e5), dig.lab=6)))
ai <- unlist(allinc); cat("\nAll MonthlyIncome primary cutpoints across 500 trees: n =", length(ai), "; trees with any income split:", sum(sapply(allinc,length)>0), "\n")
print(quantile(ai, c(0,.1,.25,.5,.75,.9,1)))
cat("\nPrimary-only top5 freq:\n"); print(round(sort(table(unlist(top5p))/B, decreasing=TRUE),3)[1:12])
# OT-yes subset best income split (bootstrap on train OT=Yes rows, single split)
oty <- tr[tr$OverTime=="Yes",]; set.seed(SEED); cs1 <- replicate(500, { bi <- sample(nrow(oty), replace=TRUE)
  f1 <- rpart(Attrition~MonthlyIncome, data=oty[bi,], method="class", control=rpart.control(cp=-1,maxdepth=1,minbucket=7,minsplit=20,xval=0,maxsurrogate=0,maxcompete=0)); if (nrow(f1$frame)<3) NA else f1$splits[1,"index"] })
cat("\nBest single income split within train OT=Yes rows, 500 bootstraps:\n"); print(quantile(cs1, c(0,.05,.1,.25,.5,.75,.9,.95,1), na.rm=TRUE))
print(table(cut(cs1, c(0,2000,2300,2400,2500,2600,2700,3000,4000,6000,1e5), dig.lab=6)))
saveRDS(list(c3=c3, cs1=cs1, root=root), "/tmp/qa_attr/boot.rds")
