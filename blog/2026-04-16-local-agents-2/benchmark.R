library(httr2)
library(jsonlite)

# -- config ------------------------------------------------------------------
ollama_model <- "gemma4:26b"
n_runs <- 5

# -- system prompt ------------------------------------------------------------
# Use side::kick()'s real system prompt for realistic context size.
# Download once if not cached locally.
prompt_path <- "system_prompt.md"
if (!file.exists(prompt_path)) {
  download.file(
    "https://raw.githubusercontent.com/simonpcouch/side/main/inst/agents/main.md",
    prompt_path
  )
}
system_prompt <- paste(readLines(prompt_path), collapse = "\n")

# Minimal tool definitions — just enough to be realistic about token count.
# These mirror the shape of side::kick()'s tools.
tools <- list(
  list(
    name = "read_text_file",
    description = "Read the contents of a text file at the given path.",
    input_schema = list(
      type = "object",
      properties = list(
        path = list(type = "string", description = "Absolute path to the file"),
        start_line = list(type = "integer", description = "First line to read (1-indexed)"),
        end_line = list(type = "integer", description = "Last line to read (1-indexed)")
      ),
      required = list("path")
    )
  ),
  list(
    name = "write_text_file",
    description = "Write content to a text file, creating it if needed.",
    input_schema = list(
      type = "object",
      properties = list(
        path = list(type = "string", description = "Absolute path to the file"),
        content = list(type = "string", description = "Content to write"),
        create_directories = list(type = "boolean", description = "Create parent dirs if needed")
      ),
      required = list("path", "content")
    )
  ),
  list(
    name = "shell",
    description = "Execute a shell command and return stdout/stderr.",
    input_schema = list(
      type = "object",
      properties = list(
        command = list(type = "string", description = "The shell command to run"),
        timeout = list(type = "integer", description = "Timeout in seconds")
      ),
      required = list("command")
    )
  ),
  list(
    name = "run_r_code",
    description = "Run R code in the current session and return the result.",
    input_schema = list(
      type = "object",
      properties = list(
        code = list(type = "string", description = "R code to evaluate")
      ),
      required = list("code")
    )
  ),
  list(
    name = "list_files",
    description = "List files in a directory, optionally filtered by glob pattern.",
    input_schema = list(
      type = "object",
      properties = list(
        path = list(type = "string", description = "Directory path"),
        pattern = list(type = "string", description = "Glob pattern to filter files"),
        recursive = list(type = "boolean", description = "Whether to list recursively")
      ),
      required = list("path")
    )
  ),
  list(
    name = "code_search",
    description = "Search for a pattern across files in the project.",
    input_schema = list(
      type = "object",
      properties = list(
        pattern = list(type = "string", description = "Regex pattern to search for"),
        path = list(type = "string", description = "Directory to search in"),
        file_pattern = list(type = "string", description = "Glob to filter files")
      ),
      required = list("pattern")
    )
  )
)

user_message <- "Please extract the input validation logic from the `fit()` method in R/model.R into a helper function called `check_fit_inputs()`. The validation is on lines 42-68."

# -- ollama benchmarking ------------------------------------------------------
# Ollama returns timing metadata in the final streamed chunk:
#   prompt_eval_count, prompt_eval_duration (ns),
#   eval_count, eval_duration (ns)

# Convert tools to ollama format (slightly different schema shape)
ollama_tools <- lapply(tools, function(tool) {
  list(
    type = "function",
    `function` = list(
      name = tool$name,
      description = tool$description,
      parameters = tool$input_schema
    )
  )
})

bench_ollama <- function(model, system, user_msg, tools, warm = FALSE) {
  if (!warm) {
    # Overwrite the KV cache with a short unrelated message so the benchmark
    # request won't hit the cached prefix. The model stays loaded in memory.
    try(
      request("http://localhost:11434/api/chat") |>
        req_body_json(list(
          model = model,
          messages = list(list(role = "user", content = "Say hi.")),
          stream = FALSE
        )) |>
        req_timeout(120) |>
        req_perform(),
      silent = TRUE
    )
  }

  body <- list(
    model = model,
    messages = list(
      list(role = "system", content = system),
      list(role = "user", content = user_msg)
    ),
    tools = tools,
    stream = FALSE
  )

  start <- proc.time()["elapsed"]
  resp <- request("http://localhost:11434/api/chat") |>
    req_body_json(body) |>
    req_timeout(300) |>
    req_perform()
  wall_time <- proc.time()["elapsed"] - start

  data <- resp_body_json(resp)

  prompt_tokens <- data$prompt_eval_count %||% NA
  prompt_ns <- data$prompt_eval_duration %||% NA
  eval_tokens <- data$eval_count %||% NA
  eval_ns <- data$eval_duration %||% NA

  list(
    prompt_tokens = prompt_tokens,
    input_throughput = if (!is.na(prompt_tokens) && !is.na(prompt_ns) && prompt_ns > 0) {
      prompt_tokens / (prompt_ns / 1e9)
    } else NA,
    ttft = if (!is.na(prompt_ns)) prompt_ns / 1e9 else NA,
    output_tokens = eval_tokens,
    output_toks = if (!is.na(eval_tokens) && !is.na(eval_ns) && eval_ns > 0) {
      eval_tokens / (eval_ns / 1e9)
    } else NA,
    wall_time = wall_time
  )
}

# -- persistence --------------------------------------------------------------
results_dir <- "benchmark_results"
if (!dir.exists(results_dir)) dir.create(results_dir)

save_result <- function(scenario, i, result) {
  path <- file.path(results_dir, sprintf("%s_%02d.json", scenario, i))
  writeLines(toJSON(result, auto_unbox = TRUE, pretty = TRUE), path)
  cat("    -> saved to", path, "\n")
}

# -- run benchmarks -----------------------------------------------------------
run_benchmarks <- function() {
  cat("=== Ollama:", ollama_model, "===\n")

  cat("\n-- Cold (no KV cache) --\n")
  ollama_cold <- lapply(seq_len(n_runs), function(i) {
    cat("  Run", i, "of", n_runs, "\n")
    res <- bench_ollama(ollama_model, system_prompt, user_message, ollama_tools, warm = FALSE)
    save_result("ollama_cold", i, res)
    res
  })

  cat("\n-- Warm (KV cache) --\n")
  # First request primes the cache
  bench_ollama(ollama_model, system_prompt, user_message, ollama_tools, warm = FALSE)
  ollama_warm <- lapply(seq_len(n_runs), function(i) {
    cat("  Run", i, "of", n_runs, "\n")
    res <- bench_ollama(ollama_model, system_prompt, user_message, ollama_tools, warm = TRUE)
    save_result("ollama_warm", i, res)
    res
  })

  # -- summarize ----------------------------------------------------------------
  median_of <- function(lst, field) median(sapply(lst, `[[`, field), na.rm = TRUE)

  cat("\n\n=== Results (medians over", n_runs, "runs) ===\n\n")

  cat(sprintf("%-30s %15s\n", "", ollama_model))
  cat(strrep("-", 46), "\n")

  cat(sprintf("%-30s %14.1f\n", "Input throughput (tok/s)", median_of(ollama_cold, "input_throughput")))
  cat(sprintf("%-30s %13.2fs\n", "TTFT (cold)", median_of(ollama_cold, "ttft")))
  cat(sprintf("%-30s %13.2fs\n", "TTFT (warm)", median_of(ollama_warm, "ttft")))
  cat(sprintf("%-30s %14.1f\n", "Output (tok/s)", median_of(ollama_cold, "output_toks")))
}

run_benchmarks()
