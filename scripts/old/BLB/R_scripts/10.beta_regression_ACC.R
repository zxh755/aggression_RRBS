library(BiSeq)
library(stringr)
library(dplyr)
library(data.table)

###########################BETA REGRESSION#################################

# phenotype csv
setwd("/rds/projects/v/vianaj-genomics-brain-development/MATRICS/")
pheno <- as.data.frame(fread(file='BLBbrains_pheno.csv', stringsAsFactors = FALSE, header = TRUE))
pheno <- pheno[-which(pheno$ACC_ID=="-"),] # remove missing row for ACC

colData <- DataFrame(group = factor(pheno$Group), row.names = pheno$ACC_ID)

# cd
setwd("/rds/projects/v/vianaj-genomics-brain-development/MATRICS/bismark_methylation_extractor/")

# file names
files <- list.files(pattern="*ACC_r1_trimmed_bismark_bt2.bismark.cov")
names(files) <- str_match(Sys.glob("*ACC_r1_trimmed_bismark_bt2.bismark.cov"),paste0("BLB","(.*?.....)"))[,1]
# names(files)[[f]]

#####
identical(names(files), rownames(colData)) # should return true
#####

rrbs <- readBismark(files, colData = colData) #BSraw object

# rrbs small - to test out code
# rrbs.small <- rrbs[1:1000,]
rrbs.clust.unlim <- clusterSites(object = rrbs,
                                 groups = colData(rrbs)$group,
                                 perc.samples = 4/5,
                                 min.sites = 20,
                                 max.dist = 100)

# smoothing
ind.cov <- totalReads(rrbs.clust.unlim) > 0
quant <- quantile(totalReads(rrbs.clust.unlim)[ind.cov], 0.9) # coverage
rrbs.clust.lim <- limitCov(rrbs.clust.unlim, maxCov = quant) # smooth the methylation values of CpG sites within the clusters

# predicted meth
predictedMeth <- predictMeth(object = rrbs.clust.lim) # BSrel object with smoothed relative methylation levels for each CpG site within CpG clusters

betaResults <- betaRegression(formula = ~group,
                              link = "probit",
                              object = predictedMeth,
                              type = "BR")
print("betaResults:")
print(head(betaResults))

# predicted meth null

#you don't need to select columns, you can just use the predictedMeth and add a column to the group data where the caes and controls are mixed.
colData(predictedMeth)$group.null <- as.factor(c(rep(c('cByJ', 'cJ'), 5)))
print("colData(predictedMeth)")
print(colData(predictedMeth)) # and note the two columns. Before you used the real allocation of cByJ and cJ to run the betaregression, now you are making up a fake status of cByj and cJ for each sample so the p-values are normally distributed.
#the code below wasn't working because your new group wasn't a factor, it was still a string. makeVariogram works now.

betaResultsNull <- betaRegression(formula = ~group.null,
                                  link = "probit",
                                  object = predictedMeth,
                                  type="BR") #note I substituted predictedMethNull for predictedMeth - you can use the same methylation values as long as you use the made up group criteria (group.null)

vario <- makeVariogram(betaResultsNull)

# variogram
pdf("/rds/projects/v/vianaj-genomics-brain-development/MATRICS/bismark_methylation_extractor/boxplots/ACC/variogram_ACC.pdf")
plot(vario$variogram$v)
vario.sm <- smoothVariogram(vario, sill = 0.9)
lines(vario.sm$variogram[,c("h", "v.sm")],
      col = "red", lwd = 1.5)
grid()
dev.off()

# replace pValsList object (contains test results of resampled data) with test results of interest
vario.aux <- makeVariogram(betaResults, make.variogram=FALSE)
vario.sm$pValsList <- vario.aux$pValsList

# estimation of correlation of the Z scores between two locations
locCor <- estLocCor(vario.sm)
clusters.rej <- testClusters(locCor,
                             FDR.cluster = 0.1)
print("rejected clusters:")
clusters.rej$clusters.reject

# Trim significant CpG clusters
clusters.trimmed <- trimClusters(clusters.rej,
                                 FDR.loc = 0.05)
print("head(clusters.trimmed)")
head(clusters.trimmed)

# find DMRs
DMRs <- findDMRs(clusters.trimmed,
                 max.dist = 100,
                 diff.dir = TRUE)
print("DMRs")
DMRs

# DNA methylation values in each DMR
rowCols <- c("magenta", "blue")[as.numeric(colData(predictedMeth)$group)]

for(i in 1:length(DMRs)){
  pdf(paste0("/rds/projects/v/vianaj-genomics-brain-development/MATRICS/bismark_methylation_extractor/boxplots/ACC/DMR_",i,"_methylation_levels_scatter.pdf"))
  print("scatter plot", i)
  plotSmoothMeth(object.rel = predictedMeth,
                 region = DMRs[i],
                 groups = colData(predictedMeth)$group,
                 group.average = FALSE,
                 col = c("magenta", "blue"),
                 lwd = 1.5)
  legend("topright",
         legend=levels(colData(predictedMeth)$group),
         col=c("magenta", "blue"),
         lty=1, lwd = 1.5)
  dev.off()
}