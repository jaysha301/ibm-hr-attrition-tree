# Quinn QA: independent checks of analysis/exec (Rowan's exec rework). Run from project root.
# Needs /tmp/qa_exec/boot_ps.rds (Rowan's bootstrap re-run with primary splits saved; identical outputs).
.libPaths(c("~/R/library", .libPaths())); suppressPackageStartupMessages(library(rpart))
d0 <- read.csv("data/WA_Fn-UseC_-HR-Employee-Attrition.csv", fileEncoding="UTF-8-BOM", stringsAsFactors=TRUE)
y <- d0$Attrition=="Yes"; N <- nrow(d0); L <- sum(y); avg <- L/N
cat("N", N, "L", L, "rate", round(100*avg,3), "\n")
set.seed(20261008); idx <- unlist(lapply(split(seq_len(N), d0$Attrition), function(ix) sample(ix, round(0.7*length(ix)))))
te <- !(seq_len(N) %in% idx); cat("test n", sum(te), "test leavers", sum(y&te), round(100*mean(y[te]),2), "\n")
W <- function(x,n){z<-1.959964;p<-x/n;dd<-1+z^2/n;c0<-(p+z^2/(2*n))/dd;h<-z*sqrt(p*(1-p)/n+z^2/(4*n^2))/dd;c(c0-h,c0+h)}
G <- with(d0, list(
 ot_yes=OverTime=="Yes", ot_no=OverTime=="No", inc_boot=MonthlyIncome<3500, inc_lt2500=MonthlyIncome<2500,
 inc_lt3000=MonthlyIncome<3000, inc_lt4000=MonthlyIncome<4000, ot_inc_boot=OverTime=="Yes"&MonthlyIncome<3500,
 tree_node_7=OverTime=="Yes"&MonthlyIncome<2807, tree_node_6=OverTime=="Yes"&MonthlyIncome>=2807,
 fulltree_node_7=OverTime=="Yes"&MonthlyIncome<3751.5, fulltree_node_6=OverTime=="Yes"&MonthlyIncome>=3751.5,
 twy_boot=TotalWorkingYears<2.5, age_boot=Age<33.5, jl1=JobLevel==1, single=MaritalStatus=="Single", sol0=StockOptionLevel==0,
 age_lt30=Age<30, age_lt25=Age<25, yac_lt2=YearsAtCompany<2, yac_le3=YearsAtCompany<=3, twy_le3=TotalWorkingYears<=3,
 travel_freq=BusinessTravel=="Travel_Frequently", role_salesrep=JobRole=="Sales Representative", role_labtech=JobRole=="Laboratory Technician",
 role_salesexec=JobRole=="Sales Executive", dept_sales=Department=="Sales", jobinv1=JobInvolvement==1, envsat1=EnvironmentSatisfaction==1,
 jobsat1=JobSatisfaction==1, wlb1=WorkLifeBalance==1, mgr_new=YearsWithCurrManager==0, ncw_ge5=NumCompaniesWorked>=5,
 dist_ge10=DistanceFromHome>=10, ot_inc2475=OverTime=="Yes"&MonthlyIncome<2475, ot_jl1=OverTime=="Yes"&JobLevel==1,
 ot_sol0=OverTime=="Yes"&StockOptionLevel==0, ot_single=OverTime=="Yes"&MaritalStatus=="Single", ot_age30=OverTime=="Yes"&Age<30,
 jl1_sol0=JobLevel==1&StockOptionLevel==0))
cand <- read.csv("analysis/exec/candidates.csv", stringsAsFactors=FALSE)
tab <- do.call(rbind, lapply(names(G), function(k){m<-G[[k]];n<-sum(m);x<-sum(m&y);ro<-sum(y&!m)/sum(!m)
 data.frame(id=k,n=n,x=x,lift=x/n/avg,wlo=W(x,n)[1],tn=sum(m&te),tx=sum(m&te&y),imp_pp=100*(x-n*0.1612)/N,imp_p=x-n*0.1612,
            imp_out_pp=100*(x-n*ro)/N,imp_out_p=x-n*ro)}))
