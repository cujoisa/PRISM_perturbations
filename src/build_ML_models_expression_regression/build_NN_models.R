#!/usr/bin/env Rscript

library(tidyverse)
library(here)
library(tidymodels)
library(tictoc)
library(doParallel)
library(argparse)

tic()

print(commandArgs())

parser <- ArgumentParser(description='Process input paramters')
parser$add_argument('--feature_num', default = 500, type="integer")
parser$add_argument('--hyper_slice', default = 1, type="integer")
parser$add_argument('--fold_number', default = 1, type="integer")

args = parser$parse_args()
print(sprintf('Hyper: %03d, Fold: %02d',args$hyper_slice,args$fold_number))

dir.create(here('results/single_model_expression_regression/', 
								sprintf('NN_param_scan_%dfeat/',args$feature_num)), showWarnings = F)

output_file = here('results/single_model_expression_regression/', 
									 sprintf('NN_param_scan_%dfeat/',args$feature_num),
									 sprintf('hyper%03d_fold%02d.rds',args$hyper_slice,args$fold_number))

binarized_viability_CV = read_rds(here('results/single_model_expression_regression',
																			 sprintf('CV_splits_%dfeat/',args$feature_num),
																			 sprintf('%02d.rds',args$fold_number)))

###############################################################################
# Build Models
###############################################################################

PRISM_klaeger_recipe = recipe(target_viability ~ ., binarized_viability_CV$splits[[1]]$data) %>%
	update_role(-starts_with("act_"),
							-starts_with("exp_"),
							-starts_with("dep_"),
							-starts_with("target_"), new_role = "id variable") %>%
	step_BoxCox(all_predictors())%>%
	step_normalize(all_predictors()) %>%
	prep()

library(keras)
reticulate::use_condaenv('tf-gpu',required =T)

NN_spec <- mlp(epochs = 100, hidden_units = 5, dropout = 0.1) %>%
	set_mode("regression") %>% 
	# Also set engine-specific `verbose` argument to prevent logging the results: 
	set_engine("keras", verbose = 0)

NN_wf <- workflow() %>%
	add_model(NN_spec) %>%
	add_recipe(PRISM_klaeger_recipe)

# model_results <- tune_grid(
# 	NN_wf,
# 	resamples = binarized_viability_CV,
# 	control = control_grid(save_pred = TRUE)
# ) %>% write_rds(output_file, compress = 'gz')
notifysendR::notify_send("done")
toc()