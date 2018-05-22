#!/usr/bin/env Rscript
# 2018-04-25
# FOFRA 2018
# NIST
# Score-level fusion.
# Toy example of fusion, implementing the required API function call


library(plyr)
options(width=256)


errmsg <- function(...) {print(paste(..., collapse = " ")); TRUE}


# 1 -----------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# Example of a function that takes scores and identity labels from two named algorithms
# and writes parameters of a normalization and fusion scheme to permanent storage.
# The implementation of this function is developer-defined, as is the output directory contents.
# While this function is optional in FRPC - a developer may hand-craft the fusion scheme -
# it does that developers must provide a directory containing whatever data is need for fusion
prepare_and_write_verification_fuser <- function(x, directory)
{
   normalizer <- function(some) 
   {
      impostor <- some$ID1 != some$ID2
      data.frame(Algorithm = some$Algorithm[1],
                 position  = mean(some$Score[impostor]),  # vanilla z-norm
                 scale     =   sd(some$Score[impostor]))
   }
   score_calibration <- ddply(x, .(Algorithm), normalizer)

   filename <- sprintf("%s/z_norm.txt", directory)
   write.table(score_calibration, file = filename, quote=F, row.names=F)
   invisible(0)
}


# 2 -----------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# Example of a function that prepares and returns a function that will fuse scores
# from two or more verification algorithms. The function may access storage to do this.
# The implementation of this function is developer-defined.
# Input: Dataframe 
# Return: A function that fuses scores
read_verification_fuser <- function(directory)
{
   # fake data, from file, that parameterises fusion of scores from this specific pair of algorithms
   read_fusion_scheme <- function(filename)
   {
      file.exists(filename) || errmsg("Missing", filename) && q() # hard exit, should do something more informative
      read.table(filename, header=TRUE, stringsAsFactors=FALSE)
   }
   fusion_model_file <- sprintf("%s/z_norm.txt", directory)
   fusion_model <- read_fusion_scheme(fusion_model_file)
   K_expected <- nrow(fusion_model)

   fusion_by_sum_of_z_norms <- function(scores, algorithms = NULL)
   {
      K <- length(scores)  # number of algorithms to be fused
      (K != K_expected) && errmsg("Fail: Number of algorithms is unexpected") && q()
      normA <- (scores[1] - fusion_model$position[1]) / fusion_model$scale[1]
      normB <- (scores[2] - fusion_model$position[2]) / fusion_model$scale[2]
      normA + normB
   }
   fusion_by_sum_of_z_norms
}



# 3 -----------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# Example of a function that prepares and returns a function that will fuse candidate lists
# from two or more identification algorithms. The function may access storage to do this.
# The implementation of this function is developer-defined.
# Input: Dataframe 
# Return: A function that fuses candidate lists
read_identification_fuser <- function(directory)
{
   # in this toy example ignore the input directory entirely - no model needed!

   fuse_clists <- function(clists, algorithms = NULL)
   {
      c1 <- clists[[1]]
      c2 <- clists[[2]]

      # unite the two lists, this will produce NA values where IDs are not present on both lists
      cm <- merge(c1, c2, by="hypothesized_ids", all=TRUE)
      cm$scores.x <- ifelse(is.na(cm$scores.x), 1, cm$scores.x)
      cm$scores.y <- ifelse(is.na(cm$scores.y), 1, cm$scores.y)

      # product of score fusion.
      p <- data.frame(scores = cm$scores.x * cm$scores.y, hypothesized_ids = cm$hypothesized_ids)
      ii <- order(p$scores, decreasing=TRUE)
      p[ii,]   # return fused candidate list in reducing order of scores
   }

   fuse_clists
}


# 4 -----------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# Prepare some synthetic scores from two faux recognition algorithms, just random numbers
# with the genuine scores shifted right somewhat
n <- 20000
genuine <- runif(n) > 0.92
ids1 <- 1:n; ids2 <- ifelse(genuine, ids1, ids1 + n)

pluto_scores <- rnorm(n, mean=3,  sd=0.2); pluto_scores[genuine] <- pluto_scores[genuine] + 0.5
venus_scores <- rnorm(n, mean=50, sd=2);   venus_scores[genuine] <- venus_scores[genuine] + 7.0
pluto_name   <- "Pluto_University"
venus_name   <- "Venus_Corporation"

training <- data.frame(Score = c(pluto_scores, venus_scores),
                       ID1 = c(ids1, ids1),
                       ID2 = c(ids2, ids2),
                       Algorithm = c(rep(pluto_name, length(pluto_scores)),
                                     rep(venus_name, length(venus_scores))))

# 5 -----------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# TRAINING: Compute and store a fusion scheme for scores from these two algorithms
#           This function is not required in FRPC 2018. It is present here simply to
#           as a simple example of what a models directory might contain
prepare_and_write_verification_fuser(training, "nist/models/score_level/pluto_venus")


# 6 -----------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# INITIALIZATION: Read previously computed fusion calibration information and get a function that does fusion
pluto_venus_fuser  <- read_verification_fuser("nist/models/score_level/pluto_venus")


# EXECUTION: Fuse the scores - this function is not permitted to know whether a score is genuine or impostor
#            But here use the training data for testing! In FPRC, scores from disjoint sets will be used
nist_wrapper <- function(ii) { onevec <- c(pluto_scores[ii], venus_scores[ii]); pluto_venus_fuser(onevec) }
pluto_venus_scores <- sapply(1:n, nist_wrapper)
print(summary(pluto_venus_scores))

# ACCURACY:  Compute DET points from arbitrary scores and a logical mask indicating which are genuine
compute_det <- function(scores, genuine, false_match_of_interest = c(0.001, 0.01, 0.1))
{
   thresholds <- -as.numeric(quantile(-scores[!genuine], false_match_of_interest))
   compute_det_one_point <- function(t) data.frame(threshold = t,
                                                   fmr = sum(scores[!genuine] >= t) / sum(!genuine),
                                                   fnmr = sum(scores[genuine] <  t) / sum(genuine))
   ldply(thresholds, compute_det_one_point)
}
print(c("DET for", pluto_name, "alone")); print(compute_det(pluto_scores, genuine))
print(c("DET for", venus_name, "alone")); print(compute_det(venus_scores, genuine))
print(c("DET for fusion of ", pluto_name, "and", venus_name)); print(compute_det(pluto_venus_scores, genuine))


# 7 -----------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# Exercise fusion of candidate lists from one-to-many identification
L <- 20

# generate two synthetic score lists
cc1 <- data.frame(scores = sort(5 + runif(L), decreasing=TRUE), hypothesized_ids = 101+(1:L))
cc2 <- data.frame(scores = sort(cc1$scores + rnorm(L, sd=0.2), decreasing=TRUE),
                 hypothesized_ids = sample(101:180, L))

nist_fuser <- read_identification_fuser("/dev/random")
newlist <- nist_fuser(list(cc1, cc2))
print(newlist)