mm <- merge(tab, cand[,c("id","n","leavers","lift","wilson_lo","test_n","test_leavers","impact_pp_to_avg","impact_people_to_avg","impact_pp_to_outside","impact_people_to_outside","stability_share","pass_all","status")], by="id")
mm$match <- with(mm, n.x==n.y & x==leavers & abs(lift.x-lift.y)<1e-9 & abs(wlo-wilson_lo)<1e-6 & tn==test_n & tx==test_leavers &
  abs(imp_pp-impact_pp_to_avg)<1e-9 & abs(imp_out_p-impact_people_to_outside)<1e-9)
cat("\nIndependent recompute:", sum(mm$match), "of", nrow(mm), "candidates match on n, leavers, lift, Wilson lo, test n/leavers, impacts\n")
print(mm[!mm$match, 1:6])
# rule re-application (no Wilson; stability from Rowan's file)
ta <- mean(y[te]); mm$my_pass <- with(mm, n.x>=100 & x>=24 & lift.x>=1.5 & tn>=30 & tx/tn>ta & stability_share>0.5)
mm$my_pass_wilson <- mm$my_pass & mm$wlo>0.1612
cat("verdict agreement (Rowan pass_all vs my rule w/o Wilson):", sum(mm$my_pass==mm$pass_all), "/43; with Wilson:", sum(mm$my_pass_wilson==mm$pass_all), "/43\n")
cat("Wilson check changes any verdict among lift>=1.5 groups?", any(mm$lift.x>=1.5 & mm$wlo<=0.1612), "\n")
cat("Lift boundary 1.40-1.60:\n"); print(mm[mm$lift.x>1.4 & mm$lift.x<1.6, c("id","n.x","x","lift.x")])
cat("Size boundary 90-110:\n"); print(mm[mm$n.x>=90 & mm$n.x<=110, c("id","n.x","x","tn")])
# overlap / union
a <- G$ot_yes; b <- G$inc_boot; u <- a|b
cat(sprintf("\nOverlap: both %d, leavers both %d; union %d (%.1f%%), leavers %d (%.1f%%), rate %.1f%%, impact %.3f pp / %.2f people; sum of separate = %.2f people\n",
 sum(a&b), sum(a&b&y), sum(u), 100*mean(u), sum(u&y), 100*sum(u&y)/L, 100*mean(y[u]), 100*(sum(u&y)-sum(u)*0.1612)/N, sum(u&y)-sum(u)*0.1612,
 (sum(a&y)-sum(a)*.1612)+(sum(b&y)-sum(b)*.1612)))
cat(sprintf("Lower-paid: JL1 %d of %d; median age %.1f vs %.1f; outside rates ot %.2f%% inc %.2f%%\n", sum(b&d0$JobLevel==1), sum(b), median(d0$Age[b]), median(d0$Age[!b]), 100*mean(y[!a]), 100*mean(y[!b])))
# ---------- bootstrap location of income splits (Rowan's 500 refits)
bp <- readRDS("/tmp/qa_exec/boot_ps.rds")$ps
loc <- t(sapply(bp, function(ps){ if(!nrow(ps)) return(c(any=F,root=F,lvl12=F,in_ot_yes=F,in_ot_no=F,other=F,inc_or_jl=F,pay_root_or_lvl1_companywide=F))
 inc <- ps[ps$var=="MonthlyIncome",]; anc <- function(nd){ out<-c(); m<-nd; while(m>1){p<-m%/%2; r<-ps[ps$node==p,]; out<-c(out, paste0(r$var,"|",r$left,"|",ifelse(m%%2==0,"L","R"))); m<-p}; out}
 br <- sapply(inc$node, function(nd){ if(nd==1) return("root"); a<-anc(nd); top<-a[length(a)]
   if(grepl("^OverTime",top)){ inNo <- (grepl("\\{No\\}",top)&grepl("\\|L$",top))|(grepl("\\{Yes\\}",top)&grepl("\\|R$",top)); if(inNo) "ot_no" else "ot_yes"} else "other"})
 c(any=nrow(inc)>0, root=any(br=="root"), lvl12=any(inc$node<=3), in_ot_yes=any(br=="ot_yes"), in_ot_no=any(br=="ot_no"), other=any(br=="other"),
   inc_or_jl=any(ps$var %in% c("MonthlyIncome","JobLevel")), pay_root_or_lvl1_companywide=any(br=="root") ) }))
