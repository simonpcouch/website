# the code that generated the raw data is at https://github.com/simonpcouch/evalthat/commit/5b9aded17c8f7240cc48e64072cbd78fddf27c88
# using the state of that repo at that commit
library(tidyverse)
library(here)

load(here("blog/2025-01-30-llm-biases/data/ggplot2_graded.rda"))

ggplot2_evals <- 
  ggplot2_graded %>% 
  unnest(result) %>% 
  unnest_wider(result) %>%
  pivot_longer(cols = `claude-3-5-sonnet-latest`:`qwen2.5-coder:14b`) %>%
  unnest_wider(value) %>%
  filter(!is.na(response)) %>%
  select(-judge) %>%
  mutate(
    config_a = unlist(config_a),
    config_b = unlist(config_b)
  ) %>% 
  rename(judge = name, response_judge = response) %>%
  mutate(
    choice = case_when(
      choice == "a" ~ config_a,
      choice == "b" ~ config_b,
      .default = NA_character_
    ),
    judge = case_when(
      judge == "claude-3-5-sonnet-latest" ~ "Claude claude-3-5-sonnet-latest",
      judge == "gpt-4o" ~ "OpenAI gpt-4o",
      judge == "qwen2.5-coder:14b" ~ "ollama qwen2.5-coder:14b"
    )
  ) %>%
  mutate(
    across(.cols = c(config_a, config_b, judge, choice), 
    ~case_when( 
      .x == "Claude claude-3-5-sonnet-latest" ~ "Claude Sonnet 3.5",
      .x == "OpenAI gpt-4o" ~ "OpenAI gpt-4o",
      .x == "ollama qwen2.5-coder:14b" ~ "Qwen2.5 14b"
    )
  )) %>%
  relocate(config_a, config_b, judge, choice, .before = everything())

ggplot2_evals

save(
  ggplot2_evals,
  file = here("blog/2025-01-30-llm-biases/data/ggplot2_evals.rda")
)
