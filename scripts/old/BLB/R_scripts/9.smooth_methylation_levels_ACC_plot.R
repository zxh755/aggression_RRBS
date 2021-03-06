# install
#if (!requireNamespace("BiocManager", quietly = TRUE))
 #install.packages("BiocManager")

 #BiocManager::install("BiSeq")

library(BiSeq)
library(stringr)
library(dplyr)
library(data.table)

###########################TESTING GROUP EFFECTS#################################
# phenotype csv
setwd("/rds/projects/v/vianaj-genomics-brain-development/MATRICS/")
pheno <- as.data.frame(fread(file='BLBbrains_pheno.csv', stringsAsFactors = FALSE, header = TRUE))
pheno <- pheno[-which(pheno$ACC_ID=="-"),] # remove missing row for ACC

colData <- DataFrame(group = pheno$Group, row.names = pheno$ACC_ID)

# cd
setwd("/rds/projects/v/vianaj-genomics-brain-development/MATRICS/bismark_methylation_extractor/")

# file names
files <- list.files(pattern="*ACC_r1_trimmed_bismark_bt2.bismark.cov")
names(files) <- str_match(Sys.glob("*ACC_r1_trimmed_bismark_bt2.bismark.cov"),paste0("BLB","(.*?.....)"))[,1]
# names(files)[[f]]

rrbs <- readBismark(files, colData = colData) #BSraw object

# predicted meth
# BSraw object but restricted to CpG sites within CpG clusters:
rrbs.clust.unlim <- clusterSites(object = rrbs,
                                 groups = colData(rrbs)$group,
                                 perc.samples = 4/5,
                                 min.sites = 20,
                                 max.dist = 100)

# smoothing
ind.cov <- totalReads(rrbs.clust.unlim) > 0
quant <- quantile(totalReads(rrbs.clust.unlim)[ind.cov], 0.9) # coverage
rrbs.clust.lim <- limitCov(rrbs.clust.unlim, maxCov = quant) # smooth the methylation values of CpG sites within the clusters

predictedMeth <- predictMeth(object = rrbs.clust.lim) # BSrel object with smoothed relative methylation levels for each CpG site within CpG clusters

# subsetting rrbs
cByJ <- predictedMeth[, 1:5]
cJ <- predictedMeth[, 6:10]
mean.cByJ <- rowMeans(methLevel(cByJ))
mean.cJ <- rowMeans(methLevel(cJ))

# methylation plot
pdf(paste0("/rds/projects/v/vianaj-genomics-brain-development/MATRICS/bismark_methylation_extractor/boxplots/ACC/smooth_methylation_levels_ACC_plot.pdf"))
plot(mean.cByJ,
     mean.cJ,
     col = "blue",
     xlab = "Methylation in cByJ Samples (Non-aggressive)",
     ylab = "Methylation in cJ Samples (Aggressive)")
dev.off()