cat("\nBootstrap (500): share of refits where MonthlyIncome is a primary split ...\n"); print(round(100*colMeans(loc),1))
cat("income split ONLY inside overtime=Yes branch:", round(100*mean(loc[,"any"]&loc[,"in_ot_yes"]&!loc[,"root"]&!loc[,"in_ot_no"]&!loc[,"other"]),1), "%\n")
cat("income at root OR in both overtime branches (i.e. company-wide pay split):", round(100*mean(loc[,"root"]|(loc[,"in_ot_yes"]&loc[,"in_ot_no"])),1), "%\n")
cuts <- unlist(lapply(bp, function(ps) ps$cut[ps$var=="MonthlyIncome"])); cat("income cuts: n", length(cuts), "share in [2500,4000]:", round(100*mean(cuts>=2500&cuts<=4000),1), "%; quantiles:\n"); print(quantile(cuts, c(.1,.25,.5,.75,.9)))
cat("root/level-1 income cuts quantiles:\n"); print(quantile(unlist(lapply(bp, function(ps) ps$cut[ps$var=="MonthlyIncome"&ps$node==1])), c(.1,.25,.5,.75,.9)))
# ---------- fixed bands: group-level stability (2000 bootstrap resamples) + train/test
set.seed(1); B <- 2000; bands <- seq(2500, 4000, 250)
bs <- replicate(B, { i <- sample(N, replace=TRUE); yy <- y[i]; inc <- d0$MonthlyIncome[i]; a2 <- mean(yy)
  sapply(bands, function(c) { m <- inc<c; c(n=sum(m), lift=mean(yy[m])/a2, x=sum(yy[m])) }) }, simplify="array")
tr <- !te
band_tab <- do.call(rbind, lapply(seq_along(bands), function(j){c0<-bands[j]; m<-d0$MonthlyIncome<c0
 data.frame(cut=c0, n=sum(m), leavers=sum(m&y), rate=100*mean(y[m]), lift=mean(y[m])/avg, rate_above=100*mean(y[!m]),
  train_rate=100*mean(y[m&tr]), test_n=sum(m&te), test_rate=100*mean(y[m&te]), test_rate_above=100*mean(y[!m&te]),
  boot_lift_ge1.5=100*mean(bs["lift",j,]>=1.5), boot_all_size_lift=100*mean(bs["lift",j,]>=1.5 & bs["n",j,]>=100 & bs["x",j,]>=24),
  boot_lift_p05=quantile(bs["lift",j,],.05), boot_rate_higher=100*mean(bs["lift",j,]>1))}))
cat("\nFixed income bands (full data; train/test; bootstrap 2000):\n"); print(format(band_tab, digits=3), row.names=FALSE)
# ---------- confound with JobLevel
jl <- d0$JobLevel==1
for (c0 in c(2475, 3000, 3500, 4000)) { lo <- d0$MonthlyIncome<c0
 cat(sprintf("JL1 & <%d: %d/%d = %.1f%% | JL1 & >=%d: %d/%d = %.1f%% | not-JL1 & <%d: %d/%d | not-JL1 & >=%d: %.1f%% (n %d)\n", c0, sum(jl&lo&y), sum(jl&lo), 100*mean(y[jl&lo]),
   c0, sum(jl&!lo&y), sum(jl&!lo), 100*mean(y[jl&!lo]), c0, sum(!jl&lo&y), sum(!jl&lo), c0, 100*mean(y[!jl&!lo]), sum(!jl&!lo))) }
