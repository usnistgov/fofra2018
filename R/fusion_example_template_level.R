#!/usr/bin/env Rscript
library(plyr)


errmsg <- function(...) {print(paste(..., collapse = " ")); TRUE}




# 1  ----------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# Example of a function that prepares and returns a function that will fuse templates
# from two or more verification algorithms. 
# Input: Dataframe 
# Output: A function than fuses scores
read_template_fuser <- function(directory)
{
   # fake data, from file, that parameterises fusion of scores from this specific pair of algorithms
   read_fusion_scheme <- function(filename)
   {
      file.exists(filename) || errmsg("Missing", filename) && q() # hard exit, should do something more informative
      read.table(filename, header=FALSE, stringsAsFactors=FALSE)
   }
   fusion_model_file <- sprintf("%s/t_concatenator.txt", directory)
   fusion_model <- read_fusion_scheme(fusion_model_file)
   K_expected <- fusion_model[1,1]  # single integer in this file

   fusion_by_naive_concatenation <- function(templates)
   {
      K <- length(templates)  # number of algorithms to be fused
      (K != K_expected) && errmsg("Fail: unexpected number of inputs to template fuser") && q()

      # we don't check that each template has the expected length. just rely on the caller
      # to pass in the correct templates in the correct order. some error checking might be valuable...
      unlist(templates)  # i.e. concatenate c(templates[[1]], templates[[2]], ... )
   }
   fusion_by_naive_concatenation
}


# 2  ----------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# Example of a function that prepares and returns a function that will compare two templates,
# in FRPC 2018, two fused templates.  The choice of metric is generally non-trivial and must be
# tailored to the particular fusion scheme. Here it is a generic L1 norm.
read_template_verifier <- function(directory)
{
   L1 <- function(a, b) sum(abs(a - b))

   # convert some distance score to a similarity score because
   # all verifiers must return non-negative similarity scores
   distance_to_similarity <- function(d) { 100 / (1 + d) }

   # ignore the input directory! simply return an L1 norm
   template_comparator <- function(enrollment, verification) distance_to_similarity(L1(enrollment, verification))
}



# 3  ----------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# Example of a function that prepares and returns a list. The list has two elements.
# The first is a function that constructs a gallery from N templates and N identity labels.
# The second is function that executes a one to many search of a new (fused) template against the gallery
read_template_identifier <- function(dir)
{
   gallery <- matrix()
   ids <- vector()

   L1 <- function(a, b) sum(abs(a - b))
   distance_to_similarity <- function(d) { 100 / (1 + d) }

   build_gallery <- function(gvectors, gids, N, Nfeatures)
   {
      gallery <<- gvectors
      ids <<- gids
   }

   search_gallery <- function(probe, L = 20)  # return top L candidates, default 20
   {
      # gallery has N columns for N enrolled faces, Nfeatures rows i.e. dimensionality of feature vector
      # compare probe against each gallery entry
      compare <- function(ii) { distance_to_similarity(L1(gallery[,ii], probe)) }
      scores <- sapply(1:ncol(gallery), compare)
      ordering <- order(scores, decreasing=TRUE)
      top <- ordering[1:L]
      data.frame(scores = scores[top], hypothesized_ids = ids[top]) # return a candidate_list
   }

   list(builder = build_gallery, searcher = search_gallery)
}


# 4  ----------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# Read a template fuser, and exercise it on dummy feature vectors
pluto_venus_fuser  <- read_template_fuser("nist/models/template_level")
pluto_dim <- 16; pluto_template <- rnorm(pluto_dim)
venus_dim <- 20; venus_template <- rexp(venus_dim)
fused_template <- pluto_venus_fuser(list(pluto_template, venus_template))


# 5  ----------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# Exercise the template comparator
Nfeatures <- length(fused_template)
e <- fused_template
v <- fused_template + rnorm(Nfeatures, sd=0.02)
nist_verifier <- read_template_verifier("/dev/random")
nist_verifier(e,v)


# 6  ----------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# Exercise gallery construction and search
# prepare a gallery from synthetic numbers
Nfeatures <- length(fused_template)
Npeople <- 28
gvectors <- matrix(rnorm(Npeople * Nfeatures), ncol=Npeople, nrow=Nfeatures)
gids <- 100 + 1:Npeople

nist_identifier <- read_template_identifier("/dev/null")
nist_identifier$builder(gvectors, gids, Npeople, Nfeatures)

probe <- fused_template
clist <- nist_identifier$searcher(probe)
print(clist)
