# will be "are_task_gemini_2_5"
# has old APIs and thus won't work "out of the box"
load("blog/2025-04-01-gemini-2-5-pro/tasks/are_task_gemini_2_5.rda")

are_task_gemini_2_5

# import a "shell" task "are_gemini_2_5_pro_new"
load("blog/2025-05-07-gemini-2-5-pro-new/tasks/are_gemini_2_5_pro_new.rda")

are_gemini_2_5_pro_old <- are_gemini_2_5_pro_new

updated_samples <- are_task_gemini_2_5$samples
updated_samples$id <- updated_samples$title
updated_samples$title <- NULL

are_gemini_2_5_pro_old$.__enclos_env__$private$samples <- updated_samples

testthat::local_mocked_bindings(
  translate_to_model_usage = function(...) {c()},
  .package = "vitals"
)

are_gemini_2_5_pro_old$measure()
are_gemini_2_5_pro_old$log()

save(
  are_gemini_2_5_pro_old,
  file = "blog/2025-05-07-gemini-2-5-pro-new/tasks/are_gemini_2_5_pro_old.rda"
)