lo <- d0$MonthlyIncome<3500
cat(sprintf("JL1 within test set: <3500 %d/%d (%.1f%%) vs >=3500 %d/%d (%.1f%%)\n", sum(jl&lo&y&te), sum(jl&lo&te), 100*mean(y[jl&lo&te]), sum(jl&!lo&y&te), sum(jl&!lo&te), 100*mean(y[jl&!lo&te])))
cat(sprintf("JL1 overall %d/%d = %.1f%%; lower-paid %d/%d = %.1f%%; JL1 or lower-paid %d; JL1 & lower-paid %d\n", sum(jl&y), sum(jl), 100*mean(y[jl]), sum(lo&y), sum(lo), 100*mean(y[lo]), sum(jl|lo), sum(jl&lo)))
dd <- transform(d0, yv=as.numeric(y), lowpay=as.numeric(MonthlyIncome<3500), JL=factor(JobLevel), jl1=as.numeric(JobLevel==1), linc=log(MonthlyIncome))
p <- function(f, nm){ s <- summary(glm(f, binomial, dd))$coef; cat(nm, ":", paste(sprintf("%s OR %.2f p=%.3g", rownames(s)[-1], exp(s[-1,1]), s[-1,4]), collapse="; "), "\n") }
cat("\nLogistic (full data, association only):\n")
p(yv ~ lowpay + jl1, "lowpay + JL1"); p(yv ~ lowpay + JL, "lowpay + JobLevel factor")
p(yv ~ linc + JL, "log income + JobLevel factor"); p(yv ~ lowpay + JL + TotalWorkingYears + Age + OverTime, "lowpay + JL + TWY + Age + OT")
p(yv ~ linc, "log income alone")
m <- dd[dd$JobLevel==1,]; s<-summary(glm(yv~linc, binomial, m))$coef; cat(sprintf("within JL1: log income OR %.2f p=%.3g (n %d)\n", exp(s[2,1]), s[2,4], nrow(m)))
cat("JL1 income range:", range(d0$MonthlyIncome[jl]), "; JL2+ min:", min(d0$MonthlyIncome[!jl]), "; cor(income, JobLevel)", round(cor(d0$MonthlyIncome, d0$JobLevel),3), "\n")
# test-set independence of cuts: lower-paid in training only with training-derived band
cat(sprintf("Train-only rates <3500: %.1f%% (n %d) vs %.1f%%\n", 100*mean(y[lo&tr]), sum(lo&tr), 100*mean(y[!lo&tr])))
# ---------- what-if: group-level bootstrap stability for every simple candidate (lift>=1.5 & n>=100 & leavers>=24 in resample)
set.seed(2); B2 <- 1000; ids <- setdiff(names(G), c("tree_node_6","tree_node_7","fulltree_node_6","fulltree_node_7"))
M <- sapply(G[ids], identity)
gs <- replicate(B2, { i <- sample(N, replace=TRUE); yy <- y[i]; a2 <- mean(yy); Mi <- M[i,,drop=FALSE]
  apply(Mi, 2, function(m) sum(m)>=100 & sum(yy[m])>=24 & mean(yy[m])/a2>=1.5) })
gl <- sort(rowMeans(gs), decreasing=TRUE)
cat("\nWhat-if group-level bootstrap share (size+lift hold in resample):\n"); print(round(100*gl[gl>0.3],1))
# ---------- pay x overtime cross-tab (full and test)
lo <- d0$MonthlyIncome<3500; ot <- d0$OverTime=="Yes"
for (s in list(list("full", rep(TRUE,N)), list("test", te), list("train", !te))) { k <- s[[2]]
 f <- function(m) sprintf("%d/%d=%.1f%%", sum(m&y&k), sum(m&k), 100*sum(m&y&k)/sum(m&k))
 cat(s[[1]], ": OT&low", f(ot&lo), "| OT&high", f(ot&!lo), "| noOT&low", f(!ot&lo), "| noOT&high", f(!ot&!lo), "\n") }
cat("excess leavers over 16.12% avg: OT&low", round(sum(ot&lo&y)-sum(ot&lo)*.1612,1), "OT&high", round(sum(ot&!lo&y)-sum(ot&!lo)*.1612,1),
    "noOT&low", round(sum(!ot&lo&y)-sum(!ot&lo)*.1612,1), "\n")
